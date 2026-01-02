//+------------------------------------------------------------------+
//|                                      CorrelationManager.mqh       |
//|                    Correlation-Aware Position Management         |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Currency Exposure Structure                                      |
//+------------------------------------------------------------------+
struct CurrencyExposure
{
    string            Currency;            // Currency code (EUR, USD, etc.)
    double            LongExposure;        // Long exposure in lots
    double            ShortExposure;       // Short exposure in lots
    double            NetExposure;         // Net exposure
    double            RiskPercent;         // Risk as % of equity
};

//+------------------------------------------------------------------+
//| Correlation Manager                                              |
//+------------------------------------------------------------------+
class CCorrelationManager
{
private:
    double            m_MaxRiskPerCurrency; // Max 3% risk per currency
    double            m_MaxRiskPerDirection; // Max 8% risk per direction
    bool              m_AutoHedge;          // Auto hedge if overexposed
    
    CurrencyExposure  m_Exposures[];        // Currency exposures
    int               m_ExposureCount;      // Number of currencies
    
    // Correlation matrix (simplified)
    double            m_CorrelationMatrix[10][10];
    
public:
    CCorrelationManager();
    ~CCorrelationManager();
    
    bool              Initialize(double maxRiskPerCurrency = 3.0,
                                double maxRiskPerDirection = 8.0,
                                bool autoHedge = false);
    
