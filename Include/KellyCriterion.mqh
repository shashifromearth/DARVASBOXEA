//+------------------------------------------------------------------+
//|                                        KellyCriterion.mqh        |
//|                    Dynamic Position Sizing Based on Kelly       |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Kelly Criterion Calculator                                      |
//+------------------------------------------------------------------+
class CKellyCriterion
{
private:
    int               m_LookbackPeriod;    // Number of trades to analyze
    double            m_WinRate;           // Current win rate
    double            m_AvgWin;            // Average win size
    double            m_AvgLoss;           // Average loss size
    double            m_ConfidenceFactor;  // Confidence multiplier
    
    // Trade history
    double            m_TradeResults[];   // Profit/loss results
    int               m_TradeCount;        // Number of trades
    
public:
    CKellyCriterion();
    ~CKellyCriterion();
    
    bool              Initialize(int lookbackPeriod = 50);
    double            CalculateKellyFraction(double setupScore = 70.0,
                                            double regimeAlignment = 1.0,
                                            double streakMultiplier = 1.0);
    void              UpdateTradeResult(double profit);
    void              RecalculateStats();
    
    double            GetWinRate() { return m_WinRate; }
    double            GetAvgWin() { return m_AvgWin; }
    double            GetAvgLoss() { return m_AvgLoss; }
    double            GetKellyFraction() { return CalculateKellyFraction(); }
    
private:
    double            CalculateBaseKelly();
    double            CalculateConfidenceFactor(double setupScore,
                                               double regimeAlignment,
                                               double streakMultiplier);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKellyCriterion::CKellyCriterion()
{
    m_LookbackPeriod = 50;
    m_WinRate = 0.5;
    m_AvgWin = 0;
    m_AvgLoss = 0;
    m_ConfidenceFactor = 1.0;
    m_TradeCount = 0;
    ArrayResize(m_TradeResults, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CKellyCriterion::~CKellyCriterion()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CKellyCriterion::Initialize(int lookbackPeriod = 50)
{
    m_LookbackPeriod = lookbackPeriod;
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Kelly fraction                                         |
//+------------------------------------------------------------------+
double CKellyCriterion::CalculateKellyFraction(double setupScore = 70.0,
                                                double regimeAlignment = 1.0,
                                                double streakMultiplier = 1.0)
{
    RecalculateStats();
    
    // Base Kelly: f* = (bp - q) / b
    // where: b = win/loss ratio, p = win rate, q = loss rate (1-p)
    double baseKelly = CalculateBaseKelly();
    
    // Apply confidence factor
    double confidence = CalculateConfidenceFactor(setupScore, regimeAlignment, streakMultiplier);
    
    // Final Kelly fraction
    double kellyFraction = baseKelly * confidence;
    
    // Cap at reasonable levels (0.01 to 0.15 = 1% to 15% risk)
    if(kellyFraction < 0.01) kellyFraction = 0.01;
    if(kellyFraction > 0.15) kellyFraction = 0.15;
    
    return kellyFraction;
}

//+------------------------------------------------------------------+
//| Update trade result                                              |
//+------------------------------------------------------------------+
void CKellyCriterion::UpdateTradeResult(double profit)
{
    ArrayResize(m_TradeResults, m_TradeCount + 1);
    m_TradeResults[m_TradeCount] = profit;
    m_TradeCount++;
    
    // Keep only last N trades
    if(m_TradeCount > m_LookbackPeriod)
    {
        // Shift array
        for(int i = 0; i < m_LookbackPeriod; i++)
            m_TradeResults[i] = m_TradeResults[m_TradeCount - m_LookbackPeriod + i];
        m_TradeCount = m_LookbackPeriod;
        ArrayResize(m_TradeResults, m_LookbackPeriod);
    }
    
    RecalculateStats();
}

//+------------------------------------------------------------------+
//| Recalculate statistics                                           |
//+------------------------------------------------------------------+
void CKellyCriterion::RecalculateStats()
{
    if(m_TradeCount == 0)
    {
        m_WinRate = 0.5;
        m_AvgWin = 0;
        m_AvgLoss = 0;
        return;
    }
    
    int wins = 0;
    int losses = 0;
    double totalWin = 0;
    double totalLoss = 0;
    
    for(int i = 0; i < m_TradeCount; i++)
    {
        if(m_TradeResults[i] > 0)
        {
            wins++;
            totalWin += m_TradeResults[i];
        }
        else if(m_TradeResults[i] < 0)
        {
            losses++;
            totalLoss += MathAbs(m_TradeResults[i]);
        }
    }
    
    m_WinRate = (double)wins / m_TradeCount;
    
    if(wins > 0)
        m_AvgWin = totalWin / wins;
    else
        m_AvgWin = 0;
    
    if(losses > 0)
        m_AvgLoss = totalLoss / losses;
    else
        m_AvgLoss = 0;
}

//+------------------------------------------------------------------+
//| Calculate base Kelly                                              |
//+------------------------------------------------------------------+
double CKellyCriterion::CalculateBaseKelly()
{
    if(m_AvgLoss == 0) return 0.01; // Default 1% if no loss data
    
    // Kelly formula: f* = (bp - q) / b
    // where: b = avgWin/avgLoss, p = winRate, q = 1 - winRate
    double b = m_AvgWin / m_AvgLoss;
    double p = m_WinRate;
    double q = 1.0 - m_WinRate;
    
    double kelly = (b * p - q) / b;
    
    // If negative, return minimum
    if(kelly < 0) return 0.01;
    
    return kelly;
}

//+------------------------------------------------------------------+
//| Calculate confidence factor                                       |
//+------------------------------------------------------------------+
double CKellyCriterion::CalculateConfidenceFactor(double setupScore,
                                                  double regimeAlignment,
                                                  double streakMultiplier)
{
    // Setup score factor (0-100 -> 0.5 to 1.5)
    double scoreFactor = 0.5 + (setupScore / 100.0);
    
    // Regime alignment factor (0.5 to 1.5)
    double regimeFactor = regimeAlignment;
    
    // Streak multiplier (0.8 to 1.5)
    double streakFactor = streakMultiplier;
    
    // Combined confidence
    double confidence = (scoreFactor * 0.4 + regimeFactor * 0.3 + streakFactor * 0.3);
    
    // Cap between 0.5 and 2.0
    if(confidence < 0.5) confidence = 0.5;
    if(confidence > 2.0) confidence = 2.0;
    
    return confidence;
}

//+------------------------------------------------------------------+
