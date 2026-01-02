//+------------------------------------------------------------------+
//|                                        CircuitBreakers.mqh        |
//|                    Safety Protocols and Circuit Breakers          |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Circuit Breaker Manager                                          |
//+------------------------------------------------------------------+
class CCircuitBreakers
{
private:
    // Drawdown limits
    double            m_MaxDrawdownPercent;    // Maximum drawdown (15%)
    double            m_WarningDrawdown;        // Warning level (5%)
    double            m_StopDrawdown;          // Stop trading (10%)
    
    // Loss limits
    int               m_MaxConsecutiveLosses;  // Max consecutive losses (3)
    int               m_ConsecutiveLosses;     // Current consecutive losses
    
    // Time-based restrictions
    bool              m_NoTradesLast30Min;     // No trades last 30 min
    bool              m_FridayReduction;       // Reduce size Friday after 18:00 UTC
    int               m_FridayReductionPercent; // Reduction % (50%)
    
    // Volatility limits
    double            m_MaxDailyRangeMultiplier; // Max daily range (3× average)
    
    // News restrictions
    bool              m_FlatBeforeNews;        // Flat 5 min before news
    int               m_NewsBufferMinutes;     // Buffer minutes (5)
    
    // Current state
    double            m_InitialEquity;         // Starting equity
    double            m_HighestEquity;         // Highest equity
    double            m_CurrentDrawdown;       // Current drawdown %
    bool              m_TradingEnabled;        // Is trading enabled
    bool              m_EmergencyStop;         // Emergency stop activated
    
    // Daily tracking
    datetime          m_LastTradeDate;         // Last trade date
    int               m_TradesToday;           // Trades today
    int               m_MaxTradesPerDay;       // Max trades per day
    
public:
    CCircuitBreakers();
    ~CCircuitBreakers();
    
    bool              Initialize(double maxDrawdown = 15.0,
                                 int maxConsecutiveLosses = 3,
                                 bool noTradesLast30Min = true,
                                 bool fridayReduction = true,
                                 double maxDailyRange = 3.0,
                                 bool flatBeforeNews = true,
                                 int newsBuffer = 5,
                                 int maxTradesPerDay = 5);
    
    bool              CanTrade();
    bool              CheckDrawdown();
    void              UpdateTradeResult(bool isWin, double profit);
    void              ResetDaily();
    void              ActivateEmergencyStop();
    void              DeactivateEmergencyStop();
    
