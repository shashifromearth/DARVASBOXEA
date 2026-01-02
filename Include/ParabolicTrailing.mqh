//+------------------------------------------------------------------+
//|                                      ParabolicTrailing.mqh       |
//|                    Parabolic Acceleration Trailing System        |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Parabolic Trailing Stop Manager                                  |
//+------------------------------------------------------------------+
class CParabolicTrailing
{
private:
    double            m_InitialAF;         // Initial acceleration factor (0.02)
    double            m_MaxAF;             // Maximum acceleration factor (0.20)
    double            m_StepAF;            // Step increment (0.02)
    
    // Trade tracking
    struct TrailingData
    {
        ulong         Ticket;              // Trade ticket
        double        HighestPrice;        // Highest price (long) or lowest (short)
        double        LowestPrice;         // Lowest price (long) or highest (short)
        double        AccelerationFactor;  // Current AF
        datetime      LastUpdate;          // Last update time
        int           BarsSinceEntry;      // Bars since entry
        bool          IsLong;              // Trade direction
    };
    
    TrailingData      m_TrailingTrades[];  // Active trailing trades
    int               m_TradeCount;        // Number of tracked trades
    
public:
    CParabolicTrailing();
    ~CParabolicTrailing();
    
    bool              Initialize(double initialAF = 0.02, 
                                 double maxAF = 0.20,
                                 double stepAF = 0.02);
    
    void              AddTrade(ulong ticket, bool isLong);
    void              UpdateTrailingStops();
    void              RemoveTrade(ulong ticket);
    
