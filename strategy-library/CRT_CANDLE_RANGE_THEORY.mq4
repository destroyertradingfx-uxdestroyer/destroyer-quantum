//+------------------------------------------------------------------+
//| CRT (Candle Range Theory) Strategy                                |
//| Session-based candle range theory / time-based structure           |
//| "If you just master the 9am CRT, it's enough to become profitable"|
//| For DESTROYER QUANTUM strategy library                            |
//+------------------------------------------------------------------+

// Magic number for CRT
#define MAGIC_CRT 9014

// CRT candle times (server time - adjust for broker)
// These are H4 candle open times
#define CRT_1AM_HOUR  1    // London session CRT candle
#define CRT_5AM_HOUR  5    // London lunch / NY opening CRT candle
#define CRT_9AM_HOUR  9    // NY session CRT candle (highest probability)

// Key entry times
#define KEY_TIME_START_HOUR 10  // NY session entry window start
#define KEY_TIME_END_HOUR   12  // NY session entry window end

// CRT candle indices (H4 bars back)
// For 9AM CRT: candles are 9PM (yesterday), 1AM, 5AM
// On H4, these are specific bars

//+------------------------------------------------------------------+
//| Structure for CRT candle data                                     |
//+------------------------------------------------------------------+
struct CRTCandle
{
   double open;
   double high;
   double low;
   double close;
   double range;      // high - low
   bool isOHLC;       // Open, High, Low, Close (bearish)
   bool isOLHC;       // Open, Low, High, Close (bullish)
   datetime time;
   bool isValid;
};

//+------------------------------------------------------------------+
//| Get CRT candle data for a specific time                           |
//+------------------------------------------------------------------+
CRTCandle GetCRTCandle(int hour)
{
   CRTCandle candle;
   candle.isValid = false;
   
   // Find the H4 bar that opened at this hour today
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Create target time
   MqlDateTime targetDt = dt;
   targetDt.hour = hour;
   targetDt.min = 0;
   targetDt.sec = 0;
   datetime targetTime = StructToTime(targetDt);
   
   // If target time is in the future, use yesterday
   if(targetTime > TimeCurrent())
      targetTime -= 86400;
   
   int bar = iBarShift(Symbol(), PERIOD_H4, targetTime);
   if(bar < 0) return candle;
   
   candle.open = iOpen(Symbol(), PERIOD_H4, bar);
   candle.high = iHigh(Symbol(), PERIOD_H4, bar);
   candle.low = iLow(Symbol(), PERIOD_H4, bar);
   candle.close = iClose(Symbol(), PERIOD_H4, bar);
   candle.range = candle.high - candle.low;
   candle.time = iTime(Symbol(), PERIOD_H4, bar);
   
   if(candle.range <= 0) return candle;
   
   // Determine candle type
   // OHLC = Open near high, close near low (bearish)
   // OLHC = Open near low, close near high (bullish)
   double openPos = (candle.open - candle.low) / candle.range;
   double closePos = (candle.close - candle.low) / candle.range;
   
   candle.isOHLC = (openPos > 0.6 && closePos < 0.4);  // Open high, close low
   candle.isOLHC = (openPos < 0.4 && closePos > 0.6);  // Open low, close high
   candle.isValid = true;
   
   return candle;
}

