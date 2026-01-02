//+------------------------------------------------------------------+
//|                                        PrecisionEntry.mqh        |
//|                    Hierarchical Entry Trigger System             |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "VolumeAnalyzer.mqh"
#include "SessionManager.mqh"

//+------------------------------------------------------------------+
//| Entry Timing Grade                                               |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_TIMING
{
    TIMING_A_PLUS,  // London/NY overlap (13:00-16:00 UTC)
    TIMING_A,       // Pure London (07:00-13:00 UTC)
    TIMING_B,       // NY session (13:00-22:00 UTC)
    TIMING_C        // Asian session (avoid unless exceptional)
};

//+------------------------------------------------------------------+
//| Entry Type                                                       |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_TYPE
{
    ENTRY_PRIMARY,      // Clean breakout with retest
    ENTRY_SECONDARY,    // Volume spike breakout
    ENTRY_TERTIARY      // Failed breakout reversal
};

//+------------------------------------------------------------------+
//| Entry Trigger Structure                                          |
//+------------------------------------------------------------------+
struct EntryTrigger
{
    ENUM_ENTRY_TYPE     Type;              // Entry type
    ENUM_ENTRY_TIMING   Timing;           // Timing grade
    double              EntryPrice;        // Entry price
    double              StopLoss;          // Stop loss
    double              PositionSize;     // Position size
    int                 QualityScore;      // Entry quality (0-100)
    bool                IsValid;          // Is trigger valid
    string              Reason;            // Entry reason
};

//+------------------------------------------------------------------+
//| Precision Entry Manager                                          |
//+------------------------------------------------------------------+
class CPrecisionEntry
{
private:
    bool              m_RequireRetest;     // Require retest for primary
    double            m_MinVolumeSurge;   // Minimum volume surge (1.8×)
    double            m_RetestTolerance;   // Retest tolerance (0.25× box height)
    double            m_CloseOutsidePercent; // Close outside % (75%)
    
    CVolumeAnalyzer  *m_VolumeAnalyzer;
    CSessionManager  *m_SessionManager;
    
    // Entry tracking
    struct BreakoutState
    {
        DarvasBox     Box;
        bool          IsLong;
        datetime      BreakoutTime;
        double        BreakoutHigh;
        double        BreakoutLow;
        bool          HasRetested;
        bool          IsConfirmed;
    };
    
    BreakoutState     m_BreakoutStates[];
    int               m_StateCount;
    
public:
    CPrecisionEntry();
    ~CPrecisionEntry();
    
    bool              Initialize(bool requireRetest = true,
                                 double minVolumeSurge = 1.8,
                                 double retestTolerance = 0.25,
                                 double closeOutsidePercent = 0.75,
                                 CVolumeAnalyzer *volumeAnalyzer = NULL,
                                 CSessionManager *sessionManager = NULL);
    
    bool              CheckPrimaryEntry(const DarvasBox &box,
                                       ENUM_TIMEFRAMES timeframe,
                                       bool isLong,
                                       EntryTrigger &trigger);
    
    bool              CheckSecondaryEntry(const DarvasBox &box,
                                         ENUM_TIMEFRAMES timeframe,
                                         bool isLong,
                                         EntryTrigger &trigger);
    
    bool              CheckTertiaryEntry(const DarvasBox &box,
                                       ENUM_TIMEFRAMES timeframe,
                                       bool isLong,
                                       EntryTrigger &trigger);
    