    double            CalculateTrailingStop(ulong ticket, ENUM_TIMEFRAMES timeframe);
    
private:
    bool              FindTrade(ulong ticket, int &index);
    void              UpdateTradeData(int index, ENUM_TIMEFRAMES timeframe);
    double            GetATR(ENUM_TIMEFRAMES timeframe, int period = 14);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CParabolicTrailing::CParabolicTrailing()
{
    m_InitialAF = 0.02;
    m_MaxAF = 0.20;
    m_StepAF = 0.02;
    m_TradeCount = 0;
    ArrayResize(m_TrailingTrades, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CParabolicTrailing::~CParabolicTrailing()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CParabolicTrailing::Initialize(double initialAF, double maxAF, double stepAF)
{
    m_InitialAF = initialAF;
    m_MaxAF = maxAF;
    m_StepAF = stepAF;
    return true;
}

//+------------------------------------------------------------------+
//| Add trade for trailing                                           |
//+------------------------------------------------------------------+
void CParabolicTrailing::AddTrade(ulong ticket, bool isLong)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    TrailingData data;
    data.Ticket = ticket;
    data.IsLong = isLong;
    data.AccelerationFactor = m_InitialAF;
    data.LastUpdate = TimeCurrent();
    data.BarsSinceEntry = 0;
    
    if(isLong)
    {
        data.HighestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        data.LowestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    }
    else
    {
        data.HighestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        data.LowestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    }
    
    ArrayResize(m_TrailingTrades, m_TradeCount + 1);
    m_TrailingTrades[m_TradeCount] = data;
    m_TradeCount++;
}

//+------------------------------------------------------------------+
//| Update trailing stops                                            |
//+------------------------------------------------------------------+
void CParabolicTrailing::UpdateTrailingStops()
{
    for(int i = m_TradeCount - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(m_TrailingTrades[i].Ticket))
        {
            // Trade closed, remove
            RemoveTrade(m_TrailingTrades[i].Ticket);
            continue;
        }
        
        // Update trade data
        UpdateTradeData(i, PERIOD_CURRENT);
        
        // Calculate new trailing stop
        double newStop = CalculateTrailingStop(m_TrailingTrades[i].Ticket, PERIOD_CURRENT);
        double currentStop = PositionGetDouble(POSITION_SL);
        
        // Update stop if beneficial
        if(m_TrailingTrades[i].IsLong)
        {
            if(newStop > currentStop || currentStop == 0)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                request.action = TRADE_ACTION_SLTP;
                request.position = m_TrailingTrades[i].Ticket;
                request.symbol = _Symbol;
                request.sl = newStop;
                request.tp = PositionGetDouble(POSITION_TP);
                if(!OrderSend(request, result))
                {
                    Print("Failed to update trailing stop: ", result.retcode);
                }
            }
        }
        else
        {
            if(newStop < currentStop || currentStop == 0)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                request.action = TRADE_ACTION_SLTP;
                request.position = m_TrailingTrades[i].Ticket;
                request.symbol = _Symbol;
                request.sl = newStop;
                request.tp = PositionGetDouble(POSITION_TP);
                if(!OrderSend(request, result))
                {
                    Print("Failed to update trailing stop: ", result.retcode);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Remove trade                                                     |
//+------------------------------------------------------------------+
void CParabolicTrailing::RemoveTrade(ulong ticket)
{
    int index;
    if(!FindTrade(ticket, index))
        return;
    
    // Shift array
    for(int i = index; i < m_TradeCount - 1; i++)
        m_TrailingTrades[i] = m_TrailingTrades[i + 1];
    
    m_TradeCount--;
    ArrayResize(m_TrailingTrades, m_TradeCount);
}

//+------------------------------------------------------------------+
//| Calculate trailing stop                                           |
//+------------------------------------------------------------------+
double CParabolicTrailing::CalculateTrailingStop(ulong ticket, ENUM_TIMEFRAMES timeframe)
{
    int index;
    if(!FindTrade(ticket, index))
        return 0;
    
    TrailingData data = m_TrailingTrades[index];
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double atr = GetATR(timeframe);
    
    if(data.IsLong)
    {
        // Update highest price
        if(currentPrice > data.HighestPrice)
        {
            m_TrailingTrades[index].HighestPrice = currentPrice;
            // Increase acceleration factor
            if(m_TrailingTrades[index].AccelerationFactor < m_MaxAF)
                m_TrailingTrades[index].AccelerationFactor += m_StepAF;
        }
        
        // Parabolic stop: HighestPrice - (AF × (HighestPrice - LowestPrice))
        double range = m_TrailingTrades[index].HighestPrice - m_TrailingTrades[index].LowestPrice;
        double stop = m_TrailingTrades[index].HighestPrice - 
                     (m_TrailingTrades[index].AccelerationFactor * range);
        
        // Minimum stop distance (1 ATR)
        double minStop = currentPrice - atr;
        if(stop < minStop)
            stop = minStop;
        
        return stop;
    }
    else
    {
        // Update lowest price
        if(currentPrice < data.LowestPrice)
        {
            m_TrailingTrades[index].LowestPrice = currentPrice;
            // Increase acceleration factor
            if(m_TrailingTrades[index].AccelerationFactor < m_MaxAF)
                m_TrailingTrades[index].AccelerationFactor += m_StepAF;
        }
        
        // Parabolic stop: LowestPrice + (AF × (HighestPrice - LowestPrice))
        double range = m_TrailingTrades[index].HighestPrice - m_TrailingTrades[index].LowestPrice;
        double stop = m_TrailingTrades[index].LowestPrice + 
                     (m_TrailingTrades[index].AccelerationFactor * range);
        
        // Minimum stop distance (1 ATR)
        double maxStop = currentPrice + atr;
        if(stop > maxStop)
            stop = maxStop;
        
        return stop;
    }
}

//+------------------------------------------------------------------+
//| Find trade index                                                 |
//+------------------------------------------------------------------+
bool CParabolicTrailing::FindTrade(ulong ticket, int &index)
{
    for(int i = 0; i < m_TradeCount; i++)
    {
        if(m_TrailingTrades[i].Ticket == ticket)
        {
            index = i;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Update trade data                                                |
//+------------------------------------------------------------------+
void CParabolicTrailing::UpdateTradeData(int index, ENUM_TIMEFRAMES timeframe)
{
    if(!PositionSelectByTicket(m_TrailingTrades[index].Ticket))
        return;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    
    if(m_TrailingTrades[index].IsLong)
    {
        if(currentPrice > m_TrailingTrades[index].HighestPrice)
            m_TrailingTrades[index].HighestPrice = currentPrice;
        if(currentPrice < m_TrailingTrades[index].LowestPrice)
            m_TrailingTrades[index].LowestPrice = currentPrice;
    }
    else
    {
        if(currentPrice < m_TrailingTrades[index].LowestPrice)
            m_TrailingTrades[index].LowestPrice = currentPrice;
        if(currentPrice > m_TrailingTrades[index].HighestPrice)
            m_TrailingTrades[index].HighestPrice = currentPrice;
    }
    
    // Update bars since entry
    datetime entryTime = (datetime)PositionGetInteger(POSITION_TIME);
    int barsSinceEntry = (int)((TimeCurrent() - entryTime) / PeriodSeconds(timeframe));
    m_TrailingTrades[index].BarsSinceEntry = barsSinceEntry;
    
    // Time-based acceleration (more aggressive after 5 bars)
    if(barsSinceEntry >= 5 && m_TrailingTrades[index].AccelerationFactor < m_MaxAF)
    {
        m_TrailingTrades[index].AccelerationFactor += m_StepAF * 0.5;
    }
}

//+------------------------------------------------------------------+
//| Get ATR                                                          |
//+------------------------------------------------------------------+
double CParabolicTrailing::GetATR(ENUM_TIMEFRAMES timeframe, int period)
{
    int atrHandle = iATR(_Symbol, timeframe, period);
    if(atrHandle == INVALID_HANDLE) return 0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
    {
        IndicatorRelease(atrHandle);
        return 0;
    }
    
    IndicatorRelease(atrHandle);
    return atr[0];
}

//+------------------------------------------------------------------+
