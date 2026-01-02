//+------------------------------------------------------------------+
//|                                      VolatilityRegime.mqh         |
//|                    Volatility Regime Detection and Switching    |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Volatility Regime Enum                                           |
//+------------------------------------------------------------------+
enum ENUM_VOLATILITY_REGIME
{
    REGIME_LOW,      // VIX < 15: Gamma Scalping Mode
    REGIME_NORMAL,   // VIX 15-25: Trend Following Mode
    REGIME_HIGH      // VIX > 25: Breakout Fade Mode
};

//+------------------------------------------------------------------+
//| Regime Settings                                                  |
//+------------------------------------------------------------------+
struct RegimeSettings
{
    ENUM_VOLATILITY_REGIME Regime;
    double            PositionMultiplier; // Position size multiplier
    double            StopMultiplier;      // Stop loss multiplier
    double            TargetMultiplier;   // Target multiplier
    int               MinBarsInBox;       // Minimum consolidation bars
    bool              UseQuickExits;      // Quick exit mode
    string            StrategyName;       // Strategy name
};

//+------------------------------------------------------------------+
//| Volatility Regime Detector                                       |
//+------------------------------------------------------------------+
class CVolatilityRegime
{
private:
    int               m_ATRHandle;        // ATR indicator handle
    int               m_ATRPeriod;         // ATR period
    int               m_LookbackPeriod;   // Lookback for regime calculation
    
    double            m_CurrentATR;        // Current ATR
    double            m_AverageATR;        // Average ATR
    double            m_ATRRatio;          // Current/Average ratio
    
    ENUM_VOLATILITY_REGIME m_CurrentRegime; // Current regime
    
public:
    CVolatilityRegime();
    ~CVolatilityRegime();
    
