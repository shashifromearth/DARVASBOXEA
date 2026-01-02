//+------------------------------------------------------------------+
//|                                                  DarvasBoxEA.mq5 |
//|                        Super Duper Darvas Box Trading System     |
//|                                              shashi ByteBAba LLp |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "Institutional-grade Darvas Box trading system with 3-tier entries, pyramid exits, and advanced risk management"

//--- Include files
#include "Include/DarvasBox.mqh"
#include "Include/BoxDetector.mqh"
#include "Include/VolumeAnalyzer.mqh"
#include "Include/MarketStructure.mqh"
#include "Include/SessionManager.mqh"
#include "Include/BreakoutScorer.mqh"
#include "Include/RiskManager.mqh"
#include "Include/EntryManager.mqh"
#include "Include/ExitManager.mqh"
#include "Include/TradeManager.mqh"
#include "Include/NewsFilter.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Darvas Box Settings ==="
input int      InpMinBarsInBox      = 5;        // Minimum consolidation bars
input double   InpBoxSensitivity    = 0.15;     // Sensitivity to price swings
input bool     InpUseVolumeFilter   = true;     // Volume confirmation required
input bool     InpUseMultiTFBoxes   = true;     // Multiple timeframe boxes

input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES InpOperationalTF = PERIOD_H1;   // Operational timeframe (Entry)
input ENUM_TIMEFRAMES InpTrendTF       = PERIOD_H4;   // Trend timeframe (Direction)
input ENUM_TIMEFRAMES InpConfirmationTF = PERIOD_D1;  // Confirmation timeframe (Box Validity)

input group "=== Entry Parameters ==="
input bool     InpUseTieredEntries  = true;     // 3-tier entry system
input int      InpMinBreakoutScore  = 70;       // Minimum quality score
input double   InpVolumeSurgeMin    = 1.5;      // 150% volume surge required

input group "=== Exit Strategy ==="
input bool     InpUsePyramidExit    = true;     // Scale out in 30/30/40
input double   InpProfitMultiplier  = 3.0;      // 3× box height target
input bool     InpUseChandelierExit = true;     // Volatility-based trailing

input group "=== Risk Management ==="
input double   InpBaseRiskPercent   = 1.5;      // Base risk per trade (%)
input bool     InpUseAdaptiveSizing = true;     // Adjust based on box size
input double   InpMaxDailyRisk      = 5.0;      // Maximum daily risk (%)
input int      InpMaxTradesPerDay   = 3;        // Maximum trades per day

input group "=== Market Filters ==="
input bool     InpFilterBySession   = true;     // Weight by trading session
input bool     InpAvoidNews         = true;     // Skip high-impact news
input int      InpNewsBufferMinutes = 30;       // Minutes before/after news
input bool     InpTrendFilter       = true;     // Higher TF alignment

input group "=== Magic Number ==="
input int      InpMagicNumber       = 123456;   // Magic number for trades

//+------------------------------------------------------------------+
//| Global Objects                                                   |
//+------------------------------------------------------------------+
CBoxDetector      *g_BoxDetector;
CVolumeAnalyzer   *g_VolumeAnalyzer;
CMarketStructure  *g_MarketStructure;
CSessionManager   *g_SessionManager;
CBreakoutScorer   *g_BreakoutScorer;
CRiskManager      *g_RiskManager;
CEntryManager     *g_EntryManager;
CExitManager      *g_ExitManager;
CTradeManager     *g_TradeManager;
CNewsFilter       *g_NewsFilter;

