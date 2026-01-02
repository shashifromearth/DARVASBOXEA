//+------------------------------------------------------------------+
//|                                            VolumeAnalyzer.mqh    |
//|                    Volume Confirmation and Analysis Engine       |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Volume Analyzer Class                                            |
//+------------------------------------------------------------------+
class CVolumeAnalyzer
{
private:
    int               m_VolumePeriod;      // Period for average volume
    double             m_VolumeSurgeMin;     // Minimum volume surge (1.5 = 150%)
    
    long               m_VolumeArray[];
    double             m_VolumeMA[];
    
public:
    CVolumeAnalyzer();
    ~CVolumeAnalyzer();
    
    bool              Initialize(int period = 20, double surgeMin = 1.5);
    bool              CheckVolumeSurge(ENUM_TIMEFRAMES timeframe, double &surgeRatio);
    bool              CheckVolumePattern(const DarvasBox &box, ENUM_TIMEFRAMES timeframe);
    bool              IsVolumeDecreasing(ENUM_TIMEFRAMES timeframe, int bars);
    bool              IsVolumeExhaustion(ENUM_TIMEFRAMES timeframe);
    double            GetVolumeRatio(ENUM_TIMEFRAMES timeframe, int period = 20);
    bool              ValidateBreakoutVolume(ENUM_TIMEFRAMES timeframe, double minSurge = 1.5);
    
private:
    double            GetAverageVolume(ENUM_TIMEFRAMES timeframe, int period);
    long              GetCurrentVolume(ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVolumeAnalyzer::CVolumeAnalyzer()
{
    m_VolumePeriod = 20;
    m_VolumeSurgeMin = 1.5;
    ArrayResize(m_VolumeArray, 0);
    ArrayResize(m_VolumeMA, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVolumeAnalyzer::~CVolumeAnalyzer()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CVolumeAnalyzer::Initialize(int period = 20, double surgeMin = 1.5)
{
    m_VolumePeriod = period;
    m_VolumeSurgeMin = surgeMin;
    return true;
}

//+------------------------------------------------------------------+
//| Check for volume surge                                           |
//+------------------------------------------------------------------+
bool CVolumeAnalyzer::CheckVolumeSurge(ENUM_TIMEFRAMES timeframe, double &surgeRatio)
{
    long currentVolume = GetCurrentVolume(timeframe);
    double avgVolume = GetAverageVolume(timeframe, m_VolumePeriod);
    
    if(avgVolume == 0) return false;
    
    surgeRatio = (double)currentVolume / avgVolume;
    return (surgeRatio >= m_VolumeSurgeMin);
}

//+------------------------------------------------------------------+
//| Check volume pattern for box                                     |
//+------------------------------------------------------------------+
bool CVolumeAnalyzer::CheckVolumePattern(const DarvasBox &box, ENUM_TIMEFRAMES timeframe)
{
    // Inside Box: Volume should decrease (consolidation)
    double avgVolumeInside = GetAverageVolume(timeframe, box.ConsolidationBars);
    double avgVolumeBefore = GetAverageVolume(timeframe, box.ConsolidationBars * 2);
    
    // Volume inside should be lower than before (consolidation)
    if(avgVolumeInside >= avgVolumeBefore * 1.1)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if volume is decreasing                                    |
//+------------------------------------------------------------------+
bool CVolumeAnalyzer::IsVolumeDecreasing(ENUM_TIMEFRAMES timeframe, int bars)
{
    if(bars < 3) return false;
    
    double firstHalf = GetAverageVolume(timeframe, bars / 2);
    double secondHalf = GetAverageVolume(timeframe, bars);
    
    return (secondHalf < firstHalf * 0.9);
}

//+------------------------------------------------------------------+
//| Check for volume exhaustion                                      |
//+------------------------------------------------------------------+
bool CVolumeAnalyzer::IsVolumeExhaustion(ENUM_TIMEFRAMES timeframe)
{
    long currentVolume = GetCurrentVolume(timeframe);
    double avgVolume = GetAverageVolume(timeframe, m_VolumePeriod);
    
    if(avgVolume == 0) return false;
    
    // Volume spike > 300% but price stalls
    double volumeRatio = (double)currentVolume / avgVolume;
    
    if(volumeRatio > 3.0)
    {
        // Check if price is stalling (small body, long wicks)
        double open = iOpen(_Symbol, timeframe, 0);
        double close = iClose(_Symbol, timeframe, 0);
        double high = iHigh(_Symbol, timeframe, 0);
        double low = iLow(_Symbol, timeframe, 0);
        
        double bodySize = MathAbs(close - open);
        double totalRange = high - low;
        
        // Small body relative to range indicates stalling
        if(totalRange > 0 && bodySize / totalRange < 0.3)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get volume ratio                                                 |
//+------------------------------------------------------------------+
double CVolumeAnalyzer::GetVolumeRatio(ENUM_TIMEFRAMES timeframe, int period = 20)
{
    long currentVolume = GetCurrentVolume(timeframe);
    double avgVolume = GetAverageVolume(timeframe, period);
    
    if(avgVolume == 0) return 0;
    
    return (double)currentVolume / avgVolume;
}

//+------------------------------------------------------------------+
//| Validate breakout volume                                         |
//+------------------------------------------------------------------+
bool CVolumeAnalyzer::ValidateBreakoutVolume(ENUM_TIMEFRAMES timeframe, double minSurge = 1.5)
{
    double surgeRatio;
    return CheckVolumeSurge(timeframe, surgeRatio) && surgeRatio >= minSurge;
}

//+------------------------------------------------------------------+
//| Get average volume                                               |
//+------------------------------------------------------------------+
double CVolumeAnalyzer::GetAverageVolume(ENUM_TIMEFRAMES timeframe, int period)
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
//| Get current volume                                               |
//+------------------------------------------------------------------+
long CVolumeAnalyzer::GetCurrentVolume(ENUM_TIMEFRAMES timeframe)
{
    long volume[];
    ArraySetAsSeries(volume, true);
    
    if(CopyTickVolume(_Symbol, timeframe, 0, 1, volume) <= 0)
        return 0;
    
    return volume[0];
}

//+------------------------------------------------------------------+
