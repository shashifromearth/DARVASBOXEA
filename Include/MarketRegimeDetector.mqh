//+------------------------------------------------------------------+
//|                                    MarketRegimeDetector.mqh       |
//|                    Enhanced Market Regime Detection              |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "VolatilityRegime.mqh"

//+------------------------------------------------------------------+
//| Market Regime Enum                                               |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
    REGIME_TRENDING_STRONG,    // ADX > 30, clear direction
    REGIME_TRENDING_WEAK,      // ADX 20-30
    REGIME_RANGING,            // ADX < 20, clear boundaries
    REGIME_VOLATILE,           // High ATR, choppy
    REGIME_BREAKOUT            // Just broke major level
};

//+------------------------------------------------------------------+
//| Regime Strategy Settings                                         |
//+------------------------------------------------------------------+
struct RegimeStrategy
{
    ENUM_MARKET_REGIME Regime;
    double            PositionMultiplier; // Position size adjustment
    double            StopMultiplier;      // Stop loss adjustment
    double            TargetMultiplier;    // Target adjustment
    bool              LetRunnersGo;        // Let winners run
    bool              TakeProfitsEarly;    // Take profits early
    string            StrategyName;        // Strategy description
};

//+------------------------------------------------------------------+
//| Market Regime Detector                                            |
//+------------------------------------------------------------------+
class CMarketRegimeDetector
{
private:
    int               m_ADXHandle;         // ADX indicator handle
    int               m_ADXPeriod;         // ADX period (14)
    double            m_ADXValue;          // Current ADX value
    
    CVolatilityRegime *m_VolatilityRegime;
    
    ENUM_MARKET_REGIME m_CurrentRegime;    // Current regime
    
public:
    CMarketRegimeDetector();
    ~CMarketRegimeDetector();
    
    bool              Initialize(int adxPeriod = 14,
                                CVolatilityRegime *volatilityRegime = NULL);
    
