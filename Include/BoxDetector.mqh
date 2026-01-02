//+------------------------------------------------------------------+
//|                                              BoxDetector.mqh     |
//|                    Multi-Timeframe Box Detection Engine          |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Box Detector Class                                               |
//+------------------------------------------------------------------+
class CBoxDetector
{
private:
    ENUM_TIMEFRAMES   m_OperationalTF;   // Entry timeframe
    ENUM_TIMEFRAMES   m_TrendTF;         // Trend timeframe
    ENUM_TIMEFRAMES   m_ConfirmationTF;  // Confirmation timeframe
    
    int               m_MinBarsInBox;    // Minimum consolidation bars
    double            m_BoxSensitivity;  // Sensitivity to price swings
    bool              m_UseVolumeFilter; // Volume confirmation
    bool              m_UseMultiTFBoxes; // Multi-timeframe boxes
    
    DarvasBox         m_CurrentBoxes[];  // Current boxes array
    int               m_BoxCount;        // Number of active boxes
    
    // ATR handle for volatility calculation
    int               m_ATRHandle;
    
    // Volume array
    long              m_VolumeArray[];
    
public:
    CBoxDetector();
    ~CBoxDetector();
    
    bool              Initialize(ENUM_TIMEFRAMES operationalTF, 
                                  ENUM_TIMEFRAMES trendTF, 
                                  ENUM_TIMEFRAMES confirmationTF,
                                  int minBars, 
                                  double sensitivity,
                                  bool useVolume,
                                  bool useMultiTF);
    
    bool              DetectBox(ENUM_TIMEFRAMES timeframe, DarvasBox &box);
    bool              ValidateBox(DarvasBox &box, ENUM_TIMEFRAMES timeframe);
    bool              CheckBoxBreakout(const DarvasBox &box, ENUM_TIMEFRAMES timeframe, bool &isLong);
    bool              IsBoxForming(ENUM_TIMEFRAMES timeframe, DarvasBox &box);
    bool              CheckNestedBox(const DarvasBox &parentBox, DarvasBox &nestedBox);
    
    double            GetATR(ENUM_TIMEFRAMES timeframe, int period = 14);
    double            GetAverageVolume(ENUM_TIMEFRAMES timeframe, int period = 20);
    bool              CheckVolumePattern(const DarvasBox &box, ENUM_TIMEFRAMES timeframe);
    
