//+------------------------------------------------------------------+
//|                                  CounterTradeGenerator.mqh       |
//|                    Automatic Counter-Trade on Failed Breakouts   |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "VolumeAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Counter Trade Generator                                          |
//+------------------------------------------------------------------+
class CCounterTradeGenerator
{
private:
    bool              m_Enabled;          // Enable counter-trades
    double            m_SizeMultiplier;    // Size multiplier (1.5× losing trade)
    double            m_MinRejectionPercent; // Minimum rejection % (50% of box height)
    
    CVolumeAnalyzer  *m_VolumeAnalyzer;
    
    // Failed breakout tracking
    struct FailedBreakout
    {
        ulong         OriginalTicket;      // Original losing trade
        datetime      FailureTime;         // When breakout failed
        double        RejectionBarSize;    // Size of rejection bar
        DarvasBox     Box;                 // Associated box
        bool          IsLong;              // Original direction
    };
    
    FailedBreakout    m_FailedBreakouts[]; // Tracked failures
    int                m_FailureCount;      // Number of failures
    
public:
    CCounterTradeGenerator();
    ~CCounterTradeGenerator();
    
    bool              Initialize(bool enabled = true,
                                 double sizeMultiplier = 1.5,
                                 double minRejection = 0.5,
                                 CVolumeAnalyzer *volumeAnalyzer = NULL);
    
