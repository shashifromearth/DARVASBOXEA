//+------------------------------------------------------------------+
//|                                      QuantumTradeMatrix.mqh      |
//|                    Multi-Phase Entry System for Maximum Gains    |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Quantum Trade Phase Structure                                    |
//+------------------------------------------------------------------+
struct QuantumTradePhase
{
    int               Phase;              // Phase number (1-5)
    double            PositionSize;      // Size for this phase
    double            EntryPrice;         // Entry price
    double            StopLoss;           // Stop loss
    double            TakeProfit;         // Take profit
    datetime          EntryTime;          // Entry timestamp
    datetime          ExpirationTime;     // Phase expiration
    bool              IsActive;           // Is phase active
    bool              IsLong;             // Trade direction
    ulong             Ticket;              // Trade ticket
    string            PhaseName;          // Phase description
};

//+------------------------------------------------------------------+
//| Quantum Trade Matrix Structure                                   |
//+------------------------------------------------------------------+
struct QuantumTradeMatrix
{
    ulong             BoxId;              // Associated box ID
    QuantumTradePhase  Phases[];           // All phases
    int               ActivePhases;        // Number of active phases
    double            TotalPositionSize;   // Total position across all phases
    bool              IsLong;             // Overall direction
    datetime          CreationTime;        // Matrix creation time
};

//+------------------------------------------------------------------+
//| Quantum Trade Matrix Manager                                     |
//+------------------------------------------------------------------+
class CQuantumTradeMatrix
{
private:
    QuantumTradeMatrix m_ActiveMatrices[]; // Active trade matrices
    int                m_MatrixCount;      // Number of active matrices
    
    // Phase allocation percentages
    double             m_Phase1Percent;   // Breakout Entry (20%)
    double             m_Phase2Percent;   // Retest Entry (30%)
    double             m_Phase3Percent;   // Momentum Add (25%)
    double             m_Phase4Percent;   // Extension Play (15%)
    double             m_Phase5Percent;   // Exhaustion Fade (10%)
    
    int                m_MaxPhasesPerBox; // Maximum phases per box
    
public:
    CQuantumTradeMatrix();
    ~CQuantumTradeMatrix();
    
    bool              Initialize(double phase1 = 0.20, double phase2 = 0.30,
                                 double phase3 = 0.25, double phase4 = 0.15,
                                 double phase5 = 0.10, int maxPhases = 5);
    
    bool              CreateMatrix(const DarvasBox &box, bool isLong, 
                                   double basePositionSize);
    bool              AddPhase(ulong matrixId, int phase, const DarvasBox &box,
                              bool isLong, double baseSize);
    bool              ExecutePhase(ulong matrixId, int phase);
    void              UpdatePhases();
    void              CloseExpiredPhases();
    bool              GetMatrix(ulong boxId, QuantumTradeMatrix &outMatrix);
    
