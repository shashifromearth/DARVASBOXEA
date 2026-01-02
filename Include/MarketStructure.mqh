//+------------------------------------------------------------------+
//|                                          MarketStructure.mqh     |
//|                    Trend Alignment and Market Structure         |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Market Structure Class                                           |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
    ENUM_TIMEFRAMES   m_TrendTimeframe;      // Trend timeframe
    ENUM_TIMEFRAMES   m_ConfirmationTF;      // Confirmation timeframe
    
    int               m_ADXHandle;          // ADX indicator handle
    int               m_EMAHandle;          // EMA indicator handle
    
    bool              m_UseTrendFilter;      // Use trend filter
    
public:
    CMarketStructure();
    ~CMarketStructure();
    
    bool              Initialize(ENUM_TIMEFRAMES trendTF, 
                                  ENUM_TIMEFRAMES confirmationTF,
                                  bool useTrendFilter);
    
    bool              IsWithTrend(bool isLong, ENUM_TIMEFRAMES timeframe);
    double            GetTrendStrength(ENUM_TIMEFRAMES timeframe);
    bool              IsTrending(ENUM_TIMEFRAMES timeframe);
    bool              IsBullishTrend(ENUM_TIMEFRAMES timeframe);
    bool              IsContinuationPattern(const DarvasBox &box, bool isLong);
    MarketCondition   GetMarketCondition(ENUM_TIMEFRAMES timeframe);
    bool              CheckMarketStructureAlignment(bool isLong);
    
