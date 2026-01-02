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
#include "Include/QuantumTradeMatrix.mqh"
#include "Include/KellyCriterion.mqh"
#include "Include/ParabolicTrailing.mqh"
#include "Include/FibonacciExtensions.mqh"
#include "Include/CounterTradeGenerator.mqh"
#include "Include/VolatilityRegime.mqh"
#include "Include/CircuitBreakers.mqh"
#include "Include/BoxQualifier.mqh"
#include "Include/PrecisionEntry.mqh"
#include "Include/SurgicalExit.mqh"
#include "Include/PositionManager.mqh"
#include "Include/CorrelationManager.mqh"
#include "Include/MarketRegimeDetector.mqh"
#include "Include/TradeDiagnostics.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Darvas Box Settings ==="
input int      InpMinBarsInBox      = 5;        // Minimum consolidation bars
input double   InpBoxSensitivity    = 0.15;     // Sensitivity to price swings
input bool     InpUseVolumeFilter   = true;     // Volume confirmation required
input bool     InpUseMultiTFBoxes   = true;     // Multiple timeframe boxes

input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES InpBoxTF         = PERIOD_M5;   // Box Detection TF (5-min for more trades)
input ENUM_TIMEFRAMES InpBoxTFSecondary = PERIOD_M15; // Secondary Box TF (15-min fallback)
input ENUM_TIMEFRAMES InpEntryTF       = PERIOD_M5;   // Entry Execution TF (5-min)
input ENUM_TIMEFRAMES InpOperationalTF = PERIOD_M5;   // Operational timeframe (Entry) - DEPRECATED
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
input double   InpBaseRiskPercent   = 0.5;      // Base risk per trade (%) - REDUCED FOR SAFETY
input bool     InpUseAdaptiveSizing = true;     // Adjust based on box size
input double   InpMaxDailyRisk      = 2.0;      // Maximum daily risk (%) - REDUCED
input int      InpMaxTradesPerDay   = 2;        // Maximum trades per day - REDUCED
input double   InpMaxLossPerDay     = 500.0;    // Maximum loss per day ($) - NEW

input group "=== Market Filters ==="
input bool     InpFilterBySession   = false;    // Weight by trading session (RELAXED)
input bool     InpAvoidNews         = false;    // Skip high-impact news (RELAXED)
input int      InpNewsBufferMinutes = 15;       // Minutes before/after news (RELAXED)
input bool     InpTrendFilter       = false;    // Higher TF alignment (RELAXED)

input group "=== Magic Number ==="
input int      InpMagicNumber       = 123456;   // Magic number for trades

input group "=== QUANTUM MODE (Maximum Gain) ==="
input bool     InpQuantumMode       = false;   // Enable quantum multi-phase entries
input bool     InpUseKellyCriterion  = false;   // Use Kelly Criterion position sizing
input bool     InpUseParabolicTrail  = false;   // Use parabolic trailing stops
input bool     InpUseFibExtensions   = false;   // Use Fibonacci extension targets
input bool     InpUseCounterTrades   = false;   // Auto counter-trade on failed breakouts
input bool     InpUseVolatilityRegime = true;   // Adjust strategy by volatility regime
input bool     InpUseCircuitBreakers = true;    // Enable safety circuit breakers

input group "=== EXTREME PROFIT SETTINGS ==="
input double   InpExtremeBaseRisk   = 2.5;      // Base risk per trade (%)
input double   InpStreakMultiplier   = 1.5;     // Increase after 3 wins
input double   InpMaxPositionRisk   = 15.0;     // Max risk during hot streaks (%)
input int      InpMaxPhasesPerBox    = 5;        // Max phases per box cycle

input group "=== FIBONACCI EXTENSIONS ==="
input double   InpFibLevel1         = 1.618;    // First extension level
input double   InpFibLevel2         = 2.618;    // Second extension level
input double   InpFibLevel3         = 4.236;    // Third extension level
input double   InpFibLevel4         = 6.854;    // Fourth extension level

input group "=== CIRCUIT BREAKERS ==="
input double   InpMaxDrawdown       = 15.0;     // Maximum drawdown (%)
input int      InpMaxConsecutiveLosses = 3;     // Max consecutive losses
input bool     InpNoTradesLast30Min = true;     // No trades last 30 min
input bool     InpFridayReduction   = true;     // Reduce size Friday after 18:00
input double   InpMaxDailyRange     = 3.0;      // Max daily range multiplier

input group "=== SURGICAL ENTRY SYSTEM ==="
input bool     InpRequireRetest     = false;    // Wait for retest before entry (RELAXED)
input double   InpMinBoxScore        = 70.0;     // Minimum box quality score (0-100) - INCREASED FOR QUALITY
input int      InpMinConsolidationBars = 3;      // Minimum bars in box (RELAXED)
input double   InpMinVolumeSurge     = 1.3;      // Minimum volume surge (130%) (RELAXED)
input bool     InpEnableDiagnostics  = true;     // Enable trade diagnostics
input bool     InpRelaxedMode        = true;     // Relaxed mode (less strict filters)
input bool     InpForceTradeMode    = false;    // FORCE TRADE MODE (bypasses most filters) - DISABLED FOR SAFETY
input bool     InpVerboseLogging     = true;     // Verbose logging for debugging
input bool     InpMinimalFilters     = true;     // MINIMAL FILTERS MODE (only essential checks)

input group "=== SURGICAL EXIT SYSTEM ==="
input bool     InpUseSurgicalExits  = true;     // Use 5-tier surgical exit
input double   InpSurgicalTier1Multiplier = 0.75; // Tier 1: 0.75× box height
input double   InpSurgicalTier2Multiplier = 1.5; // Tier 2: 1.5× box height
input double   InpSurgicalTier3TrailStart = 1.0; // Tier 3: Trail start (ATR multiplier)
input int      InpMaxHoldDays        = 7;       // Maximum hold days

input group "=== POSITION MANAGEMENT ==="
input double   InpSurgicalBaseRisk   = 0.5;      // Base risk per trade (%) - REDUCED FOR SAFETY
input bool     InpAllowPyramiding    = true;     // Allow adding to winners
input int      InpMaxAddsPerTrade    = 2;        // Maximum adds per trade
input double   InpPyramidSizeRatio   = 0.5;      // Add size ratio (50% of initial)
input bool     InpUseCorrelationFilter = true;  // Filter correlated positions

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

// Quantum Mode Components
CQuantumTradeMatrix *g_QuantumMatrix;
CKellyCriterion    *g_KellyCriterion;
CParabolicTrailing *g_ParabolicTrailing;
CFibonacciExtensions *g_FibExtensions;
CCounterTradeGenerator *g_CounterTrade;
CVolatilityRegime  *g_VolatilityRegime;
CCircuitBreakers   *g_CircuitBreakers;