    int               GetActivePhaseCount(ulong boxId);
    double            GetTotalPositionSize(ulong boxId);
    
private:
    bool              FindMatrix(ulong boxId, int &index);
    bool              CheckPhaseConditions(int phase, const DarvasBox &box,
                                          bool isLong, ENUM_TIMEFRAMES timeframe);
    double            CalculatePhaseSize(int phase, double baseSize);
    datetime          CalculatePhaseExpiration(int phase, ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CQuantumTradeMatrix::CQuantumTradeMatrix()
{
    m_MatrixCount = 0;
    m_Phase1Percent = 0.20;
    m_Phase2Percent = 0.30;
    m_Phase3Percent = 0.25;
    m_Phase4Percent = 0.15;
    m_Phase5Percent = 0.10;
    m_MaxPhasesPerBox = 5;
    ArrayResize(m_ActiveMatrices, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CQuantumTradeMatrix::~CQuantumTradeMatrix()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CQuantumTradeMatrix::Initialize(double phase1, double phase2,
                                     double phase3, double phase4,
                                     double phase5, int maxPhases)
{
    m_Phase1Percent = phase1;
    m_Phase2Percent = phase2;
    m_Phase3Percent = phase3;
    m_Phase4Percent = phase4;
    m_Phase5Percent = phase5;
    m_MaxPhasesPerBox = maxPhases;
    
    // Verify percentages sum to 1.0
    double total = phase1 + phase2 + phase3 + phase4 + phase5;
    if(MathAbs(total - 1.0) > 0.01)
    {
        Print("Warning: Phase percentages don't sum to 1.0, normalizing...");
        m_Phase1Percent /= total;
        m_Phase2Percent /= total;
        m_Phase3Percent /= total;
        m_Phase4Percent /= total;
        m_Phase5Percent /= total;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Create trade matrix                                              |
//+------------------------------------------------------------------+
bool CQuantumTradeMatrix::CreateMatrix(const DarvasBox &box, bool isLong, 
                                       double basePositionSize)
{
    // Add to active matrices
    ArrayResize(m_ActiveMatrices, m_MatrixCount + 1);
    
    m_ActiveMatrices[m_MatrixCount].BoxId = (ulong)box.CreationTime;
    m_ActiveMatrices[m_MatrixCount].IsLong = isLong;
    m_ActiveMatrices[m_MatrixCount].CreationTime = TimeCurrent();
    m_ActiveMatrices[m_MatrixCount].ActivePhases = 0;
    m_ActiveMatrices[m_MatrixCount].TotalPositionSize = 0;
    ArrayResize(m_ActiveMatrices[m_MatrixCount].Phases, 0);
    
    m_MatrixCount++;
    
    return true;
}

//+------------------------------------------------------------------+
//| Add phase to matrix                                              |
//+------------------------------------------------------------------+
bool CQuantumTradeMatrix::AddPhase(ulong boxId, int phase, const DarvasBox &box,
                                   bool isLong, double baseSize)
{
    int matrixIndex;
    if(!FindMatrix(boxId, matrixIndex))
        return false;
    
    if(phase < 1 || phase > m_MaxPhasesPerBox)
        return false;
    
    QuantumTradePhase tradePhase;
    tradePhase.Phase = phase;
    tradePhase.PositionSize = CalculatePhaseSize(phase, baseSize);
    tradePhase.IsLong = isLong;
    tradePhase.IsActive = false;
    tradePhase.EntryTime = 0;
    tradePhase.ExpirationTime = CalculatePhaseExpiration(phase, (ENUM_TIMEFRAMES)box.Timeframe);
    tradePhase.Ticket = 0;
    
    // Set phase names
    switch(phase)
    {
        case 1: tradePhase.PhaseName = "Breakout Entry"; break;
        case 2: tradePhase.PhaseName = "Retest Entry"; break;
        case 3: tradePhase.PhaseName = "Momentum Add"; break;
        case 4: tradePhase.PhaseName = "Extension Play"; break;
        case 5: tradePhase.PhaseName = "Exhaustion Fade"; break;
    }
    
    // Add phase to matrix
    int phaseCount = ArraySize(m_ActiveMatrices[matrixIndex].Phases);
    ArrayResize(m_ActiveMatrices[matrixIndex].Phases, phaseCount + 1);
    m_ActiveMatrices[matrixIndex].Phases[phaseCount] = tradePhase;
    m_ActiveMatrices[matrixIndex].ActivePhases++;
    
    return true;
}

//+------------------------------------------------------------------+
//| Execute phase                                                    |
//+------------------------------------------------------------------+
bool CQuantumTradeMatrix::ExecutePhase(ulong boxId, int phase)
{
    int matrixIndex;
    if(!FindMatrix(boxId, matrixIndex))
        return false;
    
    // Find the phase
    int phaseCount = ArraySize(m_ActiveMatrices[matrixIndex].Phases);
    for(int i = 0; i < phaseCount; i++)
    {
        if(m_ActiveMatrices[matrixIndex].Phases[i].Phase == phase && 
           !m_ActiveMatrices[matrixIndex].Phases[i].IsActive)
        {
            m_ActiveMatrices[matrixIndex].Phases[i].IsActive = true;
            m_ActiveMatrices[matrixIndex].Phases[i].EntryTime = TimeCurrent();
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update phases                                                    |
//+------------------------------------------------------------------+
void CQuantumTradeMatrix::UpdatePhases()
{
    CloseExpiredPhases();
    
    // Update active phases (trailing stops, etc.)
    for(int i = 0; i < m_MatrixCount; i++)
    {
        int phaseCount = ArraySize(m_ActiveMatrices[i].Phases);
        for(int j = 0; j < phaseCount; j++)
        {
            if(m_ActiveMatrices[i].Phases[j].IsActive && 
               m_ActiveMatrices[i].Phases[j].Ticket > 0)
            {
                // Update trailing stops, check targets, etc.
                // This would be handled by ExitManager
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Close expired phases                                             |
//+------------------------------------------------------------------+
void CQuantumTradeMatrix::CloseExpiredPhases()
{
    datetime currentTime = TimeCurrent();
    
    for(int i = m_MatrixCount - 1; i >= 0; i--)
    {
        bool matrixEmpty = true;
        int phaseCount = ArraySize(m_ActiveMatrices[i].Phases);
        
        for(int j = phaseCount - 1; j >= 0; j--)
        {
            if(m_ActiveMatrices[i].Phases[j].IsActive && 
               m_ActiveMatrices[i].Phases[j].ExpirationTime > 0 &&
               currentTime >= m_ActiveMatrices[i].Phases[j].ExpirationTime)
            {
                // Close expired phase
                if(m_ActiveMatrices[i].Phases[j].Ticket > 0)
                {
                    // Close trade
                    if(PositionSelectByTicket(m_ActiveMatrices[i].Phases[j].Ticket))
                    {
                        MqlTradeRequest request = {};
                        MqlTradeResult result = {};
                        request.action = TRADE_ACTION_DEAL;
                        request.position = m_ActiveMatrices[i].Phases[j].Ticket;
                        request.symbol = _Symbol;
                        request.volume = PositionGetDouble(POSITION_VOLUME);
                        request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                                       ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                        request.deviation = 10;
                        if(!OrderSend(request, result))
                        {
                            Print("Failed to close expired phase: ", result.retcode);
                        }
                    }
                }
                
                // Remove phase
                for(int k = j; k < phaseCount - 1; k++)
                    m_ActiveMatrices[i].Phases[k] = m_ActiveMatrices[i].Phases[k + 1];
                ArrayResize(m_ActiveMatrices[i].Phases, phaseCount - 1);
                m_ActiveMatrices[i].ActivePhases--;
                phaseCount--;
            }
            
            if(m_ActiveMatrices[i].Phases[j].IsActive)
                matrixEmpty = false;
        }
        
        // Remove empty matrices
        if(matrixEmpty)
        {
            for(int k = i; k < m_MatrixCount - 1; k++)
                m_ActiveMatrices[k] = m_ActiveMatrices[k + 1];
            m_MatrixCount--;
            ArrayResize(m_ActiveMatrices, m_MatrixCount);
        }
    }
}

//+------------------------------------------------------------------+
//| Get matrix by box ID                                             |
//+------------------------------------------------------------------+
bool CQuantumTradeMatrix::GetMatrix(ulong boxId, QuantumTradeMatrix &outMatrix)
{
    int index;
    if(!FindMatrix(boxId, index))
        return false;
    
    outMatrix = m_ActiveMatrices[index];
    return true;
}

//+------------------------------------------------------------------+
//| Get active phase count                                           |
//+------------------------------------------------------------------+
int CQuantumTradeMatrix::GetActivePhaseCount(ulong boxId)
{
    int index;
    if(!FindMatrix(boxId, index))
        return 0;
    
    return m_ActiveMatrices[index].ActivePhases;
}

//+------------------------------------------------------------------+
//| Get total position size                                          |
//+------------------------------------------------------------------+
double CQuantumTradeMatrix::GetTotalPositionSize(ulong boxId)
{
    int index;
    if(!FindMatrix(boxId, index))
        return 0;
    
    double total = 0;
    int phaseCount = ArraySize(m_ActiveMatrices[index].Phases);
    for(int i = 0; i < phaseCount; i++)
    {
        if(m_ActiveMatrices[index].Phases[i].IsActive)
            total += m_ActiveMatrices[index].Phases[i].PositionSize;
    }
    
    return total;
}

//+------------------------------------------------------------------+
//| Find matrix index                                                |
//+------------------------------------------------------------------+
bool CQuantumTradeMatrix::FindMatrix(ulong boxId, int &index)
{
    for(int i = 0; i < m_MatrixCount; i++)
    {
        if(m_ActiveMatrices[i].BoxId == boxId)
        {
            index = i;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check phase conditions                                           |
//+------------------------------------------------------------------+
bool CQuantumTradeMatrix::CheckPhaseConditions(int phase, const DarvasBox &box,
                                                bool isLong, ENUM_TIMEFRAMES timeframe)
{
    // Phase-specific conditions would be checked here
    // This would integrate with EntryManager logic
    return true;
}

//+------------------------------------------------------------------+
//| Calculate phase size                                             |
//+------------------------------------------------------------------+
double CQuantumTradeMatrix::CalculatePhaseSize(int phase, double baseSize)
{
    switch(phase)
    {
        case 1: return baseSize * m_Phase1Percent;
        case 2: return baseSize * m_Phase2Percent;
        case 3: return baseSize * m_Phase3Percent;
        case 4: return baseSize * m_Phase4Percent;
        case 5: return baseSize * m_Phase5Percent;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Calculate phase expiration                                       |
//+------------------------------------------------------------------+
datetime CQuantumTradeMatrix::CalculatePhaseExpiration(int phase, ENUM_TIMEFRAMES timeframe)
{
    // Phase 1-2: Short expiration (1-4 hours)
    // Phase 3-4: Medium expiration (4-12 hours)
    // Phase 5: Long expiration (12-24 hours)
    
    int hours = 0;
    switch(phase)
    {
        case 1: hours = 2; break;
        case 2: hours = 4; break;
        case 3: hours = 8; break;
        case 4: hours = 12; break;
        case 5: hours = 24; break;
    }
    
    return TimeCurrent() + hours * 3600;
}

//+------------------------------------------------------------------+