private:
    double            GetADX(ENUM_TIMEFRAMES timeframe, int period = 14);
    double            GetEMA(ENUM_TIMEFRAMES timeframe, int period = 50);
    bool              IsHigherHighsHigherLows(ENUM_TIMEFRAMES timeframe);
    bool              IsLowerHighsLowerLows(ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure()
{
    m_ADXHandle = INVALID_HANDLE;
    m_EMAHandle = INVALID_HANDLE;
    m_UseTrendFilter = true;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketStructure::~CMarketStructure()
{
    if(m_ADXHandle != INVALID_HANDLE)
        IndicatorRelease(m_ADXHandle);
    if(m_EMAHandle != INVALID_HANDLE)
        IndicatorRelease(m_EMAHandle);
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CMarketStructure::Initialize(ENUM_TIMEFRAMES trendTF, 
                                  ENUM_TIMEFRAMES confirmationTF,
                                  bool useTrendFilter)
{
    m_TrendTimeframe = trendTF;
    m_ConfirmationTF = confirmationTF;
    m_UseTrendFilter = useTrendFilter;
    
    // Initialize ADX
    m_ADXHandle = iADX(_Symbol, m_TrendTimeframe, 14);
    if(m_ADXHandle == INVALID_HANDLE)
    {
        Print("Failed to create ADX indicator");
        return false;
    }
    
    // Initialize EMA
    m_EMAHandle = iMA(_Symbol, m_TrendTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(m_EMAHandle == INVALID_HANDLE)
    {
        Print("Failed to create EMA indicator");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if trade is with trend                                    |
//+------------------------------------------------------------------+
bool CMarketStructure::IsWithTrend(bool isLong, ENUM_TIMEFRAMES timeframe)
{
    if(!m_UseTrendFilter) return true;
    
    // Check higher timeframe trend
    bool trendIsBullish = IsBullishTrend(m_TrendTimeframe);
    
    // For long trades, trend should be bullish
    // For short trades, trend should be bearish
    if(isLong)
        return trendIsBullish;
    else
        return !trendIsBullish;
}

//+------------------------------------------------------------------+
//| Get trend strength                                               |
//+------------------------------------------------------------------+
double CMarketStructure::GetTrendStrength(ENUM_TIMEFRAMES timeframe)
{
    return GetADX(timeframe);
}

//+------------------------------------------------------------------+
//| Check if market is trending                                      |
//+------------------------------------------------------------------+
bool CMarketStructure::IsTrending(ENUM_TIMEFRAMES timeframe)
{
    double adx = GetADX(timeframe);
    return (adx > 25.0); // ADX above 25 indicates trending market
}

//+------------------------------------------------------------------+
//| Check if trend is bullish                                        |
//+------------------------------------------------------------------+
bool CMarketStructure::IsBullishTrend(ENUM_TIMEFRAMES timeframe)
{
    double ema = GetEMA(timeframe);
    double currentPrice = iClose(_Symbol, timeframe, 0);
    
    return (currentPrice > ema);
}

//+------------------------------------------------------------------+
//| Check if continuation pattern                                    |
//+------------------------------------------------------------------+
bool CMarketStructure::IsContinuationPattern(const DarvasBox &box, bool isLong)
{
    // Check if box aligns with trend
    bool trendIsBullish = IsBullishTrend(m_TrendTimeframe);
    
    if(isLong && trendIsBullish)
        return true;
    if(!isLong && !trendIsBullish)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Get market condition                                             |
//+------------------------------------------------------------------+
MarketCondition CMarketStructure::GetMarketCondition(ENUM_TIMEFRAMES timeframe)
{
    MarketCondition condition;
    
    condition.IsTrending = IsTrending(timeframe);
    condition.IsRanging = !condition.IsTrending;
    condition.Volatility = 0; // Can be calculated with ATR
    condition.TrendStrength = GetTrendStrength(timeframe);
    condition.TrendTimeframe = timeframe;
    condition.IsBullishTrend = IsBullishTrend(timeframe);
    
    return condition;
}

//+------------------------------------------------------------------+
//| Check market structure alignment                                 |
//+------------------------------------------------------------------+
bool CMarketStructure::CheckMarketStructureAlignment(bool isLong)
{
    // Check trend timeframe
    bool trendAligned = IsWithTrend(isLong, m_TrendTimeframe);
    
    // Check confirmation timeframe
    bool confirmationAligned = IsWithTrend(isLong, m_ConfirmationTF);
    
    // Both should align for best setup
    return (trendAligned && confirmationAligned);
}

//+------------------------------------------------------------------+
//| Get ADX value                                                    |
//+------------------------------------------------------------------+
double CMarketStructure::GetADX(ENUM_TIMEFRAMES timeframe, int period = 14)
{
    if(m_ADXHandle == INVALID_HANDLE)
    {
        m_ADXHandle = iADX(_Symbol, timeframe, period);
        if(m_ADXHandle == INVALID_HANDLE) return 0;
    }
    
    double adx[];
    ArraySetAsSeries(adx, true);
    
    if(CopyBuffer(m_ADXHandle, 0, 0, 1, adx) <= 0)
        return 0;
    
    return adx[0];
}

//+------------------------------------------------------------------+
//| Get EMA value                                                    |
//+------------------------------------------------------------------+
double CMarketStructure::GetEMA(ENUM_TIMEFRAMES timeframe, int period = 50)
{
    if(m_EMAHandle == INVALID_HANDLE)
    {
        m_EMAHandle = iMA(_Symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
        if(m_EMAHandle == INVALID_HANDLE) return 0;
    }
    
    double ema[];
    ArraySetAsSeries(ema, true);
    
    if(CopyBuffer(m_EMAHandle, 0, 0, 1, ema) <= 0)
        return 0;
    
    return ema[0];
}

//+------------------------------------------------------------------+
//| Check for higher highs and higher lows                          |
//+------------------------------------------------------------------+
bool CMarketStructure::IsHigherHighsHigherLows(ENUM_TIMEFRAMES timeframe)
{
    double high1 = iHigh(_Symbol, timeframe, 0);
    double high2 = iHigh(_Symbol, timeframe, 5);
    double low1 = iLow(_Symbol, timeframe, 0);
    double low2 = iLow(_Symbol, timeframe, 5);
    
    return (high1 > high2 && low1 > low2);
}

//+------------------------------------------------------------------+
//| Check for lower highs and lower lows                            |
//+------------------------------------------------------------------+
bool CMarketStructure::IsLowerHighsLowerLows(ENUM_TIMEFRAMES timeframe)
{
    double high1 = iHigh(_Symbol, timeframe, 0);
    double high2 = iHigh(_Symbol, timeframe, 5);
    double low1 = iLow(_Symbol, timeframe, 0);
    double low2 = iLow(_Symbol, timeframe, 5);
    
    return (high1 < high2 && low1 < low2);
}

//+------------------------------------------------------------------+
