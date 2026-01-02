//+------------------------------------------------------------------+
//|                                            EntryManager.mqh      |
//|                    3-Tier Entry System Implementation            |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "BreakoutScorer.mqh"
#include "RiskManager.mqh"
#include "VolumeAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Entry Manager Class                                              |
//+------------------------------------------------------------------+
class CEntryManager
{
private:
    bool              m_UseTieredEntries;    // Use 3-tier entry system
    int               m_MinBreakoutScore;   // Minimum quality score
    double            m_VolumeSurgeMin;     // Minimum volume surge
    
    CBreakoutScorer  *m_Scorer;
    CRiskManager     *m_RiskManager;
    CVolumeAnalyzer  *m_VolumeAnalyzer;
    
    // Entry tracking
    TradeEntry        m_PendingEntries[];
    int               m_EntryCount;
    
public:
    CEntryManager();
    ~CEntryManager();
    
    bool              Initialize(bool useTiered,
                                  int minScore,
                                  double volumeSurge,
                                  CBreakoutScorer *scorer,
                                  CRiskManager *riskManager,
                                  CVolumeAnalyzer *volumeAnalyzer);
    
    bool              CheckTier1Entry(const DarvasBox &box, 
                                      ENUM_TIMEFRAMES timeframe,
                                      TradeEntry &entry);
    bool              CheckTier2Entry(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe,
                                      TradeEntry &entry);
    bool              CheckTier3Entry(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe,
                                      TradeEntry &entry);
    
    bool              ProcessBreakout(const DarvasBox &box,
                                     ENUM_TIMEFRAMES timeframe,
                                     bool isLong,
                                     TradeEntry &entry);
    
