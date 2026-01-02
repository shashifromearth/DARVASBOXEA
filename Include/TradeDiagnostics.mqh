//+------------------------------------------------------------------+
//|                                          TradeDiagnostics.mqh     |
//|                    Diagnostic System for Trade Blocking            |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Trade Diagnostic Structure                                        |
//+------------------------------------------------------------------+
struct TradeDiagnostic
{
    bool              BoxDetected;           // Was box detected?
    bool              BoxQualified;          // Did box pass qualification?
    double            BoxScore;              // Box qualification score
    string            BoxRejectionReason;    // Why box was rejected
    
    bool              BreakoutDetected;      // Was breakout detected?
    bool              BreakoutValid;         // Did breakout pass validation?
    int               BreakoutScore;         // Breakout quality score
    bool              FalseBreakout;         // Was it a false breakout?
    
    bool              TrendAligned;          // Is aligned with trend?
    bool              EntryTriggerFound;      // Was entry trigger found?
    string            EntryType;            // Type of entry (Primary/Secondary/Tertiary)
    string            EntryRejectionReason; // Why entry was rejected
    
    bool              CircuitBreakerOK;     // Circuit breaker check
    bool              RiskManagerOK;         // Risk manager check
    bool              NewsFilterOK;          // News filter check
    bool              CorrelationOK;          // Correlation check
    
    datetime          Timestamp;             // When diagnostic was run
    string            Symbol;               // Symbol being analyzed
};

//+------------------------------------------------------------------+
//| Trade Diagnostics Manager                                        |
//+------------------------------------------------------------------+
class CTradeDiagnostics
{
private:
    TradeDiagnostic   m_Diagnostics[];
    int               m_DiagnosticCount;
    bool              m_LogToFile;
    string            m_LogFileName;
    
public:
    CTradeDiagnostics();
    ~CTradeDiagnostics();
    
