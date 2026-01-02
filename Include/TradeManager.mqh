//+------------------------------------------------------------------+
//|                                            TradeManager.mqh      |
//|                    Trade Management and Scaling System           |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "EntryManager.mqh"
#include "ExitManager.mqh"
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Trade Manager Class                                              |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    CEntryManager     *m_EntryManager;
    CExitManager      *m_ExitManager;
    CRiskManager      *m_RiskManager;
    
    // Trade tracking
    ulong             m_OpenTrades[];
    int               m_TradeCount;
    
    // Box tracking for open trades
    DarvasBox         m_TradeBoxes[];
    
    // Magic number
    int               m_MagicNumber;
    
public:
    CTradeManager();
    ~CTradeManager();
    
    bool              Initialize(CEntryManager *entryManager,
                                 CExitManager *exitManager,
                                 CRiskManager *riskManager,
                                 int magicNumber = 123456);
    
    bool              OpenTrade(const TradeEntry &entry, const DarvasBox &box);
    void              ManageOpenTrades();
    void              ProcessExits();
    bool              ScaleInTrade(ulong ticket, const DarvasBox &newBox);
    void              UpdateTradeBoxes();
    
    int               GetOpenTradeCount() { return m_TradeCount; }
    bool              HasOpenTrades() { return (m_TradeCount > 0); }
    
private:
    void              AddTrade(ulong ticket, const DarvasBox &box);
    void              RemoveTrade(ulong ticket);
    bool              FindTrade(ulong ticket, int &index);
    bool              CheckScaleInConditions(ulong ticket, const DarvasBox &newBox);
    void              UpdateTradeStatistics();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
    m_EntryManager = NULL;
    m_ExitManager = NULL;
    m_RiskManager = NULL;
    m_TradeCount = 0;
    m_MagicNumber = 123456;
    ArrayResize(m_OpenTrades, 0);
    ArrayResize(m_TradeBoxes, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CTradeManager::Initialize(CEntryManager *entryManager,
                               CExitManager *exitManager,
                               CRiskManager *riskManager,
                               int magicNumber = 123456)
{
    m_EntryManager = entryManager;
    m_ExitManager = exitManager;
    m_RiskManager = riskManager;
    m_MagicNumber = magicNumber;
    
    return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
bool CTradeManager::OpenTrade(const TradeEntry &entry, const DarvasBox &box)
{
    //--- CRITICAL: Check if we already have an open position - ONLY ONE POSITION AT A TIME
    int totalPositions = PositionsTotal();
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionSelectByTicket(ticket))
            {
                // Check if it's our symbol and our magic number
                if(PositionGetString(POSITION_SYMBOL) == _Symbol)
                {
                    if(PositionGetInteger(POSITION_MAGIC) == m_MagicNumber)
                    {
                        Print("OpenTrade BLOCKED: Already have open position. Ticket=", ticket);
                        return false; // Block opening new trade
                    }
                }
            }
        }
    }
    
    // Also check our internal tracking
    if(m_TradeCount > 0)
    {
        // Verify positions still exist
        for(int i = m_TradeCount - 1; i >= 0; i--)
        {
            if(!PositionSelectByTicket(m_OpenTrades[i]))
            {
                // Position closed, remove from tracking
                RemoveTrade(m_OpenTrades[i]);
            }
            else
            {
                // Position still open
                Print("OpenTrade BLOCKED: Internal tracking shows open trade. Ticket=", m_OpenTrades[i]);
                return false; // Block opening new trade
            }
        }
    }
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = entry.PositionSize;
    request.type = entry.IsLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(_Symbol, entry.IsLong ? SYMBOL_ASK : SYMBOL_BID);
    request.sl = entry.StopLoss;
    request.tp = entry.TakeProfit;
    request.deviation = 10;
    request.magic = m_MagicNumber;
    request.comment = "DarvasBoxEA Tier " + IntegerToString(entry.Tier);
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            // Get the position ticket
            if(PositionSelect(_Symbol))
            {
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                AddTrade(ticket, box);
                Print("Trade OPENED: Ticket=", ticket, ", Type=", entry.IsLong ? "LONG" : "SHORT",
                      ", Size=", entry.PositionSize);
                return true;
            }
        }
        else
        {
            Print("Trade OPEN FAILED: retcode=", result.retcode, ", comment=", result.comment);
        }
    }
    else
    {
        Print("OrderSend FAILED: retcode=", result.retcode, ", comment=", result.comment);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Manage open trades                                               |
//+------------------------------------------------------------------+
void CTradeManager::ManageOpenTrades()
{
    // First, clean up any closed positions from tracking
    for(int i = m_TradeCount - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(m_OpenTrades[i]))
        {
            // Position was closed externally, remove from tracking
            Print("Position CLOSED (external): Ticket=", m_OpenTrades[i], " - Removed from tracking");
            RemoveTrade(m_OpenTrades[i]);
        }
    }
    
    // If no positions, nothing to manage
    if(m_TradeCount == 0)
        return;
    
    // Update trade boxes
    UpdateTradeBoxes();
    
    // Process exits
    ProcessExits();
    
    // Check for scale-in opportunities (DISABLED for single-position mode)
    // Pyramiding should be disabled to maintain single position rule
    // for(int i = 0; i < m_TradeCount; i++)
    // {
    //     if(PositionSelectByTicket(m_OpenTrades[i]))
    //     {
    //         // Check if we can scale in
    //         // DISABLED: Only one position at a time
    //     }
    // }
    
    // Update statistics
    UpdateTradeStatistics();
}

