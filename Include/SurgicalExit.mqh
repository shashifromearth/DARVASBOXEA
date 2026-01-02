//+------------------------------------------------------------------+
//|                                          SurgicalExit.mqh         |
//|                    5-Tier Surgical Exit System                   |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"
#include "ParabolicTrailing.mqh"

//+------------------------------------------------------------------+
//| Exit Tier Structure                                              |
//+------------------------------------------------------------------+
struct ExitTier
{
    int               Tier;               // Tier number (1-5)
    double            TargetMultiplier;    // Box height multiplier
    double            ExitPercent;         // % of position to exit
    bool              IsHit;              // Has target been hit?
    datetime          HitTime;             // When target was hit
    double            TargetPrice;         // Target price
    string            ExitReason;          // Reason for exit
};

//+------------------------------------------------------------------+
//| Surgical Exit Manager                                            |
//+------------------------------------------------------------------+
class CSurgicalExit
{
private:
    double            m_Tier1Multiplier;   // 0.75× box height
    double            m_Tier2Multiplier;   // 1.5× box height
    double            m_Tier3TrailStart;   // 1.0× ATR trail start
    int               m_MaxHoldDays;       // Maximum hold (7 days)
    bool              m_UseParabolicTrail; // Use parabolic trailing
    
    CParabolicTrailing *m_ParabolicTrailing;
    
    // Exit tracking
    struct ExitTracking
    {
        ulong         Ticket;              // Trade ticket
        DarvasBox     Box;                 // Associated box
        double        EntryPrice;          // Entry price
        bool          IsLong;              // Trade direction
        ExitTier      Tiers[];             // Exit tiers
        datetime      EntryTime;           // Entry time
        double        MaxProfit;           // Maximum profit achieved
        double        CurrentTrail;        // Current trailing stop
    };
    
    ExitTracking      m_ExitTracking[];
    int               m_TrackingCount;
    
public:
    CSurgicalExit();
    ~CSurgicalExit();
    
    bool              Initialize(double tier1Multiplier = 0.75,
                                double tier2Multiplier = 1.5,
                                double tier3TrailStart = 1.0,
                                int maxHoldDays = 7,
                                bool useParabolicTrail = true,
                                CParabolicTrailing *parabolicTrailing = NULL);
    
    bool              SetupExitTiers(ulong ticket,
                                    const DarvasBox &box,
                                    double entryPrice,
                                    bool isLong);
    