    bool              CheckFailedBreakout(ulong ticket, const DarvasBox &box,
                                         ENUM_TIMEFRAMES timeframe);
    bool              GenerateCounterTrade(const FailedBreakout &failure,
                                          TradeEntry &entry);
    void              CleanupOldFailures();
    
private:
    bool              IsBreakoutFailed(const DarvasBox &box,
                                      ENUM_TIMEFRAMES timeframe,
                                      bool originalDirection);
    double            CalculateRejectionBarSize(ENUM_TIMEFRAMES timeframe,
                                               bool isLong);
    bool              CheckVolumeSpike(ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCounterTradeGenerator::CCounterTradeGenerator()
{
    m_Enabled = true;
    m_SizeMultiplier = 1.5;
    m_MinRejectionPercent = 0.5;
    m_VolumeAnalyzer = NULL;
    m_FailureCount = 0;
    ArrayResize(m_FailedBreakouts, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCounterTradeGenerator::~CCounterTradeGenerator()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CCounterTradeGenerator::Initialize(bool enabled, double sizeMultiplier,
                                       double minRejection,
                                       CVolumeAnalyzer *volumeAnalyzer)
{
    m_Enabled = enabled;
    m_SizeMultiplier = sizeMultiplier;
    m_MinRejectionPercent = minRejection;
    m_VolumeAnalyzer = volumeAnalyzer;
    return true;
}

//+------------------------------------------------------------------+
//| Check for failed breakout                                        |
//+------------------------------------------------------------------+
bool CCounterTradeGenerator::CheckFailedBreakout(ulong ticket, const DarvasBox &box,
                                                 ENUM_TIMEFRAMES timeframe)
{
    if(!m_Enabled) return false;
    if(!PositionSelectByTicket(ticket)) return false;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // Check if breakout has failed
    if(!IsBreakoutFailed(box, timeframe, isLong))
        return false;
    
    // Check rejection bar size
    double rejectionSize = CalculateRejectionBarSize(timeframe, isLong);
    double boxHeight = box.Height;
    
    if(rejectionSize < boxHeight * m_MinRejectionPercent)
        return false;
    
    // Check volume spike on rejection
    if(!CheckVolumeSpike(timeframe))
        return false;
    
    // Record failed breakout
    FailedBreakout failure;
    failure.OriginalTicket = ticket;
    failure.FailureTime = TimeCurrent();
    failure.RejectionBarSize = rejectionSize;
    failure.Box = box;
    failure.IsLong = isLong;
    
    ArrayResize(m_FailedBreakouts, m_FailureCount + 1);
    m_FailedBreakouts[m_FailureCount] = failure;
    m_FailureCount++;
    
    return true;
}

//+------------------------------------------------------------------+
//| Generate counter trade                                           |
//+------------------------------------------------------------------+
bool CCounterTradeGenerator::GenerateCounterTrade(const FailedBreakout &failure,
                                                  TradeEntry &entry)
{
    if(!m_Enabled) return false;
    
    // Counter direction
    bool counterDirection = !failure.IsLong;
    
    // Entry price: At failed breakout confirmation
    double entryPrice = 0;
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    if(counterDirection) // Going long (original was short)
    {
        entryPrice = close; // Enter at current price
    }
    else // Going short (original was long)
    {
        entryPrice = close;
    }
    
    // Stop loss: Opposite box boundary or further
    double stopLoss = 0;
    if(counterDirection)
        stopLoss = failure.Box.Bottom - failure.Box.ATRValue;
    else
        stopLoss = failure.Box.Top + failure.Box.ATRValue;
    
    // Take profit: Opposite box boundary or previous swing
    double takeProfit = 0;
    if(counterDirection)
        takeProfit = failure.Box.Top + failure.Box.Height;
    else
        takeProfit = failure.Box.Bottom - failure.Box.Height;
    
    // Position size: 1.5× original losing trade
    double originalSize = 0;
    if(PositionSelectByTicket(failure.OriginalTicket))
        originalSize = PositionGetDouble(POSITION_VOLUME);
    
    double positionSize = originalSize * m_SizeMultiplier;
    
    // Fill entry structure
    entry.EntryPrice = entryPrice;
    entry.StopLoss = stopLoss;
    entry.TakeProfit = takeProfit;
    entry.PositionSize = positionSize;
    entry.BreakoutScore = 75; // Good score for counter-trade
    entry.EntryTime = TimeCurrent();
    entry.IsLong = counterDirection;
    entry.BoxId = failure.Box.CreationTime;
    entry.OrderType = ORDER_TYPE_BUY; // Will be set based on direction
    entry.Tier = 0; // Counter-trade tier
    
    return true;
}

//+------------------------------------------------------------------+
//| Cleanup old failures                                             |
//+------------------------------------------------------------------+
void CCounterTradeGenerator::CleanupOldFailures()
{
    datetime currentTime = TimeCurrent();
    int maxAge = 86400; // 24 hours
    
    for(int i = m_FailureCount - 1; i >= 0; i--)
    {
        if((currentTime - m_FailedBreakouts[i].FailureTime) > maxAge)
        {
            // Remove old failure
            for(int j = i; j < m_FailureCount - 1; j++)
                m_FailedBreakouts[j] = m_FailedBreakouts[j + 1];
            m_FailureCount--;
            ArrayResize(m_FailedBreakouts, m_FailureCount);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if breakout failed                                         |
//+------------------------------------------------------------------+
bool CCounterTradeGenerator::IsBreakoutFailed(const DarvasBox &box,
                                              ENUM_TIMEFRAMES timeframe,
                                              bool originalDirection)
{
    double close = iClose(_Symbol, timeframe, 0);
    
    // For long breakout: price should be above box top
    // Failure: price closes back inside or below box
    if(originalDirection) // Was long
    {
        if(close < box.Top)
            return true;
    }
    else // Was short
    {
        if(close > box.Bottom)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate rejection bar size                                     |
//+------------------------------------------------------------------+
double CCounterTradeGenerator::CalculateRejectionBarSize(ENUM_TIMEFRAMES timeframe,
                                                         bool isLong)
{
    double open = iOpen(_Symbol, timeframe, 0);
    double close = iClose(_Symbol, timeframe, 0);
    double high = iHigh(_Symbol, timeframe, 0);
    double low = iLow(_Symbol, timeframe, 0);
    
    if(isLong)
    {
        // For failed long: rejection is the lower wick
        double lowerWick = MathMin(open, close) - low;
        return lowerWick;
    }
    else
    {
        // For failed short: rejection is the upper wick
        double upperWick = high - MathMax(open, close);
        return upperWick;
    }
}

//+------------------------------------------------------------------+
//| Check volume spike                                               |
//+------------------------------------------------------------------+
bool CCounterTradeGenerator::CheckVolumeSpike(ENUM_TIMEFRAMES timeframe)
{
    if(m_VolumeAnalyzer == NULL) return true; // Skip check if no analyzer
    
    double volumeRatio = m_VolumeAnalyzer.GetVolumeRatio(timeframe, 5);
    return (volumeRatio >= 1.5); // 150% volume surge
}

//+------------------------------------------------------------------+
