//+------------------------------------------------------------------+
//|                                            ExitManager.mqh       |
//|                    Pyramid Exit Strategy Implementation          |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "VolumeAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Exit Manager Class                                               |
//+------------------------------------------------------------------+
class CExitManager
{
private:
    bool              m_UsePyramidExit;     // Use pyramid exit (30/30/40)
    double            m_ProfitMultiplier;    // Profit multiplier (3.0)
    bool              m_UseChandelierExit;  // Use chandelier exit
    
    CVolumeAnalyzer  *m_VolumeAnalyzer;
    
    // Exit tracking
    TradeExit         m_PendingExits[];
    int               m_ExitCount;
    
public:
    CExitManager();
    ~CExitManager();
    
    bool              Initialize(bool usePyramid,
                                 double profitMultiplier,
                                 bool useChandelier,
                                 CVolumeAnalyzer *volumeAnalyzer);
    
    bool              CheckExit1_TrailingBox(ulong ticket, 
                                             const DarvasBox &newBox,
                                             TradeExit &exit);
    bool              CheckExit2_VolumeExhaustion(ulong ticket,
                                                   ENUM_TIMEFRAMES timeframe,
                                                   TradeExit &exit);
    bool              CheckExit3_TrendTermination(ulong ticket,
                                                   const DarvasBox &box,
                                                   ENUM_TIMEFRAMES timeframe,
                                                   TradeExit &exit);
    
    bool              ProcessTradeExit(ulong ticket,
                                       const DarvasBox &box,
                                       ENUM_TIMEFRAMES timeframe,
                                       TradeExit &exit);
    
