//+------------------------------------------------------------------+
//|                                          BoxQualifier.mqh        |
//|                    Surgical Box Qualification System             |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "VolumeAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Box Qualification Score                                          |
//+------------------------------------------------------------------+
struct BoxQualificationScore
{
    double            StructuralScore;    // Box structure quality (0-100)
    double            VolumeScore;         // Volume pattern score (0-100)
    double            ContractionScore;    // ATR contraction score (0-100)
    double            OverallScore;        // Combined score (0-100)
    bool              IsQualified;        // Passes minimum threshold
    string            RejectionReason;    // Why box was rejected
};

//+------------------------------------------------------------------+
//| Box Qualifier Class                                              |
//+------------------------------------------------------------------+
class CBoxQualifier
{
private:
    double            m_MinScore;         // Minimum score (75/100)
    int               m_MinBars;          // Minimum consolidation bars (5)
    double            m_MinVolumeDecline;  // Minimum volume decline (30%)
    double            m_MinATRContraction; // Minimum ATR contraction (40%)
    double            m_OverlapDistance;   // Overlap check distance (1.5×)
    
    CVolumeAnalyzer  *m_VolumeAnalyzer;
    
public:
    CBoxQualifier();
    ~CBoxQualifier();
    
    bool              Initialize(double minScore = 75.0,
                                 int minBars = 5,
                                 double minVolumeDecline = 0.30,
                                 double minATRContraction = 0.40,
                                 double overlapDistance = 1.5,
                                 CVolumeAnalyzer *volumeAnalyzer = NULL);
    
    bool              QualifyBox(const DarvasBox &box,
                                 ENUM_TIMEFRAMES timeframe,
                                 BoxQualificationScore &score);
    
    bool              IsValidDarvasBox(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe);
    
