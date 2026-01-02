//+------------------------------------------------------------------+
//|                                            RiskManager.mqh       |
//|                    Dynamic Position Sizing and Risk Management   |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    double            m_BaseRiskPercent;    // Base risk per trade (1.5%)
    double            m_MaxDailyRisk;       // Maximum daily risk (5%)
    int               m_MaxTradesPerDay;    // Maximum trades per day
    bool              m_UseAdaptiveSizing;   // Adaptive position sizing
    
    double            m_DailyRiskUsed;      // Risk used today
    int               m_TradesToday;        // Trades executed today
    datetime          m_LastTradeDate;      // Last trade date
    
    // Account info
    double            m_AccountBalance;
    double            m_AccountEquity;
    
    // Win/loss streak
    int               m_WinStreak;
    int               m_LossStreak;
    
public:
    CRiskManager();
    ~CRiskManager();
    
    bool              Initialize(double baseRisk, 
                                 double maxDailyRisk,
                                 int maxTradesPerDay,
                                 bool useAdaptive);
    
    double            CalculatePositionSize(const DarvasBox &box,
                                            double entryPrice,
                                            double stopLoss);
    double            CalculateStopLoss(const DarvasBox &box,
                                        bool isLong,
                                        ENUM_TIMEFRAMES timeframe);
    bool              CanOpenNewTrade();
    bool              CheckDailyRiskLimit();
    void              UpdateTradeResult(bool isWin);
    void              ResetDailyLimits();
    
    // Adaptive sizing based on box characteristics
    double            GetAdaptiveRiskMultiplier(const DarvasBox &box);
    