    ENUM_MARKET_REGIME GetCurrentRegime(ENUM_TIMEFRAMES timeframe);
    RegimeStrategy     GetRegimeStrategy(ENUM_MARKET_REGIME regime);
    void              AdjustExitStrategy(ENUM_MARKET_REGIME regime,
                                        double &tier1Multiplier,
                                        double &tier2Multiplier,
                                        double &tier1Percent,
                                        double &tier2Percent);
    
private:
    double            GetADX(ENUM_TIMEFRAMES timeframe);
    bool              CheckMajorBreakout(ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketRegimeDetector::CMarketRegimeDetector()
{
    m_ADXHandle = INVALID_HANDLE;
    m_ADXPeriod = 14;
    m_ADXValue = 0;
    m_VolatilityRegime = NULL;
    m_CurrentRegime = REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketRegimeDetector::~CMarketRegimeDetector()
{
    if(m_ADXHandle != INVALID_HANDLE)
        IndicatorRelease(m_ADXHandle);
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::Initialize(int adxPeriod,
                                      CVolatilityRegime *volatilityRegime)
{
    m_ADXPeriod = adxPeriod;
    m_VolatilityRegime = volatilityRegime;
    
    m_ADXHandle = iADX(_Symbol, PERIOD_CURRENT, m_ADXPeriod);
    if(m_ADXHandle == INVALID_HANDLE)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current regime                                               |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME CMarketRegimeDetector::GetCurrentRegime(ENUM_TIMEFRAMES timeframe)
{
    m_ADXValue = GetADX(timeframe);
    
    // Check for major breakout
    if(CheckMajorBreakout(timeframe))
    {
        m_CurrentRegime = REGIME_BREAKOUT;
        return m_CurrentRegime;
    }
    
    // Check volatility
    ENUM_VOLATILITY_REGIME volRegime = REGIME_NORMAL;
    if(m_VolatilityRegime != NULL)
        volRegime = m_VolatilityRegime.GetCurrentRegime(timeframe);
    
    // Determine regime based on ADX and volatility
    if(m_ADXValue > 30)
    {
        m_CurrentRegime = REGIME_TRENDING_STRONG;
    }
    else if(m_ADXValue >= 20)
    {
        m_CurrentRegime = REGIME_TRENDING_WEAK;
    }
    else if(volRegime == REGIME_HIGH)
    {
        m_CurrentRegime = REGIME_VOLATILE;
    }
    else
    {
        m_CurrentRegime = REGIME_RANGING;
    }
    
    return m_CurrentRegime;
}

//+------------------------------------------------------------------+
//| Get regime strategy                                              |
//+------------------------------------------------------------------+
RegimeStrategy CMarketRegimeDetector::GetRegimeStrategy(ENUM_MARKET_REGIME regime)
{
    RegimeStrategy strategy;
    strategy.Regime = regime;
    
    switch(regime)
    {
        case REGIME_TRENDING_STRONG:
            strategy.PositionMultiplier = 1.2;  // Larger positions
            strategy.StopMultiplier = 1.0;       // Normal stops
            strategy.TargetMultiplier = 1.5;    // Bigger targets
            strategy.LetRunnersGo = true;        // Let winners run
            strategy.TakeProfitsEarly = false;   // Don't take early
            strategy.StrategyName = "Strong Trend: Maximum Runners";
            break;
            
        case REGIME_TRENDING_WEAK:
            strategy.PositionMultiplier = 1.0;  // Normal positions
            strategy.StopMultiplier = 1.0;       // Normal stops
            strategy.TargetMultiplier = 1.2;    // Slightly bigger targets
            strategy.LetRunnersGo = true;        // Let winners run
            strategy.TakeProfitsEarly = false;   // Don't take early
            strategy.StrategyName = "Weak Trend: Standard Strategy";
            break;
            
        case REGIME_RANGING:
            strategy.PositionMultiplier = 0.8;  // Smaller positions
            strategy.StopMultiplier = 0.8;      // Tighter stops
            strategy.TargetMultiplier = 0.8;    // Quicker targets
            strategy.LetRunnersGo = false;       // Take profits early
            strategy.TakeProfitsEarly = true;    // Take early
            strategy.StrategyName = "Ranging: Take Profits Early";
            break;
            
        case REGIME_VOLATILE:
            strategy.PositionMultiplier = 0.7;  // Smaller positions
            strategy.StopMultiplier = 1.5;       // Wider stops
            strategy.TargetMultiplier = 1.2;     // Moderate targets
            strategy.LetRunnersGo = false;       // Don't let run
            strategy.TakeProfitsEarly = true;    // Take early
            strategy.StrategyName = "Volatile: Reduce Size, Wider Stops";
            break;
            
        case REGIME_BREAKOUT:
            strategy.PositionMultiplier = 1.3;  // Larger positions
            strategy.StopMultiplier = 1.2;       // Slightly wider stops
            strategy.TargetMultiplier = 2.0;    // Much bigger targets
            strategy.LetRunnersGo = true;        // Let winners run
            strategy.TakeProfitsEarly = false;   // Don't take early
            strategy.StrategyName = "Breakout: Maximum Position, Big Targets";
            break;
    }
    
    return strategy;
}

//+------------------------------------------------------------------+
//| Adjust exit strategy                                             |
//+------------------------------------------------------------------+
void CMarketRegimeDetector::AdjustExitStrategy(ENUM_MARKET_REGIME regime,
                                               double &tier1Multiplier,
                                               double &tier2Multiplier,
                                               double &tier1Percent,
                                               double &tier2Percent)
{
    RegimeStrategy strategy = GetRegimeStrategy(regime);
    
    switch(regime)
    {
        case REGIME_VOLATILE:
            // Take profits earlier
            tier1Multiplier = 0.5;  // 0.5× box height
            tier2Multiplier = 1.0;  // 1.0× box height
            tier1Percent = 0.20;    // 20% at first target
            tier2Percent = 0.40;    // 40% at second target
            break;
            
        case REGIME_RANGING:
            // Take profits early
            tier1Multiplier = 1.0;  // 1.0× box height
            tier2Multiplier = 2.0;  // 2.0× box height
            tier1Percent = 0.10;    // 10% at first target
            tier2Percent = 0.30;    // 30% at second target
            break;
            
        case REGIME_TRENDING_STRONG:
            // Let profits run
            tier1Multiplier = 1.5;  // 1.5× box height
            tier2Multiplier = 3.0;  // 3.0× box height
            tier1Percent = 0.10;    // 10% at first target
            tier2Percent = 0.20;    // 20% at second target
            // 70% as runner
            break;
            
        default:
            // Standard settings
            break;
    }
}

//+------------------------------------------------------------------+
//| Get ADX                                                          |
//+------------------------------------------------------------------+
double CMarketRegimeDetector::GetADX(ENUM_TIMEFRAMES timeframe)
{
    if(m_ADXHandle == INVALID_HANDLE)
    {
        m_ADXHandle = iADX(_Symbol, timeframe, m_ADXPeriod);
        if(m_ADXHandle == INVALID_HANDLE) return 0;
    }
    
    double adx[];
    ArraySetAsSeries(adx, true);
    if(CopyBuffer(m_ADXHandle, 0, 0, 1, adx) <= 0)
        return 0;
    
    return adx[0];
}

//+------------------------------------------------------------------+
//| Check major breakout                                              |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::CheckMajorBreakout(ENUM_TIMEFRAMES timeframe)
{
    // Check if price just broke a major level (simplified)
    // Would check against significant support/resistance
    
    double currentPrice = iClose(_Symbol, timeframe, 0);
    double price20 = iClose(_Symbol, timeframe, 20);
    double price50 = iClose(_Symbol, timeframe, 50);
    
    // Check if broke above/below significant moving average
    if(currentPrice > price50 && price20 < price50)
        return true; // Bullish breakout
    
    if(currentPrice < price50 && price20 > price50)
        return true; // Bearish breakout
    
    return false;
}

//+------------------------------------------------------------------+