//+------------------------------------------------------------------+
//| Get DOL (Draw on Liquidity)                                       |
//| Returns: 1 = bullish DOL, -1 = bearish DOL, 0 = neutral          |
//+------------------------------------------------------------------+
int GetDOL()
{
   // DOL = previous day high/low
   double prevDayHigh = iHigh(Symbol(), PERIOD_D1, 1);
   double prevDayLow = iLow(Symbol(), PERIOD_D1, 1);
   double prevDayClose = iClose(Symbol(), PERIOD_D1, 1);
   double currentPrice = Close[0];
   
   // Bullish: price closer to previous day low (targeting high)
   // Bearish: price closer to previous day high (targeting low)
   
   double distToHigh = prevDayHigh - currentPrice;
   double distToLow = currentPrice - prevDayLow;
   
   // Check order flow (last 5 H4 candles)
   int bullishCandles = 0;
   int bearishCandles = 0;
   for(int i = 1; i <= 5; i++)
   {
      if(iClose(Symbol(), PERIOD_H4, i) > iOpen(Symbol(), PERIOD_H4, i))
         bullishCandles++;
      else
         bearishCandles++;
   }
   
   // Bullish order flow + price near low = bullish DOL
   if(bullishCandles >= 3 && distToLow < distToHigh)
      return 1;
   
   // Bearish order flow + price near high = bearish DOL
   if(bearishCandles >= 3 && distToHigh < distToLow)
      return -1;
   
   // Use previous day close as tiebreaker
   if(prevDayClose > (prevDayHigh + prevDayLow) / 2)
      return 1; // Closed in upper half = bullish
   else
      return -1; // Closed in lower half = bearish
}