    void              LogDiagnostic(const TradeDiagnostic &diag);
    void              PrintDiagnostic(const TradeDiagnostic &diag);
    void              Reset();
    int               GetDiagnosticCount() { return m_DiagnosticCount; }
    void              PrintSummary();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeDiagnostics::CTradeDiagnostics()
{
    m_DiagnosticCount = 0;
    m_LogToFile = false;
    m_LogFileName = "DarvasBoxEA_Diagnostics.csv";
    ArrayResize(m_Diagnostics, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeDiagnostics::~CTradeDiagnostics()
{
}

//+------------------------------------------------------------------+
//| Log diagnostic                                                   |
//+------------------------------------------------------------------+
void CTradeDiagnostics::LogDiagnostic(const TradeDiagnostic &diag)
{
    ArrayResize(m_Diagnostics, m_DiagnosticCount + 1);
    m_Diagnostics[m_DiagnosticCount] = diag;
    m_DiagnosticCount++;
    
    PrintDiagnostic(diag);
}

//+------------------------------------------------------------------+
//| Print diagnostic                                                 |
//+------------------------------------------------------------------+
void CTradeDiagnostics::PrintDiagnostic(const TradeDiagnostic &diag)
{
    Print("=== TRADE DIAGNOSTIC ===");
    Print("Symbol: ", diag.Symbol);
    Print("Time: ", TimeToString(diag.Timestamp));
    Print("--- Box Detection ---");
    Print("  Box Detected: ", diag.BoxDetected ? "YES" : "NO");
    Print("  Box Qualified: ", diag.BoxQualified ? "YES" : "NO");
    Print("  Box Score: ", DoubleToString(diag.BoxScore, 2));
    if(!diag.BoxQualified)
        Print("  Rejection Reason: ", diag.BoxRejectionReason);
    
    Print("--- Breakout Analysis ---");
    Print("  Breakout Detected: ", diag.BreakoutDetected ? "YES" : "NO");
    Print("  Breakout Valid: ", diag.BreakoutValid ? "YES" : "NO");
    Print("  Breakout Score: ", diag.BreakoutScore);
    Print("  False Breakout: ", diag.FalseBreakout ? "YES" : "NO");
    
    Print("--- Entry Conditions ---");
    Print("  Trend Aligned: ", diag.TrendAligned ? "YES" : "NO");
    Print("  Entry Trigger Found: ", diag.EntryTriggerFound ? "YES" : "NO");
    if(diag.EntryTriggerFound)
        Print("  Entry Type: ", diag.EntryType);
    else
        Print("  Entry Rejection: ", diag.EntryRejectionReason);
    
    Print("--- Filter Checks ---");
    Print("  Circuit Breaker: ", diag.CircuitBreakerOK ? "PASS" : "BLOCK");
    Print("  Risk Manager: ", diag.RiskManagerOK ? "PASS" : "BLOCK");
    Print("  News Filter: ", diag.NewsFilterOK ? "PASS" : "BLOCK");
    Print("  Correlation: ", diag.CorrelationOK ? "PASS" : "BLOCK");
    Print("========================");
}

//+------------------------------------------------------------------+
//| Print summary                                                    |
//+------------------------------------------------------------------+
void CTradeDiagnostics::PrintSummary()
{
    if(m_DiagnosticCount == 0)
    {
        Print("No diagnostics recorded yet.");
        return;
    }
    
    int boxDetected = 0;
    int boxQualified = 0;
    int breakoutDetected = 0;
    int breakoutValid = 0;
    int trendAligned = 0;
    int entryFound = 0;
    int circuitBreakerBlocked = 0;
    int riskManagerBlocked = 0;
    int newsFilterBlocked = 0;
    int correlationBlocked = 0;
    
    for(int i = 0; i < m_DiagnosticCount; i++)
    {
        if(m_Diagnostics[i].BoxDetected) boxDetected++;
        if(m_Diagnostics[i].BoxQualified) boxQualified++;
        if(m_Diagnostics[i].BreakoutDetected) breakoutDetected++;
        if(m_Diagnostics[i].BreakoutValid) breakoutValid++;
        if(m_Diagnostics[i].TrendAligned) trendAligned++;
        if(m_Diagnostics[i].EntryTriggerFound) entryFound++;
        if(!m_Diagnostics[i].CircuitBreakerOK) circuitBreakerBlocked++;
        if(!m_Diagnostics[i].RiskManagerOK) riskManagerBlocked++;
        if(!m_Diagnostics[i].NewsFilterOK) newsFilterBlocked++;
        if(!m_Diagnostics[i].CorrelationOK) correlationBlocked++;
    }
    
    Print("=== DIAGNOSTIC SUMMARY ===");
    Print("Total Diagnostics: ", m_DiagnosticCount);
    Print("Boxes Detected: ", boxDetected, " (", 
          DoubleToString((double)boxDetected/m_DiagnosticCount*100, 1), "%)");
    Print("Boxes Qualified: ", boxQualified, " (", 
          DoubleToString((double)boxQualified/m_DiagnosticCount*100, 1), "%)");
    Print("Breakouts Detected: ", breakoutDetected, " (", 
          DoubleToString((double)breakoutDetected/m_DiagnosticCount*100, 1), "%)");
    Print("Breakouts Valid: ", breakoutValid, " (", 
          DoubleToString((double)breakoutValid/m_DiagnosticCount*100, 1), "%)");
    Print("Trend Aligned: ", trendAligned, " (", 
          DoubleToString((double)trendAligned/m_DiagnosticCount*100, 1), "%)");
    Print("Entry Triggers Found: ", entryFound, " (", 
          DoubleToString((double)entryFound/m_DiagnosticCount*100, 1), "%)");
    Print("--- Blocking Filters ---");
    Print("  Circuit Breaker: ", circuitBreakerBlocked, " blocks");
    Print("  Risk Manager: ", riskManagerBlocked, " blocks");
    Print("  News Filter: ", newsFilterBlocked, " blocks");
    Print("  Correlation: ", correlationBlocked, " blocks");
    Print("========================");
}

//+------------------------------------------------------------------+
//| Reset                                                            |
//+------------------------------------------------------------------+
void CTradeDiagnostics::Reset()
{
    ArrayResize(m_Diagnostics, 0);
    m_DiagnosticCount = 0;
}