    bool              Initialize(int atrPeriod = 14, int lookback = 20);
    ENUM_VOLATILITY_REGIME GetCurrentRegime(ENUM_TIMEFRAMES timeframe);
    RegimeSettings     GetRegimeSettings(ENUM_VOLATILITY_REGIME regime);
    double            GetATRRatio() { return m_ATRRatio; }
    double            GetPositionMultiplier();
    double            GetStopMultiplier();
    double            GetTargetMultiplier();
    
private:
    void              UpdateATR(ENUM_TIMEFRAMES timeframe);
    double            CalculateAverageATR(ENUM_TIMEFRAMES timeframe, int period);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVolatilityRegime::CVolatilityRegime()
{
    m_ATRHandle = INVALID_HANDLE;
    m_ATRPeriod = 14;
    m_LookbackPeriod = 20;
    m_CurrentATR = 0;
    m_AverageATR = 0;
    m_ATRRatio = 1.0;
    m_CurrentRegime = REGIME_NORMAL;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVolatilityRegime::~CVolatilityRegime()
{
    if(m_ATRHandle != INVALID_HANDLE)
        IndicatorRelease(m_ATRHandle);
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CVolatilityRegime::Initialize(int atrPeriod, int lookback)
{
    m_ATRPeriod = atrPeriod;
    m_LookbackPeriod = lookback;
    
    m_ATRHandle = iATR(_Symbol, PERIOD_CURRENT, m_ATRPeriod);
    if(m_ATRHandle == INVALID_HANDLE)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current regime                                               |
//+------------------------------------------------------------------+
ENUM_VOLATILITY_REGIME CVolatilityRegime::GetCurrentRegime(ENUM_TIMEFRAMES timeframe)
{
    UpdateATR(timeframe);
    
    // Determine regime based on ATR ratio
    // Low volatility: ATR < 0.7× average
    // Normal volatility: ATR 0.7-1.5× average
    // High volatility: ATR > 1.5× average
    
    if(m_ATRRatio < 0.7)
        m_CurrentRegime = REGIME_LOW;
    else if(m_ATRRatio > 1.5)
        m_CurrentRegime = REGIME_HIGH;
    else
        m_CurrentRegime = REGIME_NORMAL;
    
    return m_CurrentRegime;
}

//+------------------------------------------------------------------+
//| Get regime settings                                              |
//+------------------------------------------------------------------+
RegimeSettings CVolatilityRegime::GetRegimeSettings(ENUM_VOLATILITY_REGIME regime)
{
    RegimeSettings settings;
    settings.Regime = regime;
    
    switch(regime)
    {
        case REGIME_LOW:
            settings.PositionMultiplier = 1.2;  // Slightly larger positions
            settings.StopMultiplier = 0.8;      // Tighter stops
            settings.TargetMultiplier = 0.8;   // Quicker targets
            settings.MinBarsInBox = 3;          // Smaller boxes OK
            settings.UseQuickExits = true;     // Quick exit mode
            settings.StrategyName = "Gamma Scalping Mode";
            break;
            
        case REGIME_NORMAL:
            settings.PositionMultiplier = 1.0;  // Normal positions
            settings.StopMultiplier = 1.0;      // Normal stops
            settings.TargetMultiplier = 1.0;    // Normal targets
            settings.MinBarsInBox = 5;          // Standard boxes
            settings.UseQuickExits = false;     // Normal exits
            settings.StrategyName = "Trend Following Mode";
            break;
            
        case REGIME_HIGH:
            settings.PositionMultiplier = 0.7;  // Smaller positions
            settings.StopMultiplier = 1.5;      // Wider stops
            settings.TargetMultiplier = 1.5;    // Bigger targets
            settings.MinBarsInBox = 7;          // Larger boxes required
            settings.UseQuickExits = false;     // Let winners run
            settings.StrategyName = "Breakout Fade Mode";
            break;
    }
    
    return settings;
}

//+------------------------------------------------------------------+
//| Get position multiplier                                          |
//+------------------------------------------------------------------+
double CVolatilityRegime::GetPositionMultiplier()
{
    RegimeSettings settings = GetRegimeSettings(m_CurrentRegime);
    return settings.PositionMultiplier;
}

//+------------------------------------------------------------------+
//| Get stop multiplier                                              |
//+------------------------------------------------------------------+
double CVolatilityRegime::GetStopMultiplier()
{
    RegimeSettings settings = GetRegimeSettings(m_CurrentRegime);
    return settings.StopMultiplier;
}

//+------------------------------------------------------------------+
//| Get target multiplier                                            |
//+------------------------------------------------------------------+
double CVolatilityRegime::GetTargetMultiplier()
{
    RegimeSettings settings = GetRegimeSettings(m_CurrentRegime);
    return settings.TargetMultiplier;
}

//+------------------------------------------------------------------+
//| Update ATR                                                       |
//+------------------------------------------------------------------+
void CVolatilityRegime::UpdateATR(ENUM_TIMEFRAMES timeframe)
{
    if(m_ATRHandle == INVALID_HANDLE)
    {
        m_ATRHandle = iATR(_Symbol, timeframe, m_ATRPeriod);
        if(m_ATRHandle == INVALID_HANDLE) return;
    }
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(m_ATRHandle, 0, 0, 1, atr) <= 0)
        return;
    
    m_CurrentATR = atr[0];
    m_AverageATR = CalculateAverageATR(timeframe, m_LookbackPeriod);
    
    if(m_AverageATR > 0)
        m_ATRRatio = m_CurrentATR / m_AverageATR;
    else
        m_ATRRatio = 1.0;
}

//+------------------------------------------------------------------+
//| Calculate average ATR                                            |
//+------------------------------------------------------------------+
double CVolatilityRegime::CalculateAverageATR(ENUM_TIMEFRAMES timeframe, int period)
{
    int atrHandle = iATR(_Symbol, timeframe, m_ATRPeriod);
    if(atrHandle == INVALID_HANDLE) return 0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atrHandle, 0, 0, period, atr) <= 0)
    {
        IndicatorRelease(atrHandle);
        return 0;
    }
    
    IndicatorRelease(atrHandle);
    
    double sum = 0;
    for(int i = 0; i < period; i++)
        sum += atr[i];
    
    return sum / period;
}

//+------------------------------------------------------------------+