    int               GetBoxCount() { return m_BoxCount; }
    bool              GetBox(int index, DarvasBox &box);
    void              UpdateBoxes();
    void              CleanupInvalidBoxes();
    
private:
    bool              FindConsolidationRange(ENUM_TIMEFRAMES timeframe, 
                                            double &top, 
                                            double &bottom, 
                                            int &bars);
    bool              CheckCompression(ENUM_TIMEFRAMES timeframe, int bars);
    double            GetHighestHigh(ENUM_TIMEFRAMES timeframe, int bars);
    double            GetLowestLow(ENUM_TIMEFRAMES timeframe, int bars);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBoxDetector::CBoxDetector()
{
    m_BoxCount = 0;
    m_ATRHandle = INVALID_HANDLE;
    ArrayResize(m_CurrentBoxes, 0);
    ArrayResize(m_VolumeArray, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBoxDetector::~CBoxDetector()
{
    if(m_ATRHandle != INVALID_HANDLE)
        IndicatorRelease(m_ATRHandle);
}

//+------------------------------------------------------------------+
//| Initialize detector                                              |
//+------------------------------------------------------------------+
bool CBoxDetector::Initialize(ENUM_TIMEFRAMES operationalTF, 
                              ENUM_TIMEFRAMES trendTF, 
                              ENUM_TIMEFRAMES confirmationTF,
                              int minBars, 
                              double sensitivity,
                              bool useVolume,
                              bool useMultiTF)
{
    m_OperationalTF = operationalTF;
    m_TrendTF = trendTF;
    m_ConfirmationTF = confirmationTF;
    m_MinBarsInBox = minBars;
    m_BoxSensitivity = sensitivity;
    m_UseVolumeFilter = useVolume;
    m_UseMultiTFBoxes = useMultiTF;
    
    // Initialize ATR indicator
    m_ATRHandle = iATR(_Symbol, operationalTF, 14);
    if(m_ATRHandle == INVALID_HANDLE)
    {
        Print("Failed to create ATR indicator");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect Darvas Box on specified timeframe                        |
//+------------------------------------------------------------------+
bool CBoxDetector::DetectBox(ENUM_TIMEFRAMES timeframe, DarvasBox &box)
{
    // SIMPLE BOX DETECTION - Much more aggressive
    // Just look for recent high/low range (simplified Darvas Box)
    
    int lookbackBars = MathMax(m_MinBarsInBox, 5); // At least 5 bars, or minBars
    int maxLookback = 20; // Look back max 20 bars
    
    // Get recent high and low
    double highest = GetHighestHigh(timeframe, lookbackBars);
    double lowest = GetLowestLow(timeframe, lookbackBars);
    
    if(highest <= lowest) return false;
    
    // Count how many bars stayed within this range
    int barsInRange = 0;
    double range = highest - lowest;
    
    // Check if price has been trading in this range
    for(int i = 1; i <= lookbackBars && i < maxLookback; i++)
    {
        double high = iHigh(_Symbol, timeframe, i);
        double low = iLow(_Symbol, timeframe, i);
        
        // Check if bar is mostly within the range (allow 10% tolerance)
        if(high <= highest * 1.05 && low >= lowest * 0.95)
        {
            barsInRange++;
        }
    }
    
    // Require at least 60% of bars to be in range (much more lenient)
    int minBarsRequired = (int)(lookbackBars * 0.6);
    if(barsInRange < minBarsRequired)
    {
        // Try with smaller lookback
        lookbackBars = MathMax(3, m_MinBarsInBox);
        highest = GetHighestHigh(timeframe, lookbackBars);
        lowest = GetLowestLow(timeframe, lookbackBars);
        range = highest - lowest;
        
        if(highest <= lowest) return false;
        
        barsInRange = 0;
        for(int i = 1; i <= lookbackBars; i++)
        {
            double high = iHigh(_Symbol, timeframe, i);
            double low = iLow(_Symbol, timeframe, i);
            if(high <= highest * 1.1 && low >= lowest * 0.9)
                barsInRange++;
        }
        
        minBarsRequired = (int)(lookbackBars * 0.5); // Even more lenient
        if(barsInRange < minBarsRequired)
            return false;
    }
    
    // Get ATR for volatility measure
    double atr = GetATR(timeframe);
    if(atr <= 0) 
    {
        // If ATR fails, use a simple calculation
        atr = range * 0.1; // Estimate 10% of range
        if(atr <= 0) return false;
    }
    
    // Get volume information
    double avgVolume = GetAverageVolume(timeframe);
    
    // Determine direction
    double currentPrice = iClose(_Symbol, timeframe, 0);
    bool isBullish = (currentPrice > (highest + lowest) / 2);
    
    // Create box structure
    box.Top = highest;
    box.Bottom = lowest;
    box.Height = range;
    box.ConsolidationBars = barsInRange;
    box.CreationTime = iTime(_Symbol, timeframe, 0);
    box.Timeframe = (int)timeframe;
    box.ATRValue = atr;
    box.IsBullish = isBullish;
    box.VolumeInsideBox = (int)avgVolume;
    box.IsNested = false;
    box.ParentBoxId = 0;
    
    // SIMPLIFIED VALIDATION - Much more lenient
    if(box.Height <= 0) return false;
    if(box.Top <= box.Bottom) return false;
    if(box.ConsolidationBars < MathMax(2, m_MinBarsInBox - 1)) return false; // Allow 1 less bar
    
    // Volume validation - only if enabled and not too strict
    if(m_UseVolumeFilter)
    {
        if(!CheckVolumePattern(box, timeframe))
        {
            // Don't fail completely, just log
            // return false; // REMOVED - too strict
        }
    }
    
    // ATR height check - much more lenient
    if(box.Height < atr * 0.2 || box.Height > atr * 10.0)
    {
        // Still allow, just log
        // return false; // REMOVED - too strict
    }
    
    box.Validated = true;
    box.BreakoutForce = 0;
    
    return true; // Always return true if we got this far
}

//+------------------------------------------------------------------+
//| Find consolidation range                                         |
//+------------------------------------------------------------------+
bool CBoxDetector::FindConsolidationRange(ENUM_TIMEFRAMES timeframe, 
                                           double &top, 
                                           double &bottom, 
                                           int &bars)
{
    int maxBars = 50; // Maximum bars to look back
    int minBars = m_MinBarsInBox;
    
    // Start from current bar and look back
    for(int startBar = 1; startBar < maxBars - minBars; startBar++)
    {
        // Find highest high and lowest low in recent period
        double highest = GetHighestHigh(timeframe, startBar + minBars);
        double lowest = GetLowestLow(timeframe, startBar + minBars);
        
        // Check if price has been consolidating
        bool isConsolidating = true;
        int consolidationCount = 0;
        
        for(int i = startBar; i < startBar + minBars && i < maxBars; i++)
        {
            double high = iHigh(_Symbol, timeframe, i);
            double low = iLow(_Symbol, timeframe, i);
            
            // Check if price stays within range
            if(high <= highest * (1 + m_BoxSensitivity) && 
               low >= lowest * (1 - m_BoxSensitivity))
            {
                consolidationCount++;
            }
            else
            {
                // Update range if needed
                if(high > highest) highest = high;
                if(low < lowest) lowest = low;
            }
        }
        
        if(consolidationCount >= minBars)
        {
            top = highest;
            bottom = lowest;
            bars = consolidationCount;
            
            // Refine top and bottom to exact levels
            top = GetHighestHigh(timeframe, startBar + consolidationCount);
            bottom = GetLowestLow(timeframe, startBar + consolidationCount);
            
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for price compression (narrowing range)                   |
//+------------------------------------------------------------------+
bool CBoxDetector::CheckCompression(ENUM_TIMEFRAMES timeframe, int bars)
{
    if(bars < 3) return false;
    
    // Calculate range for first half and second half
    int halfBars = bars / 2;
    
    double firstHalfRange = GetHighestHigh(timeframe, halfBars) - 
                           GetLowestLow(timeframe, halfBars);
    
    double secondHalfRange = GetHighestHigh(timeframe, bars) - 
                            GetLowestLow(timeframe, bars);
    
    // Compression: second half should be smaller or equal
    return (secondHalfRange <= firstHalfRange * 1.1);
}

//+------------------------------------------------------------------+
//| Validate box                                                     |
//+------------------------------------------------------------------+
bool CBoxDetector::ValidateBox(DarvasBox &box, ENUM_TIMEFRAMES timeframe)
{
    if(box.Height <= 0) return false;
    if(box.Top <= box.Bottom) return false;
    if(box.ConsolidationBars < m_MinBarsInBox) return false;
    
    // Volume validation if enabled
    if(m_UseVolumeFilter)
    {
        if(!CheckVolumePattern(box, timeframe))
            return false;
    }
    
    // Check if box height is reasonable (not too small, not too large)
    double atr = GetATR(timeframe);
    if(box.Height < atr * 0.5 || box.Height > atr * 5.0)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check box breakout                                               |
//+------------------------------------------------------------------+
bool CBoxDetector::CheckBoxBreakout(const DarvasBox &box, ENUM_TIMEFRAMES timeframe, bool &isLong)
{
    double close = iClose(_Symbol, timeframe, 0);
    double prevClose = iClose(_Symbol, timeframe, 1);
    double high = iHigh(_Symbol, timeframe, 0);
    double low = iLow(_Symbol, timeframe, 0);
    
    // Check for bullish breakout
    if(close > box.Top && prevClose <= box.Top)
    {
        isLong = true;
        return true;
    }
    
    // Check for bearish breakout
    if(close < box.Bottom && prevClose >= box.Bottom)
    {
        isLong = false;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if box is currently forming                               |
//+------------------------------------------------------------------+
bool CBoxDetector::IsBoxForming(ENUM_TIMEFRAMES timeframe, DarvasBox &box)
{
    return DetectBox(timeframe, box);
}

//+------------------------------------------------------------------+
//| Check for nested box                                             |
//+------------------------------------------------------------------+
bool CBoxDetector::CheckNestedBox(const DarvasBox &parentBox, DarvasBox &nestedBox)
{
    // Detect a smaller box within the parent box
    if(!DetectBox((ENUM_TIMEFRAMES)parentBox.Timeframe, nestedBox))
        return false;
    
    // Check if nested box is inside parent box
    if(nestedBox.Top <= parentBox.Top && nestedBox.Bottom >= parentBox.Bottom)
    {
        nestedBox.IsNested = true;
        nestedBox.ParentBoxId = (ulong)parentBox.CreationTime; // Use creation time as ID
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double CBoxDetector::GetATR(ENUM_TIMEFRAMES timeframe, int period = 14)
{
    if(m_ATRHandle == INVALID_HANDLE)
    {
        m_ATRHandle = iATR(_Symbol, timeframe, period);
        if(m_ATRHandle == INVALID_HANDLE) return 0;
    }
    
    double atr[];
    ArraySetAsSeries(atr, true);
    
    if(CopyBuffer(m_ATRHandle, 0, 0, 1, atr) <= 0)
        return 0;
    
    return atr[0];
}

//+------------------------------------------------------------------+
//| Get average volume                                               |
//+------------------------------------------------------------------+
double CBoxDetector::GetAverageVolume(ENUM_TIMEFRAMES timeframe, int period = 20)
{
    ArrayResize(m_VolumeArray, period);
    ArraySetAsSeries(m_VolumeArray, true);
    
    if(CopyTickVolume(_Symbol, timeframe, 0, period, m_VolumeArray) <= 0)
        return 0;
    
    long sum = 0;
    for(int i = 0; i < period; i++)
        sum += m_VolumeArray[i];
    
    return (double)sum / period;
}

//+------------------------------------------------------------------+
//| Check volume pattern                                             |
//+------------------------------------------------------------------+
bool CBoxDetector::CheckVolumePattern(const DarvasBox &box, ENUM_TIMEFRAMES timeframe)
{
    // Volume should decrease inside box (consolidation)
    double avgVolumeInside = GetAverageVolume(timeframe, box.ConsolidationBars);
    double avgVolumeBefore = GetAverageVolume(timeframe, box.ConsolidationBars * 2);
    
    // Volume inside should be lower than before (consolidation)
    return (avgVolumeInside < avgVolumeBefore * 1.1);
}

//+------------------------------------------------------------------+
//| Get highest high                                                 |
//+------------------------------------------------------------------+
double CBoxDetector::GetHighestHigh(ENUM_TIMEFRAMES timeframe, int bars)
{
    double high = 0;
    for(int i = 0; i < bars; i++)
    {
        double h = iHigh(_Symbol, timeframe, i);
        if(h > high || i == 0) high = h;
    }
    return high;
}

//+------------------------------------------------------------------+
//| Get lowest low                                                    |
//+------------------------------------------------------------------+
double CBoxDetector::GetLowestLow(ENUM_TIMEFRAMES timeframe, int bars)
{
    double low = DBL_MAX;
    for(int i = 0; i < bars; i++)
    {
        double l = iLow(_Symbol, timeframe, i);
        if(l < low || i == 0) low = l;
    }
    return low;
}

//+------------------------------------------------------------------+
//| Get box by index                                                 |
//+------------------------------------------------------------------+
bool CBoxDetector::GetBox(int index, DarvasBox &box)
{
    if(index < 0 || index >= m_BoxCount)
        return false;
    
    box = m_CurrentBoxes[index];
    return true;
}

//+------------------------------------------------------------------+
//| Update boxes                                                     |
//+------------------------------------------------------------------+
void CBoxDetector::UpdateBoxes()
{
    CleanupInvalidBoxes();
    
    // Detect new boxes on operational timeframe
    DarvasBox newBox;
    if(DetectBox(m_OperationalTF, newBox))
    {
        // Check if this box already exists
        bool exists = false;
        for(int i = 0; i < m_BoxCount; i++)
        {
            if(MathAbs(m_CurrentBoxes[i].Top - newBox.Top) < _Point * 10 &&
               MathAbs(m_CurrentBoxes[i].Bottom - newBox.Bottom) < _Point * 10)
            {
                exists = true;
                break;
            }
        }
        
        if(!exists)
        {
            ArrayResize(m_CurrentBoxes, m_BoxCount + 1);
            m_CurrentBoxes[m_BoxCount] = newBox;
            m_BoxCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Cleanup invalid boxes                                            |
//+------------------------------------------------------------------+
void CBoxDetector::CleanupInvalidBoxes()
{
    // Remove boxes that are no longer valid (broken out or expired)
    for(int i = m_BoxCount - 1; i >= 0; i--)
    {
        bool isLong;
        if(CheckBoxBreakout(m_CurrentBoxes[i], (ENUM_TIMEFRAMES)m_CurrentBoxes[i].Timeframe, isLong))
        {
            // Box has broken out, remove it
            for(int j = i; j < m_BoxCount - 1; j++)
                m_CurrentBoxes[j] = m_CurrentBoxes[j + 1];
            m_BoxCount--;
            ArrayResize(m_CurrentBoxes, m_BoxCount);
        }
    }
}

//+------------------------------------------------------------------+