    void              UpdatePendingEntries();
    void              CleanupFilledEntries();
    
private:
    bool              CheckTier1Conditions(const DarvasBox &box,
                                           ENUM_TIMEFRAMES timeframe,
                                           bool isLong);
    bool              CheckTier2Conditions(const DarvasBox &box,
                                           ENUM_TIMEFRAMES timeframe,
                                           bool isLong);
    bool              CheckTier3Conditions(const DarvasBox &box,
                                           ENUM_TIMEFRAMES timeframe,
                                           bool isLong);
    double            CalculateEntryPrice(int tier, const DarvasBox &box, bool isLong);
    bool              CheckMomentumConfirmation(ENUM_TIMEFRAMES timeframe, bool isLong);
    bool              CheckRetestFormation(ENUM_TIMEFRAMES timeframe, const DarvasBox &box, bool isLong);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEntryManager::CEntryManager()
{
    m_UseTieredEntries = true;
    m_MinBreakoutScore = 70;
    m_VolumeSurgeMin = 1.5;
    m_Scorer = NULL;
    m_RiskManager = NULL;
    m_VolumeAnalyzer = NULL;
    m_EntryCount = 0;
    ArrayResize(m_PendingEntries, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEntryManager::~CEntryManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CEntryManager::Initialize(bool useTiered,
                               int minScore,
                               double volumeSurge,
                               CBreakoutScorer *scorer,
                               CRiskManager *riskManager,
                               CVolumeAnalyzer *volumeAnalyzer)
{
    m_UseTieredEntries = useTiered;
    m_MinBreakoutScore = minScore;
    m_VolumeSurgeMin = volumeSurge;
    m_Scorer = scorer;
    m_RiskManager = riskManager;
    m_VolumeAnalyzer = volumeAnalyzer;
    
    return true;
}

//+------------------------------------------------------------------+
//| Process breakout and determine entry                             |
//+------------------------------------------------------------------+
bool CEntryManager::ProcessBreakout(const DarvasBox &box,
                                     ENUM_TIMEFRAMES timeframe,
                                     bool isLong,
                                     TradeEntry &entry)
{
    // Check if breakout is valid
    if(m_Scorer != NULL)
    {
        if(!m_Scorer.IsBreakoutValid(box, timeframe, isLong))
            return false;
        
        // Check for false breakout
        if(m_Scorer.CheckFalseBreakout(box, timeframe, isLong))
            return false;
    }
    
    // Try Tier 1 entry first (aggressive)
    if(CheckTier1Entry(box, timeframe, entry))
    {
        entry.Tier = 1;
        return true;
    }
    
    // If tiered entries enabled, check for Tier 2 and 3
    if(m_UseTieredEntries)
    {
        // Tier 2 will be checked on retest
        // Tier 3 will be checked on momentum continuation
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Tier 1 Entry (Aggressive - 20% position)                  |
//+------------------------------------------------------------------+
bool CEntryManager::CheckTier1Entry(const DarvasBox &box, 
                                      ENUM_TIMEFRAMES timeframe,
                                      TradeEntry &entry)
{
    double close = iClose(_Symbol, timeframe, 0);
    double prevClose = iClose(_Symbol, timeframe, 1);
    bool isLong = (close > box.Top);
    
    // Check Tier 1 conditions
    if(!CheckTier1Conditions(box, timeframe, isLong))
        return false;
    
    // Calculate entry price (breakout close + 2 pips buffer)
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entryPrice = isLong ? (close + 2 * point * 10) : (close - 2 * point * 10);
    
    // Calculate stop loss
    double stopLoss = 0;
    if(m_RiskManager != NULL)
        stopLoss = m_RiskManager.CalculateStopLoss(box, isLong, timeframe);
    else
        stopLoss = isLong ? (box.Bottom - box.ATRValue) : (box.Top + box.ATRValue);
    
    // Calculate position size (20% of full position)
    double positionSize = 0;
    if(m_RiskManager != NULL)
    {
        double fullSize = m_RiskManager.CalculatePositionSize(box, entryPrice, stopLoss);
        positionSize = fullSize * 0.2; // 20% for Tier 1
    }
    
    if(positionSize <= 0) return false;
    
    // Calculate take profit (3× box height)
    double boxHeight = box.Height;
    double takeProfit = isLong ? (entryPrice + boxHeight * 3.0) : (entryPrice - boxHeight * 3.0);
    
    // Get breakout score
    int score = 70;
    if(m_Scorer != NULL)
        score = m_Scorer.CalculateBreakoutScore(box, timeframe, isLong);
    
    // Fill entry structure
    entry.EntryPrice = entryPrice;
    entry.StopLoss = stopLoss;
    entry.TakeProfit = takeProfit;
    entry.PositionSize = positionSize;
    entry.BreakoutScore = score;
    entry.EntryTime = TimeCurrent();
    entry.IsLong = isLong;
    entry.BoxId = (ulong)box.CreationTime; // Use creation time as ID
    entry.OrderType = ORDER_TYPE_BUY; // Will be set based on isLong
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Tier 2 Entry (Confirmation - 50% position)                |
//+------------------------------------------------------------------+
bool CEntryManager::CheckTier2Entry(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe,
                                      TradeEntry &entry)
{
    // Check if price retested broken Top as support (for long)
    bool isLong = true; // Assume long for now
    double currentPrice = iClose(_Symbol, timeframe, 0);
    
    if(currentPrice < box.Top) return false; // Not broken out yet
    
    // Check retest conditions
    if(!CheckTier2Conditions(box, timeframe, isLong))
        return false;
    
    // Entry price at retest level (Top + 1 pip)
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entryPrice = box.Top + point * 10;
    
    // Calculate stop loss
    double stopLoss = 0;
    if(m_RiskManager != NULL)
        stopLoss = m_RiskManager.CalculateStopLoss(box, isLong, timeframe);
    
    // Calculate position size (50% of full position)
    double positionSize = 0;
    if(m_RiskManager != NULL)
    {
        double fullSize = m_RiskManager.CalculatePositionSize(box, entryPrice, stopLoss);
        positionSize = fullSize * 0.5; // 50% for Tier 2
    }
    
    if(positionSize <= 0) return false;
    
    // Calculate take profit
    double boxHeight = box.Height;
    double takeProfit = entryPrice + boxHeight * 3.0;
    
    // Fill entry structure
    entry.EntryPrice = entryPrice;
    entry.StopLoss = stopLoss;
    entry.TakeProfit = takeProfit;
    entry.PositionSize = positionSize;
    entry.BreakoutScore = 80; // Higher score for retest
    entry.EntryTime = TimeCurrent();
    entry.IsLong = isLong;
    entry.BoxId = (ulong)box.CreationTime; // Use creation time as ID
    entry.OrderType = ORDER_TYPE_BUY_LIMIT; // Limit order for retest
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Tier 3 Entry (Momentum Add - 30% position)               |
//+------------------------------------------------------------------+
bool CEntryManager::CheckTier3Entry(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe,
                                      TradeEntry &entry)
{
    // Check momentum continuation conditions
    bool isLong = true;
    if(!CheckTier3Conditions(box, timeframe, isLong))
        return false;
    
    // Entry above recent consolidation high
    double recentHigh = iHigh(_Symbol, timeframe, 5);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entryPrice = recentHigh + point * 10;
    
    // Calculate stop loss
    double stopLoss = 0;
    if(m_RiskManager != NULL)
        stopLoss = m_RiskManager.CalculateStopLoss(box, isLong, timeframe);
    
    // Calculate position size (30% of full position)
    double positionSize = 0;
    if(m_RiskManager != NULL)
    {
        double fullSize = m_RiskManager.CalculatePositionSize(box, entryPrice, stopLoss);
        positionSize = fullSize * 0.3; // 30% for Tier 3
    }
    
    if(positionSize <= 0) return false;
    
    // Calculate take profit
    double boxHeight = box.Height;
    double takeProfit = entryPrice + boxHeight * 3.0;
    
    // Fill entry structure
    entry.EntryPrice = entryPrice;
    entry.StopLoss = stopLoss;
    entry.TakeProfit = takeProfit;
    entry.PositionSize = positionSize;
    entry.BreakoutScore = 75;
    entry.EntryTime = TimeCurrent();
    entry.IsLong = isLong;
    entry.BoxId = (ulong)box.CreationTime; // Use creation time as ID
    entry.OrderType = ORDER_TYPE_BUY_STOP; // Stop order for momentum
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Tier 1 Conditions                                          |
//+------------------------------------------------------------------+
bool CEntryManager::CheckTier1Conditions(const DarvasBox &box,
                                          ENUM_TIMEFRAMES timeframe,
                                          bool isLong)
{
    double close = iClose(_Symbol, timeframe, 0);
    double prevClose = iClose(_Symbol, timeframe, 1);
    
    // 1. Price breaks above TOP (for long) or below BOTTOM (for short)
    if(isLong && close <= box.Top) return false;
    if(!isLong && close >= box.Bottom) return false;
    
    // 2. Break occurs on closing basis
    if(isLong && prevClose > box.Top) return false; // Already broken
    if(!isLong && prevClose < box.Bottom) return false;
    
    // 3. Volume surge >= 150%
    if(m_VolumeAnalyzer != NULL)
    {
        double surgeRatio;
        if(!m_VolumeAnalyzer.CheckVolumeSurge(timeframe, surgeRatio) || surgeRatio < m_VolumeSurgeMin)
            return false;
    }
    
    // 4. Momentum confirmation (RSI > 60 for long, <40 for short)
    if(!CheckMomentumConfirmation(timeframe, isLong))
        return false;
    
    // 5. No immediate resistance within 1 ATR
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
        if(highest > close && (highest - close) < atr)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Tier 2 Conditions                                          |
//+------------------------------------------------------------------+
bool CEntryManager::CheckTier2Conditions(const DarvasBox &box,
                                          ENUM_TIMEFRAMES timeframe,
                                          bool isLong)
{
    // 1. Price retests broken Top as support (for long)
    double currentPrice = iClose(_Symbol, timeframe, 0);
    double low = iLow(_Symbol, timeframe, 0);
    double tolerance = box.Height * 0.1;
    
    if(isLong)
    {
        // Check if price retested top
        if(MathAbs(low - box.Top) > tolerance)
            return false;
        
        // 2. Retest must hold for minimum 2 bars
        double low1 = iLow(_Symbol, timeframe, 1);
        if(MathAbs(low1 - box.Top) > tolerance)
            return false;
        
        // 3. Check for bullish formations
        if(!CheckRetestFormation(timeframe, box, isLong))
            return false;
        
        // 4. Volume decreases on retest, increases on bounce
        if(m_VolumeAnalyzer != NULL)
        {
            double volume0 = m_VolumeAnalyzer.GetVolumeRatio(timeframe, 1);
            double volume1 = m_VolumeAnalyzer.GetVolumeRatio(timeframe, 2);
            if(volume0 >= volume1) return false; // Volume should increase
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Tier 3 Conditions                                          |
//+------------------------------------------------------------------+
bool CEntryManager::CheckTier3Conditions(const DarvasBox &box,
                                          ENUM_TIMEFRAMES timeframe,
                                          bool isLong)
{
    // 1. Price makes NEW HIGH above breakout candle
    double currentHigh = iHigh(_Symbol, timeframe, 0);
    double breakoutHigh = iHigh(_Symbol, timeframe, 5); // Assuming breakout was 5 bars ago
    
    if(isLong && currentHigh <= breakoutHigh)
        return false;
    
    // 2. Pullback ≤ 38.2% Fibonacci of breakout move
    double breakoutPrice = box.Top;
    double currentPrice = iClose(_Symbol, timeframe, 0);
    double pullback = (currentHigh - currentPrice) / (currentHigh - breakoutPrice);
    
    if(pullback > 0.382)
        return false;
    
    // 3. Volume expanding with price
    if(m_VolumeAnalyzer != NULL)
    {
        double volumeRatio = m_VolumeAnalyzer.GetVolumeRatio(timeframe, 5);
        if(volumeRatio < 1.0) return false; // Volume should be expanding
    }
    
    // 4. ADX rising > 25
    int adxHandle = iADX(_Symbol, timeframe, 14);
    if(adxHandle != INVALID_HANDLE)
    {
        double adx[];
        ArraySetAsSeries(adx, true);
        if(CopyBuffer(adxHandle, 0, 0, 1, adx) > 0)
        {
            if(adx[0] <= 25) return false;
        }
        IndicatorRelease(adxHandle);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check momentum confirmation                                      |
//+------------------------------------------------------------------+
bool CEntryManager::CheckMomentumConfirmation(ENUM_TIMEFRAMES timeframe, bool isLong)
{
    int rsiHandle = iRSI(_Symbol, timeframe, 14, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE) return true; // Skip if can't calculate
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0)
    {
        IndicatorRelease(rsiHandle);
        return true;
    }
    
    IndicatorRelease(rsiHandle);
    
    if(isLong)
        return (rsi[0] > 60);
    else
        return (rsi[0] < 40);
}

//+------------------------------------------------------------------+
//| Check retest formation                                           |
//+------------------------------------------------------------------+
bool CEntryManager::CheckRetestFormation(ENUM_TIMEFRAMES timeframe, const DarvasBox &box, bool isLong)
{
    double open0 = iOpen(_Symbol, timeframe, 0);
    double close0 = iClose(_Symbol, timeframe, 0);
    double high0 = iHigh(_Symbol, timeframe, 0);
    double low0 = iLow(_Symbol, timeframe, 0);
    
    double open1 = iOpen(_Symbol, timeframe, 1);
    double close1 = iClose(_Symbol, timeframe, 1);
    
    // Check for bullish hammer
    double body = MathAbs(close0 - open0);
    double lowerWick = MathMin(open0, close0) - low0;
    double upperWick = high0 - MathMax(open0, close0);
    
    if(isLong)
    {
        // Bullish hammer: small body, long lower wick, small upper wick
        if(body < (high0 - low0) * 0.3 && lowerWick > body * 2 && upperWick < body)
            return true;
        
        // Bullish engulfing
        if(close1 < open1 && close0 > open0 && open0 < close1 && close0 > open1)
            return true;
        
        // Inside bar breakout
        double high1 = iHigh(_Symbol, timeframe, 1);
        double low1 = iLow(_Symbol, timeframe, 1);
        if(high0 < high1 && low0 > low1 && close0 > open0)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate entry price                                            |
//+------------------------------------------------------------------+
double CEntryManager::CalculateEntryPrice(int tier, const DarvasBox &box, bool isLong)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    switch(tier)
    {
        case 1:
            // Market order at breakout close + 2 pips
            return isLong ? (box.Top + 2 * point * 10) : (box.Bottom - 2 * point * 10);
        case 2:
            // Limit order at retest level
            return isLong ? (box.Top + point * 10) : (box.Bottom - point * 10);
        case 3:
            // Stop order above recent high
            return isLong ? (iHigh(_Symbol, PERIOD_CURRENT, 5) + point * 10) : 
                           (iLow(_Symbol, PERIOD_CURRENT, 5) - point * 10);
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Update pending entries                                           |
//+------------------------------------------------------------------+
void CEntryManager::UpdatePendingEntries()
{
    // Check if pending entries should be executed
    // This would be called from OnTick
}

//+------------------------------------------------------------------+
//| Cleanup filled entries                                           |
//+------------------------------------------------------------------+
void CEntryManager::CleanupFilledEntries()
{
    // Remove filled entries from array
}

//+------------------------------------------------------------------+
