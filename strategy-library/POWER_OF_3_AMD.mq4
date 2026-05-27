//+------------------------------------------------------------------+
//| 4-Hour Power of 3 (AMD) Strategy                                  |
//| Accumulation -> Manipulation -> Distribution                      |
//| "Let the wick form, then trade the body"                          |
//| For DESTROYER QUANTUM strategy library                            |
//+------------------------------------------------------------------+

// Magic number for Power of 3
#define MAGIC_PO3 9011

// 4-Hour candle open times (server time - adjust for broker)
// Forex: 00:00, 04:00, 08:00, 12:00, 16:00, 20:00
// Or: 02:00, 06:00, 10:00, 14:00, 18:00, 22:00 (depending on broker)
#define H4_CANDLE_1_HOUR 2   // First 4H candle open
#define H4_CANDLE_2_HOUR 6   // Second 4H candle open (London)
#define H4_CANDLE_3_HOUR 10  // Third 4H candle open (London/NY overlap)
#define H4_CANDLE_4_HOUR 14  // Fourth 4H candle open (NY)

// Wick-to-body ratio threshold for "shallow wick"
#define SHALLOW_WICK_RATIO 0.3  // Wick < 30% of total range = shallow
#define LARGE_WICK_RATIO   0.6  // Wick > 60% of total range = large

//+------------------------------------------------------------------+
//| Structure for 4H candle analysis                                  |
//+------------------------------------------------------------------+
struct H4CandleAnalysis
{
   double open;
   double high;
   double low;
   double close;
   double totalRange;      // High - Low
   double upperWick;       // High - max(Open, Close)
   double lowerWick;       // min(Open, Close) - Low
   double body;            // |Close - Open|
   double upperWickRatio;  // upperWick / totalRange
   double lowerWickRatio;  // lowerWick / totalRange
   bool   isBullish;       // Close > Open
   bool   hasShallowWick;  // Wick < 30% of range
   bool   hasLargeWick;    // Wick > 60% of range
   bool   isReversal;      // Large opposing wick = reversal candle
   bool   isExpansion;     // Small wick + large body = expansion candle
   int    candleType;      // 1=Accumulation, 2=Manipulation, 3=Distribution
};

//+------------------------------------------------------------------+
//| Analyze a 4H candle                                               |
//+------------------------------------------------------------------+
H4CandleAnalysis AnalyzeH4Candle(int shift=0)
{
   H4CandleAnalysis candle;
   
   int h4Bar = iBarShift(Symbol(), PERIOD_H4, Time[shift]);
   if(h4Bar < 0)
   {
      candle.totalRange = 0;
      return candle;
   }
   
   candle.open = iOpen(Symbol(), PERIOD_H4, h4Bar);
   candle.high = iHigh(Symbol(), PERIOD_H4, h4Bar);
   candle.low = iLow(Symbol(), PERIOD_H4, h4Bar);
   candle.close = iClose(Symbol(), PERIOD_H4, h4Bar);
   
   candle.totalRange = candle.high - candle.low;
   if(candle.totalRange <= 0)
   {
      candle.totalRange = 0;
      return candle;
   }
   
   candle.body = MathAbs(candle.close - candle.open);
   candle.isBullish = (candle.close > candle.open);
   
   // Calculate wicks
   if(candle.isBullish)
   {
      candle.upperWick = candle.high - candle.close;
      candle.lowerWick = candle.open - candle.low;
   }
   else
   {
      candle.upperWick = candle.high - candle.open;
      candle.lowerWick = candle.close - candle.low;
   }
   
   candle.upperWickRatio = candle.upperWick / candle.totalRange;
   candle.lowerWickRatio = candle.lowerWick / candle.totalRange;
   
   // Determine wick characteristics
   double maxWickRatio = MathMax(candle.upperWickRatio, candle.lowerWickRatio);
   candle.hasShallowWick = (maxWickRatio < SHALLOW_WICK_RATIO);
   candle.hasLargeWick = (maxWickRatio > LARGE_WICK_RATIO);
   
   // Determine candle type
   candle.isReversal = candle.hasLargeWick;
   candle.isExpansion = candle.hasShallowWick && (candle.body / candle.totalRange > 0.5);
   
   return candle;
}

//+------------------------------------------------------------------+
//| Get current 4H candle phase (1, 2, or 3)                         |
//+------------------------------------------------------------------+
int GetCurrentH4Phase()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int hour = dt.hour;
   
   // Determine which 4H candle we're in
   if(hour >= H4_CANDLE_1_HOUR && hour < H4_CANDLE_2_HOUR) return 1;
   if(hour >= H4_CANDLE_2_HOUR && hour < H4_CANDLE_3_HOUR) return 2;
   if(hour >= H4_CANDLE_3_HOUR && hour < H4_CANDLE_4_HOUR) return 3;
   
   return 0; // Outside defined hours
}