    double            CalculateBoxScore(const DarvasBox &box,
                                       ENUM_TIMEFRAMES timeframe);
    
private:
    double            ScoreStructure(const DarvasBox &box,
                                    ENUM_TIMEFRAMES timeframe);
    double            ScoreVolume(const DarvasBox &box,
                                 ENUM_TIMEFRAMES timeframe);
    double            ScoreContraction(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe);
    bool              CheckOverlappingBoxes(const DarvasBox &box,
                                           ENUM_TIMEFRAMES timeframe);
    bool              CheckClearBoundaries(const DarvasBox &box,
                                          ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBoxQualifier::CBoxQualifier()
{
    m_MinScore = 75.0;
    m_MinBars = 5;
    m_MinVolumeDecline = 0.30;
    m_MinATRContraction = 0.40;
    m_OverlapDistance = 1.5;
    m_VolumeAnalyzer = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBoxQualifier::~CBoxQualifier()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CBoxQualifier::Initialize(double minScore, int minBars,
                               double minVolumeDecline,
                               double minATRContraction,
                               double overlapDistance,
                               CVolumeAnalyzer *volumeAnalyzer)
{
    m_MinScore = minScore;
    m_MinBars = minBars;
    m_MinVolumeDecline = minVolumeDecline;
    m_MinATRContraction = minATRContraction;
    m_OverlapDistance = overlapDistance;
    m_VolumeAnalyzer = volumeAnalyzer;
    return true;
}

//+------------------------------------------------------------------+
//| Qualify box                                                      |
//+------------------------------------------------------------------+
bool CBoxQualifier::QualifyBox(const DarvasBox &box,
                               ENUM_TIMEFRAMES timeframe,
                               BoxQualificationScore &score)
{
    // Check minimum bars
    if(box.ConsolidationBars < m_MinBars)
    {
        score.IsQualified = false;
        score.RejectionReason = "Insufficient consolidation bars: " + 
                               IntegerToString(box.ConsolidationBars);
        return false;
    }
    
    // Score components
    score.StructuralScore = ScoreStructure(box, timeframe);
    score.VolumeScore = ScoreVolume(box, timeframe);
    score.ContractionScore = ScoreContraction(box, timeframe);
    
    // Overall score (weighted average)
    score.OverallScore = (score.StructuralScore * 0.4 + 
                         score.VolumeScore * 0.3 + 
                         score.ContractionScore * 0.3);
    
    // Check if qualified
    score.IsQualified = (score.OverallScore >= m_MinScore);
    
    if(!score.IsQualified)
    {
        score.RejectionReason = "Overall score below minimum: " + 
                               DoubleToString(score.OverallScore, 2);
    }
    
    // Check overlapping boxes
    if(CheckOverlappingBoxes(box, timeframe))
    {
        score.IsQualified = false;
        score.RejectionReason = "Overlapping box detected";
    }
    
    // Check clear boundaries
    if(!CheckClearBoundaries(box, timeframe))
    {
        score.IsQualified = false;
        score.RejectionReason = "Ambiguous box boundaries";
    }
    
    return score.IsQualified;
}

//+------------------------------------------------------------------+
//| Check if valid Darvas box                                        |
//+------------------------------------------------------------------+
bool CBoxQualifier::IsValidDarvasBox(const DarvasBox &box,
                                    ENUM_TIMEFRAMES timeframe)
{
    BoxQualificationScore score;
    return QualifyBox(box, timeframe, score);
}

//+------------------------------------------------------------------+
//| Calculate box score                                              |
//+------------------------------------------------------------------+
double CBoxQualifier::CalculateBoxScore(const DarvasBox &box,
                                       ENUM_TIMEFRAMES timeframe)
{
    BoxQualificationScore score;
    QualifyBox(box, timeframe, score);
    return score.OverallScore;
}

//+------------------------------------------------------------------+
//| Score structure                                                  |
//+------------------------------------------------------------------+
double CBoxQualifier::ScoreStructure(const DarvasBox &box,
                                    ENUM_TIMEFRAMES timeframe)
{
    double score = 0;
    
    // Box height relative to ATR (should be reasonable)
    double heightATRRatio = box.Height / box.ATRValue;
    if(heightATRRatio >= 0.5 && heightATRRatio <= 3.0)
        score += 30; // Good size
    else if(heightATRRatio >= 0.3 && heightATRRatio <= 5.0)
        score += 20; // Acceptable
    else
        score += 10; // Poor
    
    // Consolidation bars (more is better, up to a point)
    if(box.ConsolidationBars >= 7 && box.ConsolidationBars <= 15)
        score += 30; // Optimal
    else if(box.ConsolidationBars >= 5 && box.ConsolidationBars <= 20)
        score += 20; // Good
    else
        score += 10; // Acceptable
    
    // Box age (not too old)
    datetime boxAge = TimeCurrent() - box.CreationTime;
    int hoursOld = (int)(boxAge / 3600);
    if(hoursOld <= 24)
        score += 20; // Fresh
    else if(hoursOld <= 48)
        score += 15; // Acceptable
    else
        score += 5; // Old
    
    // Top/Bottom clarity
    if(CheckClearBoundaries(box, timeframe))
        score += 20; // Clear boundaries
    else
        score += 0; // Ambiguous
    
    return score;
}

//+------------------------------------------------------------------+
//| Score volume                                                     |
//+------------------------------------------------------------------+
double CBoxQualifier::ScoreVolume(const DarvasBox &box,
                                 ENUM_TIMEFRAMES timeframe)
{
    if(m_VolumeAnalyzer == NULL) return 50; // Neutral if no analyzer
    
    // Get volume before consolidation
    double avgVolumeBefore = 0;
    for(int i = box.ConsolidationBars; i < box.ConsolidationBars * 2; i++)
    {
        long volume = iTickVolume(_Symbol, timeframe, i);
        avgVolumeBefore += (double)volume;
    }
    avgVolumeBefore /= box.ConsolidationBars;
    
    // Get volume during consolidation
    double avgVolumeInside = box.VolumeInsideBox;
    
    if(avgVolumeBefore == 0) return 50;
    
    // Calculate decline percentage
    double volumeDecline = 1.0 - (avgVolumeInside / avgVolumeBefore);
    
    double score = 0;
    if(volumeDecline >= m_MinVolumeDecline)
        score = 100; // Excellent decline
    else if(volumeDecline >= m_MinVolumeDecline * 0.7)
        score = 70; // Good decline
    else if(volumeDecline >= m_MinVolumeDecline * 0.5)
        score = 50; // Acceptable
    else
        score = 20; // Poor decline
    
    return score;
}

//+------------------------------------------------------------------+
//| Score contraction                                                |
//+------------------------------------------------------------------+
double CBoxQualifier::ScoreContraction(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe)
{
    // Get ATR at start of consolidation
    int atrHandle = iATR(_Symbol, timeframe, 14);
    if(atrHandle == INVALID_HANDLE) return 50;
    
    double atrArray[];
    ArraySetAsSeries(atrArray, true);
    if(CopyBuffer(atrHandle, 0, box.ConsolidationBars, 1, atrArray) <= 0)
    {
        IndicatorRelease(atrHandle);
        return 50;
    }
    double atrStart = atrArray[0];
    
    // Get current ATR
    if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) <= 0)
    {
        IndicatorRelease(atrHandle);
        return 50;
    }
    double atrCurrent = atrArray[0];
    
    IndicatorRelease(atrHandle);
    
    if(atrStart == 0) return 50;
    
    // Calculate contraction
    double contraction = 1.0 - (atrCurrent / atrStart);
    
    double score = 0;
    if(contraction >= m_MinATRContraction)
        score = 100; // Excellent contraction
    else if(contraction >= m_MinATRContraction * 0.7)
        score = 70; // Good contraction
    else if(contraction >= m_MinATRContraction * 0.5)
        score = 50; // Acceptable
    else
        score = 20; // Poor contraction
    
    return score;
}

//+------------------------------------------------------------------+
//| Check overlapping boxes                                          |
//+------------------------------------------------------------------+
bool CBoxQualifier::CheckOverlappingBoxes(const DarvasBox &box,
                                          ENUM_TIMEFRAMES timeframe)
{
    // This would check against other detected boxes
    // For now, simplified check - would need box detector integration
    double overlapDistance = box.Height * m_OverlapDistance;
    
    // Check if there are nearby price levels that could be box boundaries
    // This is a simplified check
    return false; // Assume no overlap for now
}

//+------------------------------------------------------------------+
//| Check clear boundaries                                           |
//+------------------------------------------------------------------+
bool CBoxQualifier::CheckClearBoundaries(const DarvasBox &box,
                                        ENUM_TIMEFRAMES timeframe)
{
    // Check if box top and bottom are clear (not ambiguous wicks)
    // Look at candles near boundaries
    
    int barsToCheck = MathMin(box.ConsolidationBars, 10);
    
    for(int i = 0; i < barsToCheck; i++)
    {
        double high = iHigh(_Symbol, timeframe, i);
        double low = iLow(_Symbol, timeframe, i);
        double open = iOpen(_Symbol, timeframe, i);
        double close = iClose(_Symbol, timeframe, i);
        
        // Check if wicks are too long relative to body
        double body = MathAbs(close - open);
        double upperWick = high - MathMax(open, close);
        double lowerWick = MathMin(open, close) - low;
        
        // If wick is more than 2× body, boundary might be ambiguous
        if(upperWick > body * 2.0 && high > box.Top * 0.98)
            return false;
        if(lowerWick > body * 2.0 && low < box.Bottom * 1.02)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