    void              UpdateTrailingStops(ulong ticket, const DarvasBox &newBox);
    bool              CheckBreakevenStop(ulong ticket, const DarvasBox &box);
    
private:
    bool              CheckRSIDivergence(ENUM_TIMEFRAMES timeframe, bool isLong);
    double            CalculateChandelierExit(ulong ticket, ENUM_TIMEFRAMES timeframe);
    bool              CheckConsecutiveWicks(ENUM_TIMEFRAMES timeframe, bool isLong);
    bool              CheckTimeBasedExit(ulong ticket, int maxBoxes = 5);
    double            GetTradeProfitMultiplier(ulong ticket, const DarvasBox &box);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExitManager::CExitManager()
{
    m_UsePyramidExit = true;
    m_ProfitMultiplier = 3.0;
    m_UseChandelierExit = true;
    m_VolumeAnalyzer = NULL;
    m_ExitCount = 0;
    ArrayResize(m_PendingExits, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CExitManager::~CExitManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CExitManager::Initialize(bool usePyramid,
                               double profitMultiplier,
                               bool useChandelier,
                               CVolumeAnalyzer *volumeAnalyzer)
{
    m_UsePyramidExit = usePyramid;
    m_ProfitMultiplier = profitMultiplier;
    m_UseChandelierExit = useChandelier;
    m_VolumeAnalyzer = volumeAnalyzer;
    
    return true;
}

//+------------------------------------------------------------------+
//| Process trade exit                                               |
//+------------------------------------------------------------------+
bool CExitManager::ProcessTradeExit(ulong ticket,
                                     const DarvasBox &box,
                                     ENUM_TIMEFRAMES timeframe,
                                     TradeExit &exit)
{
    // Check Exit 1: Trailing Box Bottom (30% position)
    if(CheckExit1_TrailingBox(ticket, box, exit))
    {
        exit.ExitTier = 1;
        exit.ExitSize = 0.3; // 30% of position
        return true;
    }
    
    // Check Exit 2: Volume Exhaustion (30% position)
    if(CheckExit2_VolumeExhaustion(ticket, timeframe, exit))
    {
        exit.ExitTier = 2;
        exit.ExitSize = 0.3; // 30% of position
        return true;
    }
    
    // Check Exit 3: Trend Termination (40% position)
    if(CheckExit3_TrendTermination(ticket, box, timeframe, exit))
    {
        exit.ExitTier = 3;
        exit.ExitSize = 0.4; // 40% of position
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Exit 1: Trailing Box Bottom                                |
//+------------------------------------------------------------------+
bool CExitManager::CheckExit1_TrailingBox(ulong ticket, 
                                           const DarvasBox &newBox,
                                           TradeExit &exit)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    
    // As price moves up, create NEW Darvas Box
    // Exit 30% when price closes below NEW box bottom (for long)
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    if(isLong)
    {
        if(close < newBox.Bottom)
        {
            exit.ExitPrice = newBox.Bottom;
            exit.ExitTime = TimeCurrent();
            exit.ExitReason = "Trailing Box Bottom";
            exit.IsPartial = true;
            return true;
        }
    }
    else
    {
        if(close > newBox.Top)
        {
            exit.ExitPrice = newBox.Top;
            exit.ExitTime = TimeCurrent();
            exit.ExitReason = "Trailing Box Top";
            exit.IsPartial = true;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Exit 2: Volume Exhaustion                                  |
//+------------------------------------------------------------------+
bool CExitManager::CheckExit2_VolumeExhaustion(ulong ticket,
                                                 ENUM_TIMEFRAMES timeframe,
                                                 TradeExit &exit)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // 1. Volume spike > 300% but price stalls
    if(m_VolumeAnalyzer != NULL)
    {
        if(m_VolumeAnalyzer.IsVolumeExhaustion(timeframe))
        {
            exit.ExitPrice = iClose(_Symbol, timeframe, 0);
            exit.ExitTime = TimeCurrent();
            exit.ExitReason = "Volume Exhaustion";
            exit.IsPartial = true;
            return true;
        }
    }
    
    // 2. Consecutive long wicks (rejection)
    if(CheckConsecutiveWicks(timeframe, isLong))
    {
        exit.ExitPrice = iClose(_Symbol, timeframe, 0);
        exit.ExitTime = TimeCurrent();
        exit.ExitReason = "Consecutive Rejection Wicks";
        exit.IsPartial = true;
        return true;
    }
    
    // 3. RSI divergence
    if(CheckRSIDivergence(timeframe, isLong))
    {
        exit.ExitPrice = iClose(_Symbol, timeframe, 0);
        exit.ExitTime = TimeCurrent();
        exit.ExitReason = "RSI Divergence";
        exit.IsPartial = true;
        return true;
    }
    
    // 4. Chandelier Exit (3 ATR from high)
    if(m_UseChandelierExit)
    {
        double chandelierExit = CalculateChandelierExit(ticket, timeframe);
        double currentPrice = iClose(_Symbol, timeframe, 0);
        
        if(isLong && currentPrice < chandelierExit)
        {
            exit.ExitPrice = chandelierExit;
            exit.ExitTime = TimeCurrent();
            exit.ExitReason = "Chandelier Exit";
            exit.IsPartial = true;
            return true;
        }
        else if(!isLong && currentPrice > chandelierExit)
        {
            exit.ExitPrice = chandelierExit;
            exit.ExitTime = TimeCurrent();
            exit.ExitReason = "Chandelier Exit";
            exit.IsPartial = true;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Exit 3: Trend Termination                                  |
//+------------------------------------------------------------------+
bool CExitManager::CheckExit3_TrendTermination(ulong ticket,
                                                 const DarvasBox &box,
                                                 ENUM_TIMEFRAMES timeframe,
                                                 TradeExit &exit)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    // 1. Major support/resistance reached
    // This would require support/resistance detection
    
    // 2. Trendline break on higher timeframe
    // This would require trendline detection
    
    // 3. Time-based: After 5 new consecutive boxes
    if(CheckTimeBasedExit(ticket, 5))
    {
        exit.ExitPrice = iClose(_Symbol, timeframe, 0);
        exit.ExitTime = TimeCurrent();
        exit.ExitReason = "Time-Based Exit (5 Boxes)";
        exit.IsPartial = false; // Full exit
        return true;
    }
    
    // 4. Profit target: 3× initial box height
    double profitMultiplier = GetTradeProfitMultiplier(ticket, box);
    if(profitMultiplier >= m_ProfitMultiplier)
    {
        exit.ExitPrice = iClose(_Symbol, timeframe, 0);
        exit.ExitTime = TimeCurrent();
        exit.ExitReason = "Profit Target Reached";
        exit.IsPartial = false; // Full exit
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update trailing stops                                            |
//+------------------------------------------------------------------+
void CExitManager::UpdateTrailingStops(ulong ticket, const DarvasBox &newBox)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double currentStop = PositionGetDouble(POSITION_SL);
    
    double newStop = isLong ? newBox.Bottom : newBox.Top;
    
    // Only move stop in favorable direction
    if(isLong && newStop > currentStop)
    {
        // Modify stop loss
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = _Symbol;
        request.sl = newStop;
        request.tp = PositionGetDouble(POSITION_TP);
        
        if(!OrderSend(request, result))
        {
            Print("Failed to update stop loss: ", result.retcode);
        }
    }
    else if(!isLong && (currentStop == 0 || newStop < currentStop))
    {
        // Modify stop loss
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = _Symbol;
        request.sl = newStop;
        request.tp = PositionGetDouble(POSITION_TP);
        
        if(!OrderSend(request, result))
        {
            Print("Failed to update stop loss: ", result.retcode);
        }
    }
}

//+------------------------------------------------------------------+
//| Check breakeven stop                                              |
//+------------------------------------------------------------------+
bool CExitManager::CheckBreakevenStop(ulong ticket, const DarvasBox &box)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentStop = PositionGetDouble(POSITION_SL);
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // Trigger at 1.5× box height profit
    double boxHeight = box.Height;
    double profitTarget = isLong ? (entryPrice + boxHeight * 1.5) : (entryPrice - boxHeight * 1.5);
    
    if(isLong && currentPrice >= profitTarget)
    {
        // Move stop to breakeven
        if(currentStop < entryPrice)
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = _Symbol;
            request.sl = entryPrice;
            request.tp = PositionGetDouble(POSITION_TP);
            
            if(!OrderSend(request, result))
            {
                Print("Failed to move stop to breakeven: ", result.retcode);
            }
            return true;
        }
    }
    else if(!isLong && currentPrice <= profitTarget)
    {
        // Move stop to breakeven
        if(currentStop == 0 || currentStop > entryPrice)
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = _Symbol;
            request.sl = entryPrice;
            request.tp = PositionGetDouble(POSITION_TP);
            
            if(!OrderSend(request, result))
            {
                Print("Failed to move stop to breakeven: ", result.retcode);
            }
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check RSI divergence                                             |
//+------------------------------------------------------------------+
bool CExitManager::CheckRSIDivergence(ENUM_TIMEFRAMES timeframe, bool isLong)
{
    int rsiHandle = iRSI(_Symbol, timeframe, 14, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE) return false;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if(CopyBuffer(rsiHandle, 0, 0, 10, rsi) <= 0)
    {
        IndicatorRelease(rsiHandle);
        return false;
    }
    
    IndicatorRelease(rsiHandle);
    
    // Check for divergence (simplified)
    double price0 = iClose(_Symbol, timeframe, 0);
    double price5 = iClose(_Symbol, timeframe, 5);
    
    if(isLong)
    {
        // Bearish divergence: price higher, RSI lower
        if(price0 > price5 && rsi[0] < rsi[5])
            return true;
    }
    else
    {
        // Bullish divergence: price lower, RSI higher
        if(price0 < price5 && rsi[0] > rsi[5])
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate chandelier exit                                        |
//+------------------------------------------------------------------+
double CExitManager::CalculateChandelierExit(ulong ticket, ENUM_TIMEFRAMES timeframe)
{
    if(!PositionSelectByTicket(ticket)) return 0;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // Get ATR
    int atrHandle = iATR(_Symbol, timeframe, 14);
    if(atrHandle == INVALID_HANDLE) return 0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
    {
        IndicatorRelease(atrHandle);
        return 0;
    }
    
    IndicatorRelease(atrHandle);
    
    // Get highest high (for long) or lowest low (for short) in recent period
    double highest = iHigh(_Symbol, timeframe, 0);
    double lowest = iLow(_Symbol, timeframe, 0);
    
    for(int i = 1; i < 20; i++)
    {
        double h = iHigh(_Symbol, timeframe, i);
        double l = iLow(_Symbol, timeframe, i);
        if(h > highest) highest = h;
        if(l < lowest) lowest = l;
    }
    
    // Chandelier exit: 3 ATR from high/low
    if(isLong)
        return highest - (atr[0] * 3.0);
    else
        return lowest + (atr[0] * 3.0);
}

//+------------------------------------------------------------------+
//| Check consecutive wicks                                          |
//+------------------------------------------------------------------+
bool CExitManager::CheckConsecutiveWicks(ENUM_TIMEFRAMES timeframe, bool isLong)
{
    int consecutiveWicks = 0;
    
    for(int i = 0; i < 3; i++)
    {
        double open = iOpen(_Symbol, timeframe, i);
        double close = iClose(_Symbol, timeframe, i);
        double high = iHigh(_Symbol, timeframe, i);
        double low = iLow(_Symbol, timeframe, i);
        
        double body = MathAbs(close - open);
        double upperWick = high - MathMax(open, close);
        double lowerWick = MathMin(open, close) - low;
        
        if(isLong)
        {
            // Long upper wick indicates rejection
            if(upperWick > body * 1.5)
                consecutiveWicks++;
        }
        else
        {
            // Long lower wick indicates rejection
            if(lowerWick > body * 1.5)
                consecutiveWicks++;
        }
    }
    
    return (consecutiveWicks >= 2);
}

//+------------------------------------------------------------------+
//| Check time-based exit                                            |
//+------------------------------------------------------------------+
bool CExitManager::CheckTimeBasedExit(ulong ticket, int maxBoxes = 5)
{
    // This would track number of boxes formed since entry
    // For now, simplified version
    if(!PositionSelectByTicket(ticket)) return false;
    
    datetime entryTime = (datetime)PositionGetInteger(POSITION_TIME);
    datetime currentTime = TimeCurrent();
    
    // Exit after certain time period (simplified)
    int hoursOpen = (int)((currentTime - entryTime) / 3600);
    
    // Exit after 24 hours (adjust based on timeframe)
    return (hoursOpen >= 24);
}

//+------------------------------------------------------------------+
//| Get trade profit multiplier                                      |
//+------------------------------------------------------------------+
double CExitManager::GetTradeProfitMultiplier(ulong ticket, const DarvasBox &box)
{
    if(!PositionSelectByTicket(ticket)) return 0;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    double boxHeight = box.Height;
    double profit = isLong ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
    
    if(boxHeight <= 0) return 0;
    
    return profit / boxHeight;
}

//+------------------------------------------------------------------+
