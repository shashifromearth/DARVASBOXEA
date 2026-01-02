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
input bool     InpRequireRetest     = true;     // Wait for retest before entry
input double   InpMinBoxScore        = 75.0;     // Minimum box quality score (0-100)
input int      InpMinConsolidationBars = 5;      // Minimum bars in box
input double   InpMinVolumeSurge     = 1.8;      // Minimum volume surge (180%)

input group "=== SURGICAL EXIT SYSTEM ==="
input bool     InpUseSurgicalExits  = true;     // Use 5-tier surgical exit
input double   InpSurgicalTier1Multiplier = 0.75; // Tier 1: 0.75× box height
input double   InpSurgicalTier2Multiplier = 1.5; // Tier 2: 1.5× box height
input double   InpSurgicalTier3TrailStart = 1.0; // Tier 3: Trail start (ATR multiplier)
input int      InpMaxHoldDays        = 7;       // Maximum hold days

input group "=== POSITION MANAGEMENT ==="
input double   InpSurgicalBaseRisk   = 1.0;      // Base risk per trade (%)
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
    
    // Initialize Box Detector
    bool boxDetInit = g_BoxDetector.Initialize(InpOperationalTF, InpTrendTF, InpConfirmationTF,
                                  InpMinBarsInBox, InpBoxSensitivity,
                                  InpUseVolumeFilter, InpUseMultiTFBoxes);
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
    bool riskInit = g_RiskManager.Initialize(InpBaseRiskPercent, InpMaxDailyRisk,
                                 InpMaxTradesPerDay, InpUseAdaptiveSizing);
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
    {
        g_TradeManager.ManageOpenTrades();
    }
    
    //--- Check circuit breakers first (safety first!)
    if(g_CircuitBreakers != NULL)
    {
        if(!g_CircuitBreakers.CanTrade())
            return;
    }
    
    //--- Check if can open new trades
    if(g_RiskManager != NULL)
    {
        if(!g_RiskManager.CanOpenNewTrade())
            return;
    }
    
    //--- Check news filter
    if(g_NewsFilter != NULL)
    {
        if(!g_NewsFilter.CanTrade())
            return;
    }
    
    //--- Update volatility regime
    if(g_VolatilityRegime != NULL)
    {
        g_VolatilityRegime.GetCurrentRegime(InpOperationalTF);
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
        g_MarketRegimeDetector.GetCurrentRegime(InpOperationalTF);
    }
    
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
    
    //--- STEP 1: Box Qualification (Surgical System)
    if(g_BoxQualifier != NULL)
    {
        BoxQualificationScore score;
        if(!g_BoxQualifier.QualifyBox(box, timeframe, score))
        {
            Print("Box rejected: ", score.RejectionReason, 
                  " (Score: ", DoubleToString(score.OverallScore, 2), ")");
            g_BoxStats.FailedBoxes++;
            return;
        }
        Print("Box qualified with score: ", DoubleToString(score.OverallScore, 2));
    }
    
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
    
    //--- Process entry (Surgical System with hierarchical priority)
    EntryTrigger trigger;
    bool entryFound = false;
    
    // Try Primary Entry first (clean breakout with retest)
    if(g_PrecisionEntry != NULL)
    {
        if(g_PrecisionEntry.CheckPrimaryEntry(box, timeframe, isLong, trigger))
        {
            entryFound = true;
        }
        // Try Secondary Entry (volume spike)
        else if(g_PrecisionEntry.CheckSecondaryEntry(box, timeframe, isLong, trigger))
        {
            entryFound = true;
        }
        // Try Tertiary Entry (failed breakout reversal)
        else if(g_PrecisionEntry.CheckTertiaryEntry(box, timeframe, isLong, trigger))
        {
            entryFound = true;
        }
    }
    
    // Fallback to standard entry manager
    if(!entryFound && g_EntryManager != NULL)
    {
        TradeEntry entry;
        if(g_EntryManager.ProcessBreakout(box, timeframe, isLong, entry))
        {
            // Convert to trigger format
            trigger.Type = (ENUM_ENTRY_TYPE)entry.Tier;
            trigger.EntryPrice = entry.EntryPrice;
            trigger.PositionSize = entry.PositionSize;
            trigger.QualityScore = entry.BreakoutScore;
            trigger.IsValid = true;
            trigger.Timing = TIMING_B; // Default timing
            entryFound = true;
        }
    }
    
    // Execute entry if found
    if(entryFound && trigger.IsValid)
    {
        // Check correlation limits
        if(g_CorrelationManager != NULL)
        {
            if(!g_CorrelationManager.CanOpenTrade(_Symbol, isLong, trigger.PositionSize))
            {
                Print("Trade rejected: Correlation limit exceeded");
                return;
            }
            
            // Adjust position size based on correlation
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
            
            // Calculate stop loss
            double stopLoss = isLong ? (box.Bottom - box.ATRValue) : 
                             (box.Top + box.ATRValue);
            
            trigger.PositionSize = g_PositionManager.CalculateOptimalPosition(
                box, trigger.EntryPrice, stopLoss, boxScore,
                volMultiplier, timingMultiplier, streakMultiplier);
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
            
            if(g_TradeManager.OpenTrade(entry, box))
            {
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