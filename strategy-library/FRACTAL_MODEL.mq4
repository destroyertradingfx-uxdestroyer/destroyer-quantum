//+------------------------------------------------------------------+
//| Fractal Model Strategy                                            |
//| Multi-timeframe alignment / swing point + CISD + continuation OB  |
//| "Price cannot reverse without a swing point"                      |
//| For DESTROYER QUANTUM strategy library                            |
//+------------------------------------------------------------------+

// Magic number for Fractal Model
#define MAGIC_FRACTAL 9012

// Timeframe pairing for fractal model
// Structure TF -> Entry TF
// Monthly -> Daily
// Daily -> H1
// H4 -> M15/M5
// H1 -> M5
// M30 -> M3

// We'll use H4 as structure, M15 as entry for EURUSD H4 EA
#define STRUCTURE_TF PERIOD_H4
#define ENTRY_TF PERIOD_M15

// Point of Interest types
#define POI_NONE      0
#define POI_FVG       1  // Fair Value Gap
#define POI_OB        2  // Order Block
#define POI_EQH       3  // Equal Highs (bearish POI)
#define POI_EQL       4  // Equal Lows (bullish POI)

//+------------------------------------------------------------------+
//| Structure for Point of Interest                                   |
//+------------------------------------------------------------------+
struct PointOfInterest
{
   int type;         // POI_FVG, POI_OB, etc.
   double price;     // Center price of POI
   double high;      // Upper boundary
   double low;       // Lower boundary
   int bias;         // 1 = bullish POI, -1 = bearish POI
   datetime time;    // When POI formed
   bool isValid;
};

//+------------------------------------------------------------------+
//| Structure for Swing Point                                         |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double price;
   int direction;    // 1 = bullish swing (low), -1 = bearish swing (high)
   bool isProtected; // Has it been swept and closed back?
   datetime time;
   bool isValid;
};