//+------------------------------------------------------------------+
//| Process exits                                                    |
//+------------------------------------------------------------------+
void CTradeManager::ProcessExits()
{
    for(int i = m_TradeCount - 1; i >= 0; i--)
    {
        ulong ticket = m_OpenTrades[i];
        
        if(!PositionSelectByTicket(ticket))
        {
            // Trade closed, remove from tracking
            RemoveTrade(ticket);
            continue;
        }
        
        // Get associated box
        DarvasBox box = m_TradeBoxes[i];
        
        // Check for exits
        TradeExit exit;
        if(m_ExitManager != NULL)
        {
            if(m_ExitManager.ProcessTradeExit(ticket, box, PERIOD_CURRENT, exit))
            {
                // Execute exit
                if(exit.IsPartial)
                {
                    // Partial exit
                    double currentVolume = PositionGetDouble(POSITION_VOLUME);
                    double exitVolume = currentVolume * exit.ExitSize;
                    
                    MqlTradeRequest request = {};
                    MqlTradeResult result = {};
                    
                    request.action = TRADE_ACTION_DEAL;
                    request.position = ticket;
                    request.symbol = _Symbol;
                    request.volume = exitVolume;
                    request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                                   ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                    request.deviation = 10;
                    request.magic = m_MagicNumber;
                    
                    if(!OrderSend(request, result))
                    {
                        Print("Failed to open trade: ", result.retcode);
                    }
                }
                else
                {
                    // Full exit
                    MqlTradeRequest request = {};
                    MqlTradeResult result = {};
                    
                    request.action = TRADE_ACTION_DEAL;
                    request.position = ticket;
                    request.symbol = _Symbol;
                    request.volume = PositionGetDouble(POSITION_VOLUME);
                    request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                                   ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                    request.deviation = 10;
                    request.magic = m_MagicNumber;
                    
                    if(!OrderSend(request, result))
                    {
                        Print("Failed to open trade: ", result.retcode);
                    }
                    
                    RemoveTrade(ticket);
                }
            }
            
            // Update trailing stops
            m_ExitManager.UpdateTrailingStops(ticket, box);
            
            // Check breakeven
            m_ExitManager.CheckBreakevenStop(ticket, box);
        }
    }
}

//+------------------------------------------------------------------+
//| Scale in trade                                                   |
//+------------------------------------------------------------------+
bool CTradeManager::ScaleInTrade(ulong ticket, const DarvasBox &newBox)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    // Check scale-in conditions
    if(!CheckScaleInConditions(ticket, newBox))
        return false;
    
    // This would use EntryManager to create Tier 2 or Tier 3 entry
    // For now, simplified
    
    return false;
}

//+------------------------------------------------------------------+
//| Update trade boxes                                               |
//+------------------------------------------------------------------+
void CTradeManager::UpdateTradeBoxes()
{
    // This would detect new boxes and update tracking
    // For each open trade, track the current box
}

//+------------------------------------------------------------------+
//| Add trade to tracking                                            |
//+------------------------------------------------------------------+
void CTradeManager::AddTrade(ulong ticket, const DarvasBox &box)
{
    ArrayResize(m_OpenTrades, m_TradeCount + 1);
    ArrayResize(m_TradeBoxes, m_TradeCount + 1);
    
    m_OpenTrades[m_TradeCount] = ticket;
    m_TradeBoxes[m_TradeCount] = box;
    m_TradeCount++;
}

//+------------------------------------------------------------------+
//| Remove trade from tracking                                       |
//+------------------------------------------------------------------+
void CTradeManager::RemoveTrade(ulong ticket)
{
    int index;
    if(!FindTrade(ticket, index))
        return;
    
    // Shift arrays
    for(int i = index; i < m_TradeCount - 1; i++)
    {
        m_OpenTrades[i] = m_OpenTrades[i + 1];
        m_TradeBoxes[i] = m_TradeBoxes[i + 1];
    }
    
    m_TradeCount--;
    ArrayResize(m_OpenTrades, m_TradeCount);
    ArrayResize(m_TradeBoxes, m_TradeCount);
}

//+------------------------------------------------------------------+
//| Find trade index                                                 |
//+------------------------------------------------------------------+
bool CTradeManager::FindTrade(ulong ticket, int &index)
{
    for(int i = 0; i < m_TradeCount; i++)
    {
        if(m_OpenTrades[i] == ticket)
        {
            index = i;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check scale-in conditions                                        |
//+------------------------------------------------------------------+
bool CTradeManager::CheckScaleInConditions(ulong ticket, const DarvasBox &newBox)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    // Scale IN when:
    // 1. New higher box forms (for long)
    // 2. Pullback to 50% of recent move
    // 3. Multiple timeframe confirmation
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    
    if(isLong)
    {
        // New box should be higher
        if(newBox.Bottom > entryPrice)
            return true;
    }
    else
    {
        // New box should be lower
        if(newBox.Top < entryPrice)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update trade statistics                                          |
//+------------------------------------------------------------------+
void CTradeManager::UpdateTradeStatistics()
{
    // Update win/loss streaks for RiskManager
    // This would be called when trades close
}

//+------------------------------------------------------------------+