    void              UpdateExits();
    bool              CheckTierExits(ulong ticket);
    void              ApplyTimeDecay(ulong ticket);
    
private:
    bool              FindTracking(ulong ticket, int &index);
    bool              CheckTier1(ExitTracking &tracking);
    bool              CheckTier2(ExitTracking &tracking);
    bool              CheckTier3(ExitTracking &tracking);
    bool              CheckTier4(ExitTracking &tracking);
    bool              CheckTier5(ExitTracking &tracking);
    void              ExecuteExit(ulong ticket, int tier, double exitPercent);
    double            CalculateTierPrice(int tier, const DarvasBox &box,
                                       double entryPrice, bool isLong);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSurgicalExit::CSurgicalExit()
{
    m_Tier1Multiplier = 0.75;
    m_Tier2Multiplier = 1.5;
    m_Tier3TrailStart = 1.0;
    m_MaxHoldDays = 7;
    m_UseParabolicTrail = true;
    m_ParabolicTrailing = NULL;
    m_TrackingCount = 0;
    ArrayResize(m_ExitTracking, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSurgicalExit::~CSurgicalExit()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CSurgicalExit::Initialize(double tier1Multiplier,
                              double tier2Multiplier,
                              double tier3TrailStart,
                              int maxHoldDays,
                              bool useParabolicTrail,
                              CParabolicTrailing *parabolicTrailing)
{
    m_Tier1Multiplier = tier1Multiplier;
    m_Tier2Multiplier = tier2Multiplier;
    m_Tier3TrailStart = tier3TrailStart;
    m_MaxHoldDays = maxHoldDays;
    m_UseParabolicTrail = useParabolicTrail;
    m_ParabolicTrailing = parabolicTrailing;
    return true;
}

//+------------------------------------------------------------------+
//| Setup exit tiers                                                 |
//+------------------------------------------------------------------+
bool CSurgicalExit::SetupExitTiers(ulong ticket,
                                  const DarvasBox &box,
                                  double entryPrice,
                                  bool isLong)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    ExitTracking tracking;
    tracking.Ticket = ticket;
    tracking.Box = box;
    tracking.EntryPrice = entryPrice;
    tracking.IsLong = isLong;
    tracking.EntryTime = TimeCurrent();
    tracking.MaxProfit = 0;
    tracking.CurrentTrail = 0;
    
    // Setup 5 tiers
    ArrayResize(tracking.Tiers, 5);
    
    // Tier 1: Quick profit lock (10%)
    tracking.Tiers[0].Tier = 1;
    tracking.Tiers[0].TargetMultiplier = m_Tier1Multiplier;
    tracking.Tiers[0].ExitPercent = 0.10;
    tracking.Tiers[0].IsHit = false;
    tracking.Tiers[0].TargetPrice = CalculateTierPrice(1, box, entryPrice, isLong);
    tracking.Tiers[0].ExitReason = "Quick profit lock";
    
    // Tier 2: Technical target (30%)
    tracking.Tiers[1].Tier = 2;
    tracking.Tiers[1].TargetMultiplier = m_Tier2Multiplier;
    tracking.Tiers[1].ExitPercent = 0.30;
    tracking.Tiers[1].IsHit = false;
    tracking.Tiers[1].TargetPrice = CalculateTierPrice(2, box, entryPrice, isLong);
    tracking.Tiers[1].ExitReason = "Technical target";
    
    // Tier 3: Parabolic trail (30%)
    tracking.Tiers[2].Tier = 3;
    tracking.Tiers[2].TargetMultiplier = 0; // Trail-based
    tracking.Tiers[2].ExitPercent = 0.30;
    tracking.Tiers[2].IsHit = false;
    tracking.Tiers[2].ExitReason = "Parabolic trail";
    
    // Tier 4: Trend termination (20%)
    tracking.Tiers[3].Tier = 4;
    tracking.Tiers[3].TargetMultiplier = 0; // Condition-based
    tracking.Tiers[3].ExitPercent = 0.20;
    tracking.Tiers[3].IsHit = false;
    tracking.Tiers[3].ExitReason = "Trend termination";
    
    // Tier 5: Emergency exit (10%)
    tracking.Tiers[4].Tier = 5;
    tracking.Tiers[4].TargetMultiplier = 0; // Trail-based
    tracking.Tiers[4].ExitPercent = 0.10;
    tracking.Tiers[4].IsHit = false;
    tracking.Tiers[4].ExitReason = "Emergency exit";
    
    // Add to tracking
    ArrayResize(m_ExitTracking, m_TrackingCount + 1);
    m_ExitTracking[m_TrackingCount] = tracking;
    m_TrackingCount++;
    
    return true;
}

//+------------------------------------------------------------------+
//| Update exits                                                     |
//+------------------------------------------------------------------+
void CSurgicalExit::UpdateExits()
{
    for(int i = m_TrackingCount - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(m_ExitTracking[i].Ticket))
        {
            // Trade closed, remove tracking
            for(int j = i; j < m_TrackingCount - 1; j++)
                m_ExitTracking[j] = m_ExitTracking[j + 1];
            m_TrackingCount--;
            ArrayResize(m_ExitTracking, m_TrackingCount);
            continue;
        }
        
        // Check all tiers
        CheckTierExits(m_ExitTracking[i].Ticket);
        
        // Apply time decay
        ApplyTimeDecay(m_ExitTracking[i].Ticket);
        
        // Update max profit
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double entryPrice = m_ExitTracking[i].EntryPrice;
        double profit = m_ExitTracking[i].IsLong ? 
                       (currentPrice - entryPrice) : 
                       (entryPrice - currentPrice);
        
        if(profit > m_ExitTracking[i].MaxProfit)
            m_ExitTracking[i].MaxProfit = profit;
    }
}

//+------------------------------------------------------------------+
//| Check tier exits                                                 |
//+------------------------------------------------------------------+
bool CSurgicalExit::CheckTierExits(ulong ticket)
{
    int index;
    if(!FindTracking(ticket, index))
        return false;
    
    // Check each tier in order
    if(!m_ExitTracking[index].Tiers[0].IsHit && CheckTier1(m_ExitTracking[index]))
        ExecuteExit(ticket, 1, m_ExitTracking[index].Tiers[0].ExitPercent);
    
    if(!m_ExitTracking[index].Tiers[1].IsHit && CheckTier2(m_ExitTracking[index]))
        ExecuteExit(ticket, 2, m_ExitTracking[index].Tiers[1].ExitPercent);
    
    if(!m_ExitTracking[index].Tiers[2].IsHit && CheckTier3(m_ExitTracking[index]))
        ExecuteExit(ticket, 3, m_ExitTracking[index].Tiers[2].ExitPercent);
    
    if(!m_ExitTracking[index].Tiers[3].IsHit && CheckTier4(m_ExitTracking[index]))
        ExecuteExit(ticket, 4, m_ExitTracking[index].Tiers[3].ExitPercent);
    
    if(!m_ExitTracking[index].Tiers[4].IsHit && CheckTier5(m_ExitTracking[index]))
        ExecuteExit(ticket, 5, m_ExitTracking[index].Tiers[4].ExitPercent);
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Tier 1 (Quick profit lock)                               |
//+------------------------------------------------------------------+
bool CSurgicalExit::CheckTier1(ExitTracking &tracking)
{
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double targetPrice = tracking.Tiers[0].TargetPrice;
    
    bool targetHit = false;
    if(tracking.IsLong)
        targetHit = (currentPrice >= targetPrice);
    else
        targetHit = (currentPrice <= targetPrice);
    
    if(targetHit)
    {
        // Check if reached within 30 minutes
        datetime timeSinceEntry = TimeCurrent() - tracking.EntryTime;
        if(timeSinceEntry <= 1800) // 30 minutes
        {
            tracking.Tiers[0].IsHit = true;
            tracking.Tiers[0].HitTime = TimeCurrent();
            return true;
        }
        
        // Or check for sudden volume spike
        // This would require volume analyzer integration
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Tier 2 (Technical target)                                 |
//+------------------------------------------------------------------+
bool CSurgicalExit::CheckTier2(ExitTracking &tracking)
{
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double targetPrice = tracking.Tiers[1].TargetPrice;
    
    bool targetHit = false;
    if(tracking.IsLong)
        targetHit = (currentPrice >= targetPrice);
    else
        targetHit = (currentPrice <= targetPrice);
    
    if(targetHit)
    {
        tracking.Tiers[1].IsHit = true;
        tracking.Tiers[1].HitTime = TimeCurrent();
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Tier 3 (Parabolic trail)                                  |
//+------------------------------------------------------------------+
bool CSurgicalExit::CheckTier3(ExitTracking &tracking)
{
    if(m_ParabolicTrailing == NULL) return false;
    
    double trailingStop = m_ParabolicTrailing.CalculateTrailingStop(
        tracking.Ticket, PERIOD_CURRENT);
    
    if(trailingStop == 0) return false;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    
    bool exitTriggered = false;
    if(tracking.IsLong)
        exitTriggered = (currentPrice < trailingStop);
    else
        exitTriggered = (currentPrice > trailingStop);
    
    if(exitTriggered)
    {
        tracking.Tiers[2].IsHit = true;
        tracking.Tiers[2].HitTime = TimeCurrent();
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Tier 4 (Trend termination)                                |
//+------------------------------------------------------------------+
bool CSurgicalExit::CheckTier4(ExitTracking &tracking)
{
    // Check for higher timeframe rejection
    double close4H = iClose(_Symbol, PERIOD_H4, 0);
    double open4H = iOpen(_Symbol, PERIOD_H4, 0);
    double prevClose4H = iClose(_Symbol, PERIOD_H4, 1);
    double prevOpen4H = iOpen(_Symbol, PERIOD_H4, 1);
    
    // Bearish engulfing on 4H
    if(tracking.IsLong)
    {
        if(prevClose4H > prevOpen4H && close4H < open4H && 
           open4H > prevClose4H && close4H < prevOpen4H)
        {
            tracking.Tiers[3].IsHit = true;
            tracking.Tiers[3].HitTime = TimeCurrent();
            return true;
        }
    }
    
    // Check time expiry (5 trading days)
    datetime timeSinceEntry = TimeCurrent() - tracking.EntryTime;
    if(timeSinceEntry >= 5 * 86400) // 5 days
    {
        tracking.Tiers[3].IsHit = true;
        tracking.Tiers[3].HitTime = TimeCurrent();
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Tier 5 (Emergency exit)                                   |
//+------------------------------------------------------------------+
bool CSurgicalExit::CheckTier5(ExitTracking &tracking)
{
    // 10% trailing stop (never moves backward)
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double maxPrice = tracking.IsLong ? 
                     (tracking.EntryPrice + tracking.MaxProfit) : 
                     (tracking.EntryPrice - tracking.MaxProfit);
    
    double trailingStop = 0;
    if(tracking.IsLong)
        trailingStop = maxPrice * 0.90; // 10% below max
    else
        trailingStop = maxPrice * 1.10; // 10% above min
    
    // Update trail if beneficial
    if(tracking.CurrentTrail == 0 || 
       (tracking.IsLong && trailingStop > tracking.CurrentTrail) ||
       (!tracking.IsLong && trailingStop < tracking.CurrentTrail))
    {
        tracking.CurrentTrail = trailingStop;
    }
    
    bool exitTriggered = false;
    if(tracking.IsLong)
        exitTriggered = (currentPrice < tracking.CurrentTrail);
    else
        exitTriggered = (currentPrice > tracking.CurrentTrail);
    
    if(exitTriggered)
    {
        tracking.Tiers[4].IsHit = true;
        tracking.Tiers[4].HitTime = TimeCurrent();
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Apply time decay                                                 |
//+------------------------------------------------------------------+
void CSurgicalExit::ApplyTimeDecay(ulong ticket)
{
    int index;
    if(!FindTracking(ticket, index))
        return;
    
    datetime timeSinceEntry = TimeCurrent() - m_ExitTracking[index].EntryTime;
    int daysInTrade = (int)(timeSinceEntry / 86400);
    
    // After 3 days: reduce position by 25%
    if(daysInTrade >= 3 && daysInTrade < 5)
    {
        // Close 25% if not already done
        // This would be handled by a separate mechanism
    }
    
    // After 5 days: close 50%
    if(daysInTrade >= 5 && daysInTrade < 7)
    {
        // Close 50% if not already done
    }
    
    // After 7 days: close all
    if(daysInTrade >= m_MaxHoldDays)
    {
        // Close entire position
        if(PositionSelectByTicket(ticket))
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = m_ExitTracking[index].IsLong ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.deviation = 10;
            if(!OrderSend(request, result))
            {
                Print("Failed to close tier position: ", result.retcode);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Execute exit                                                     |
//+------------------------------------------------------------------+
void CSurgicalExit::ExecuteExit(ulong ticket, int tier, double exitPercent)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    double exitVolume = currentVolume * exitPercent;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = exitVolume;
    request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                   ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.deviation = 10;
    if(!OrderSend(request, result))
    {
        Print("Failed to execute exit: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Calculate tier price                                             |
//+------------------------------------------------------------------+
double CSurgicalExit::CalculateTierPrice(int tier, const DarvasBox &box,
                                        double entryPrice, bool isLong)
{
    double boxHeight = box.Height;
    double multiplier = 0;
    
    switch(tier)
    {
        case 1: multiplier = m_Tier1Multiplier; break;
        case 2: multiplier = m_Tier2Multiplier; break;
    }
    
    if(isLong)
        return entryPrice + (boxHeight * multiplier);
    else
        return entryPrice - (boxHeight * multiplier);
}

//+------------------------------------------------------------------+
//| Find tracking                                                    |
//+------------------------------------------------------------------+
bool CSurgicalExit::FindTracking(ulong ticket, int &index)
{
    for(int i = 0; i < m_TrackingCount; i++)
    {
        if(m_ExitTracking[i].Ticket == ticket)
        {
            index = i;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
