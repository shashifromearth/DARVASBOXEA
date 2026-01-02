//+------------------------------------------------------------------+
//|                                            SessionManager.mqh    |
//|                    Trading Session Weighting System             |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "DarvasBox.mqh"

//+------------------------------------------------------------------+
//| Session Manager Class                                            |
//+------------------------------------------------------------------+
class CSessionManager
{
private:
    bool              m_FilterBySession;    // Use session filter
    
    // Session times (UTC)
    int               m_LondonStart;        // 07:00 UTC
    int               m_LondonEnd;          // 16:00 UTC
    int               m_NYStart;            // 13:00 UTC
    int               m_NYEnd;              // 22:00 UTC
    int               m_AsianStart;         // 00:00 UTC
    int               m_AsianEnd;           // 09:00 UTC
    
public:
    CSessionManager();
    ~CSessionManager();
    
    bool              Initialize(bool filterBySession);
    double            GetSessionWeight();
    SessionInfo       GetCurrentSession();
    bool              IsSessionActive(string sessionName);
    bool              IsHighLiquidityTime();
    double            GetTimeOfDayWeight();
    
private:
    int               GetCurrentHourUTC();
    bool              IsTimeInRange(int hour, int start, int end);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSessionManager::CSessionManager()
{
    m_FilterBySession = true;
    m_LondonStart = 7;
    m_LondonEnd = 16;
    m_NYStart = 13;
    m_NYEnd = 22;
    m_AsianStart = 0;
    m_AsianEnd = 9;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSessionManager::~CSessionManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CSessionManager::Initialize(bool filterBySession)
{
    m_FilterBySession = filterBySession;
    return true;
}

//+------------------------------------------------------------------+
//| Get session weight                                               |
//+------------------------------------------------------------------+
double CSessionManager::GetSessionWeight()
{
    if(!m_FilterBySession) return 1.0;
    
    SessionInfo session = GetCurrentSession();
    return session.Weight;
}

//+------------------------------------------------------------------+
//| Get current session                                              |
//+------------------------------------------------------------------+
SessionInfo CSessionManager::GetCurrentSession()
{
    SessionInfo session;
    int currentHour = GetCurrentHourUTC();
    
    // Check for session overlap (London/NY)
    if(IsTimeInRange(currentHour, m_LondonStart, m_LondonEnd) && 
       IsTimeInRange(currentHour, m_NYStart, m_NYEnd))
    {
        session.SessionName = "London/NY Overlap";
        session.Weight = 1.5; // Highest weight for overlap
        session.IsActive = true;
    }
    // London session
    else if(IsTimeInRange(currentHour, m_LondonStart, m_LondonEnd))
    {
        session.SessionName = "London";
        session.Weight = 1.2;
        session.IsActive = true;
    }
    // NY session
    else if(IsTimeInRange(currentHour, m_NYStart, m_NYEnd))
    {
        session.SessionName = "New York";
        session.Weight = 1.3;
        session.IsActive = true;
    }
    // Asian session
    else if(IsTimeInRange(currentHour, m_AsianStart, m_AsianEnd))
    {
        session.SessionName = "Asian";
        session.Weight = 0.8; // Lower weight
        session.IsActive = true;
    }
    else
    {
        session.SessionName = "Off Hours";
        session.Weight = 0.5; // Lowest weight
        session.IsActive = false;
    }
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = (currentHour >= m_LondonStart && currentHour < m_LondonEnd) ? m_LondonStart : 
              (currentHour >= m_NYStart && currentHour < m_NYEnd) ? m_NYStart : m_AsianStart;
    dt.min = 0;
    dt.sec = 0;
    session.StartTime = StructToTime(dt);
    
    dt.hour = (currentHour >= m_LondonStart && currentHour < m_LondonEnd) ? m_LondonEnd : 
              (currentHour >= m_NYStart && currentHour < m_NYEnd) ? m_NYEnd : m_AsianEnd;
    session.EndTime = StructToTime(dt);
    
    return session;
}

//+------------------------------------------------------------------+
//| Check if session is active                                       |
//+------------------------------------------------------------------+
bool CSessionManager::IsSessionActive(string sessionName)
{
    SessionInfo session = GetCurrentSession();
    return (session.SessionName == sessionName && session.IsActive);
}

//+------------------------------------------------------------------+
//| Check if high liquidity time                                     |
//+------------------------------------------------------------------+
bool CSessionManager::IsHighLiquidityTime()
{
    SessionInfo session = GetCurrentSession();
    return (session.Weight >= 1.2);
}

//+------------------------------------------------------------------+
//| Get time of day weight                                           |
//+------------------------------------------------------------------+
double CSessionManager::GetTimeOfDayWeight()
{
    return GetSessionWeight();
}

//+------------------------------------------------------------------+
//| Get current hour in UTC                                          |
//+------------------------------------------------------------------+
int CSessionManager::GetCurrentHourUTC()
{
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    return dt.hour;
}

//+------------------------------------------------------------------+
//| Check if time is in range                                        |
//+------------------------------------------------------------------+
bool CSessionManager::IsTimeInRange(int hour, int start, int end)
{
    if(start <= end)
        return (hour >= start && hour < end);
    else
        return (hour >= start || hour < end);
}

//+------------------------------------------------------------------+
