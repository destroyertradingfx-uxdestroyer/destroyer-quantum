//+------------------------------------------------------------------+
//| Time-Based Manipulation Strategy (Umar Arpanjabi)                 |
//| EURUSD H4 bias + Asia session liquidity sweep + BOS entry         |
//| For DESTROYER QUANTUM strategy library                            |
//+------------------------------------------------------------------+

// Magic number for Time-Based Manipulation
#define MAGIC_TBM 9010

// Asia session times (server time - adjust for your broker)
// Default: Asia = 00:00-09:00 Dubai (UTC+4) = 20:00-05:00 server (UTC+0)
// Adjust these based on your broker's server timezone
#define ASIA_START_HOUR  0    // Asia session start hour (server time)
#define ASIA_START_MIN   0
#define ASIA_END_HOUR    9    // Asia session end hour (server time)
#define ASIA_END_MIN     0

// London open (when to start looking for entry)
#define LONDON_OPEN_HOUR 9    // London open hour (server time)
#define LONDON_OPEN_MIN  0

// Trade cutoff time (don't enter after this)
#define TRADE_CUTOFF_HOUR 12  // 1 PM Dubai = 9 AM London
#define TRADE_CUTOFF_MIN  0

//+------------------------------------------------------------------+
//| Structure for Asia session data                                   |
//+------------------------------------------------------------------+
struct AsiaSessionData
{
   double asiaHigh;       // Asia session high
   double asiaLow;        // Asia session low
   bool   highSwept;      // Has Asia high been swept?
   bool   lowSwept;       // Has Asia low been swept?
   bool   isValid;        // Is Asia data valid?
   datetime asiaStart;    // Asia session start time
   datetime asiaEnd;      // Asia session end time
};

//+------------------------------------------------------------------+
//| Get Asia session high and low for today                           |
//+------------------------------------------------------------------+
AsiaSessionData GetAsiaSession()
{
   AsiaSessionData data;
   data.isValid = false;
   data.highSwept = false;
   data.lowSwept = false;
   
   // Get today's date
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Asia session start (today)
   MqlDateTime asiaStartDt = dt;
   asiaStartDt.hour = ASIA_START_HOUR;
   asiaStartDt.min = ASIA_START_MIN;
   asiaStartDt.sec = 0;
   data.asiaStart = StructToTime(asiaStartDt);
   
   // Asia session end (today)
   MqlDateTime asiaEndDt = dt;
   asiaEndDt.hour = ASIA_END_HOUR;
   asiaEndDt.min = ASIA_END_MIN;
   asiaEndDt.sec = 0;
   data.asiaEnd = StructToTime(asiaEndDt);
   
   // If current time is before Asia end, use yesterday's Asia session
   if(TimeCurrent() < data.asiaEnd)
   {
      // Use yesterday's Asia session
      data.asiaStart -= 86400;
      data.asiaEnd -= 86400;
   }
   
   // Find Asia session high and low
   data.asiaHigh = 0;
   data.asiaLow = 999999;
   
   int asiaStartBar = iBarShift(Symbol(), PERIOD_H1, data.asiaStart);
   int asiaEndBar = iBarShift(Symbol(), PERIOD_H1, data.asiaEnd);
   
   if(asiaStartBar < 0 || asiaEndBar < 0) return data;
   
   for(int i = asiaEndBar; i <= asiaStartBar; i++)
   {
      if(i < 0 || i >= Bars) continue;
      
      if(High[i] > data.asiaHigh) data.asiaHigh = High[i];
      if(Low[i] < data.asiaLow) data.asiaLow = Low[i];
   }
   
   if(data.asiaHigh > 0 && data.asiaLow < 999999)
      data.isValid = true;
   
   return data;
}