// Statistics
BoxStatistics     g_BoxStats;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialize all components
    Print("=== DarvasBoxEA Initialization ===");
    
    // Create objects
    g_BoxDetector = new CBoxDetector();
    g_VolumeAnalyzer = new CVolumeAnalyzer();
    g_MarketStructure = new CMarketStructure();
    g_SessionManager = new CSessionManager();
    g_BreakoutScorer = new CBreakoutScorer();
    g_RiskManager = new CRiskManager();
    g_EntryManager = new CEntryManager();
    g_ExitManager = new CExitManager();
    g_TradeManager = new CTradeManager();
    g_NewsFilter = new CNewsFilter();
    
    // Initialize Box Detector
    if(!g_BoxDetector.Initialize(InpOperationalTF, InpTrendTF, InpConfirmationTF,
                                  InpMinBarsInBox, InpBoxSensitivity,
                                  InpUseVolumeFilter, InpUseMultiTFBoxes))
    {
        Print("Failed to initialize Box Detector");
        return INIT_FAILED;
    }
    
    // Initialize Volume Analyzer
    if(!g_VolumeAnalyzer.Initialize(20, InpVolumeSurgeMin))
    {
        Print("Failed to initialize Volume Analyzer");
        return INIT_FAILED;
    }
    
    // Initialize Market Structure
    if(!g_MarketStructure.Initialize(InpTrendTF, InpConfirmationTF, InpTrendFilter))
    {
        Print("Failed to initialize Market Structure");
        return INIT_FAILED;
    }
    
    // Initialize Session Manager
    if(!g_SessionManager.Initialize(InpFilterBySession))
    {
        Print("Failed to initialize Session Manager");
        return INIT_FAILED;
    }
    
    // Initialize Breakout Scorer
    if(!g_BreakoutScorer.Initialize(InpMinBreakoutScore, g_VolumeAnalyzer,
                                    g_MarketStructure, g_SessionManager))
    {
        Print("Failed to initialize Breakout Scorer");
        return INIT_FAILED;
    }
    
    // Initialize Risk Manager
    if(!g_RiskManager.Initialize(InpBaseRiskPercent, InpMaxDailyRisk,
                                 InpMaxTradesPerDay, InpUseAdaptiveSizing))
    {
        Print("Failed to initialize Risk Manager");
        return INIT_FAILED;
    }
    
    // Initialize Entry Manager
    if(!g_EntryManager.Initialize(InpUseTieredEntries, InpMinBreakoutScore,
                                   InpVolumeSurgeMin, g_BreakoutScorer,
                                   g_RiskManager, g_VolumeAnalyzer))
    {
        Print("Failed to initialize Entry Manager");
        return INIT_FAILED;
    }
    
    // Initialize Exit Manager
    if(!g_ExitManager.Initialize(InpUsePyramidExit, InpProfitMultiplier,
                                 InpUseChandelierExit, g_VolumeAnalyzer))
    {
        Print("Failed to initialize Exit Manager");
        return INIT_FAILED;
    }
    
    // Initialize Trade Manager
    if(!g_TradeManager.Initialize(g_EntryManager, g_ExitManager, g_RiskManager, InpMagicNumber))
    {
        Print("Failed to initialize Trade Manager");
        return INIT_FAILED;
    }
    
    // Initialize News Filter
    if(!g_NewsFilter.Initialize(InpAvoidNews, InpNewsBufferMinutes))
    {
        Print("Failed to initialize News Filter");
        return INIT_FAILED;
    }
    
    // Initialize statistics
    g_BoxStats.TotalBoxes = 0;
    g_BoxStats.SuccessfulBoxes = 0;
    g_BoxStats.FailedBoxes = 0;
    g_BoxStats.AvgBreakoutScore = 0;
    g_BoxStats.AvgProfitMultiplier = 0;
    g_BoxStats.FalseBreakouts = 0;
    
    Print("=== DarvasBoxEA Initialized Successfully ===");
    Print("Operational TF: ", EnumToString(InpOperationalTF));
    Print("Trend TF: ", EnumToString(InpTrendTF));
    Print("Confirmation TF: ", EnumToString(InpConfirmationTF));
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Cleanup
    Print("=== DarvasBoxEA Deinitialization ===");
    Print("Reason: ", reason);
    
    // Print statistics
    Print("=== Trading Statistics ===");
    Print("Total Boxes: ", g_BoxStats.TotalBoxes);
    Print("Successful Boxes: ", g_BoxStats.SuccessfulBoxes);
    Print("Failed Boxes: ", g_BoxStats.FailedBoxes);
    Print("False Breakouts: ", g_BoxStats.FalseBreakouts);
    Print("Average Breakout Score: ", g_BoxStats.AvgBreakoutScore);
    Print("Average Profit Multiplier: ", g_BoxStats.AvgProfitMultiplier);
    
    // Delete objects
    if(g_BoxDetector != NULL) delete g_BoxDetector;
    if(g_VolumeAnalyzer != NULL) delete g_VolumeAnalyzer;
    if(g_MarketStructure != NULL) delete g_MarketStructure;
    if(g_SessionManager != NULL) delete g_SessionManager;
    if(g_BreakoutScorer != NULL) delete g_BreakoutScorer;
    if(g_RiskManager != NULL) delete g_RiskManager;
    if(g_EntryManager != NULL) delete g_EntryManager;
    if(g_ExitManager != NULL) delete g_ExitManager;
    if(g_TradeManager != NULL) delete g_TradeManager;
    if(g_NewsFilter != NULL) delete g_NewsFilter;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Check if new bar
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, InpOperationalTF, 0);
    
    bool isNewBar = (currentBarTime != lastBarTime);
    if(isNewBar)
        lastBarTime = currentBarTime;
    
    //--- Manage existing trades
    if(g_TradeManager != NULL)
        g_TradeManager.ManageOpenTrades();
    
    //--- Check if can open new trades
    if(!g_RiskManager.CanOpenNewTrade())
        return;
    
    //--- Check news filter
    if(g_NewsFilter != NULL && !g_NewsFilter.CanTrade())
        return;
    
    //--- Update box detection
    if(g_BoxDetector != NULL)
    {
        g_BoxDetector.UpdateBoxes();
        
        // Check for new boxes and breakouts
        int boxCount = g_BoxDetector.GetBoxCount();
        
        for(int i = 0; i < boxCount; i++)
        {
            DarvasBox box;
            if(g_BoxDetector.GetBox(i, box))
            {
                // Check for breakout
                bool isLong;
                if(g_BoxDetector.CheckBoxBreakout(box, (ENUM_TIMEFRAMES)box.Timeframe, isLong))
                {
                    // Process breakout
                    ProcessBreakout(box, (ENUM_TIMEFRAMES)box.Timeframe, isLong);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Process breakout                                                 |
//+------------------------------------------------------------------+
void ProcessBreakout(const DarvasBox &box, ENUM_TIMEFRAMES timeframe, bool isLong)
{
    //--- Update statistics
    g_BoxStats.TotalBoxes++;
    
    //--- Check if breakout is valid
    if(g_BreakoutScorer != NULL)
    {
        // Check for false breakout
        if(g_BreakoutScorer.CheckFalseBreakout(box, timeframe, isLong))
        {
            g_BoxStats.FailedBoxes++;
            g_BoxStats.FalseBreakouts++;
            return;
        }
        
        // Check if breakout score is sufficient
        if(!g_BreakoutScorer.IsBreakoutValid(box, timeframe, isLong))
        {
            g_BoxStats.FailedBoxes++;
            return;
        }
    }
    
    //--- Check market structure alignment
    if(g_MarketStructure != NULL)
    {
        if(!g_MarketStructure.IsWithTrend(isLong, timeframe))
        {
            Print("Breakout not aligned with trend - skipping");
            return;
        }
    }
    
    //--- Process entry
    if(g_EntryManager != NULL)
    {
        TradeEntry entry;
        if(g_EntryManager.ProcessBreakout(box, timeframe, isLong, entry))
        {
            // Open trade
            if(g_TradeManager != NULL)
            {
                if(g_TradeManager.OpenTrade(entry, box))
                {
                    g_BoxStats.SuccessfulBoxes++;
                    
                    // Update average breakout score
                    if(g_BoxStats.TotalBoxes > 0)
                    {
                        g_BoxStats.AvgBreakoutScore = 
                            (g_BoxStats.AvgBreakoutScore * (g_BoxStats.TotalBoxes - 1) + entry.BreakoutScore) / 
                            g_BoxStats.TotalBoxes;
                    }
                    
                    Print("Trade opened: Tier ", entry.Tier, 
                          ", Score: ", entry.BreakoutScore,
                          ", Size: ", entry.PositionSize);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
    //--- Update risk manager with trade results
    HistorySelect(0, TimeCurrent());
    
    // Get last closed trade
    int totalDeals = HistoryDealsTotal();
    if(totalDeals > 0)
    {
        ulong ticket = HistoryDealGetTicket(totalDeals - 1);
        if(ticket > 0)
        {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            bool isWin = (profit > 0);
            
            if(g_RiskManager != NULL)
                g_RiskManager.UpdateTradeResult(isWin);
            
            // Update statistics
            if(isWin)
            {
                // Calculate profit multiplier if possible
                // This would require tracking the box associated with the trade
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    //--- Periodic updates
    if(g_BoxDetector != NULL)
        g_BoxDetector.UpdateBoxes();
    
    if(g_TradeManager != NULL)
        g_TradeManager.ManageOpenTrades();
}

//+------------------------------------------------------------------+