    ENUM_ENTRY_TIMING GetEntryTiming();
    double            GetTimingMultiplier(ENUM_ENTRY_TIMING timing);
    
private:
    bool              DetectBreakoutCandle(const DarvasBox &box,
                                          ENUM_TIMEFRAMES timeframe,
                                          bool isLong);
    bool              DetectRetestCandle(const DarvasBox &box,
                                        ENUM_TIMEFRAMES timeframe,
                                        bool isLong,
                                        double breakoutLevel);
    bool              DetectConfirmationCandle(const DarvasBox &box,
                                             ENUM_TIMEFRAMES timeframe,
                                             bool isLong);
    bool              CheckVolumeSpike(ENUM_TIMEFRAMES timeframe,
                                     double minSurge);
    double            CalculateEntryPrice(ENUM_ENTRY_TYPE type,
                                         const DarvasBox &box,
                                         bool isLong);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPrecisionEntry::CPrecisionEntry()
{
    m_RequireRetest = true;
    m_MinVolumeSurge = 1.8;
    m_RetestTolerance = 0.25;
    m_CloseOutsidePercent = 0.75;
    m_VolumeAnalyzer = NULL;
    m_SessionManager = NULL;
    m_StateCount = 0;
    ArrayResize(m_BreakoutStates, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPrecisionEntry::~CPrecisionEntry()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CPrecisionEntry::Initialize(bool requireRetest,
                                double minVolumeSurge,
                                double retestTolerance,
                                double closeOutsidePercent,
                                CVolumeAnalyzer *volumeAnalyzer,
                                CSessionManager *sessionManager)
{
    m_RequireRetest = requireRetest;
    m_MinVolumeSurge = minVolumeSurge;
    m_RetestTolerance = retestTolerance;
    m_CloseOutsidePercent = closeOutsidePercent;
    m_VolumeAnalyzer = volumeAnalyzer;
    m_SessionManager = sessionManager;
    return true;
}

//+------------------------------------------------------------------+
//| Check primary entry (clean breakout with retest)                |
//+------------------------------------------------------------------+
bool CPrecisionEntry::CheckPrimaryEntry(const DarvasBox &box,
                                        ENUM_TIMEFRAMES timeframe,
                                        bool isLong,
                                        EntryTrigger &trigger)
{
    trigger.Type = ENTRY_PRIMARY;
    trigger.IsValid = false;
    
    // Step 1: Detect breakout candle
    if(!DetectBreakoutCandle(box, timeframe, isLong))
    {
        trigger.Reason = "No breakout candle detected";
        return false;
    }
    
    // Check volume surge
    if(!CheckVolumeSpike(timeframe, m_MinVolumeSurge))
    {
        trigger.Reason = "Insufficient volume surge";
        return false;
    }
    
    // Step 2: Detect retest (if required)
    if(m_RequireRetest)
    {
        double breakoutLevel = isLong ? box.Top : box.Bottom;
        if(!DetectRetestCandle(box, timeframe, isLong, breakoutLevel))
        {
            trigger.Reason = "No retest detected";
            return false;
        }
    }
    
    // Step 3: Detect confirmation candle
    if(!DetectConfirmationCandle(box, timeframe, isLong))
    {
        trigger.Reason = "No confirmation candle";
        return false;
    }
    
    // Calculate entry price
    trigger.EntryPrice = CalculateEntryPrice(ENTRY_PRIMARY, box, isLong);
    trigger.Timing = GetEntryTiming();
    trigger.QualityScore = 90; // High quality for primary entry
    trigger.IsValid = true;
    trigger.Reason = "Primary entry: Clean breakout with retest";
    
    return true;
}

//+------------------------------------------------------------------+
//| Check secondary entry (volume spike breakout)                   |
//+------------------------------------------------------------------+
bool CPrecisionEntry::CheckSecondaryEntry(const DarvasBox &box,
                                         ENUM_TIMEFRAMES timeframe,
                                         bool isLong,
                                         EntryTrigger &trigger)
{
    trigger.Type = ENTRY_SECONDARY;
    trigger.IsValid = false;
    
    // Check for volume spike (>2.5×)
    if(!CheckVolumeSpike(timeframe, 2.5))
    {
        trigger.Reason = "Insufficient volume spike";
        return false;
    }
    
    // Check close outside box (>75%)
    double close = iClose(_Symbol, timeframe, 0);
    double boxHeight = box.Height;
    double outsideDistance = 0;
    
    if(isLong)
    {
        outsideDistance = close - box.Top;
        if(outsideDistance < boxHeight * m_CloseOutsidePercent)
        {
            trigger.Reason = "Close not far enough outside box";
            return false;
        }
    }
    else
    {
        outsideDistance = box.Bottom - close;
        if(outsideDistance < boxHeight * m_CloseOutsidePercent)
        {
            trigger.Reason = "Close not far enough outside box";
            return false;
        }
    }
    
    // Check for immediate resistance
    int atrHandle = iATR(_Symbol, timeframe, 14);
    double atr = 0;
    if(atrHandle != INVALID_HANDLE)
    {
        double atrArray[];
        ArraySetAsSeries(atrArray, true);
        if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) > 0)
            atr = atrArray[0];
        IndicatorRelease(atrHandle);
    }
    
    if(isLong)
    {
        double highest = iHigh(_Symbol, timeframe, 20);
        if(highest > close && (highest - close) < atr * 0.5)
        {
            trigger.Reason = "Immediate resistance too close";
            return false;
        }
    }
    
    trigger.EntryPrice = CalculateEntryPrice(ENTRY_SECONDARY, box, isLong);
    trigger.Timing = GetEntryTiming();
    trigger.QualityScore = 75; // Good quality
    trigger.IsValid = true;
    trigger.Reason = "Secondary entry: Volume spike breakout";
    
    return true;
}

//+------------------------------------------------------------------+
//| Check tertiary entry (failed breakout reversal)                 |
//+------------------------------------------------------------------+
bool CPrecisionEntry::CheckTertiaryEntry(const DarvasBox &box,
                                        ENUM_TIMEFRAMES timeframe,
                                        bool isLong,
                                        EntryTrigger &trigger)
{
    trigger.Type = ENTRY_TERTIARY;
    trigger.IsValid = false;
    
    // Check if breakout failed (price re-entered box within 2 bars)
    double close0 = iClose(_Symbol, timeframe, 0);
    double close1 = iClose(_Symbol, timeframe, 1);
    double close2 = iClose(_Symbol, timeframe, 2);
    
    bool breakoutFailed = false;
    if(isLong)
    {
        // Was above box, now back inside
        if(close2 > box.Top && close0 < box.Top)
            breakoutFailed = true;
    }
    else
    {
        // Was below box, now back inside
        if(close2 < box.Bottom && close0 > box.Bottom)
            breakoutFailed = true;
    }
    
    if(!breakoutFailed)
    {
        trigger.Reason = "No failed breakout detected";
        return false;
    }
    
    // Check volume spike on rejection
    if(!CheckVolumeSpike(timeframe, 2.0))
    {
        trigger.Reason = "No volume spike on rejection";
        return false;
    }
    
    // Check for engulfing pattern
    double open0 = iOpen(_Symbol, timeframe, 0);
    double open1 = iOpen(_Symbol, timeframe, 1);
    
    bool engulfing = false;
    if(isLong) // Failed long breakout, look for bearish engulfing
    {
        if(close1 > open1 && close0 < open0 && open0 > close1 && close0 < open1)
            engulfing = true;
    }
    else // Failed short breakout, look for bullish engulfing
    {
        if(close1 < open1 && close0 > open0 && open0 < close1 && close0 > open1)
            engulfing = true;
    }
    
    if(!engulfing)
    {
        trigger.Reason = "No engulfing pattern at boundary";
        return false;
    }
    
    // Entry at opposite boundary
    trigger.EntryPrice = isLong ? box.Bottom : box.Top;
    trigger.Timing = GetEntryTiming();
    trigger.QualityScore = 70; // Moderate quality
    trigger.IsValid = true;
    trigger.Reason = "Tertiary entry: Failed breakout reversal";
    
    return true;
}

//+------------------------------------------------------------------+
//| Get entry timing                                                 |
//+------------------------------------------------------------------+
ENUM_ENTRY_TIMING CPrecisionEntry::GetEntryTiming()
{
    if(m_SessionManager == NULL) return TIMING_B; // Default
    
    SessionInfo session = m_SessionManager.GetCurrentSession();
    
    if(session.SessionName == "London/NY Overlap")
        return TIMING_A_PLUS;
    else if(session.SessionName == "London")
        return TIMING_A;
    else if(session.SessionName == "New York")
        return TIMING_B;
    else
        return TIMING_C;
}

//+------------------------------------------------------------------+
//| Get timing multiplier                                            |
//+------------------------------------------------------------------+
double CPrecisionEntry::GetTimingMultiplier(ENUM_ENTRY_TIMING timing)
{
    switch(timing)
    {
        case TIMING_A_PLUS: return 1.5;
        case TIMING_A: return 1.2;
        case TIMING_B: return 1.0;
        case TIMING_C: return 0.5;
    }
    return 1.0;
}

//+------------------------------------------------------------------+
//| Detect breakout candle                                           |
//+------------------------------------------------------------------+
bool CPrecisionEntry::DetectBreakoutCandle(const DarvasBox &box,
                                          ENUM_TIMEFRAMES timeframe,
                                          bool isLong)
{
    double close = iClose(_Symbol, timeframe, 0);
    double prevClose = iClose(_Symbol, timeframe, 1);
    
    if(isLong)
        return (close > box.Top && prevClose <= box.Top);
    else
        return (close < box.Bottom && prevClose >= box.Bottom);
}

//+------------------------------------------------------------------+
//| Detect retest candle                                             |
//+------------------------------------------------------------------+
bool CPrecisionEntry::DetectRetestCandle(const DarvasBox &box,
                                        ENUM_TIMEFRAMES timeframe,
                                        bool isLong,
                                        double breakoutLevel)
{
    double tolerance = box.Height * m_RetestTolerance;
    double low = iLow(_Symbol, timeframe, 0);
    double high = iHigh(_Symbol, timeframe, 0);
    
    if(isLong)
    {
        // Retest: price returns to breakout level (top)
        return (low <= breakoutLevel + tolerance && 
                low >= breakoutLevel - tolerance);
    }
    else
    {
        // Retest: price returns to breakout level (bottom)
        return (high >= breakoutLevel - tolerance && 
                high <= breakoutLevel + tolerance);
    }
}

//+------------------------------------------------------------------+
//| Detect confirmation candle                                         |
//+------------------------------------------------------------------+
bool CPrecisionEntry::DetectConfirmationCandle(const DarvasBox &box,
                                               ENUM_TIMEFRAMES timeframe,
                                               bool isLong)
{
    double close = iClose(_Symbol, timeframe, 0);
    
    if(isLong)
        return (close > box.Top);
    else
        return (close < box.Bottom);
}

//+------------------------------------------------------------------+
//| Check volume spike                                               |
//+------------------------------------------------------------------+
bool CPrecisionEntry::CheckVolumeSpike(ENUM_TIMEFRAMES timeframe,
                                       double minSurge)
{
    if(m_VolumeAnalyzer == NULL) return true; // Skip if no analyzer
    
    double surgeRatio;
    if(m_VolumeAnalyzer.CheckVolumeSurge(timeframe, surgeRatio))
        return (surgeRatio >= minSurge);
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate entry price                                            |
//+------------------------------------------------------------------+
double CPrecisionEntry::CalculateEntryPrice(ENUM_ENTRY_TYPE type,
                                           const DarvasBox &box,
                                           bool isLong)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double boxHeight = box.Height;
    
    switch(type)
    {
        case ENTRY_PRIMARY:
        {
            // Entry: Max(breakoutHigh, retestLow) + 0.1× boxHeight
            double breakoutHigh = isLong ? iHigh(_Symbol, PERIOD_CURRENT, 1) : 
                                          iLow(_Symbol, PERIOD_CURRENT, 1);
            double retestLow = isLong ? iLow(_Symbol, PERIOD_CURRENT, 0) : 
                                       iHigh(_Symbol, PERIOD_CURRENT, 0);
            double basePrice = isLong ? MathMax(breakoutHigh, retestLow) : 
                                       MathMin(breakoutHigh, retestLow);
            return basePrice + (isLong ? 1 : -1) * boxHeight * 0.1;
        }
        
        case ENTRY_SECONDARY:
        {
            // Immediate entry at current price
            return iClose(_Symbol, PERIOD_CURRENT, 0);
        }
        
        case ENTRY_TERTIARY:
        {
            // Entry at opposite boundary
            return isLong ? box.Bottom : box.Top;
        }
    }
    
    return 0;
}

//+------------------------------------------------------------------+