//+------------------------------------------------------------------+
//| Detect protected swing (CISD - Change in State of Delivery)       |
//+------------------------------------------------------------------+
bool DetectProtectedSwing(int bias, int maxBars=20)
{
   // Bullish: look for protected low (price swept low then closed above)
   // Bearish: look for protected high (price swept high then closed below)
   
   if(bias == 1) // Bullish
   {
      // Find recent swing low
      double swingLow = 999999;
      int swingLowBar = 0;
      
      for(int i = 2; i <= maxBars; i++)
      {
         if(Low[i] < swingLow)
         {
            swingLow = Low[i];
            swingLowBar = i;
         }
      }
      
      // Check if current price swept the low then closed above
      if(Low[1] <= swingLow && Close[1] > swingLow)
         return true; // Protected low formed
      
      if(Low[0] <= swingLow && Close[0] > swingLow)
         return true; // Protected low forming
   }
   else if(bias == -1) // Bearish
   {
      // Find recent swing high
      double swingHigh = 0;
      int swingHighBar = 0;
      
      for(int i = 2; i <= maxBars; i++)
      {
         if(High[i] > swingHigh)
         {
            swingHigh = High[i];
            swingHighBar = i;
         }
      }
      
      // Check if current price swept the high then closed below
      if(High[1] >= swingHigh && Close[1] < swingHigh)
         return true; // Protected high formed
      
      if(High[0] >= swingHigh && Close[0] < swingHigh)
         return true; // Protected high forming
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Determine daily bias                                              |
//| Returns: 1 = bullish, -1 = bearish, 0 = neutral                  |
//+------------------------------------------------------------------+
int GetDailyBias()
{
   // Use daily candle structure
   double dailyHigh1 = iHigh(Symbol(), PERIOD_D1, 1);
   double dailyLow1 = iLow(Symbol(), PERIOD_D1, 1);
   double dailyClose1 = iClose(Symbol(), PERIOD_D1, 1);
   double dailyOpen1 = iOpen(Symbol(), PERIOD_D1, 1);
   
   double dailyHigh2 = iHigh(Symbol(), PERIOD_D1, 2);
   double dailyLow2 = iLow(Symbol(), PERIOD_D1, 2);
   double dailyClose2 = iClose(Symbol(), PERIOD_D1, 2);
   
   // Previous day closed outside prior day's range = continuation
   if(dailyClose1 > dailyHigh2) return 1;  // Bullish continuation
   if(dailyClose1 < dailyLow2) return -1;  // Bearish continuation
   
   // Previous day was bullish reversal
   if(dailyClose1 > dailyOpen1 && dailyLow1 < dailyLow2)
      return 1; // Bullish reversal
   
   // Previous day was bearish reversal
   if(dailyClose1 < dailyOpen1 && dailyHigh1 > dailyHigh2)
      return -1; // Bearish reversal
   
   // Use EMA as tiebreaker
   double ema20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   if(Close[0] > ema20 && ema20 > ema50) return 1;
   if(Close[0] < ema20 && ema20 < ema50) return -1;
   
   return 0; // Neutral
}

//+------------------------------------------------------------------+
//| Get previous day high/low for target                              |
//+------------------------------------------------------------------+
void GetDailyTarget(int bias, double &target)
{
   if(bias == 1) // Bullish — target previous day high
      target = iHigh(Symbol(), PERIOD_D1, 1);
   else if(bias == -1) // Bearish — target previous day low
      target = iLow(Symbol(), PERIOD_D1, 1);
   else
      target = 0;
}

//+------------------------------------------------------------------+
//| Execute Power of 3 Strategy                                       |
//+------------------------------------------------------------------+
void ExecutePowerOf3(double lotSize=0.01, double rrRatio=2.0)
{
   // Check if we already have an open PO3 trade
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() == MAGIC_PO3) return; // Already have a trade
   }
   
   // Get daily bias
   int bias = GetDailyBias();
   if(bias == 0) return; // No clear bias
   
   // Get current 4H candle analysis
   H4CandleAnalysis currentH4 = AnalyzeH4Candle(0);
   H4CandleAnalysis prevH4 = AnalyzeH4Candle(1);
   H4CandleAnalysis prev2H4 = AnalyzeH4Candle(2);
   
   if(currentH4.totalRange <= 0) return; // No data
   
   // Get current phase
   int phase = GetCurrentH4Phase();
   if(phase == 0) return; // Outside trading hours
   
   // Get daily target
   double dailyTarget;
   GetDailyTarget(bias, dailyTarget);
   
   // Determine entry scenario
   bool canTrade = false;
   double entryPrice, stopLoss, takeProfit;
   
   // Scenario 1: Continuation Expansion (Candle 3)
   // Previous candle had large opposing run (reversal)
   // Current candle should have shallow wick (expansion)
   if(phase == 3 && prevH4.isReversal)
   {
      if(bias == 1 && currentH4.hasShallowWick && currentH4.isBullish)
      {
         // Bullish: wait for protected low, then enter long
         if(DetectProtectedSwing(1))
         {
            entryPrice = Ask;
            stopLoss = currentH4.low - currentH4.totalRange * 0.1;
            double slDistance = entryPrice - stopLoss;
            takeProfit = MathMax(entryPrice + slDistance * rrRatio, dailyTarget);
            canTrade = true;
         }
      }
      else if(bias == -1 && currentH4.hasShallowWick && !currentH4.isBullish)
      {
         // Bearish: wait for protected high, then enter short
         if(DetectProtectedSwing(-1))
         {
            entryPrice = Bid;
            stopLoss = currentH4.high + currentH4.totalRange * 0.1;
            double slDistance = stopLoss - entryPrice;
            takeProfit = MathMin(entryPrice - slDistance * rrRatio, dailyTarget);
            canTrade = true;
         }
      }
   }
   
   // Scenario 2: Reversal Expansion (Candle 2)
   // Current candle has shallow wick = supports expansion within same candle
   if(!canTrade && phase == 2 && currentH4.hasShallowWick)
   {
      if(bias == 1 && currentH4.isBullish)
      {
         if(DetectProtectedSwing(1))
         {
            entryPrice = Ask;
            stopLoss = currentH4.low - currentH4.totalRange * 0.1;
            double slDistance = entryPrice - stopLoss;
            takeProfit = MathMax(entryPrice + slDistance * rrRatio, dailyTarget);
            canTrade = true;
         }
      }
      else if(bias == -1 && !currentH4.isBullish)
      {
         if(DetectProtectedSwing(-1))
         {
            entryPrice = Bid;
            stopLoss = currentH4.high + currentH4.totalRange * 0.1;
            double slDistance = stopLoss - entryPrice;
            takeProfit = MathMin(entryPrice - slDistance * rrRatio, dailyTarget);
            canTrade = true;
         }
      }
   }
   
   // Execute trade if all conditions met
   if(canTrade)
   {
      if(bias == 1) // Long
      {
         int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entryPrice, 3,
                                stopLoss, takeProfit, "PO3_Long", MAGIC_PO3, 0, clrGreen);
         if(ticket > 0)
         {
            Print("PO3 LONG: Phase=", phase, " Bias=Bullish, WickRatio=", 
                  NormalizeDouble(currentH4.lowerWickRatio, 2),
                  " Entry=", entryPrice, " SL=", stopLoss, " TP=", takeProfit);
         }
      }
      else if(bias == -1) // Short
      {
         int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entryPrice, 3,
                                stopLoss, takeProfit, "PO3_Short", MAGIC_PO3, 0, clrRed);
         if(ticket > 0)
         {
            Print("PO3 SHORT: Phase=", phase, " Bias=Bearish, WickRatio=",
                  NormalizeDouble(currentH4.upperWickRatio, 2),
                  " Entry=", entryPrice, " SL=", stopLoss, " TP=", takeProfit);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw 4H candle phases on chart (visual debugging)                 |
//+------------------------------------------------------------------+
void DrawPowerOf3Phases()
{
   // Mark the last 3 4H candles with their phases
   for(int i = 0; i < 3; i++)
   {
      int h4Bar = iBarShift(Symbol(), PERIOD_H4, Time[i * 4]);
      if(h4Bar < 0) continue;
      
      H4CandleAnalysis candle = AnalyzeH4Candle(i * 4);
      if(candle.totalRange <= 0) continue;
      
      string name = "PO3_Candle_" + IntegerToString(i);
      string label;
      color clr;
      
      if(candle.isReversal)
      {
         label = "Manipulation (C2)";
         clr = clrOrange;
      }
      else if(candle.isExpansion)
      {
         label = "Distribution (C3)";
         clr = clrLime;
      }
      else
      {
         label = "Accumulation (C1)";
         clr = clrGray;
      }
      
      ObjectCreate(0, name, OBJ_TEXT, 0, Time[i * 4], candle.high + 100 * Point);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   }
}

//+------------------------------------------------------------------+
//| Integration notes for DESTROYER QUANTUM:                          |
//|                                                                   |
//| 1. Add to OnInit():                                               |
//|    V23_RegisterStrategy("PO3", MAGIC_PO3);                        |
//|                                                                   |
//| 2. Add inputs:                                                    |
//|    extern bool InpPO3_Enabled = false;                             |
//|    extern double InpPO3_LotSize = 0.01;                            |
//|    extern double InpPO3_RRRatio = 2.0;                             |
//|    extern double InpPO3_ShallowWickRatio = 0.3;                    |
//|    extern double InpPO3_LargeWickRatio = 0.6;                      |
//|                                                                   |
//| 3. Add to OnTick():                                               |
//|    if(InpPO3_Enabled)                                              |
//|       ExecutePowerOf3(InpPO3_LotSize, InpPO3_RRRatio);            |
//|                                                                   |
//| 4. Add to g_perfData[]:                                           |
//|    {"PO3", MAGIC_PO3, 0,0,0,0,0.0},                               |
//+------------------------------------------------------------------+
