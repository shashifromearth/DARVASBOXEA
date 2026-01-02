//+------------------------------------------------------------------+
//|                                        PositionManager.mqh       |
//|                    Precision Position Management Engine          |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Position Management Manager                                      |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
    double            m_BaseRiskPercent;   // Base risk (1%)
    bool              m_AllowPyramiding;   // Allow adding to winners
    int               m_MaxAddsPerTrade;  // Maximum adds (2)
    double            m_PyramidSizeRatio;   // Add size ratio (0.5)
    bool              m_UseCorrelationFilter; // Correlation filtering
    
    // Position tracking
    struct PositionData
    {
        ulong         Ticket;              // Trade ticket
        double        EntryPrice;          // Entry price
        double        InitialSize;         // Initial position size
        int           AddCount;            // Number of adds
        double        TotalSize;           // Total position size
        bool          IsLong;              // Trade direction
        DarvasBox     Box;                 // Associated box
        datetime      EntryTime;           // Entry time
        double        MaxProfit;           // Maximum profit achieved
    };
    
    PositionData      m_Positions[];
    int               m_PositionCount;
    
public:
    CPositionManager();
    ~CPositionManager();
    
    bool              Initialize(double baseRisk = 1.0,
                                bool allowPyramiding = true,
                                int maxAdds = 2,
                                double pyramidRatio = 0.5,
                                bool useCorrelationFilter = true);
    
    double            CalculateOptimalPosition(const DarvasBox &box,
                                              double entryPrice,
                                              double stopLoss,
                                              double boxScore = 80.0,
                                              double volatilityMultiplier = 1.0,
                                              double timingMultiplier = 1.0,
                                              double streakMultiplier = 1.0);
    
    bool              CanAddToPosition(ulong ticket, const DarvasBox &newBox);
    bool              AddToPosition(ulong ticket, double addSize);
    void              UpdatePositions();
    void              ManageStopLoss(ulong ticket);
    
    double            GetPositionSizeMultiplier(double boxScore,
                                               double volatilityMultiplier,
                                               double timingMultiplier,
                                               double streakMultiplier);
    