private:
    double            GetAccountBalance();
    double            GetAccountEquity();
    double            GetLotSize(double riskAmount, double entryPrice, double stopLoss);
    double            NormalizeLotSize(double lots);
    void              UpdateDailyStats();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
    m_BaseRiskPercent = 1.5;
    m_MaxDailyRisk = 5.0;
    m_MaxTradesPerDay = 3;
    m_UseAdaptiveSizing = true;
    m_DailyRiskUsed = 0;
    m_TradesToday = 0;
    m_LastTradeDate = 0;
    m_WinStreak = 0;
    m_LossStreak = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(double baseRisk, 
                             double maxDailyRisk,
                             int maxTradesPerDay,
                             bool useAdaptive)
{
    m_BaseRiskPercent = baseRisk;
    m_MaxDailyRisk = maxDailyRisk;
    m_MaxTradesPerDay = maxTradesPerDay;
    m_UseAdaptiveSizing = useAdaptive;
    
    ResetDailyLimits();
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(const DarvasBox &box,
                                           double entryPrice,
                                           double stopLoss)
{
    UpdateDailyStats();
    
    if(!CanOpenNewTrade())
        return 0;
    
    double accountBalance = GetAccountBalance();
    double riskAmount = 0;
    
    // Calculate base risk amount
    double baseRiskAmount = accountBalance * (m_BaseRiskPercent / 100.0);
    
    // Apply adaptive multiplier if enabled
    if(m_UseAdaptiveSizing)
    {
        double multiplier = GetAdaptiveRiskMultiplier(box);
        riskAmount = baseRiskAmount * multiplier;
    }
    else
    {
        riskAmount = baseRiskAmount;
    }
    
    // Adjust for win/loss streak
    if(m_WinStreak >= 3)
        riskAmount *= 1.2; // Increase after wins
    else if(m_LossStreak >= 2)
        riskAmount *= 0.7; // Decrease after losses
    
    // Calculate stop distance
    double stopDistance = MathAbs(entryPrice - stopLoss);
    if(stopDistance <= 0) return 0;
    
    // Calculate lot size
    double lots = GetLotSize(riskAmount, entryPrice, stopLoss);
    
    // Normalize lot size
    lots = NormalizeLotSize(lots);
    
    // Update daily risk
    double actualRisk = (stopDistance / entryPrice) * 100.0 * lots * accountBalance / 100.0;
    m_DailyRiskUsed += actualRisk;
    
    return lots;
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateStopLoss(const DarvasBox &box,
                                       bool isLong,
                                       ENUM_TIMEFRAMES timeframe)
{
    // Get ATR for volatility measure
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
    
    if(atr == 0) atr = box.Height * 0.5; // Fallback
    
    // Initial stop: Bottom of breakout box - 1 ATR (for long)
    if(isLong)
    {
        double stopLoss = box.Bottom - atr;
        // Ensure stop is not more than 2× daily ATR from price
        double currentPrice = iClose(_Symbol, timeframe, 0);
        double maxStopDistance = atr * 2.0;
        if((currentPrice - stopLoss) > maxStopDistance)
            stopLoss = currentPrice - maxStopDistance;
        return stopLoss;
    }
    else
    {
        double stopLoss = box.Top + atr;
        // Ensure stop is not more than 2× daily ATR from price
        double currentPrice = iClose(_Symbol, timeframe, 0);
        double maxStopDistance = atr * 2.0;
        if((stopLoss - currentPrice) > maxStopDistance)
            stopLoss = currentPrice + maxStopDistance;
        return stopLoss;
    }
}

//+------------------------------------------------------------------+
//| Check if can open new trade                                      |
//+------------------------------------------------------------------+
bool CRiskManager::CanOpenNewTrade()
{
    UpdateDailyStats();
    
    // Check daily trade limit
    if(m_TradesToday >= m_MaxTradesPerDay)
        return false;
    
    // Check daily risk limit
    if(!CheckDailyRiskLimit())
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check daily risk limit                                           |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyRiskLimit()
{
    double accountBalance = GetAccountBalance();
    double maxRiskAmount = accountBalance * (m_MaxDailyRisk / 100.0);
    
    return (m_DailyRiskUsed < maxRiskAmount);
}

//+------------------------------------------------------------------+
//| Update trade result                                              |
//+------------------------------------------------------------------+
void CRiskManager::UpdateTradeResult(bool isWin)
{
    if(isWin)
    {
        m_WinStreak++;
        m_LossStreak = 0;
    }
    else
    {
        m_LossStreak++;
        m_WinStreak = 0;
    }
}

//+------------------------------------------------------------------+
//| Reset daily limits                                               |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyLimits()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDate = StringToTime(IntegerToString(dt.year) + "." + 
                                       IntegerToString(dt.mon) + "." + 
                                       IntegerToString(dt.day));
    
    if(m_LastTradeDate != currentDate)
    {
        m_DailyRiskUsed = 0;
        m_TradesToday = 0;
        m_LastTradeDate = currentDate;
    }
}

//+------------------------------------------------------------------+
//| Get adaptive risk multiplier                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetAdaptiveRiskMultiplier(const DarvasBox &box)
{
    if(!m_UseAdaptiveSizing) return 1.0;
    
    // Larger boxes = smaller position (more volatility)
    // Smaller boxes = larger position (less risk)
    double boxHeightATRRatio = box.Height / box.ATRValue;
    
    // Normalize ratio (typical range: 0.5 to 5.0)
    double multiplier = 1.0;
    
    if(boxHeightATRRatio > 3.0)
        multiplier = 0.7; // Large box, reduce risk
    else if(boxHeightATRRatio > 2.0)
        multiplier = 0.85;
    else if(boxHeightATRRatio > 1.0)
        multiplier = 1.0; // Normal
    else if(boxHeightATRRatio > 0.5)
        multiplier = 1.15; // Small box, can increase risk
    else
        multiplier = 1.3; // Very small box
    
    // Clamp between 0.5 and 2.0
    if(multiplier < 0.5) multiplier = 0.5;
    if(multiplier > 2.0) multiplier = 2.0;
    
    return multiplier;
}

//+------------------------------------------------------------------+
//| Get account balance                                              |
//+------------------------------------------------------------------+
double CRiskManager::GetAccountBalance()
{
    return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Get account equity                                               |
//+------------------------------------------------------------------+
double CRiskManager::GetAccountEquity()
{
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CRiskManager::GetLotSize(double riskAmount, double entryPrice, double stopLoss)
{
    double stopDistance = MathAbs(entryPrice - stopLoss);
    if(stopDistance <= 0) return 0;
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize <= 0) return 0;
    
    double riskInPoints = stopDistance / tickSize;
    double lotSize = riskAmount / (riskInPoints * tickValue);
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeLotSize(double lots)
{
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;
    
    lots = MathFloor(lots / lotStep) * lotStep;
    
    return lots;
}

//+------------------------------------------------------------------+
//| Update daily stats                                               |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDailyStats()
{
    ResetDailyLimits();
}

//+------------------------------------------------------------------+