//+------------------------------------------------------------------+
//| Get Daily Bias                                                    |
//| Returns: 1 = bullish, -1 = bearish, 0 = neutral                  |
//+------------------------------------------------------------------+
int GetFractalDailyBias()
{
   double prevDayHigh = iHigh(Symbol(), PERIOD_D1, 1);
   double prevDayLow = iLow(Symbol(), PERIOD_D1, 1);
   double prevDayClose = iClose(Symbol(), PERIOD_D1, 1);
   double prevDayOpen = iOpen(Symbol(), PERIOD_D1, 1);
   
   double prev2DayHigh = iHigh(Symbol(), PERIOD_D1, 2);
   double prev2DayLow = iLow(Symbol(), PERIOD_D1, 2);
   
   // Continuation: close outside previous range
   if(prevDayClose > prev2DayHigh) return 1;  // Bullish continuation
   if(prevDayClose < prev2DayLow) return -1;  // Bearish continuation
   
   // Reversal: sweep + close back inside
   // Bullish reversal: sweep previous low, close back above
   if(prevDayLow < prev2DayLow && prevDayClose > prev2DayLow)
      return 1;
   
   // Bearish reversal: sweep previous high, close back below
   if(prevDayHigh > prev2DayHigh && prevDayClose < prev2DayHigh)
      return -1;
   
   // Inside day — use EMA
   double ema20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   if(Close[0] > ema20 && ema20 > ema50) return 1;
   if(Close[0] < ema20 && ema20 < ema50) return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gap on structure timeframe                      |
//+------------------------------------------------------------------+
PointOfInterest DetectFVG(int bias, int lookback=50)
{
   PointOfInterest poi;
   poi.isValid = false;
   poi.type = POI_FVG;
   poi.bias = bias;
   
   for(int i = 2; i < lookback; i++)
   {
      double h1 = iHigh(Symbol(), STRUCTURE_TF, i + 1);
      double l1 = iLow(Symbol(), STRUCTURE_TF, i + 1);
      double h2 = iHigh(Symbol(), STRUCTURE_TF, i);
      double l2 = iLow(Symbol(), STRUCTURE_TF, i);
      double h3 = iHigh(Symbol(), STRUCTURE_TF, i - 1);
      double l3 = iLow(Symbol(), STRUCTURE_TF, i - 1);
      
      if(bias == 1) // Bullish FVG: gap between candle 1 high and candle 3 low
      {
         if(l3 > h1) // Gap exists
         {
            // Check if price has reached into this FVG
            double currentPrice = Close[0];
            if(currentPrice <= l3 && currentPrice >= h1)
            {
               poi.high = l3;
               poi.low = h1;
               poi.price = (poi.high + poi.low) / 2;
               poi.time = iTime(Symbol(), STRUCTURE_TF, i);
               poi.isValid = true;
               return poi;
            }
         }
      }
      else if(bias == -1) // Bearish FVG: gap between candle 3 high and candle 1 low
      {
         if(h3 < l1) // Gap exists
         {
            double currentPrice = Close[0];
            if(currentPrice >= h3 && currentPrice <= l1)
            {
               poi.high = l1;
               poi.low = h3;
               poi.price = (poi.high + poi.low) / 2;
               poi.time = iTime(Symbol(), STRUCTURE_TF, i);
               poi.isValid = true;
               return poi;
            }
         }
      }
   }
   
   return poi;
}

//+------------------------------------------------------------------+
//| Detect Order Block on structure timeframe                         |
//+------------------------------------------------------------------+
PointOfInterest DetectOrderBlock(int bias, int lookback=30)
{
   PointOfInterest poi;
   poi.isValid = false;
   poi.type = POI_OB;
   poi.bias = bias;
   
   for(int i = 2; i < lookback; i++)
   {
      double o = iOpen(Symbol(), STRUCTURE_TF, i);
      double c = iClose(Symbol(), STRUCTURE_TF, i);
      double h = iHigh(Symbol(), STRUCTURE_TF, i);
      double l = iLow(Symbol(), STRUCTURE_TF, i);
      
      if(bias == 1) // Bullish OB: last down-close candle before expansion
      {
         if(c < o) // Down-close candle
         {
            // Check if followed by up-close expansion
            double nextC = iClose(Symbol(), STRUCTURE_TF, i - 1);
            double nextO = iOpen(Symbol(), STRUCTURE_TF, i - 1);
            if(nextC > nextO && nextC > h) // Expansion
            {
               double currentPrice = Close[0];
               if(currentPrice <= h && currentPrice >= l)
               {
                  poi.high = h;
                  poi.low = l;
                  poi.price = (poi.high + poi.low) / 2;
                  poi.time = iTime(Symbol(), STRUCTURE_TF, i);
                  poi.isValid = true;
                  return poi;
               }
            }
         }
      }
      else if(bias == -1) // Bearish OB: last up-close candle before expansion
      {
         if(c > o) // Up-close candle
         {
            double nextC = iClose(Symbol(), STRUCTURE_TF, i - 1);
            double nextO = iOpen(Symbol(), STRUCTURE_TF, i - 1);
            if(nextC < nextO && nextC < l) // Expansion
            {
               double currentPrice = Close[0];
               if(currentPrice >= l && currentPrice <= h)
               {
                  poi.high = h;
                  poi.low = l;
                  poi.price = (poi.high + poi.low) / 2;
                  poi.time = iTime(Symbol(), STRUCTURE_TF, i);
                  poi.isValid = true;
                  return poi;
               }
            }
         }
      }
   }
   
   return poi;
}

//+------------------------------------------------------------------+
//| Detect Change in State of Delivery (CISD) on entry timeframe     |
//+------------------------------------------------------------------+
bool DetectCISD(int bias, int lookback=20)
{
   // CISD: price sweeps protected swing then closes through series of opposing candles
   
   if(bias == 1) // Bullish CISD: sweep low, close above series of down-close candles
   {
      // Find recent swing low on entry TF
      double swingLow = 999999;
      for(int i = 2; i <= lookback; i++)
      {
         double l = iLow(Symbol(), ENTRY_TF, i);
         if(l < swingLow) swingLow = l;
      }
      
      // Check if price swept low and closed above
      double currentLow = iLow(Symbol(), ENTRY_TF, 1);
      double currentClose = iClose(Symbol(), ENTRY_TF, 1);
      
      if(currentLow <= swingLow && currentClose > swingLow)
         return true;
   }
   else if(bias == -1) // Bearish CISD: sweep high, close below series of up-close candles
   {
      double swingHigh = 0;
      for(int i = 2; i <= lookback; i++)
      {
         double h = iHigh(Symbol(), ENTRY_TF, i);
         if(h > swingHigh) swingHigh = h;
      }
      
      double currentHigh = iHigh(Symbol(), ENTRY_TF, 1);
      double currentClose = iClose(Symbol(), ENTRY_TF, 1);
      
      if(currentHigh >= swingHigh && currentClose < swingHigh)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Continuation Order Block on entry timeframe                |
//+------------------------------------------------------------------+
bool DetectContinuationOB(int bias, int lookback=15)
{
   // Continuation OB: close through series of opposing candles
   
   if(bias == 1) // Bullish: close above series of down-close candles
   {
      int downCandles = 0;
      for(int i = 2; i <= lookback; i++)
      {
         double o = iOpen(Symbol(), ENTRY_TF, i);
         double c = iClose(Symbol(), ENTRY_TF, i);
         if(c < o) downCandles++;
         else break;
      }
      
      if(downCandles >= 2) // At least 2 opposing candles
      {
         // Check if current candle closed above them
         double highestDown = 0;
         for(int i = 2; i <= downCandles + 1; i++)
         {
            double h = iHigh(Symbol(), ENTRY_TF, i);
            if(h > highestDown) highestDown = h;
         }
         
         if(iClose(Symbol(), ENTRY_TF, 1) > highestDown)
            return true;
      }
   }
   else if(bias == -1) // Bearish: close below series of up-close candles
   {
      int upCandles = 0;
      for(int i = 2; i <= lookback; i++)
      {
         double o = iOpen(Symbol(), ENTRY_TF, i);
         double c = iClose(Symbol(), ENTRY_TF, i);
         if(c > o) upCandles++;
         else break;
      }
      
      if(upCandles >= 2)
      {
         double lowestUp = 999999;
         for(int i = 2; i <= upCandles + 1; i++)
         {
            double l = iLow(Symbol(), ENTRY_TF, i);
            if(l < lowestUp) lowestUp = l;
         }
         
         if(iClose(Symbol(), ENTRY_TF, 1) < lowestUp)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get protected swing for stop loss                                 |
//+------------------------------------------------------------------+
double GetProtectedSwing(int bias, int lookback=20)
{
   if(bias == 1) // Bullish: stop below protected low
   {
      double swingLow = 999999;
      for(int i = 2; i <= lookback; i++)
      {
         double l = iLow(Symbol(), ENTRY_TF, i);
         if(l < swingLow) swingLow = l;
      }
      return swingLow;
   }
   else // Bearish: stop above protected high
   {
      double swingHigh = 0;
      for(int i = 2; i <= lookback; i++)
      {
         double h = iHigh(Symbol(), ENTRY_TF, i);
         if(h > swingHigh) swingHigh = h;
      }
      return swingHigh;
   }
}

//+------------------------------------------------------------------+
//| Get daily target                                                  |
//+------------------------------------------------------------------+
double GetFractalTarget(int bias)
{
   if(bias == 1)
      return iHigh(Symbol(), PERIOD_D1, 1); // Previous day high
   else
      return iLow(Symbol(), PERIOD_D1, 1);  // Previous day low
}

//+------------------------------------------------------------------+
//| Execute Fractal Model Strategy                                     |
//+------------------------------------------------------------------+
void ExecuteFractalModel(double lotSize=0.01, double rrRatio=2.0)
{
   // Check if we already have an open Fractal trade
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() == MAGIC_FRACTAL) return;
   }
   
   // Step 1: Get daily bias
   int bias = GetFractalDailyBias();
   if(bias == 0) return;
   
   // Step 2: Look for Point of Interest on structure TF
   PointOfInterest fvg = DetectFVG(bias);
   PointOfInterest ob = DetectOrderBlock(bias);
   
   PointOfInterest poi;
   if(fvg.isValid) poi = fvg;
   else if(ob.isValid) poi = ob;
   else return; // No POI found
   
   // Step 3: Check for CISD on entry TF (confirms swing point)
   if(!DetectCISD(bias)) return;
   
   // Step 4: Check for Continuation Order Block on entry TF
   if(!DetectContinuationOB(bias)) return;
   
   // All conditions met — enter trade
   double entryPrice, stopLoss, takeProfit;
   double slDistance;
   double protectedSwing = GetProtectedSwing(bias);
   double dailyTarget = GetFractalTarget(bias);
   
   // Buffer for stop loss
   double buffer = (Ask - Bid) * 2 + 10 * Point;
   
   if(bias == 1) // Long
   {
      entryPrice = Ask;
      stopLoss = protectedSwing - buffer;
      slDistance = entryPrice - stopLoss;
      takeProfit = MathMax(entryPrice + slDistance * rrRatio, dailyTarget);
      
      // Ensure minimum R:R
      if(takeProfit - entryPrice < slDistance * 1.5) return;
      
      int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entryPrice, 3,
                             stopLoss, takeProfit, "Fractal_Long", MAGIC_FRACTAL, 0, clrGreen);
      if(ticket > 0)
      {
         Print("FRACTAL LONG: Bias=Bullish, POI=", poi.type, 
               " ProtectedSwing=", protectedSwing,
               " Entry=", entryPrice, " SL=", stopLoss, " TP=", takeProfit);
      }
   }
   else if(bias == -1) // Short
   {
      entryPrice = Bid;
      stopLoss = protectedSwing + buffer;
      slDistance = stopLoss - entryPrice;
      takeProfit = MathMin(entryPrice - slDistance * rrRatio, dailyTarget);
      
      if(entryPrice - takeProfit < slDistance * 1.5) return;
      
      int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entryPrice, 3,
                             stopLoss, takeProfit, "Fractal_Short", MAGIC_FRACTAL, 0, clrRed);
      if(ticket > 0)
      {
         Print("FRACTAL SHORT: Bias=Bearish, POI=", poi.type,
               " ProtectedSwing=", protectedSwing,
               " Entry=", entryPrice, " SL=", stopLoss, " TP=", takeProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| Integration notes for DESTROYER QUANTUM:                          |
//|                                                                   |
//| 1. Add to OnInit():                                               |
//|    V23_RegisterStrategy("Fractal", MAGIC_FRACTAL);                |
//|                                                                   |
//| 2. Add inputs:                                                    |
//|    extern bool InpFractal_Enabled = false;                         |
//|    extern double InpFractal_LotSize = 0.01;                        |
//|    extern double InpFractal_RRRatio = 2.0;                         |
//|                                                                   |
//| 3. Add to OnTick():                                               |
//|    if(InpFractal_Enabled)                                          |
//|       ExecuteFractalModel(InpFractal_LotSize, InpFractal_RRRatio);|
//|                                                                   |
//| 4. Add to g_perfData[]:                                           |
//|    {"Fractal", MAGIC_FRACTAL, 0,0,0,0,0.0},                       |
//+------------------------------------------------------------------+