    double            GetPositionSizeMultiplier();
    bool              IsEmergencyStop() { return m_EmergencyStop; }
    double            GetCurrentDrawdown() { return m_CurrentDrawdown; }
    
private:
    void              UpdateDrawdown();
    bool              CheckTimeRestrictions();
    bool              CheckVolatilityLimits();
    bool              CheckNewsRestrictions();
    bool              IsLast30Minutes();
    bool              IsFridayAfter1800();
    double            GetDailyRangeRatio();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCircuitBreakers::CCircuitBreakers()
{
    m_MaxDrawdownPercent = 15.0;
    m_WarningDrawdown = 5.0;
    m_StopDrawdown = 10.0;
    m_MaxConsecutiveLosses = 3;
    m_ConsecutiveLosses = 0;
    m_NoTradesLast30Min = true;
    m_FridayReduction = true;
    m_FridayReductionPercent = 50;
    m_MaxDailyRangeMultiplier = 3.0;
    m_FlatBeforeNews = true;
    m_NewsBufferMinutes = 5;
    m_TradingEnabled = true;
    m_EmergencyStop = false;
    m_TradesToday = 0;
    m_MaxTradesPerDay = 5;
    m_LastTradeDate = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCircuitBreakers::~CCircuitBreakers()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CCircuitBreakers::Initialize(double maxDrawdown, int maxConsecutiveLosses,
                                 bool noTradesLast30Min, bool fridayReduction,
                                 double maxDailyRange, bool flatBeforeNews,
                                 int newsBuffer, int maxTradesPerDay)
{
    m_MaxDrawdownPercent = maxDrawdown;
    m_MaxConsecutiveLosses = maxConsecutiveLosses;
    m_NoTradesLast30Min = noTradesLast30Min;
    m_FridayReduction = fridayReduction;
    m_MaxDailyRangeMultiplier = maxDailyRange;
    m_FlatBeforeNews = flatBeforeNews;
    m_NewsBufferMinutes = newsBuffer;
    m_MaxTradesPerDay = maxTradesPerDay;
    
    m_InitialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    m_HighestEquity = m_InitialEquity;
    m_CurrentDrawdown = 0;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if can trade                                               |
//+------------------------------------------------------------------+
bool CCircuitBreakers::CanTrade()
{
    // Emergency stop
    if(m_EmergencyStop)
    {
        Print("Circuit Breaker: Emergency stop activated");
        return false;
    }
    
    // Check drawdown
    UpdateDrawdown();
    if(m_CurrentDrawdown >= m_StopDrawdown)
    {
        Print("Circuit Breaker: Drawdown limit reached: ", m_CurrentDrawdown, "%");
        ActivateEmergencyStop();
        return false;
    }
    
    // Check consecutive losses
    if(m_ConsecutiveLosses >= m_MaxConsecutiveLosses)
    {
        Print("Circuit Breaker: Max consecutive losses reached: ", m_ConsecutiveLosses);
        return false;
    }
    
    // Check time restrictions
    if(!CheckTimeRestrictions())
        return false;
    
    // Check volatility limits
    if(!CheckVolatilityLimits())
        return false;
    
    // Check news restrictions
    if(!CheckNewsRestrictions())
        return false;
    
    // Check daily trade limit
    ResetDaily();
    if(m_TradesToday >= m_MaxTradesPerDay)
    {
        Print("Circuit Breaker: Max trades per day reached: ", m_TradesToday);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check drawdown                                                   |
//+------------------------------------------------------------------+
bool CCircuitBreakers::CheckDrawdown()
{
    UpdateDrawdown();
    return (m_CurrentDrawdown < m_StopDrawdown);
}

//+------------------------------------------------------------------+
//| Update trade result                                              |
//+------------------------------------------------------------------+
void CCircuitBreakers::UpdateTradeResult(bool isWin, double profit)
{
    if(isWin)
    {
        m_ConsecutiveLosses = 0;
    }
    else
    {
        m_ConsecutiveLosses++;
    }
    
    // Update equity tracking
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(currentEquity > m_HighestEquity)
        m_HighestEquity = currentEquity;
    
    UpdateDrawdown();
    
    // Increment daily trade count
    m_TradesToday++;
}

//+------------------------------------------------------------------+
//| Reset daily limits                                               |
//+------------------------------------------------------------------+
void CCircuitBreakers::ResetDaily()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDate = StringToTime(IntegerToString(dt.year) + "." + 
                                       IntegerToString(dt.mon) + "." + 
                                       IntegerToString(dt.day));
    
    if(m_LastTradeDate != currentDate)
    {
        m_TradesToday = 0;
        m_LastTradeDate = currentDate;
    }
}

//+------------------------------------------------------------------+
//| Activate emergency stop                                          |
//+------------------------------------------------------------------+
void CCircuitBreakers::ActivateEmergencyStop()
{
    m_EmergencyStop = true;
    m_TradingEnabled = false;
    Print("*** EMERGENCY STOP ACTIVATED ***");
    Print("Current Drawdown: ", m_CurrentDrawdown, "%");
    Print("Manual review required before resuming trading.");
}

//+------------------------------------------------------------------+
//| Deactivate emergency stop                                        |
//+------------------------------------------------------------------+
void CCircuitBreakers::DeactivateEmergencyStop()
{
    m_EmergencyStop = false;
    m_TradingEnabled = true;
    m_ConsecutiveLosses = 0;
    m_HighestEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    Print("Emergency stop deactivated. Trading resumed.");
}

//+------------------------------------------------------------------+
//| Get position size multiplier                                     |
//+------------------------------------------------------------------+
double CCircuitBreakers::GetPositionSizeMultiplier()
{
    double multiplier = 1.0;
    
    // Reduce after consecutive losses
    if(m_ConsecutiveLosses >= 2)
        multiplier *= 0.5; // 50% reduction
    
    // Reduce on Friday after 18:00
    if(m_FridayReduction && IsFridayAfter1800())
        multiplier *= (1.0 - m_FridayReductionPercent / 100.0);
    
    // Reduce if drawdown warning
    if(m_CurrentDrawdown >= m_WarningDrawdown)
        multiplier *= 0.7; // 30% reduction
    
    return multiplier;
}

//+------------------------------------------------------------------+
//| Update drawdown                                                  |
//+------------------------------------------------------------------+
void CCircuitBreakers::UpdateDrawdown()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    if(currentEquity > m_HighestEquity)
        m_HighestEquity = currentEquity;
    
    if(m_HighestEquity > 0)
        m_CurrentDrawdown = ((m_HighestEquity - currentEquity) / m_HighestEquity) * 100.0;
    else
        m_CurrentDrawdown = 0;
}

//+------------------------------------------------------------------+
//| Check time restrictions                                          |
//+------------------------------------------------------------------+
bool CCircuitBreakers::CheckTimeRestrictions()
{
    if(m_NoTradesLast30Min && IsLast30Minutes())
    {
        Print("Circuit Breaker: Last 30 minutes - no new trades");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check volatility limits                                          |
//+------------------------------------------------------------------+
bool CCircuitBreakers::CheckVolatilityLimits()
{
    double rangeRatio = GetDailyRangeRatio();
    if(rangeRatio > m_MaxDailyRangeMultiplier)
    {
        Print("Circuit Breaker: Daily range too high: ", rangeRatio, "× average");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check news restrictions                                          |
//+------------------------------------------------------------------+
bool CCircuitBreakers::CheckNewsRestrictions()
{
    // This would integrate with news calendar
    // For now, return true (no news restriction)
    return true;
}

//+------------------------------------------------------------------+
//| Check if last 30 minutes                                          |
//+------------------------------------------------------------------+
bool CCircuitBreakers::IsLast30Minutes()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Check if within last 30 minutes of trading day
    // This is simplified - would need to check actual market hours
    int hour = dt.hour;
    int minute = dt.min;
    
    // Assume trading day ends at 22:00 (simplified)
    if(hour >= 21 && minute >= 30)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if Friday after 18:00                                      |
//+------------------------------------------------------------------+
bool CCircuitBreakers::IsFridayAfter1800()
{
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    
    if(dt.day_of_week == 5 && dt.hour >= 18) // Friday, 18:00+
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Get daily range ratio                                            |
//+------------------------------------------------------------------+
double CCircuitBreakers::GetDailyRangeRatio()
{
    // Calculate today's range
    double todayHigh = iHigh(_Symbol, PERIOD_D1, 0);
    double todayLow = iLow(_Symbol, PERIOD_D1, 0);
    double todayRange = todayHigh - todayLow;
    
    // Calculate average range (last 20 days)
    double sumRange = 0;
    for(int i = 1; i <= 20; i++)
    {
        double high = iHigh(_Symbol, PERIOD_D1, i);
        double low = iLow(_Symbol, PERIOD_D1, i);
        sumRange += (high - low);
    }
    double avgRange = sumRange / 20.0;
    
    if(avgRange > 0)
        return todayRange / avgRange;
    
    return 1.0;
}

//+------------------------------------------------------------------+
