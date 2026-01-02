//+------------------------------------------------------------------+
//|                                            NewsFilter.mqh        |
//|                    News Avoidance Filter                         |
//+------------------------------------------------------------------+
#property copyright "shashi ByteBAba LLp"
#property link      "https://www.mql5.com"
#property version   "2.00"

//+------------------------------------------------------------------+
//| News Filter Class                                                |
//+------------------------------------------------------------------+
class CNewsFilter
{
private:
    bool              m_AvoidNews;          // Avoid news
    int               m_NewsBufferMinutes;  // Minutes before/after news
    
    // News events (simplified - in real implementation, would use calendar API)
    datetime          m_NewsEvents[];
    int               m_NewsCount;
    
public:
    CNewsFilter();
    ~CNewsFilter();
    
    bool              Initialize(bool avoidNews, int bufferMinutes);
    bool              IsNewsTime();
    bool              CanTrade();
    datetime          GetNextNewsTime();
    
private:
    void              LoadNewsEvents(); // Would load from calendar
    bool              IsTimeNearNews(datetime time);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CNewsFilter::CNewsFilter()
{
    m_AvoidNews = true;
    m_NewsBufferMinutes = 30;
    m_NewsCount = 0;
    ArrayResize(m_NewsEvents, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNewsFilter::~CNewsFilter()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CNewsFilter::Initialize(bool avoidNews, int bufferMinutes)
{
    m_AvoidNews = avoidNews;
    m_NewsBufferMinutes = bufferMinutes;
    
    if(m_AvoidNews)
        LoadNewsEvents();
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if news time                                               |
//+------------------------------------------------------------------+
bool CNewsFilter::IsNewsTime()
{
    if(!m_AvoidNews) return false;
    
    return IsTimeNearNews(TimeCurrent());
}

//+------------------------------------------------------------------+
//| Check if can trade                                               |
//+------------------------------------------------------------------+
bool CNewsFilter::CanTrade()
{
    if(!m_AvoidNews) return true;
    
    return !IsNewsTime();
}

//+------------------------------------------------------------------+
//| Get next news time                                               |
//+------------------------------------------------------------------+
datetime CNewsFilter::GetNextNewsTime()
{
    datetime currentTime = TimeCurrent();
    datetime nextNews = 0;
    
    for(int i = 0; i < m_NewsCount; i++)
    {
        if(m_NewsEvents[i] > currentTime)
        {
            if(nextNews == 0 || m_NewsEvents[i] < nextNews)
                nextNews = m_NewsEvents[i];
        }
    }
    
    return nextNews;
}

//+------------------------------------------------------------------+
//| Load news events                                                 |
//+------------------------------------------------------------------+
void CNewsFilter::LoadNewsEvents()
{
    // In real implementation, this would load from economic calendar
    // For now, empty - would need calendar API integration
    m_NewsCount = 0;
    ArrayResize(m_NewsEvents, 0);
}

//+------------------------------------------------------------------+
//| Check if time is near news                                       |
//+------------------------------------------------------------------+
bool CNewsFilter::IsTimeNearNews(datetime time)
{
    int bufferSeconds = m_NewsBufferMinutes * 60;
    
    for(int i = 0; i < m_NewsCount; i++)
    {
        datetime newsTime = m_NewsEvents[i];
        int timeDiff = (int)MathAbs(time - newsTime);
        
        if(timeDiff <= bufferSeconds)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
