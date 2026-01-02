//+------------------------------------------------------------------+
//|                                    FibonacciExtensions.mqh       |
//|                    Fibonacci Extension Profit Targets            |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Fibonacci Extension Target                                      |
//+------------------------------------------------------------------+
struct FibExtensionTarget
{
    double            Level;              // Extension level (1.618, 2.618, etc.)
    double            Price;              // Target price
    double            ExitPercent;        // % of position to exit at this level
    bool              IsHit;              // Has this target been hit?
    datetime          HitTime;            // When target was hit
};

//+------------------------------------------------------------------+
//| Fibonacci Extension Manager                                      |
//+------------------------------------------------------------------+
class CFibonacciExtensions
{
private:
    double            m_FibLevels[];      // Fibonacci levels
    int               m_LevelCount;       // Number of levels
    
public:
    CFibonacciExtensions();
    ~CFibonacciExtensions();
    
    bool              Initialize(double level1 = 1.618, double level2 = 2.618,
                                 double level3 = 4.236, double level4 = 6.854);
    
    bool              CalculateTargets(const DarvasBox &box, 
                                      double entryPrice,
                                      bool isLong,
                                      FibExtensionTarget &targets[]);
    
    bool              CheckTargets(ulong ticket, FibExtensionTarget &targets[]);
    double            GetNextTarget(ulong ticket, const DarvasBox &box,
                                   double entryPrice, bool isLong);
    
private:
    double            CalculateExtensionPrice(double basePrice, double boxHeight,
                                             double fibLevel, bool isLong);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFibonacciExtensions::CFibonacciExtensions()
{
    m_LevelCount = 0;
    ArrayResize(m_FibLevels, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFibonacciExtensions::~CFibonacciExtensions()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CFibonacciExtensions::Initialize(double level1, double level2,
                                      double level3, double level4)
{
    ArrayResize(m_FibLevels, 4);
    m_FibLevels[0] = level1;
    m_FibLevels[1] = level2;
    m_FibLevels[2] = level3;
    m_FibLevels[3] = level4;
    m_LevelCount = 4;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate targets                                                |
//+------------------------------------------------------------------+
bool CFibonacciExtensions::CalculateTargets(const DarvasBox &box,
                                           double entryPrice,
                                           bool isLong,
                                           FibExtensionTarget &targets[])
{
    double boxHeight = box.Height;
    ArrayResize(targets, m_LevelCount);
    
    // Exit percentages: 20%, 30%, 25%, 15% (remaining 10% runs)
    double exitPercents[] = {0.20, 0.30, 0.25, 0.15};
    
    for(int i = 0; i < m_LevelCount; i++)
    {
        targets[i].Level = m_FibLevels[i];
        targets[i].Price = CalculateExtensionPrice(entryPrice, boxHeight, 
                                                   m_FibLevels[i], isLong);
        targets[i].ExitPercent = exitPercents[i];
        targets[i].IsHit = false;
        targets[i].HitTime = 0;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if targets are hit                                         |
//+------------------------------------------------------------------+
bool CFibonacciExtensions::CheckTargets(ulong ticket, FibExtensionTarget &targets[])
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double positionSize = PositionGetDouble(POSITION_VOLUME);
    
    for(int i = 0; i < ArraySize(targets); i++)
    {
        if(targets[i].IsHit) continue;
        
        bool targetHit = false;
        if(isLong && currentPrice >= targets[i].Price)
            targetHit = true;
        else if(!isLong && currentPrice <= targets[i].Price)
            targetHit = true;
        
        if(targetHit)
        {
            targets[i].IsHit = true;
            targets[i].HitTime = TimeCurrent();
            
            // Execute partial exit
            double exitSize = positionSize * targets[i].ExitPercent;
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = exitSize;
            request.type = isLong ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.deviation = 10;
            if(!OrderSend(request, result))
            {
                Print("Failed to set take profit: ", result.retcode);
            }
            
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get next target price                                            |
//+------------------------------------------------------------------+
double CFibonacciExtensions::GetNextTarget(ulong ticket, const DarvasBox &box,
                                          double entryPrice, bool isLong)
{
    FibExtensionTarget targets[];
    if(!CalculateTargets(box, entryPrice, isLong, targets))
        return 0;
    
    for(int i = 0; i < ArraySize(targets); i++)
    {
        if(!targets[i].IsHit)
            return targets[i].Price;
    }
    
    return 0; // All targets hit
}

//+------------------------------------------------------------------+
//| Calculate extension price                                        |
//+------------------------------------------------------------------+
double CFibonacciExtensions::CalculateExtensionPrice(double basePrice, double boxHeight,
                                                     double fibLevel, bool isLong)
{
    double extension = boxHeight * fibLevel;
    
    if(isLong)
        return basePrice + extension;
    else
        return basePrice - extension;
}

//+------------------------------------------------------------------+