//+------------------------------------------------------------------+
//| Determine H4 bias (bullish or bearish)                            |
//| Returns: 1 = bullish, -1 = bearish, 0 = neutral                  |
//+------------------------------------------------------------------+
int GetH4Bias(int lookback=20)
{
   // Use H4 timeframe for bias detection
   // Look at recent swing highs and lows
   
   double recentHigh1 = 0, recentHigh2 = 0;
   double recentLow1 = 999999, recentLow2 = 999999;
   int highBar1 = 0, highBar2 = 0;
   int lowBar1 = 0, lowBar2 = 0;
   
   // Find two most recent swing highs and lows on H4
   // Simple approach: look at last 'lookback' H4 bars
   for(int i = 1; i < lookback; i++)
   {
      int h4Bar = iBarShift(Symbol(), PERIOD_H4, Time[i]);
      if(h4Bar < 0) continue;
      
      double h4High = iHigh(Symbol(), PERIOD_H4, h4Bar);
      double h4Low = iLow(Symbol(), PERIOD_H4, h4Bar);
      
      // Track highest and second highest
      if(h4High > recentHigh1)
      {
         recentHigh2 = recentHigh1;
         highBar2 = highBar1;
         recentHigh1 = h4High;
         highBar1 = i;
      }
      else if(h4High > recentHigh2)
      {
         recentHigh2 = h4High;
         highBar2 = i;
      }
      
      // Track lowest and second lowest
      if(h4Low < recentLow1)
      {
         recentLow2 = recentLow1;
         lowBar2 = lowBar1;
         recentLow1 = h4Low;
         lowBar1 = i;
      }
      else if(h4Low < recentLow2)
      {
         recentLow2 = h4Low;
         lowBar2 = i;
      }
   }
   
   // Determine bias based on structure
   // Bullish: higher highs and higher lows
   // Bearish: lower highs and lower lows
   
   bool higherHigh = (recentHigh1 > recentHigh2 && highBar1 < highBar2); // Newer high is higher
   bool higherLow = (recentLow1 > recentLow2 && lowBar1 < lowBar2);     // Newer low is higher
   bool lowerHigh = (recentHigh1 < recentHigh2 && highBar1 < highBar2);  // Newer high is lower
   bool lowerLow = (recentLow1 < recentLow2 && lowBar1 < lowBar2);      // Newer low is lower
   
   if(higherHigh && higherLow) return 1;   // Bullish
   if(lowerHigh && lowerLow) return -1;    // Bearish
   
   // Mixed signals — use EMA as tiebreaker
   double ema50 = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema20 = iMA(Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   if(ema20 > ema50) return 1;   // Bullish
   if(ema20 < ema50) return -1;  // Bearish
   
   return 0; // Neutral
}

//+------------------------------------------------------------------+
//| Check if price swept (took out) Asia high or low                  |
//+------------------------------------------------------------------+
bool CheckSweep(AsiaSessionData &asia, int bias)
{
   // Check recent candles for sweep
   int barsToCheck = 20; // Check last 20 candles
   
   for(int i = 1; i <= barsToCheck; i++)
   {
      // Bullish bias: we need Asia LOW to be swept
      if(bias == 1 && Low[i] < asia.asiaLow)
      {
         asia.lowSwept = true;
         return true;
      }
      
      // Bearish bias: we need Asia HIGH to be swept
      if(bias == -1 && High[i] > asia.asiaHigh)
      {
         asia.highSwept = true;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS) after sweep                       |
//+------------------------------------------------------------------+
bool DetectBOS(int bias, int maxBarsBack=20)
{
   // After sweep, look for BOS on current timeframe
   // Bullish BOS: price breaks above recent swing high
   // Bearish BOS: price breaks below recent swing low
   
   if(bias == 1) // Bullish — look for break above recent high
   {
      double recentSwingHigh = 0;
      for(int i = 2; i <= maxBarsBack; i++)
      {
         if(High[i] > recentSwingHigh)
            recentSwingHigh = High[i];
      }
      
      // Current price broke above the recent swing high
      if(Close[1] > recentSwingHigh || Close[0] > recentSwingHigh)
         return true;
   }
   else if(bias == -1) // Bearish — look for break below recent low
   {
      double recentSwingLow = 999999;
      for(int i = 2; i <= maxBarsBack; i++)
      {
         if(Low[i] < recentSwingLow)
            recentSwingLow = Low[i];
      }
      
      // Current price broke below the recent swing low
      if(Close[1] < recentSwingLow || Close[0] < recentSwingLow)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if we're within trading hours                               |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Must be after London open
   int currentMinutes = dt.hour * 60 + dt.min;
   int londonOpen = LONDON_OPEN_HOUR * 60 + LONDON_OPEN_MIN;
   int cutoff = TRADE_CUTOFF_HOUR * 60 + TRADE_CUTOFF_MIN;
   
   return (currentMinutes >= londonOpen && currentMinutes < cutoff);
}

//+------------------------------------------------------------------+
//| Execute Time-Based Manipulation Strategy                          |
//+------------------------------------------------------------------+
void ExecuteTimeBasedManipulation(double lotSize=0.01, double rrRatio=2.0)
{
   // Check if we already have an open TBM trade
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() == MAGIC_TBM) return; // Already have a trade
   }
   
   // Check if within trading hours
   if(!IsWithinTradingHours()) return;
   
   // Get H4 bias
   int bias = GetH4Bias();
   if(bias == 0) return; // No clear bias
   
   // Get Asia session data
   AsiaSessionData asia = GetAsiaSession();
   if(!asia.isValid) return; // No valid Asia data
   
   // Check if Asia high/low was swept
   if(!CheckSweep(asia, bias)) return; // No sweep yet
   
   // Check for Break of Structure
   if(!DetectBOS(bias)) return; // No BOS yet
   
   // All conditions met — enter trade
   double entryPrice, stopLoss, takeProfit;
   double slDistance;
   
   if(bias == 1) // Bullish — LONG
   {
      entryPrice = Ask;
      stopLoss = asia.asiaLow - (asia.asiaHigh - asia.asiaLow) * 0.1; // Below Asia low with buffer
      slDistance = entryPrice - stopLoss;
      takeProfit = entryPrice + slDistance * rrRatio;
      
      int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entryPrice, 3,
                             stopLoss, takeProfit, "TBM_Long", MAGIC_TBM, 0, clrGreen);
      if(ticket > 0)
      {
         Print("TBM LONG: Bias=Bullish, AsiaHigh=", asia.asiaHigh, 
               " AsiaLow=", asia.asiaLow, " Entry=", entryPrice,
               " SL=", stopLoss, " TP=", takeProfit);
      }
   }
   else if(bias == -1) // Bearish — SHORT
   {
      entryPrice = Bid;
      stopLoss = asia.asiaHigh + (asia.asiaHigh - asia.asiaLow) * 0.1; // Above Asia high with buffer
      slDistance = stopLoss - entryPrice;
      takeProfit = entryPrice - slDistance * rrRatio;
      
      int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entryPrice, 3,
                             stopLoss, takeProfit, "TBM_Short", MAGIC_TBM, 0, clrRed);
      if(ticket > 0)
      {
         Print("TBM SHORT: Bias=Bearish, AsiaHigh=", asia.asiaHigh,
               " AsiaLow=", asia.asiaLow, " Entry=", entryPrice,
               " SL=", stopLoss, " TP=", takeProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Asia session box on chart (for visual debugging)             |
//+------------------------------------------------------------------+
void DrawAsiaSession(AsiaSessionData &asia)
{
   if(!asia.isValid) return;
   
   string prefix = "TBM_Asia_";
   
   // Draw Asia high line
   ObjectCreate(0, prefix+"High", OBJ_TREND, 0, 
                asia.asiaStart, asia.asiaHigh, asia.asiaEnd, asia.asiaHigh);
   ObjectSetInteger(0, prefix+"High", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, prefix+"High", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix+"High", OBJPROP_WIDTH, 1);
   
   // Draw Asia low line
   ObjectCreate(0, prefix+"Low", OBJ_TREND, 0,
                asia.asiaStart, asia.asiaLow, asia.asiaEnd, asia.asiaLow);
   ObjectSetInteger(0, prefix+"Low", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, prefix+"Low", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix+"Low", OBJPROP_WIDTH, 1);
   
   // Draw Asia session box
   ObjectCreate(0, prefix+"Box", OBJ_RECTANGLE, 0,
                asia.asiaStart, asia.asiaHigh, asia.asiaEnd, asia.asiaLow);
   ObjectSetInteger(0, prefix+"Box", OBJPROP_COLOR, clrDarkSlateGray);
   ObjectSetInteger(0, prefix+"Box", OBJPROP_FILL, true);
   
   // Label
   ObjectCreate(0, prefix+"Label", OBJ_TEXT, 0,
                asia.asiaStart, asia.asiaHigh);
   ObjectSetString(0, prefix+"Label", OBJPROP_TEXT, "Asia Range");
   ObjectSetInteger(0, prefix+"Label", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, prefix+"Label", OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Integration notes for DESTROYER QUANTUM:                          |
//|                                                                   |
//| 1. Add to OnInit():                                               |
//|    V23_RegisterStrategy("TBM", MAGIC_TBM);                        |
//|                                                                   |
//| 2. Add inputs:                                                    |
//|    extern bool InpTBM_Enabled = false;                             |
//|    extern double InpTBM_LotSize = 0.01;                            |
//|    extern double InpTBM_RRRatio = 2.0;                             |
//|    extern int InpTBM_AsiaStartHour = 0;                            |
//|    extern int InpTBM_AsiaEndHour = 9;                              |
//|    extern int InpTBM_LondonOpenHour = 9;                           |
//|    extern int InpTBM_CutoffHour = 12;                              |
//|                                                                   |
//| 3. Add to OnTick():                                               |
//|    if(InpTBM_Enabled)                                              |
//|       ExecuteTimeBasedManipulation(InpTBM_LotSize, InpTBM_RRRatio);|
//|                                                                   |
//| 4. Add to g_perfData[]:                                           |
//|    {"TBM", MAGIC_TBM, 0,0,0,0,0.0},                               |
//+------------------------------------------------------------------+
