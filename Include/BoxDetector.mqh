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
    double top, bottom;
    int consolidationBars;
    
    // Find consolidation range
    if(!FindConsolidationRange(timeframe, top, bottom, consolidationBars))
        return false;
    
    if(consolidationBars < m_MinBarsInBox)
        return false;
    
    // Check for compression (narrowing range)
    if(!CheckCompression(timeframe, consolidationBars))
        return false;
    
    // Get ATR for volatility measure
    double atr = GetATR(timeframe);
    if(atr <= 0) return false;
    
    // Get volume information
    double avgVolume = GetAverageVolume(timeframe);
    
    // Determine direction based on higher timeframe
    bool isBullish = true;
    if(m_UseMultiTFBoxes && timeframe == m_OperationalTF)
    {
        // Check trend timeframe for direction
        double trendHigh = GetHighestHigh(m_TrendTF, 20);
        double trendLow = GetLowestLow(m_TrendTF, 20);
        double currentPrice = iClose(_Symbol, m_TrendTF, 0);
        isBullish = (currentPrice > (trendHigh + trendLow) / 2);
    }
    
    // Create box structure
    box.Top = top;
    box.Bottom = bottom;
    box.Height = MathAbs(top - bottom);
    box.ConsolidationBars = consolidationBars;
    box.CreationTime = iTime(_Symbol, timeframe, 0);
    box.Timeframe = (int)timeframe;
    box.ATRValue = atr;
    box.IsBullish = isBullish;
    box.VolumeInsideBox = (int)avgVolume;
    box.IsNested = false;
    box.ParentBoxId = 0;
    
    // Validate box
    box.Validated = ValidateBox(box, timeframe);
    
    // Calculate initial breakout force
    box.BreakoutForce = 0;
    
    return box.Validated;
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