// Surgical System Components
CBoxQualifier      *g_BoxQualifier;
CPrecisionEntry    *g_PrecisionEntry;
CSurgicalExit      *g_SurgicalExit;
CPositionManager   *g_PositionManager;
CCorrelationManager *g_CorrelationManager;
CMarketRegimeDetector *g_MarketRegimeDetector;
CTradeDiagnostics *g_Diagnostics;

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
    
    // Initialize Quantum Mode Components
    if(InpQuantumMode || InpUseKellyCriterion || InpUseParabolicTrail || 
       InpUseFibExtensions || InpUseCounterTrades)
    {
        g_QuantumMatrix = new CQuantumTradeMatrix();
        g_KellyCriterion = new CKellyCriterion();
        g_ParabolicTrailing = new CParabolicTrailing();
        g_FibExtensions = new CFibonacciExtensions();
        g_CounterTrade = new CCounterTradeGenerator();
        g_VolatilityRegime = new CVolatilityRegime();
        g_CircuitBreakers = new CCircuitBreakers();
        
        // Initialize Quantum Matrix
        if(InpQuantumMode)
        {
            g_QuantumMatrix.Initialize(0.20, 0.30, 0.25, 0.15, 0.10, InpMaxPhasesPerBox);
        }
        
        // Initialize Kelly Criterion
        if(InpUseKellyCriterion)
        {
            g_KellyCriterion.Initialize(50);
        }
        
        // Initialize Parabolic Trailing
        if(InpUseParabolicTrail)
        {
            g_ParabolicTrailing.Initialize(0.02, 0.20, 0.02);
        }
        
        // Initialize Fibonacci Extensions
        if(InpUseFibExtensions)
        {
            g_FibExtensions.Initialize(InpFibLevel1, InpFibLevel2, InpFibLevel3, InpFibLevel4);
        }
        
        // Initialize Counter Trade Generator
        if(InpUseCounterTrades)
        {
            g_CounterTrade.Initialize(true, 1.5, 0.5, g_VolumeAnalyzer);
        }
        
        // Initialize Volatility Regime
        if(InpUseVolatilityRegime)
        {
            g_VolatilityRegime.Initialize(14, 20);
        }
        
        // Initialize Circuit Breakers
        if(InpUseCircuitBreakers)
        {
            g_CircuitBreakers.Initialize(InpMaxDrawdown, InpMaxConsecutiveLosses,
                                        InpNoTradesLast30Min, InpFridayReduction,
                                        InpMaxDailyRange, true, 5, InpMaxTradesPerDay);
        }
    }
    else
    {
        g_QuantumMatrix = NULL;
        g_KellyCriterion = NULL;
        g_ParabolicTrailing = NULL;
        g_FibExtensions = NULL;
        g_CounterTrade = NULL;
        g_VolatilityRegime = NULL;
        g_CircuitBreakers = NULL;
    }
    
    // Initialize Surgical System Components (always initialize)
    g_BoxQualifier = new CBoxQualifier();
    g_PrecisionEntry = new CPrecisionEntry();
    g_SurgicalExit = new CSurgicalExit();
    g_PositionManager = new CPositionManager();
    g_CorrelationManager = new CCorrelationManager();
    g_MarketRegimeDetector = new CMarketRegimeDetector();
    g_Diagnostics = new CTradeDiagnostics();
    
    // Initialize Box Qualifier
    bool boxQualifierInit = g_BoxQualifier.Initialize(InpMinBoxScore,
                                                      InpMinConsolidationBars,
                                                      0.30, 0.40, 1.5,
                                                      g_VolumeAnalyzer);
    if(!boxQualifierInit)
    {
        Print("Failed to initialize Box Qualifier");
        return INIT_FAILED;
    }
    
    // Initialize Precision Entry
    bool precisionEntryInit = g_PrecisionEntry.Initialize(InpRequireRetest,
                                                          InpMinVolumeSurge,
                                                          0.25, 0.75,
                                                          g_VolumeAnalyzer,
                                                          g_SessionManager);
    if(!precisionEntryInit)
    {
        Print("Failed to initialize Precision Entry");
        return INIT_FAILED;
    }
    
    // Initialize Surgical Exit
    bool surgicalExitInit = g_SurgicalExit.Initialize(InpSurgicalTier1Multiplier,
                                                     InpSurgicalTier2Multiplier,
                                                     InpSurgicalTier3TrailStart,
                                                     InpMaxHoldDays,
                                                     InpUseSurgicalExits,
                                                     g_ParabolicTrailing);
    if(!surgicalExitInit)
    {
        Print("Failed to initialize Surgical Exit");
        return INIT_FAILED;
    }
    
    // Initialize Position Manager
    bool positionMgrInit = g_PositionManager.Initialize(InpSurgicalBaseRisk,
                                                        InpAllowPyramiding,
                                                        InpMaxAddsPerTrade,
                                                        InpPyramidSizeRatio,
                                                        InpUseCorrelationFilter);
    if(!positionMgrInit)
    {
        Print("Failed to initialize Position Manager");
        return INIT_FAILED;
    }
    
    // Initialize Correlation Manager
    bool correlationInit = g_CorrelationManager.Initialize(3.0, 8.0, false);
    if(!correlationInit)
    {
        Print("Failed to initialize Correlation Manager");
        return INIT_FAILED;
    }
    
    // Initialize Market Regime Detector
    bool regimeDetectorInit = g_MarketRegimeDetector.Initialize(14, g_VolatilityRegime);
    if(!regimeDetectorInit)
    {
        Print("Failed to initialize Market Regime Detector");
        return INIT_FAILED;
    }
    
    // Initialize Box Detector (use relaxed parameters in force mode)
    // Use 5-min for box detection, 15-min as fallback
    int minBars = InpForceTradeMode ? 3 : InpMinBarsInBox;
    double sensitivity = InpForceTradeMode ? 0.25 : InpBoxSensitivity;
    bool useVolume = InpForceTradeMode ? false : InpUseVolumeFilter;
    
    // Initialize with primary box TF (5-min), but we'll check both
    bool boxDetInit = g_BoxDetector.Initialize(InpBoxTF, InpTrendTF, InpConfirmationTF,
                                  minBars, sensitivity,
                                  useVolume, InpUseMultiTFBoxes);
    if(!boxDetInit)
    {
        Print("Failed to initialize Box Detector");
        return INIT_FAILED;
    }
    
    // Initialize Volume Analyzer
    bool volAnalyzerInit = g_VolumeAnalyzer.Initialize(20, InpVolumeSurgeMin);
    if(!volAnalyzerInit)
    {
        Print("Failed to initialize Volume Analyzer");
        return INIT_FAILED;
    }
    
    // Initialize Market Structure
    bool marketStructInit = g_MarketStructure.Initialize(InpTrendTF, InpConfirmationTF, InpTrendFilter);
    if(!marketStructInit)
    {
        Print("Failed to initialize Market Structure");
        return INIT_FAILED;
    }
    
    // Initialize Session Manager
    bool sessionInit = g_SessionManager.Initialize(InpFilterBySession);
    if(!sessionInit)
    {
        Print("Failed to initialize Session Manager");
        return INIT_FAILED;
    }
    
    // Initialize Breakout Scorer
    bool scorerInit = g_BreakoutScorer.Initialize(InpMinBreakoutScore, g_VolumeAnalyzer,
                                    g_MarketStructure, g_SessionManager);
    if(!scorerInit)
    {
        Print("Failed to initialize Breakout Scorer");
        return INIT_FAILED;
    }
    
    // Initialize Risk Manager
    // Initialize risk manager with conservative settings
    double safeBaseRisk = MathMin(InpBaseRiskPercent, 0.5); // Cap at 0.5%
    double safeDailyRisk = MathMin(InpMaxDailyRisk, 2.0); // Cap at 2%
    int safeMaxTrades = MathMin(InpMaxTradesPerDay, 2); // Cap at 2 trades/day
    
    bool riskInit = g_RiskManager.Initialize(safeBaseRisk, safeDailyRisk,
                                 safeMaxTrades, InpUseAdaptiveSizing);
    if(!riskInit)
    {
        Print("Failed to initialize Risk Manager");
        return INIT_FAILED;
    }
    
    // Initialize Entry Manager
    bool entryInit = g_EntryManager.Initialize(InpUseTieredEntries, InpMinBreakoutScore,
                                   InpVolumeSurgeMin, g_BreakoutScorer,
                                   g_RiskManager, g_VolumeAnalyzer);
    if(!entryInit)
    {
        Print("Failed to initialize Entry Manager");
        return INIT_FAILED;
    }
    
    // Initialize Exit Manager
    bool exitInit = g_ExitManager.Initialize(InpUsePyramidExit, InpProfitMultiplier,
                                 InpUseChandelierExit, g_VolumeAnalyzer);
    if(!exitInit)
    {
        Print("Failed to initialize Exit Manager");
        return INIT_FAILED;
    }
    
    // Initialize Trade Manager
    bool tradeInit = g_TradeManager.Initialize(g_EntryManager, g_ExitManager, g_RiskManager, InpMagicNumber);
    if(!tradeInit)
    {
        Print("Failed to initialize Trade Manager");
        return INIT_FAILED;
    }
    
    // Initialize News Filter
    bool newsInit = g_NewsFilter.Initialize(InpAvoidNews, InpNewsBufferMinutes);
    if(!newsInit)
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
    Print("Box Detection TF (Primary): ", EnumToString(InpBoxTF));
    Print("Box Detection TF (Secondary): ", EnumToString(InpBoxTFSecondary));
    Print("Entry Execution TF: ", EnumToString(InpEntryTF));
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
    
    //--- Print diagnostic summary
    if(g_Diagnostics != NULL && InpEnableDiagnostics)
    {
        g_Diagnostics.PrintSummary();
    }
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
    
    // Delete Quantum Mode Components
    if(g_QuantumMatrix != NULL) delete g_QuantumMatrix;
    if(g_KellyCriterion != NULL) delete g_KellyCriterion;
    if(g_ParabolicTrailing != NULL) delete g_ParabolicTrailing;
    if(g_FibExtensions != NULL) delete g_FibExtensions;
    if(g_CounterTrade != NULL) delete g_CounterTrade;
    if(g_VolatilityRegime != NULL) delete g_VolatilityRegime;
    if(g_CircuitBreakers != NULL) delete g_CircuitBreakers;
    
    // Delete Surgical System Components
    if(g_BoxQualifier != NULL) delete g_BoxQualifier;
    if(g_PrecisionEntry != NULL) delete g_PrecisionEntry;
    if(g_SurgicalExit != NULL) delete g_SurgicalExit;
    if(g_PositionManager != NULL) delete g_PositionManager;
    if(g_CorrelationManager != NULL) delete g_CorrelationManager;
    if(g_MarketRegimeDetector != NULL) delete g_MarketRegimeDetector;
    if(g_Diagnostics != NULL) delete g_Diagnostics;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Check if new bar on entry timeframe (5-min)
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, InpEntryTF, 0);
    
    bool isNewBar = (currentBarTime != lastBarTime);
    if(isNewBar)
        lastBarTime = currentBarTime;
    
    //--- Manage existing trades
    if(g_TradeManager != NULL)
    {
        g_TradeManager.ManageOpenTrades();
    }
    
    //--- Check circuit breakers first (safety first!)
    bool circuitBreakerOK = true;
    if(g_CircuitBreakers != NULL)
    {
        circuitBreakerOK = g_CircuitBreakers.CanTrade();
        if(!circuitBreakerOK)
        {
            if(InpEnableDiagnostics && g_Diagnostics != NULL)
            {
                TradeDiagnostic diag = {};
                diag.CircuitBreakerOK = false;
                diag.Timestamp = TimeCurrent();
                diag.Symbol = _Symbol;
                g_Diagnostics.LogDiagnostic(diag);
            }
            return;
        }
    }
    
    //--- Check if can open new trades
    bool riskManagerOK = true;
    if(g_RiskManager != NULL)
    {
        riskManagerOK = g_RiskManager.CanOpenNewTrade();
        if(!riskManagerOK)
        {
            if(InpEnableDiagnostics && g_Diagnostics != NULL)
            {
                TradeDiagnostic diag = {};
                diag.RiskManagerOK = false;
                diag.Timestamp = TimeCurrent();
                diag.Symbol = _Symbol;
                g_Diagnostics.LogDiagnostic(diag);
            }
            return;
        }
    }
    
    //--- Check news filter (optional in relaxed mode)
    bool newsFilterOK = true;
    if(g_NewsFilter != NULL && InpAvoidNews)
    {
        newsFilterOK = g_NewsFilter.CanTrade();
        if(!newsFilterOK && !InpRelaxedMode)
        {
            if(InpEnableDiagnostics && g_Diagnostics != NULL)
            {
                TradeDiagnostic diag = {};
                diag.NewsFilterOK = false;
                diag.Timestamp = TimeCurrent();
                diag.Symbol = _Symbol;
                g_Diagnostics.LogDiagnostic(diag);
            }
            return;
        }
    }
    
    //--- Update volatility regime
    if(g_VolatilityRegime != NULL)
    {
        g_VolatilityRegime.GetCurrentRegime(InpEntryTF);
    }
    
    //--- Update parabolic trailing
    if(g_ParabolicTrailing != NULL)
    {
        g_ParabolicTrailing.UpdateTrailingStops();
    }
    
    //--- Update quantum matrix phases
    if(g_QuantumMatrix != NULL)
    {
        g_QuantumMatrix.UpdatePhases();
    }
    
    //--- Update surgical exit system
    if(g_SurgicalExit != NULL && InpUseSurgicalExits)
    {
        g_SurgicalExit.UpdateExits();
    }
    
    //--- Update position management
    if(g_PositionManager != NULL)
    {
        g_PositionManager.UpdatePositions();
    }
    
    //--- Update market regime
    if(g_MarketRegimeDetector != NULL)
    {
        g_MarketRegimeDetector.GetCurrentRegime(InpEntryTF);
    }
    
    //--- CRITICAL: Check if we have an open position BEFORE checking for new boxes
    // Only look for new opportunities if no position is open (ONE POSITION AT A TIME)
    int totalPositions = PositionsTotal();
    bool hasOpenPosition = false;
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionSelectByTicket(ticket))
            {
                if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
                   PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                {
                    hasOpenPosition = true;
                    if(InpVerboseLogging && isNewBar)
                        Print("SKIPPING BOX DETECTION: Position already open. Ticket=", ticket,
                              ", Type=", PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "LONG" : "SHORT",
                              ", Profit=", DoubleToString(PositionGetDouble(POSITION_PROFIT), 2));
                    break;
                }
            }
        }
    }
    
    // Also check TradeManager tracking
    if(g_TradeManager != NULL && g_TradeManager.HasOpenTrades())
    {
        hasOpenPosition = true;
        if(InpVerboseLogging && isNewBar)
            Print("SKIPPING BOX DETECTION: TradeManager reports open trades. Count=", 
                  g_TradeManager.GetOpenTradeCount());
    }
    
    // If we have an open position, skip box detection and new opportunities
    if(hasOpenPosition)
    {
        return; // Exit early - no new trades while position is open
    }
    
    //--- Update box detection - PRIORITY: 5-min first, then 15-min fallback
    // Only check for new boxes if no position is open
    if(g_BoxDetector != NULL)
    {
        g_BoxDetector.UpdateBoxes();
        
        // Check for new bar on entry timeframe (5-min)
        static datetime lastEntryBarTime = 0;
        datetime currentEntryBarTime = iTime(_Symbol, InpEntryTF, 0);
        bool isNewEntryBar = (currentEntryBarTime != lastEntryBarTime);
        if(isNewEntryBar)
            lastEntryBarTime = currentEntryBarTime;
        
        // PRIORITY 1: Try to detect box on 5-minute timeframe first
        DarvasBox box5Min;
        bool boxFound5Min = false;
        
        if(isNewEntryBar)
        {
            // Try multiple times with different parameters
            for(int attempt = 0; attempt < 3 && !boxFound5Min; attempt++)
            {
                if(g_BoxDetector.DetectBox(InpBoxTF, box5Min))
                {
                    boxFound5Min = true;
                    if(InpVerboseLogging)
                        Print("5-MIN BOX DETECTED: Top=", DoubleToString(box5Min.Top, 5), 
                              ", Bottom=", DoubleToString(box5Min.Bottom, 5), 
                              ", Bars=", box5Min.ConsolidationBars, 
                              ", Height=", DoubleToString(box5Min.Height, 5));
                }
                else
                {
                    if(InpVerboseLogging && attempt == 0)
                        Print("Box detection attempt ", attempt + 1, " failed on 5-min");
                    Sleep(10); // Small delay
                }
            }
            
            // If still no box, create a simple one from recent price action
            if(!boxFound5Min && InpForceTradeMode)
            {
                if(InpVerboseLogging)
                    Print("Creating simple box from recent 5-min price action");
                
                // Simple box: last 5-10 bars high/low
                double high = iHigh(_Symbol, InpBoxTF, 0);
                double low = iLow(_Symbol, InpBoxTF, 0);
                for(int j = 1; j < 10; j++)
                {
                    double h = iHigh(_Symbol, InpBoxTF, j);
                    double l = iLow(_Symbol, InpBoxTF, j);
                    if(h > high) high = h;
                    if(l < low) low = l;
                }
                
                if(high > low)
                {
                    box5Min.Top = high;
                    box5Min.Bottom = low;
                    box5Min.Height = high - low;
                    box5Min.ConsolidationBars = 5;
                    box5Min.CreationTime = TimeCurrent();
                    box5Min.Timeframe = (int)InpBoxTF;
                    box5Min.ATRValue = g_BoxDetector.GetATR(InpBoxTF);
                    if(box5Min.ATRValue <= 0) box5Min.ATRValue = box5Min.Height * 0.1;
                    box5Min.Validated = true;
                    box5Min.IsBullish = (iClose(_Symbol, InpBoxTF, 0) > (high + low) / 2);
                    boxFound5Min = true;
                    
                    if(InpVerboseLogging)
                        Print("SIMPLE 5-MIN BOX CREATED: Top=", DoubleToString(box5Min.Top, 5), 
                              ", Bottom=", DoubleToString(box5Min.Bottom, 5));
                }
            }
        }
        
        // PRIORITY 2: If no 5-min box, try 15-minute timeframe
        DarvasBox box15Min;
        bool boxFound15Min = false;
        
        if(!boxFound5Min && isNewEntryBar)
        {
            if(g_BoxDetector.DetectBox(InpBoxTFSecondary, box15Min))
            {
                boxFound15Min = true;
                if(InpVerboseLogging)
                    Print("15-MIN BOX DETECTED (Fallback): Top=", DoubleToString(box15Min.Top, 5), 
                          ", Bottom=", DoubleToString(box15Min.Bottom, 5), 
                          ", Bars=", box15Min.ConsolidationBars, 
                          ", Height=", DoubleToString(box15Min.Height, 5));
            }
            else if(InpForceTradeMode)
            {
                // Create simple 15-min box
                double high = iHigh(_Symbol, InpBoxTFSecondary, 0);
                double low = iLow(_Symbol, InpBoxTFSecondary, 0);
                for(int j = 1; j < 10; j++)
                {
                    double h = iHigh(_Symbol, InpBoxTFSecondary, j);
                    double l = iLow(_Symbol, InpBoxTFSecondary, j);
                    if(h > high) high = h;
                    if(l < low) low = l;
                }
                
                if(high > low)
                {
                    box15Min.Top = high;
                    box15Min.Bottom = low;
                    box15Min.Height = high - low;
                    box15Min.ConsolidationBars = 5;
                    box15Min.CreationTime = TimeCurrent();
                    box15Min.Timeframe = (int)InpBoxTFSecondary;
                    box15Min.ATRValue = g_BoxDetector.GetATR(InpBoxTFSecondary);
                    if(box15Min.ATRValue <= 0) box15Min.ATRValue = box15Min.Height * 0.1;
                    box15Min.Validated = true;
                    box15Min.IsBullish = (iClose(_Symbol, InpBoxTFSecondary, 0) > (high + low) / 2);
                    boxFound15Min = true;
                    
                    if(InpVerboseLogging)
                        Print("SIMPLE 15-MIN BOX CREATED: Top=", DoubleToString(box15Min.Top, 5), 
                              ", Bottom=", DoubleToString(box15Min.Bottom, 5));
                }
            }
        }
        
        // Check existing boxes for breakouts
        int boxCount = g_BoxDetector.GetBoxCount();
        
        if(InpVerboseLogging && isNewEntryBar)
            Print("OnTick: Box count = ", boxCount, ", New 5-min bar = ", isNewEntryBar,
                  ", 5-min box found = ", boxFound5Min, ", 15-min box found = ", boxFound15Min);
        
        // Process breakouts on 5-minute timeframe (entry TF)
        ENUM_TIMEFRAMES checkTF = boxFound5Min ? InpBoxTF : (boxFound15Min ? InpBoxTFSecondary : InpEntryTF);
        DarvasBox activeBox = boxFound5Min ? box5Min : (boxFound15Min ? box15Min : box5Min);
        
        // Check for breakout on entry timeframe (5-min) regardless of box TF
        // AGGRESSIVE BREAKOUT DETECTION - Check on every tick, not just new bars
        bool isLong = false; // Initialize
        if(boxFound5Min || boxFound15Min)
        {
            // Get current price (use Ask/Bid for more accurate breakout detection)
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double close5Min = iClose(_Symbol, InpEntryTF, 0);
            double prevClose5Min = iClose(_Symbol, InpEntryTF, 1);
            double high5Min = iHigh(_Symbol, InpEntryTF, 0);
            double low5Min = iLow(_Symbol, InpEntryTF, 0);
            
            // Log price vs box boundaries for debugging
            if(InpVerboseLogging && isNewEntryBar)
            {
                Print("PRICE CHECK: Current=", DoubleToString(currentPrice, 5),
                      ", Ask=", DoubleToString(askPrice, 5),
                      ", Close=", DoubleToString(close5Min, 5),
                      ", Box Top=", DoubleToString(activeBox.Top, 5),
                      ", Box Bottom=", DoubleToString(activeBox.Bottom, 5),
                      ", Distance to Top=", DoubleToString(activeBox.Top - currentPrice, 5),
                      ", Distance to Bottom=", DoubleToString(currentPrice - activeBox.Bottom, 5));
            }
            
            // AGGRESSIVE BREAKOUT DETECTION - Multiple conditions
            bool breakoutDetected = false;
            
            // Condition 1: Classic breakout (close breaks box boundary)
            if(close5Min > activeBox.Top && prevClose5Min <= activeBox.Top)
            {
                isLong = true;
                breakoutDetected = true;
                if(InpVerboseLogging)
                    Print("BREAKOUT TYPE 1: Close broke above box top");
            }
            else if(close5Min < activeBox.Bottom && prevClose5Min >= activeBox.Bottom)
            {
                isLong = false;
                breakoutDetected = true;
                if(InpVerboseLogging)
                    Print("BREAKOUT TYPE 1: Close broke below box bottom");
            }
            // Condition 2: Current price is outside box (already broken out)
            else if(currentPrice > activeBox.Top)
            {
                isLong = true;
                breakoutDetected = true;
                if(InpVerboseLogging)
                    Print("BREAKOUT TYPE 2: Current price above box top");
            }
            else if(currentPrice < activeBox.Bottom)
            {
                isLong = false;
                breakoutDetected = true;
                if(InpVerboseLogging)
                    Print("BREAKOUT TYPE 2: Current price below box bottom");
            }
            // Condition 3: High/Low of current bar breaks box (more aggressive)
            else if(high5Min > activeBox.Top && close5Min > activeBox.Bottom)
            {
                isLong = true;
                breakoutDetected = true;
                if(InpVerboseLogging)
                    Print("BREAKOUT TYPE 3: High broke box top");
            }
            else if(low5Min < activeBox.Bottom && close5Min < activeBox.Top)
            {
                isLong = false;
                breakoutDetected = true;
                if(InpVerboseLogging)
                    Print("BREAKOUT TYPE 3: Low broke box bottom");
            }
            // Condition 4: Price is very close to box boundary (within 5 pips) - anticipate breakout
            else if(InpForceTradeMode)
            {
                double boxHeight = activeBox.Height;
                double tolerance = boxHeight * 0.05; // 5% of box height
                
                if(currentPrice >= (activeBox.Top - tolerance) && currentPrice <= activeBox.Top)
                {
                    isLong = true;
                    breakoutDetected = true;
                    if(InpVerboseLogging)
                        Print("BREAKOUT TYPE 4 (FORCE): Price near box top, anticipating breakout");
                }
                else if(currentPrice <= (activeBox.Bottom + tolerance) && currentPrice >= activeBox.Bottom)
                {
                    isLong = false;
                    breakoutDetected = true;
                    if(InpVerboseLogging)
                        Print("BREAKOUT TYPE 4 (FORCE): Price near box bottom, anticipating breakout");
                }
            }
            
            if(breakoutDetected)
            {
                if(InpVerboseLogging)
                    Print("BREAKOUT DETECTED on 5-min: Direction=", isLong ? "LONG" : "SHORT",
                          ", Box Top=", DoubleToString(activeBox.Top, 5), 
                          ", Bottom=", DoubleToString(activeBox.Bottom, 5),
                          ", Current Price=", DoubleToString(currentPrice, 5),
                          ", Box TF=", (boxFound5Min ? "5-min" : "15-min"));
                
                // Process breakout - entry will be on 5-min
                ProcessBreakout(activeBox, InpEntryTF, isLong);
            }
        }
        
        // Also check existing tracked boxes with AGGRESSIVE breakout detection
        for(int i = 0; i < boxCount; i++)
        {
            DarvasBox box;
            if(g_BoxDetector.GetBox(i, box))
            {
                // Get current price
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double close5Min = iClose(_Symbol, InpEntryTF, 0);
                double prevClose5Min = iClose(_Symbol, InpEntryTF, 1);
                double high5Min = iHigh(_Symbol, InpEntryTF, 0);
                double low5Min = iLow(_Symbol, InpEntryTF, 0);
                
                bool isLongExisting = false; // Initialize
                bool breakout = false;
                
                // Multiple breakout conditions
                if(close5Min > box.Top && prevClose5Min <= box.Top)
                {
                    isLongExisting = true;
                    breakout = true;
                }
                else if(close5Min < box.Bottom && prevClose5Min >= box.Bottom)
                {
                    isLongExisting = false;
                    breakout = true;
                }
                else if(currentPrice > box.Top)
                {
                    isLongExisting = true;
                    breakout = true;
                }
                else if(currentPrice < box.Bottom)
                {
                    isLongExisting = false;
                    breakout = true;
                }
                else if(high5Min > box.Top && close5Min > box.Bottom)
                {
                    isLongExisting = true;
                    breakout = true;
                }
                else if(low5Min < box.Bottom && close5Min < box.Top)
                {
                    isLongExisting = false;
                    breakout = true;
                }
                
                if(breakout)
                {
                    if(InpVerboseLogging)
                        Print("BREAKOUT from tracked box: Direction=", isLongExisting ? "LONG" : "SHORT",
                              ", Box Top=", DoubleToString(box.Top, 5), 
                              ", Bottom=", DoubleToString(box.Bottom, 5),
                              ", Current Price=", DoubleToString(currentPrice, 5));
                    
                    // Process breakout on 5-min entry TF
                    ProcessBreakout(box, InpEntryTF, isLongExisting);
                }
            }
        }
        
        // FORCE TRADE MODE: If no boxes detected, try to create one manually on 5-min
        if(InpForceTradeMode && !boxFound5Min && !boxFound15Min && isNewEntryBar)
        {
            if(InpVerboseLogging)
                Print("FORCE MODE: No boxes found, attempting manual box creation on 5-min");
            
            DarvasBox forceBox;
            // Create a simple box from recent 5-min price action
            double high = iHigh(_Symbol, InpEntryTF, 0);
            double low = iLow(_Symbol, InpEntryTF, 0);
            for(int j = 1; j < 10; j++)
            {
                double h = iHigh(_Symbol, InpEntryTF, j);
                double l = iLow(_Symbol, InpEntryTF, j);
                if(h > high) high = h;
                if(l < low) low = l;
            }
            
            double currentPrice = iClose(_Symbol, InpEntryTF, 0);
            double range = high - low;
            
            if(range > 0)
            {
                forceBox.Top = high;
                forceBox.Bottom = low;
                forceBox.Height = range;
                forceBox.ConsolidationBars = 5;
                forceBox.CreationTime = TimeCurrent();
                forceBox.Timeframe = (int)InpEntryTF;
                forceBox.ATRValue = g_BoxDetector.GetATR(InpEntryTF);
                forceBox.Validated = true;
                
                // Check if price is breaking out
                bool isLong = (currentPrice > (high + low) / 2);
                
                if(currentPrice > high * 0.99 || currentPrice < low * 1.01)
                {
                    Print("FORCE MODE: Processing breakout from manual 5-min box");
                    ProcessBreakout(forceBox, InpEntryTF, isLong);
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
    //--- CRITICAL: Check if we already have an open position - ONLY ONE POSITION AT A TIME
    int totalPositions = PositionsTotal();
    bool hasOurPosition = false;
    
    // Check all positions to see if we have one open
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionSelectByTicket(ticket))
            {
                // Check if it's our symbol and our magic number
                if(PositionGetString(POSITION_SYMBOL) == _Symbol)
                {
                    if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                    {
                        hasOurPosition = true;
                        if(InpVerboseLogging)
                            Print("SKIPPING: Already have open position. Ticket=", ticket, 
                                  ", Type=", PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "LONG" : "SHORT",
                                  ", Profit=", PositionGetDouble(POSITION_PROFIT));
                        break;
                    }
                }
            }
        }
    }
    
    // Also check TradeManager's internal tracking
    if(g_TradeManager != NULL && g_TradeManager.HasOpenTrades())
    {
        hasOurPosition = true;
        if(InpVerboseLogging)
            Print("SKIPPING: TradeManager reports open trades. Count=", g_TradeManager.GetOpenTradeCount());
    }
    
    // If we have an open position, skip this opportunity
    if(hasOurPosition)
    {
        if(InpVerboseLogging)
            Print("SKIPPING BREAKOUT: Position already open. Waiting for current position to close.");
        return;
    }
    
    //--- Initialize diagnostic
    TradeDiagnostic diag = {};
    diag.BoxDetected = true;
    diag.BreakoutDetected = true;
    diag.Timestamp = TimeCurrent();
    diag.Symbol = _Symbol;
    
    //--- Update statistics
    g_BoxStats.TotalBoxes++;
    
    //--- STEP 1: Box Qualification (Surgical System)
    bool boxQualified = true;
    if(g_BoxQualifier != NULL && !InpForceTradeMode)
    {
        BoxQualificationScore score;
        boxQualified = g_BoxQualifier.QualifyBox(box, timeframe, score);
        diag.BoxQualified = boxQualified;
        diag.BoxScore = score.OverallScore;
        diag.BoxRejectionReason = score.RejectionReason;
        
        if(!boxQualified)
        {
            if(InpEnableDiagnostics && g_Diagnostics != NULL)
                g_Diagnostics.LogDiagnostic(diag);
            
            // Only allow override if score is close to threshold (within 10 points)
            if(score.OverallScore >= (InpMinBoxScore - 10.0))
            {
                if(InpRelaxedMode)
                {
                    Print("Box score below threshold but close enough (relaxed mode): ", 
                          DoubleToString(score.OverallScore, 2), " (min: ", InpMinBoxScore, ")");
                    boxQualified = true;
                }
                else if(InpForceTradeMode)
                {
                    Print("FORCE MODE: Allowing box with score: ", DoubleToString(score.OverallScore, 2));
                    boxQualified = true;
                }
                else
                {
                    if(InpVerboseLogging)
                        Print("Box rejected: ", score.RejectionReason, 
                              " (Score: ", DoubleToString(score.OverallScore, 2), 
                              " < Min: ", InpMinBoxScore, ")");
                    g_BoxStats.FailedBoxes++;
                    return;
                }
            }
            else
            {
                // Score too low - reject even in relaxed/force mode
                if(InpVerboseLogging)
                    Print("Box REJECTED (score too low): ", score.RejectionReason, 
                          " (Score: ", DoubleToString(score.OverallScore, 2), 
                          " < Min: ", InpMinBoxScore, ")");
                g_BoxStats.FailedBoxes++;
                return;
            }
        }
        if(InpVerboseLogging)
            Print("Box qualified with score: ", DoubleToString(score.OverallScore, 2));
    }
    else if(InpForceTradeMode)
    {
        Print("FORCE MODE: Skipping box qualification");
        boxQualified = true;
    }
    
    //--- Check if breakout is valid
    bool breakoutValid = true;
    if(g_BreakoutScorer != NULL && !InpForceTradeMode)
    {
        // Check for false breakout (only if not in relaxed mode)
        if(!InpRelaxedMode && !InpForceTradeMode && 
           g_BreakoutScorer.CheckFalseBreakout(box, timeframe, isLong))
        {
            diag.FalseBreakout = true;
            if(InpEnableDiagnostics && g_Diagnostics != NULL)
                g_Diagnostics.LogDiagnostic(diag);
            if(!InpForceTradeMode)
            {
                g_BoxStats.FailedBoxes++;
                g_BoxStats.FalseBreakouts++;
                return;
            }
        }
        
        // Check if breakout score is sufficient
        breakoutValid = g_BreakoutScorer.IsBreakoutValid(box, timeframe, isLong);
        diag.BreakoutValid = breakoutValid;
        if(g_BreakoutScorer != NULL)
        {
            diag.BreakoutScore = g_BreakoutScorer.CalculateBreakoutScore(box, timeframe, isLong);
        }
        
        if(!breakoutValid && !InpRelaxedMode && !InpForceTradeMode)
        {
            if(InpEnableDiagnostics && g_Diagnostics != NULL)
                g_Diagnostics.LogDiagnostic(diag);
            g_BoxStats.FailedBoxes++;
            return;
        }
    }
    else if(InpForceTradeMode)
    {
        Print("FORCE MODE: Skipping breakout validation");
        breakoutValid = true;
    }
    
    //--- Check market structure alignment (optional in relaxed mode)
    bool trendAligned = true;
    if(g_MarketStructure != NULL && InpTrendFilter && !InpForceTradeMode)
    {
        trendAligned = g_MarketStructure.IsWithTrend(isLong, timeframe);
        diag.TrendAligned = trendAligned;
        
        if(!trendAligned)
        {
            if(InpRelaxedMode || InpForceTradeMode)
            {
                Print("Breakout not aligned with trend but allowing in relaxed/force mode");
            }
            else
            {
                if(InpEnableDiagnostics && g_Diagnostics != NULL)
                    g_Diagnostics.LogDiagnostic(diag);
                if(InpVerboseLogging)
                    Print("Breakout not aligned with trend - skipping");
                return;
            }
        }
    }
    else if(InpForceTradeMode)
    {
        Print("FORCE MODE: Skipping trend filter");
        trendAligned = true;
    }
    
    //--- SIMPLIFIED ENTRY - Always create entry when breakout detected
    EntryTrigger trigger;
    bool entryFound = false;
    
    // Get current market price
    double currentPrice = SymbolInfoDouble(_Symbol, isLong ? SYMBOL_ASK : SYMBOL_BID);
    double entryPrice = currentPrice;
    
    // Calculate stop loss (IMPROVED - wider stops for better win rate)
    // Use box boundary + buffer for safety
    double boxHeight = box.Height;
    double atrValue = box.ATRValue > 0 ? box.ATRValue : (boxHeight * 0.5);
    
    // Stop loss: Below box bottom for long, above box top for short
    // Use 1.5x ATR or 30% of box height (whichever is larger) as buffer
    double stopBuffer = MathMax(atrValue * 1.5, boxHeight * 0.3);
    double stopLoss = 0.0; // Initialize stop loss
    
    if(isLong)
    {
        stopLoss = box.Bottom - stopBuffer;
        // Ensure stop is at least 2x ATR from entry
        double minStopDistance = atrValue * 2.0;
        if((entryPrice - stopLoss) < minStopDistance)
            stopLoss = entryPrice - minStopDistance;
    }
    else
    {
        stopLoss = box.Top + stopBuffer;
        // Ensure stop is at least 2x ATR from entry
        double minStopDistance = atrValue * 2.0;
        if((stopLoss - entryPrice) < minStopDistance)
            stopLoss = entryPrice + minStopDistance;
    }
    
    // Final validation
    if(stopLoss <= 0 || (isLong && stopLoss >= entryPrice) || (!isLong && stopLoss <= entryPrice))
    {
        // Emergency fallback - use 2x box height
        stopLoss = isLong ? (box.Bottom - boxHeight * 2.0) : (box.Top + boxHeight * 2.0);
    }
    
    // Log stop loss calculation
    if(InpVerboseLogging)
        Print("STOP LOSS CALCULATION: Box Height=", DoubleToString(boxHeight, 5),
              ", ATR=", DoubleToString(atrValue, 5),
              ", Stop Buffer=", DoubleToString(stopBuffer, 5),
              ", Final Stop=", DoubleToString(stopLoss, 5),
              ", Stop Distance=", DoubleToString(MathAbs(entryPrice - stopLoss), 5));
    
    // Create DIRECT entry trigger (simplified - always works)
    trigger.Type = ENTRY_PRIMARY;
    trigger.EntryPrice = entryPrice;
    trigger.StopLoss = stopLoss;
    trigger.PositionSize = 0.01; // Will be recalculated by position manager
    trigger.QualityScore = 70; // Default score
    trigger.IsValid = true;
    trigger.Timing = TIMING_B;
    entryFound = true;
    
    if(InpVerboseLogging)
        Print("DIRECT ENTRY CREATED: Price=", DoubleToString(entryPrice, 5),
              ", StopLoss=", DoubleToString(stopLoss, 5),
              ", Direction=", isLong ? "LONG" : "SHORT",
              ", Box Top=", DoubleToString(box.Top, 5),
              ", Box Bottom=", DoubleToString(box.Bottom, 5));
    
    // Try Precision Entry (optional enhancement, but don't require it)
    if(g_PrecisionEntry != NULL && !InpForceTradeMode)
    {
        EntryTrigger precisionTrigger;
        if(g_PrecisionEntry.CheckPrimaryEntry(box, timeframe, isLong, precisionTrigger))
        {
            trigger = precisionTrigger;
            if(InpVerboseLogging)
                Print("PRECISION ENTRY found: Primary - using enhanced entry");
        }
        else if(g_PrecisionEntry.CheckSecondaryEntry(box, timeframe, isLong, precisionTrigger))
        {
            trigger = precisionTrigger;
            if(InpVerboseLogging)
                Print("PRECISION ENTRY found: Secondary - using enhanced entry");
        }
        else if(g_PrecisionEntry.CheckTertiaryEntry(box, timeframe, isLong, precisionTrigger))
        {
            trigger = precisionTrigger;
            if(InpVerboseLogging)
                Print("PRECISION ENTRY found: Tertiary - using enhanced entry");
        }
        else
        {
            if(InpVerboseLogging)
                Print("Precision Entry not found - using direct entry");
        }
    }
    
    // Try standard entry manager (optional enhancement)
    if(g_EntryManager != NULL && !InpForceTradeMode)
    {
        TradeEntry entry;
        if(g_EntryManager.ProcessBreakout(box, timeframe, isLong, entry))
        {
            // Use enhanced entry if available
            trigger.Type = (ENUM_ENTRY_TYPE)entry.Tier;
            if(entry.EntryPrice > 0) trigger.EntryPrice = entry.EntryPrice;
            if(entry.StopLoss > 0) trigger.StopLoss = entry.StopLoss;
            if(entry.PositionSize > 0) trigger.PositionSize = entry.PositionSize;
            trigger.QualityScore = entry.BreakoutScore;
            if(InpVerboseLogging)
                Print("STANDARD ENTRY found: Tier=", entry.Tier, " - using enhanced entry");
        }
        else
        {
            if(InpVerboseLogging)
                Print("Standard Entry not found - using direct entry");
        }
    }
    
    // Execute entry if found
    if(entryFound && trigger.IsValid)
    {
        // Check correlation limits (optional in relaxed mode)
        bool correlationOK = true;
        if(g_CorrelationManager != NULL && InpUseCorrelationFilter)
        {
            correlationOK = g_CorrelationManager.CanOpenTrade(_Symbol, isLong, trigger.PositionSize);
            diag.CorrelationOK = correlationOK;
            
            if(!correlationOK)
            {
                if(InpRelaxedMode)
                {
                    Print("Correlation limit exceeded but allowing in relaxed mode");
                    // Reduce position size instead
                    trigger.PositionSize *= 0.5;
                }
                else
                {
                    if(InpEnableDiagnostics && g_Diagnostics != NULL)
                        g_Diagnostics.LogDiagnostic(diag);
                    Print("Trade rejected: Correlation limit exceeded");
                    return;
                }
            }
        }
        
        // Check circuit breaker, risk manager, and news filter status
        bool circuitBreakerOK = true;
        bool riskManagerOK = true;
        bool newsFilterOK = true;
        
        // Detailed logging for each filter check
        Print("=== FILTER CHECKS ===");
        
        if(g_CircuitBreakers != NULL && !InpForceTradeMode)
        {
            circuitBreakerOK = g_CircuitBreakers.CanTrade();
            if(!circuitBreakerOK)
            {
                Print("❌ Circuit Breaker: BLOCKING");
                if(InpForceTradeMode)
                {
                    Print("FORCE MODE: Overriding circuit breaker");
                    circuitBreakerOK = true;
                }
                else
                {
                    return;
                }
            }
            else
            {
                Print("✓ Circuit Breaker: PASSED");
            }
        }
        else
        {
            Print("✓ Circuit Breaker: SKIPPED (Force Mode or not enabled)");
        }
        
        if(g_RiskManager != NULL)
        {
            riskManagerOK = g_RiskManager.CanOpenNewTrade();
            if(!riskManagerOK)
            {
                Print("❌ Risk Manager: BLOCKING");
                if(InpForceTradeMode)
                {
                    Print("FORCE MODE: Overriding risk manager");
                    riskManagerOK = true;
                }
                else
                {
                    return;
                }
            }
            else
            {
                Print("✓ Risk Manager: PASSED");
            }
        }
        else
        {
            Print("✓ Risk Manager: SKIPPED (not enabled)");
        }
        
        if(g_NewsFilter != NULL && InpAvoidNews && !InpForceTradeMode)
        {
            newsFilterOK = g_NewsFilter.CanTrade();
            if(!newsFilterOK)
            {
                Print("❌ News Filter: BLOCKING");
                if(InpForceTradeMode)
                {
                    Print("FORCE MODE: Overriding news filter");
                    newsFilterOK = true;
                }
                else
                {
                    return;
                }
            }
            else
            {
                Print("✓ News Filter: PASSED");
            }
        }
        else
        {
            Print("✓ News Filter: SKIPPED (Force Mode or disabled)");
        }
        
        // Log successful entry diagnostic
        if(InpEnableDiagnostics && g_Diagnostics != NULL)
        {
            diag.EntryTriggerFound = true;
            diag.EntryType = EnumToString(trigger.Type);
            diag.CircuitBreakerOK = circuitBreakerOK;
            diag.RiskManagerOK = riskManagerOK;
            diag.NewsFilterOK = newsFilterOK;
            diag.CorrelationOK = correlationOK;
            g_Diagnostics.LogDiagnostic(diag);
        }
        
        // Adjust position size based on correlation
        if(g_CorrelationManager != NULL && InpUseCorrelationFilter)
        {
            trigger.PositionSize = g_CorrelationManager.GetAdjustedPositionSize(
                _Symbol, isLong, trigger.PositionSize);
        }
        
        // Calculate optimal position size (surgical system)
        if(g_PositionManager != NULL)
        {
            double boxScore = g_BoxQualifier != NULL ? 
                             g_BoxQualifier.CalculateBoxScore(box, timeframe) : 80.0;
            double volMultiplier = g_VolatilityRegime != NULL ? 
                                  g_VolatilityRegime.GetPositionMultiplier() : 1.0;
            double timingMultiplier = g_PrecisionEntry != NULL ? 
                                     g_PrecisionEntry.GetTimingMultiplier(trigger.Timing) : 1.0;
            double streakMultiplier = 1.0; // Would get from risk manager
            
            // Use the stop loss already calculated (improved version)
            double stopLoss = trigger.StopLoss;
            
            double calculatedSize = g_PositionManager.CalculateOptimalPosition(
                box, trigger.EntryPrice, stopLoss, boxScore,
                volMultiplier, timingMultiplier, streakMultiplier);
            
            // SAFETY: Cap position size to prevent oversized trades
            double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            double maxRiskAmount = accountEquity * (InpSurgicalBaseRisk / 100.0);
            double stopDistance = MathAbs(trigger.EntryPrice - stopLoss);
            double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            
            if(stopDistance > 0 && tickValue > 0 && tickSize > 0)
            {
                double maxLots = (maxRiskAmount / stopDistance) * (tickSize / tickValue);
                double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
                maxLots = MathMax(minLot, MathMin(maxLot, maxLots));
                
                // Use the smaller of calculated or max safe size
                trigger.PositionSize = MathMin(calculatedSize, maxLots);
                
                if(InpVerboseLogging)
                    Print("Position size: Calculated=", DoubleToString(calculatedSize, 2),
                          ", Max Safe=", DoubleToString(maxLots, 2),
                          ", Final=", DoubleToString(trigger.PositionSize, 2),
                          ", Risk Amount=$", DoubleToString(maxRiskAmount, 2));
            }
            else
            {
                trigger.PositionSize = calculatedSize;
            }
        }
        
        // Open trade
        if(g_TradeManager != NULL)
        {
            TradeEntry entry;
            entry.EntryPrice = trigger.EntryPrice;
            entry.StopLoss = isLong ? (box.Bottom - box.ATRValue) : 
                            (box.Top + box.ATRValue);
            entry.TakeProfit = 0; // Will be set by exit system
            entry.PositionSize = trigger.PositionSize;
            entry.BreakoutScore = trigger.QualityScore;
            entry.EntryTime = TimeCurrent();
            entry.IsLong = isLong;
            entry.BoxId = box.CreationTime;
            entry.OrderType = ORDER_TYPE_BUY; // Will be set based on isLong
            entry.Tier = (int)trigger.Type;
            
            Print("=== ATTEMPTING TO OPEN TRADE ===");
            Print("Entry Price: ", DoubleToString(entry.EntryPrice, 5));
            Print("Stop Loss: ", DoubleToString(entry.StopLoss, 5));
            Print("Position Size: ", DoubleToString(entry.PositionSize, 2), " lots");
            Print("Direction: ", entry.IsLong ? "LONG" : "SHORT");
            
            if(g_TradeManager.OpenTrade(entry, box))
            {
                Print("✅✅✅ TRADE OPENED SUCCESSFULLY! ✅✅✅");
                g_BoxStats.SuccessfulBoxes++;
                
                // Setup surgical exit tiers
                if(g_SurgicalExit != NULL && InpUseSurgicalExits)
                {
                    ulong ticket = 0;
                    if(PositionSelect(_Symbol))
                        ticket = PositionGetInteger(POSITION_TICKET);
                    
                    if(ticket > 0)
                    {
                        g_SurgicalExit.SetupExitTiers(ticket, box, 
                                                      trigger.EntryPrice, isLong);
                    }
                }
                
                // Update correlation exposure
                if(g_CorrelationManager != NULL)
                {
                    g_CorrelationManager.UpdateExposure(_Symbol, isLong, 
                                                       trigger.PositionSize);
                }
                
                // Update average breakout score
                if(g_BoxStats.TotalBoxes > 0)
                {
                    g_BoxStats.AvgBreakoutScore = 
                        (g_BoxStats.AvgBreakoutScore * (g_BoxStats.TotalBoxes - 1) + 
                         trigger.QualityScore) / g_BoxStats.TotalBoxes;
                }
                
                Print("Surgical Trade opened: Type ", EnumToString(trigger.Type),
                      ", Score: ", trigger.QualityScore,
                      ", Size: ", trigger.PositionSize,
                      ", Timing: ", EnumToString(trigger.Timing));
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
            
            // Update Kelly Criterion
            if(g_KellyCriterion != NULL)
            {
                g_KellyCriterion.UpdateTradeResult(profit);
            }
            
            // Update Circuit Breakers
            if(g_CircuitBreakers != NULL)
            {
                g_CircuitBreakers.UpdateTradeResult(isWin, profit);
            }
            
            // Update correlation exposure (remove closed trade)
            if(g_CorrelationManager != NULL)
            {
                g_CorrelationManager.RemoveExposure(_Symbol, ticket);
            }
            
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