//+------------------------------------------------------------------+
//| Detect CRT pattern (3-candle sequence)                            |
//| Returns: 1 = bullish CRT, -1 = bearish CRT, 0 = no pattern       |
//+------------------------------------------------------------------+
int DetectCRTPattern(int crtHour)
{
   CRTCandle candle1 = GetCRTCandle(crtHour - 8); // 8 hours before (2 H4 candles back)
   CRTCandle candle2 = GetCRTCandle(crtHour - 4); // 4 hours before (1 H4 candle back)
   CRTCandle candle3 = GetCRTCandle(crtHour);     // Current CRT candle
   
   if(!candle1.isValid || !candle2.isValid || !candle3.isValid)
      return 0;
   
   // Candle 1 = generation of liquidity (creates range)
   // Candle 2 = purging of liquidity (sweeps range)
   // Candle 3 = neutralization of liquidity (confirms direction)
   
   // Bullish CRT: candle 2 sweeps candle 1 low, candle 3 closes above candle 2 high
   if(candle2.low < candle1.low && candle3.close > candle2.high)
      return 1;
   
   // Bearish CRT: candle 2 sweeps candle 1 high, candle 3 closes below candle 2 low
   if(candle2.high > candle1.high && candle3.close < candle2.low)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get CRT high/low for entry reference                              |
//+------------------------------------------------------------------+
void GetCRTLevels(int crtHour, double &crtHigh, double &crtLow)
{
   CRTCandle candle = GetCRTCandle(crtHour);
   if(candle.isValid)
   {
      crtHigh = candle.high;
      crtLow = candle.low;
   }
   else
   {
      crtHigh = 0;
      crtLow = 0;
   }
}

//+------------------------------------------------------------------+
//| Detect Order Block on M5 for entry                                |
//+------------------------------------------------------------------+
bool DetectM5OrderBlock(int bias, int lookback=20)
{
   // Look for order block on M5 timeframe
   // Bullish OB: last down-close candle before expansion
   // Bearish OB: last up-close candle before expansion
   
   for(int i = 2; i < lookback; i++)
   {
      double o = iOpen(Symbol(), PERIOD_M5, i);
      double c = iClose(Symbol(), PERIOD_M5, i);
      double h = iHigh(Symbol(), PERIOD_M5, i);
      double l = iLow(Symbol(), PERIOD_M5, i);
      
      if(bias == 1) // Bullish OB
      {
         if(c < o) // Down-close candle
         {
            double nextC = iClose(Symbol(), PERIOD_M5, i - 1);
            if(nextC > h) // Expansion above
            {
               double currentPrice = Close[0];
               if(currentPrice <= h && currentPrice >= l)
                  return true;
            }
         }
      }
      else if(bias == -1) // Bearish OB
      {
         if(c > o) // Up-close candle
         {
            double nextC = iClose(Symbol(), PERIOD_M5, i - 1);
            if(nextC < l) // Expansion below
            {
               double currentPrice = Close[0];
               if(currentPrice >= l && currentPrice <= h)
                  return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if within key entry time                                    |
//+------------------------------------------------------------------+
bool IsWithinKeyTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= KEY_TIME_START_HOUR && dt.hour < KEY_TIME_END_HOUR);
}

//+------------------------------------------------------------------+
//| Execute CRT Strategy (9AM CRT focus)                              |
//+------------------------------------------------------------------+
void ExecuteCRT(double lotSize=0.01, double rrRatio=2.5)
{
   // Check if we already have an open CRT trade
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() == MAGIC_CRT) return;
   }
   
   // Check if within key time
   if(!IsWithinKeyTime()) return;
   
   // Get DOL
   int dol = GetDOL();
   if(dol == 0) return;
   
   // Detect CRT pattern for 9AM candle (highest probability)
   int crtBias = DetectCRTPattern(CRT_9AM_HOUR);
   if(crtBias == 0) return; // No CRT pattern
   
   // DOL and CRT must align
   if(dol != crtBias) return;
   
   // Get CRT levels
   double crtHigh, crtLow;
   GetCRTLevels(CRT_9AM_HOUR, crtHigh, crtLow);
   if(crtHigh == 0 || crtLow == 0) return;
   
   // Check for M5 order block entry
   if(!DetectM5OrderBlock(crtBias)) return;
   
   // Calculate entry, SL, TP
   double entryPrice, stopLoss, takeProfit;
   double slDistance;
   double buffer = 10 * Point;
   
   if(crtBias == 1) // Long
   {
      entryPrice = Ask;
      stopLoss = crtLow - buffer;
      slDistance = entryPrice - stopLoss;
      takeProfit = entryPrice + slDistance * rrRatio;
      
      int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entryPrice, 3,
                             stopLoss, takeProfit, "CRT_Long", MAGIC_CRT, 0, clrGreen);
      if(ticket > 0)
      {
         Print("CRT LONG: DOL=Bullish, CRT=Bullish, CRT_H=", crtHigh,
               " CRT_L=", crtLow, " Entry=", entryPrice, " SL=", stopLoss, " TP=", takeProfit);
      }
   }
   else if(crtBias == -1) // Short
   {
      entryPrice = Bid;
      stopLoss = crtHigh + buffer;
      slDistance = stopLoss - entryPrice;
      takeProfit = entryPrice - slDistance * rrRatio;
      
      int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entryPrice, 3,
                             stopLoss, takeProfit, "CRT_Short", MAGIC_CRT, 0, clrRed);
      if(ticket > 0)
      {
         Print("CRT SHORT: DOL=Bearish, CRT=Bearish, CRT_H=", crtHigh,
               " CRT_L=", crtLow, " Entry=", entryPrice, " SL=", stopLoss, " TP=", takeProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| Integration notes for DESTROYER QUANTUM:                          |
//|                                                                   |
//| 1. Add to OnInit():                                               |
//|    V23_RegisterStrategy("CRT", MAGIC_CRT);                        |
//|                                                                   |
//| 2. Add inputs:                                                    |
//|    extern bool InpCRT_Enabled = false;                             |
//|    extern double InpCRT_LotSize = 0.01;                            |
//|    extern double InpCRT_RRRatio = 2.5;                             |
//|    extern int InpCRT_CandleHour = 9;                               |
//|                                                                   |
//| 3. Add to OnTick():                                               |
//|    if(InpCRT_Enabled)                                              |
//|       ExecuteCRT(InpCRT_LotSize, InpCRT_RRRatio);                 |
//|                                                                   |
//| 4. Add to g_perfData[]:                                           |
//|    {"CRT", MAGIC_CRT, 0,0,0,0,0.0},                               |
//+------------------------------------------------------------------+
