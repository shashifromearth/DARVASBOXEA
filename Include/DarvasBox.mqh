//+------------------------------------------------------------------+
//|                                                DarvasBox.mqh     |
//|                        Darvas Box Core Structure and Definitions |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Darvas Box Structure                                            |
//+------------------------------------------------------------------+
struct DarvasBox
{
    double            Top;                // Box Resistance
    double            Bottom;             // Box Support
    double            VolumeBox;        // Volume-weighted confirmation
    datetime          CreationTime;      // When box was created
    int               ConsolidationBars; // Bars in consolidation
    bool              Validated;         // Box validation status
    double            BreakoutForce;     // Calculated breakout strength
    double            Height;            // Box height (Top - Bottom)
    int               Timeframe;         // Timeframe of the box
    bool              IsBullish;         // Direction of expected breakout
    double            ATRValue;          // ATR at box creation
    int               VolumeInsideBox;    // Average volume inside box
    int               VolumeBreakout;     // Volume on breakout
    bool              IsNested;          // Is this a nested box?
    ulong             ParentBoxId;       // Parent box ID if nested
};

//+------------------------------------------------------------------+
//| Trade Entry Structure                                           |
//+------------------------------------------------------------------+
struct TradeEntry
{
    int               Tier;              // Entry tier (1, 2, or 3)
    double            EntryPrice;        // Entry price
    double            StopLoss;          // Stop loss price
    double            TakeProfit;        // Take profit price
    double            PositionSize;     // Position size in lots
    int               BreakoutScore;     // Quality score (0-100)
    datetime          EntryTime;         // Entry timestamp
    bool              IsLong;            // Trade direction
    ulong             BoxId;             // Associated box ID
    ENUM_ORDER_TYPE   OrderType;         // Market, Limit, or Stop
};

//+------------------------------------------------------------------+
//| Trade Exit Structure                                            |
//+------------------------------------------------------------------+
struct TradeExit
{
    int               ExitTier;          // Exit tier (1, 2, or 3)
    double            ExitPrice;         // Exit price
    double            ExitSize;          // Position size to exit
    datetime          ExitTime;          // Exit timestamp
    string            ExitReason;        // Reason for exit
    bool              IsPartial;         // Partial or full exit
};

//+------------------------------------------------------------------+
//| Box Statistics                                                   |
//+------------------------------------------------------------------+
struct BoxStatistics
{
    int               TotalBoxes;        // Total boxes detected
    int               SuccessfulBoxes;   // Successful breakouts
    int               FailedBoxes;       // Failed breakouts
    double            AvgBreakoutScore; // Average breakout score
    double            AvgProfitMultiplier; // Average profit achieved
    int               FalseBreakouts;   // False breakout count
};

//+------------------------------------------------------------------+
//| Market Condition Structure                                       |
//+------------------------------------------------------------------+
struct MarketCondition
{
    bool              IsTrending;        // Market is trending
    bool              IsRanging;         // Market is ranging
    double            Volatility;        // Current volatility (ATR)
    double            TrendStrength;    // ADX value
    ENUM_TIMEFRAMES   TrendTimeframe;   // Trend timeframe
    bool              IsBullishTrend;   // Trend direction
};

//+------------------------------------------------------------------+
//| Session Information                                              |
//+------------------------------------------------------------------+
struct SessionInfo
{
    string            SessionName;       // Session name
    datetime          StartTime;         // Session start
    datetime          EndTime;           // Session end
    double            Weight;            // Trading weight
    bool              IsActive;          // Is session active
};

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Box Height                                             |
//+------------------------------------------------------------------+
double CalculateBoxHeight(const DarvasBox &box)
{
    return MathAbs(box.Top - box.Bottom);
}

//+------------------------------------------------------------------+
//| Check if price is inside box                                     |
//+------------------------------------------------------------------+
bool IsPriceInBox(double price, const DarvasBox &box)
{
    return (price >= box.Bottom && price <= box.Top);
}

//+------------------------------------------------------------------+
//| Check if box is valid                                            |
//+------------------------------------------------------------------+
bool IsBoxValid(const DarvasBox &box)
{
    return (box.Validated && 
            box.ConsolidationBars >= 5 && 
            box.Height > 0 && 
            box.Top > box.Bottom);
}

//+------------------------------------------------------------------+
//| Calculate breakout force                                         |
//+------------------------------------------------------------------+
double CalculateBreakoutForce(const DarvasBox &box, double currentVolume, double avgVolume)
{
    if(avgVolume == 0) return 0;
    
    double volumeRatio = currentVolume / avgVolume;
    double heightRatio = box.Height / box.ATRValue;
    
    return (volumeRatio * 0.6 + heightRatio * 0.4);
}

//+------------------------------------------------------------------+