private:
    bool              FindPosition(ulong ticket, int &index);
    bool              CheckPyramidingConditions(int index, const DarvasBox &newBox);
    double            CalculateBreakevenStop(ulong ticket);
    double            CalculateTrailingStop(ulong ticket);
    double            CalculateHardTrail(ulong ticket);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager()
{
    m_BaseRiskPercent = 1.0;
    m_AllowPyramiding = true;
    m_MaxAddsPerTrade = 2;
    m_PyramidSizeRatio = 0.5;
    m_UseCorrelationFilter = true;
    m_PositionCount = 0;
    ArrayResize(m_Positions, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CPositionManager::Initialize(double baseRisk,
                                 bool allowPyramiding,
                                 int maxAdds,
                                 double pyramidRatio,
                                 bool useCorrelationFilter)
{
    m_BaseRiskPercent = baseRisk;
    m_AllowPyramiding = allowPyramiding;
    m_MaxAddsPerTrade = maxAdds;
    m_PyramidSizeRatio = pyramidRatio;
    m_UseCorrelationFilter = useCorrelationFilter;
    return true;
}

//+------------------------------------------------------------------+
//| Calculate optimal position                                       |
//+------------------------------------------------------------------+
double CPositionManager::CalculateOptimalPosition(const DarvasBox &box,
                                                  double entryPrice,
                                                  double stopLoss,
                                                  double boxScore,
                                                  double volatilityMultiplier,
                                                  double timingMultiplier,
                                                  double streakMultiplier)
{
    // Base risk amount
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double baseRisk = accountEquity * (m_BaseRiskPercent / 100.0);
    
    // Calculate stop distance
    double stopDistance = MathAbs(entryPrice - stopLoss);
    if(stopDistance <= 0) return 0;
    
    // Get multipliers
    double multiplier = GetPositionSizeMultiplier(boxScore, volatilityMultiplier,
                                                 timingMultiplier, streakMultiplier);
    
    // Calculate position size
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize <= 0) return 0;
    
    double riskInPoints = stopDistance / tickSize;
    double adjustedRisk = baseRisk * multiplier;
    double lotSize = adjustedRisk / (riskInPoints * tickValue);
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Check if can add to position                                     |
//+------------------------------------------------------------------+
bool CPositionManager::CanAddToPosition(ulong ticket, const DarvasBox &newBox)
{
    if(!m_AllowPyramiding) return false;
    
    int index;
    if(!FindPosition(ticket, index))
        return false;
    
    // Check if already at max adds
    if(m_Positions[index].AddCount >= m_MaxAddsPerTrade)
        return false;
    
    // Check pyramiding conditions
    return CheckPyramidingConditions(index, newBox);
}

//+------------------------------------------------------------------+
//| Add to position                                                  |
//+------------------------------------------------------------------+
bool CPositionManager::AddToPosition(ulong ticket, double addSize)
{
    int index;
    if(!FindPosition(ticket, index))
        return false;
    
    if(!PositionSelectByTicket(ticket)) return false;
    
    // Execute add
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = addSize;
    request.type = m_Positions[index].IsLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(_Symbol, m_Positions[index].IsLong ? 
                                     SYMBOL_ASK : SYMBOL_BID);
    request.deviation = 10;
    request.magic = 123456;
    
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            m_Positions[index].AddCount++;
            m_Positions[index].TotalSize += addSize;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update positions                                                 |
//+------------------------------------------------------------------+
void CPositionManager::UpdatePositions()
{
    for(int i = m_PositionCount - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(m_Positions[i].Ticket))
        {
            // Position closed, remove
            for(int j = i; j < m_PositionCount - 1; j++)
                m_Positions[j] = m_Positions[j + 1];
            m_PositionCount--;
            ArrayResize(m_Positions, m_PositionCount);
            continue;
        }
        
        // Update max profit
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double profit = m_Positions[i].IsLong ? 
                       (currentPrice - m_Positions[i].EntryPrice) : 
                       (m_Positions[i].EntryPrice - currentPrice);
        
        if(profit > m_Positions[i].MaxProfit)
            m_Positions[i].MaxProfit = profit;
        
        // Manage stop loss
        ManageStopLoss(m_Positions[i].Ticket);
    }
}

//+------------------------------------------------------------------+
//| Manage stop loss                                                 |
//+------------------------------------------------------------------+
void CPositionManager::ManageStopLoss(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    int index;
    if(!FindPosition(ticket, index))
        return;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double entryPrice = m_Positions[index].EntryPrice;
    double boxHeight = m_Positions[index].Box.Height;
    double currentStop = PositionGetDouble(POSITION_SL);
    bool isLong = m_Positions[index].IsLong;
    
    double newStop = 0;
    
    // Phase 1: Protective stop (initial)
    double profit = isLong ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
    double profitInBoxHeights = profit / boxHeight;
    
    // Phase 2: Breakeven (+spread)
    if(profitInBoxHeights >= 0.75)
    {
        double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID);
        newStop = entryPrice + (isLong ? spread : -spread);
    }
    
    // Phase 3: Trailing profits (1.5× box height)
    if(profitInBoxHeights >= 1.5)
    {
        double trailStop = CalculateTrailingStop(ticket);
        if(trailStop != 0)
            newStop = trailStop;
    }
    
    // Phase 4: Hard trail (3.0× box height)
    if(profitInBoxHeights >= 3.0)
    {
        double hardTrail = CalculateHardTrail(ticket);
        if(hardTrail != 0)
            newStop = hardTrail;
    }
    
    // Update stop if beneficial
    if(newStop != 0)
    {
        if(isLong && (newStop > currentStop || currentStop == 0))
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = _Symbol;
            request.sl = newStop;
            request.tp = PositionGetDouble(POSITION_TP);
            if(!OrderSend(request, result))
            {
                Print("Failed to modify stop loss: ", result.retcode);
            }
        }
        else if(!isLong && (newStop < currentStop || currentStop == 0))
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = _Symbol;
            request.sl = newStop;
            request.tp = PositionGetDouble(POSITION_TP);
            if(!OrderSend(request, result))
            {
                Print("Failed to modify stop loss: ", result.retcode);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get position size multiplier                                     |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionSizeMultiplier(double boxScore,
                                                   double volatilityMultiplier,
                                                   double timingMultiplier,
                                                   double streakMultiplier)
{
    // Box quality score (0.8-1.2)
    double boxMultiplier = 0.8 + (boxScore / 100.0) * 0.4;
    
    // Volatility multiplier (high ATR = reduce)
    double volMultiplier = volatilityMultiplier;
    
    // Timing multiplier
    double timeMultiplier = timingMultiplier;
    
    // Streak multiplier
    double streakMult = streakMultiplier;
    
    // Combined multiplier
    double totalMultiplier = boxMultiplier * volMultiplier * timeMultiplier * streakMult;
    
    // Cap between 0.5 and 2.0
    if(totalMultiplier < 0.5) totalMultiplier = 0.5;
    if(totalMultiplier > 2.0) totalMultiplier = 2.0;
    
    return totalMultiplier;
}

//+------------------------------------------------------------------+
//| Find position                                                    |
//+------------------------------------------------------------------+
bool CPositionManager::FindPosition(ulong ticket, int &index)
{
    for(int i = 0; i < m_PositionCount; i++)
    {
        if(m_Positions[i].Ticket == ticket)
        {
            index = i;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check pyramiding conditions                                      |
//+------------------------------------------------------------------+
bool CPositionManager::CheckPyramidingConditions(int index, const DarvasBox &newBox)
{
    if(!PositionSelectByTicket(m_Positions[index].Ticket))
        return false;
    
    // Condition 1: Trade already profitable (>1× risk)
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double entryPrice = m_Positions[index].EntryPrice;
    double boxHeight = m_Positions[index].Box.Height;
    
    double profit = m_Positions[index].IsLong ? 
                   (currentPrice - entryPrice) : 
                   (entryPrice - currentPrice);
    
    if(profit < boxHeight) // Less than 1× box height
        return false;
    
    // Condition 2: New box forming above entry (for long)
    if(m_Positions[index].IsLong)
    {
        if(newBox.Bottom <= entryPrice)
            return false; // Box not above entry
    }
    else
    {
        if(newBox.Top >= entryPrice)
            return false; // Box not below entry
    }
    
    // Condition 3: Volume confirming (would need volume analyzer)
    // Simplified for now
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate breakeven stop                                         |
//+------------------------------------------------------------------+
double CPositionManager::CalculateBreakevenStop(ulong ticket)
{
    int index;
    if(!FindPosition(ticket, index))
        return 0;
    
    double entryPrice = m_Positions[index].EntryPrice;
    double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(m_Positions[index].IsLong)
        return entryPrice + spread;
    else
        return entryPrice - spread;
}

//+------------------------------------------------------------------+
//| Calculate trailing stop                                          |
//+------------------------------------------------------------------+
double CPositionManager::CalculateTrailingStop(ulong ticket)
{
    int index;
    if(!FindPosition(ticket, index))
        return 0;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double maxPrice = m_Positions[index].IsLong ? 
                     (m_Positions[index].EntryPrice + m_Positions[index].MaxProfit) : 
                     (m_Positions[index].EntryPrice - m_Positions[index].MaxProfit);
    
    // Trail at 50% of new highs
    double trailDistance = m_Positions[index].MaxProfit * 0.5;
    
    // Get daily ATR for maximum trail distance
    int atrHandle = iATR(_Symbol, PERIOD_D1, 14);
    double maxTrailDistance = 0;
    if(atrHandle != INVALID_HANDLE)
    {
        double atr[];
        ArraySetAsSeries(atr, true);
        if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            maxTrailDistance = atr[0] * 2.0;
        IndicatorRelease(atrHandle);
    }
    
    if(trailDistance > maxTrailDistance && maxTrailDistance > 0)
        trailDistance = maxTrailDistance;
    
    if(m_Positions[index].IsLong)
        return maxPrice - trailDistance;
    else
        return maxPrice + trailDistance;
}

//+------------------------------------------------------------------+
//| Calculate hard trail                                             |
//+------------------------------------------------------------------+
double CPositionManager::CalculateHardTrail(ulong ticket)
{
    int index;
    if(!FindPosition(ticket, index))
        return 0;
    
    double maxPrice = m_Positions[index].IsLong ? 
                     (m_Positions[index].EntryPrice + m_Positions[index].MaxProfit) : 
                     (m_Positions[index].EntryPrice - m_Positions[index].MaxProfit);
    
    // Hard trail: 70% of max profit
    double trailDistance = m_Positions[index].MaxProfit * 0.3; // Keep 70%
    
    if(m_Positions[index].IsLong)
        return maxPrice - trailDistance;
    else
        return maxPrice + trailDistance;
}

//+------------------------------------------------------------------+