    bool              CanOpenTrade(string symbol, bool isLong, double positionSize);
    void              UpdateExposure(string symbol, bool isLong, double positionSize);
    void              RemoveExposure(string symbol, ulong ticket);
    double            GetAdjustedPositionSize(string symbol, bool isLong, double baseSize);
    bool              CheckOverexposure();
    void              AutoHedge();
    
private:
    string            ExtractBaseCurrency(string symbol);
    string            ExtractQuoteCurrency(string symbol);
    bool              FindCurrency(string currency, int &index);
    void              CalculateNetExposures();
    double            GetCorrelation(string symbol1, string symbol2);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCorrelationManager::CCorrelationManager()
{
    m_MaxRiskPerCurrency = 3.0;
    m_MaxRiskPerDirection = 8.0;
    m_AutoHedge = false;
    m_ExposureCount = 0;
    ArrayResize(m_Exposures, 0);
    
    // Initialize correlation matrix (would be populated from historical data)
    for(int i = 0; i < 10; i++)
        for(int j = 0; j < 10; j++)
            m_CorrelationMatrix[i][j] = (i == j) ? 1.0 : 0.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCorrelationManager::~CCorrelationManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CCorrelationManager::Initialize(double maxRiskPerCurrency,
                                    double maxRiskPerDirection,
                                    bool autoHedge)
{
    m_MaxRiskPerCurrency = maxRiskPerCurrency;
    m_MaxRiskPerDirection = maxRiskPerDirection;
    m_AutoHedge = autoHedge;
    return true;
}

//+------------------------------------------------------------------+
//| Check if can open trade                                         |
//+------------------------------------------------------------------+
bool CCorrelationManager::CanOpenTrade(string symbol, bool isLong, double positionSize)
{
    // Extract currencies
    string baseCurrency = ExtractBaseCurrency(symbol);
    string quoteCurrency = ExtractQuoteCurrency(symbol);
    
    // Calculate risk
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double entryPrice = SymbolInfoDouble(symbol, isLong ? SYMBOL_ASK : SYMBOL_BID);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Estimate risk (simplified - would use actual stop distance)
    double estimatedRisk = positionSize * entryPrice * 0.01; // 1% estimate
    double riskPercent = (estimatedRisk / accountEquity) * 100.0;
    
    // Check currency exposure
    int baseIndex, quoteIndex;
    bool hasBase = FindCurrency(baseCurrency, baseIndex);
    bool hasQuote = FindCurrency(quoteCurrency, quoteIndex);
    
    if(hasBase)
    {
        double currentRisk = m_Exposures[baseIndex].RiskPercent;
        if(isLong)
            currentRisk += m_Exposures[baseIndex].LongExposure * riskPercent;
        else
            currentRisk += m_Exposures[baseIndex].ShortExposure * riskPercent;
        
        if(currentRisk > m_MaxRiskPerCurrency)
            return false;
    }
    
    // Check direction exposure
    double totalLongRisk = 0;
    double totalShortRisk = 0;
    for(int i = 0; i < m_ExposureCount; i++)
    {
        totalLongRisk += m_Exposures[i].LongExposure;
        totalShortRisk += m_Exposures[i].ShortExposure;
    }
    
    if(isLong && (totalLongRisk + riskPercent) > m_MaxRiskPerDirection)
        return false;
    if(!isLong && (totalShortRisk + riskPercent) > m_MaxRiskPerDirection)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Update exposure                                                  |
//+------------------------------------------------------------------+
void CCorrelationManager::UpdateExposure(string symbol, bool isLong, double positionSize)
{
    string baseCurrency = ExtractBaseCurrency(symbol);
    string quoteCurrency = ExtractQuoteCurrency(symbol);
    
    // Update base currency exposure
    int index;
    if(!FindCurrency(baseCurrency, index))
    {
        // Add new currency
        ArrayResize(m_Exposures, m_ExposureCount + 1);
        m_Exposures[m_ExposureCount].Currency = baseCurrency;
        m_Exposures[m_ExposureCount].LongExposure = 0;
        m_Exposures[m_ExposureCount].ShortExposure = 0;
        index = m_ExposureCount;
        m_ExposureCount++;
    }
    
    if(isLong)
        m_Exposures[index].LongExposure += positionSize;
    else
        m_Exposures[index].ShortExposure += positionSize;
    
    CalculateNetExposures();
}

//+------------------------------------------------------------------+
//| Remove exposure                                                  |
//+------------------------------------------------------------------+
void CCorrelationManager::RemoveExposure(string symbol, ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    string baseCurrency = ExtractBaseCurrency(symbol);
    double positionSize = PositionGetDouble(POSITION_VOLUME);
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    int index;
    if(FindCurrency(baseCurrency, index))
    {
        if(isLong)
            m_Exposures[index].LongExposure -= positionSize;
        else
            m_Exposures[index].ShortExposure -= positionSize;
        
        // Remove if no exposure
        if(m_Exposures[index].LongExposure <= 0 && 
           m_Exposures[index].ShortExposure <= 0)
        {
            for(int i = index; i < m_ExposureCount - 1; i++)
                m_Exposures[i] = m_Exposures[i + 1];
            m_ExposureCount--;
            ArrayResize(m_Exposures, m_ExposureCount);
        }
    }
    
    CalculateNetExposures();
}

//+------------------------------------------------------------------+
//| Get adjusted position size                                       |
//+------------------------------------------------------------------+
double CCorrelationManager::GetAdjustedPositionSize(string symbol, bool isLong, double baseSize)
{
    if(!CanOpenTrade(symbol, isLong, baseSize))
    {
        // Reduce size to fit within limits
        double reductionFactor = 0.7; // Reduce by 30%
        return baseSize * reductionFactor;
    }
    
    return baseSize;
}

//+------------------------------------------------------------------+
//| Check overexposure                                               |
//+------------------------------------------------------------------+
bool CCorrelationManager::CheckOverexposure()
{
    CalculateNetExposures();
    
    for(int i = 0; i < m_ExposureCount; i++)
    {
        if(m_Exposures[i].RiskPercent > m_MaxRiskPerCurrency)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Auto hedge                                                       |
//+------------------------------------------------------------------+
void CCorrelationManager::AutoHedge()
{
    if(!m_AutoHedge) return;
    
    // This would implement automatic hedging logic
    // For now, placeholder
}

//+------------------------------------------------------------------+
//| Extract base currency                                            |
//+------------------------------------------------------------------+
string CCorrelationManager::ExtractBaseCurrency(string symbol)
{
    // For pairs like EURUSD, extract EUR
    if(StringLen(symbol) >= 6)
        return StringSubstr(symbol, 0, 3);
    return "";
}

//+------------------------------------------------------------------+
//| Extract quote currency                                           |
//+------------------------------------------------------------------+
string CCorrelationManager::ExtractQuoteCurrency(string symbol)
{
    // For pairs like EURUSD, extract USD
    if(StringLen(symbol) >= 6)
        return StringSubstr(symbol, 3, 3);
    return "";
}

//+------------------------------------------------------------------+
//| Find currency                                                    |
//+------------------------------------------------------------------+
bool CCorrelationManager::FindCurrency(string currency, int &index)
{
    for(int i = 0; i < m_ExposureCount; i++)
    {
        if(m_Exposures[i].Currency == currency)
        {
            index = i;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculate net exposures                                          |
//+------------------------------------------------------------------+
void CCorrelationManager::CalculateNetExposures()
{
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    for(int i = 0; i < m_ExposureCount; i++)
    {
        m_Exposures[i].NetExposure = m_Exposures[i].LongExposure - 
                                     m_Exposures[i].ShortExposure;
        
        // Calculate risk percent (simplified)
        double totalExposure = m_Exposures[i].LongExposure + 
                              m_Exposures[i].ShortExposure;
        m_Exposures[i].RiskPercent = (totalExposure / accountEquity) * 100.0;
    }
}

//+------------------------------------------------------------------+
//| Get correlation                                                  |
//+------------------------------------------------------------------+
double CCorrelationManager::GetCorrelation(string symbol1, string symbol2)
{
    // This would calculate correlation from historical data
    // For now, return simplified values
    if(symbol1 == symbol2)
        return 1.0;
    
    // Common correlations (simplified)
    if((StringFind(symbol1, "EUR") >= 0 && StringFind(symbol2, "GBP") >= 0) ||
       (StringFind(symbol1, "GBP") >= 0 && StringFind(symbol2, "EUR") >= 0))
        return 0.8; // High correlation
    
    return 0.0; // Unknown correlation
}

//+------------------------------------------------------------------+
