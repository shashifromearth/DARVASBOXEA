//+------------------------------------------------------------------+
//|                                          BreakoutScorer.mqh      |
//|                    Breakout Quality Scoring System               |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "VolumeAnalyzer.mqh"
#include "MarketStructure.mqh"
#include "SessionManager.mqh"

//+------------------------------------------------------------------+
//| Breakout Scorer Class                                            |
//+------------------------------------------------------------------+
class CBreakoutScorer
{
private:
    int               m_MinBreakoutScore;   // Minimum score for entry (70)
    
    CVolumeAnalyzer  *m_VolumeAnalyzer;
    CMarketStructure *m_MarketStructure;
    CSessionManager  *m_SessionManager;
    
public:
    CBreakoutScorer();
    ~CBreakoutScorer();
    
    bool              Initialize(int minScore,
                                  CVolumeAnalyzer *volumeAnalyzer,
                                  CMarketStructure *marketStructure,
                                  CSessionManager *sessionManager);
    
    int               CalculateBreakoutScore(const DarvasBox &box, 
                                               ENUM_TIMEFRAMES timeframe,
                                               bool isLong);
    bool              IsBreakoutValid(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe,
                                      bool isLong);
    bool              CheckFalseBreakout(const DarvasBox &box,
                                         ENUM_TIMEFRAMES timeframe,
                                         bool isLong);
    
private:
    int               ScoreVolumeSurge(ENUM_TIMEFRAMES timeframe);
    int               ScoreCloseBreakout(ENUM_TIMEFRAMES timeframe, const DarvasBox &box, bool isLong);
    int               ScoreTrendAlignment(bool isLong);
    int               ScoreRetestQuality(const DarvasBox &box, ENUM_TIMEFRAMES timeframe);
    int               ScoreResistanceLevel(ENUM_TIMEFRAMES timeframe, bool isLong);
    int               ScoreSessionStrength();
    bool              CheckImmediateReversal(ENUM_TIMEFRAMES timeframe, bool isLong);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBreakoutScorer::CBreakoutScorer()
{
    m_MinBreakoutScore = 70;
    m_VolumeAnalyzer = NULL;
    m_MarketStructure = NULL;
    m_SessionManager = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBreakoutScorer::~CBreakoutScorer()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CBreakoutScorer::Initialize(int minScore,
                                 CVolumeAnalyzer *volumeAnalyzer,
                                 CMarketStructure *marketStructure,
                                 CSessionManager *sessionManager)
{
    m_MinBreakoutScore = minScore;
    m_VolumeAnalyzer = volumeAnalyzer;
    m_MarketStructure = marketStructure;
    m_SessionManager = sessionManager;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate breakout score                                         |
//+------------------------------------------------------------------+
int CBreakoutScorer::CalculateBreakoutScore(const DarvasBox &box, 
                                             ENUM_TIMEFRAMES timeframe,
                                             bool isLong)
{
    int score = 0;
    
    // Volume Surge (+25 if >150%)
    score += ScoreVolumeSurge(timeframe);
    
    // Close above/below (+20)
    score += ScoreCloseBreakout(timeframe, box, isLong);
    
    // Higher TF alignment (+20)
    score += ScoreTrendAlignment(isLong);
    
    // Clean retest (+15)
    score += ScoreRetestQuality(box, timeframe);
    
    // No overhead resistance (+10)
    score += ScoreResistanceLevel(timeframe, isLong);
    
    // Session strength (+10)
    score += ScoreSessionStrength();
    
    return score;
}

//+------------------------------------------------------------------+
//| Check if breakout is valid                                       |
//+------------------------------------------------------------------+
bool CBreakoutScorer::IsBreakoutValid(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe,
                                      bool isLong)
{
    int score = CalculateBreakoutScore(box, timeframe, isLong);
    return (score >= m_MinBreakoutScore);
}

//+------------------------------------------------------------------+
//| Check for false breakout                                         |
//+------------------------------------------------------------------+
bool CBreakoutScorer::CheckFalseBreakout(const DarvasBox &box,
                                         ENUM_TIMEFRAMES timeframe,
                                         bool isLong)
{
    // Check if price re-enters box within 3 bars
    for(int i = 0; i < 3; i++)
    {
        double close = iClose(_Symbol, timeframe, i);
        if(IsPriceInBox(close, box))
            return true;
    }
    
    // Check for immediate reversal
    if(CheckImmediateReversal(timeframe, isLong))
        return true;
    
    // Check volume collapse
    if(m_VolumeAnalyzer != NULL)
    {
        double volumeRatio = m_VolumeAnalyzer.GetVolumeRatio(timeframe, 5);
        if(volumeRatio < 0.7) // Volume collapsed
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Score volume surge                                               |
//+------------------------------------------------------------------+
int CBreakoutScorer::ScoreVolumeSurge(ENUM_TIMEFRAMES timeframe)
{
    if(m_VolumeAnalyzer == NULL) return 0;
    
    double surgeRatio;
    if(m_VolumeAnalyzer.CheckVolumeSurge(timeframe, surgeRatio))
    {
        if(surgeRatio >= 1.5)
            return 25;
        else if(surgeRatio >= 1.2)
            return 15;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Score close breakout                                             |
//+------------------------------------------------------------------+
int CBreakoutScorer::ScoreCloseBreakout(ENUM_TIMEFRAMES timeframe, const DarvasBox &box, bool isLong)
{
    double close = iClose(_Symbol, timeframe, 0);
    double prevClose = iClose(_Symbol, timeframe, 1);
    
    if(isLong)
    {
        if(close > box.Top && prevClose <= box.Top)
            return 20;
    }
    else
    {
        if(close < box.Bottom && prevClose >= box.Bottom)
            return 20;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Score trend alignment                                            |
//+------------------------------------------------------------------+
int CBreakoutScorer::ScoreTrendAlignment(bool isLong)
{
    if(m_MarketStructure == NULL) return 10; // Neutral if not available
    
    if(m_MarketStructure.IsWithTrend(isLong, PERIOD_H4))
        return 20;
    
    return 0;
}

//+------------------------------------------------------------------+
//| Score retest quality                                             |
//+------------------------------------------------------------------+
int CBreakoutScorer::ScoreRetestQuality(const DarvasBox &box, ENUM_TIMEFRAMES timeframe)
{
    // Check if price retested the breakout level
    double close = iClose(_Symbol, timeframe, 0);
    double low = iLow(_Symbol, timeframe, 0);
    double high = iHigh(_Symbol, timeframe, 0);
    
    // Check for retest of top (for long) or bottom (for short)
    double tolerance = box.Height * 0.1;
    
    // For long: retest of top as support
    if(MathAbs(low - box.Top) < tolerance && close > box.Top)
        return 15;
    
    // For short: retest of bottom as resistance
    if(MathAbs(high - box.Bottom) < tolerance && close < box.Bottom)
        return 15;
    
    return 0;
}

//+------------------------------------------------------------------+
//| Score resistance level                                           |
//+------------------------------------------------------------------+
int CBreakoutScorer::ScoreResistanceLevel(ENUM_TIMEFRAMES timeframe, bool isLong)
{
    // Check for nearby resistance/support
    double currentPrice = iClose(_Symbol, timeframe, 0);
    double atr = 0;
    
    // Get ATR for distance calculation
    int atrHandle = iATR(_Symbol, timeframe, 14);
    if(atrHandle != INVALID_HANDLE)
    {
        double atrArray[];
        ArraySetAsSeries(atrArray, true);
        if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) > 0)
            atr = atrArray[0];
        IndicatorRelease(atrHandle);
    }
    
    if(atr == 0) return 5; // Neutral if can't calculate
    
    // Check for resistance within 1 ATR
    if(isLong)
    {
        double highest = iHigh(_Symbol, timeframe, 20);
        if(highest > currentPrice && (highest - currentPrice) < atr)
            return 0; // Resistance too close
    }
    else
    {
        double lowest = iLow(_Symbol, timeframe, 20);
        if(lowest < currentPrice && (currentPrice - lowest) < atr)
            return 0; // Support too close
    }
    
    return 10;
}

//+------------------------------------------------------------------+
//| Score session strength                                           |
//+------------------------------------------------------------------+
int CBreakoutScorer::ScoreSessionStrength()
{
    if(m_SessionManager == NULL) return 5; // Neutral
    
    double weight = m_SessionManager.GetSessionWeight();
    
    if(weight >= 1.3)
        return 10;
    else if(weight >= 1.2)
        return 7;
    else if(weight >= 1.0)
        return 5;
    else
        return 2;
}

//+------------------------------------------------------------------+
//| Check immediate reversal                                         |
//+------------------------------------------------------------------+
bool CBreakoutScorer::CheckImmediateReversal(ENUM_TIMEFRAMES timeframe, bool isLong)
{
    // Check for opposite direction engulfing candle
    double open0 = iOpen(_Symbol, timeframe, 0);
    double close0 = iClose(_Symbol, timeframe, 0);
    double open1 = iOpen(_Symbol, timeframe, 1);
    double close1 = iClose(_Symbol, timeframe, 1);
    
    if(isLong)
    {
        // Bearish engulfing after bullish breakout
        if(close1 > open1 && close0 < open0 && open0 > close1 && close0 < open1)
            return true;
    }
    else
    {
        // Bullish engulfing after bearish breakout
        if(close1 < open1 && close0 > open0 && open0 < close1 && close0 > open1)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
