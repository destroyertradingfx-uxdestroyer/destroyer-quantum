//+------------------------------------------------------------------+
//| Gartley Harmonic Pattern Detector                                 |
//| Based on H.M. Gartley "Profits in the Stock Market" (1935)        |
//| For DESTROYER QUANTUM strategy library                            |
//+------------------------------------------------------------------+

// Fibonacci ratios for Gartley pattern
#define GARTLEY_AB_RATIO    0.618  // A-B = 61.8% of X-A
#define GARTLEY_BC_RATIO_LO 0.382  // B-C = 38.2% to 88.6% of A-B
#define GARTLEY_BC_RATIO_HI 0.886
#define GARTLEY_CD_RATIO    0.786  // C-D = 78.6% of X-A (entry point)
#define GARTLEY_TAKE_PROFIT 0.618  // TP at 61.8% retracement of C-D
#define GARTLEY_FIB_TOLERANCE 0.05 // 5% tolerance on Fibonacci ratios

// Magic numbers for Gartley trades
#define MAGIC_GARTLEY_BULL 9008
#define MAGIC_GARTLEY_BEAR 9009

//+------------------------------------------------------------------+
//| Structure to hold a detected Gartley pattern                      |
//+------------------------------------------------------------------+
struct GartleyPattern
{
   bool   isValid;        // Pattern found
   bool   isBullish;      // true = bullish, false = bearish
   double pointX;         // X point price
   double pointA;         // A point price
   double pointB;         // B point price
   double pointC;         // C point price
   double pointD;         // D point price (entry zone)
   int    barX;           // Bar index of X
   int    barA;           // Bar index of A
   int    barB;           // Bar index of B
   int    barC;           // Bar index of C
   int    barD;           // Bar index of D (current bar)
   double entryPrice;     // Entry at D
   double stopLoss;       // SL below/above X
   double takeProfit;     // TP at 61.8% retracement of C-D
   double fibAB;          // Actual AB/XA ratio
   double fibBC;          // Actual BC/AB ratio
   double fibCD;          // Actual CD/XA ratio
};

//+------------------------------------------------------------------+
//| Find swing highs and lows using ZigZag-like logic                |
//+------------------------------------------------------------------+
int FindSwingPoints(int lookback, double &highs[], double &lows[], 
                    int &highBars[], int &lowBars[], int depth=12)
{
   int highCount = 0;
   int lowCount = 0;
   
   for(int i = depth; i < lookback - depth; i++)
   {
      // Check for swing high
      bool isHigh = true;
      for(int j = 1; j <= depth; j++)
      {
         if(High[i] < High[i-j] || High[i] < High[i+j])
         {
            isHigh = false;
            break;
         }
      }
      if(isHigh && highCount < 50)
      {
         highs[highCount] = High[i];
         highBars[highCount] = i;
         highCount++;
      }
      
      // Check for swing low
      bool isLow = true;
      for(int j = 1; j <= depth; j++)
      {
         if(Low[i] > Low[i-j] || Low[i] > Low[i+j])
         {
            isLow = false;
            break;
         }
      }
      if(isLow && lowCount < 50)
      {
         lows[lowCount] = Low[i];
         lowBars[lowCount] = i;
         lowCount++;
      }
   }
   
   return highCount * 100 + lowCount; // Encode both counts
}

//+------------------------------------------------------------------+
//| Check if ratio is within tolerance of target                      |
//+------------------------------------------------------------------+
bool FibMatch(double actual, double target, double tolerance=GARTLEY_FIB_TOLERANCE)
{
   return (MathAbs(actual - target) <= tolerance);
}

//+------------------------------------------------------------------+
//| Detect Bullish Gartley Pattern                                    |
//| X(low) -> A(high) -> B(low) -> C(high) -> D(low) = BUY           |
//+------------------------------------------------------------------+
GartleyPattern DetectBullishGartley(int lookback=100, int depth=8)
{
   GartleyPattern pattern;
   pattern.isValid = false;
   pattern.isBullish = true;
   
   double swingHighs[50], swingLows[50];
   int highBars[50], lowBars[50];
   
   int counts = FindSwingPoints(lookback, swingHighs, swingLows, highBars, lowBars, depth);
   int highCount = counts / 100;
   int lowCount = counts % 100;
   
   if(highCount < 2 || lowCount < 3) return pattern;
   
   // Try to match Gartley pattern with recent swing points
   // Need: X(low), A(high), B(low), C(high), D(low)
   // X must be oldest, D must be newest
   
   for(int x = lowCount - 1; x >= 2; x--)     // X = oldest low
   {
      for(int a = highCount - 1; a >= 1; a--)  // A = high after X
      {
         if(highBars[a] >= lowBars[x]) continue; // A must be after X
         
         for(int b = x - 1; b >= 1; b--)       // B = low after A
         {
            if(lowBars[b] >= highBars[a]) continue; // B must be after A
            
            // Check AB = 61.8% of XA (retracement)
            double xaRange = swingHighs[a] - swingLows[x];
            if(xaRange <= 0) continue;
            
            double abRetrace = (swingHighs[a] - swingLows[b]) / xaRange;
            if(!FibMatch(abRetrace, GARTLEY_AB_RATIO, 0.08)) continue;
            
            for(int c = a - 1; c >= 0; c--)    // C = high after B
            {
               if(highBars[c] >= lowBars[b]) continue; // C must be after B
               
               // Check BC = 38.2% to 88.6% of AB
               double abRange = swingHighs[a] - swingLows[b];
               if(abRange <= 0) continue;
               
               double bcRetrace = (swingHighs[c] - swingLows[b]) / abRange;
               if(bcRetrace < GARTLEY_BC_RATIO_LO - 0.05 || 
                  bcRetrace > GARTLEY_BC_RATIO_HI + 0.05) continue;
               
               // D should be at current price level (near bar 0)
               // D = 78.6% retracement of XA
               double dTarget = swingLows[x] + xaRange * GARTLEY_CD_RATIO;
               double currentPrice = (Bid + Ask) / 2.0;
               
               // Check if current price is near the D target
               double cdRetrace = (swingHighs[c] - currentPrice) / xaRange;
               if(!FibMatch(cdRetrace, 1.0 - GARTLEY_CD_RATIO, 0.10)) continue;
               
               // Pattern found!
               pattern.isValid = true;
               pattern.pointX = swingLows[x];
               pattern.pointA = swingHighs[a];
               pattern.pointB = swingLows[b];
               pattern.pointC = swingHighs[c];
               pattern.pointD = currentPrice;
               pattern.barX = lowBars[x];
               pattern.barA = highBars[a];
               pattern.barB = lowBars[b];
               pattern.barC = highBars[c];
               pattern.barD = 0;
               pattern.entryPrice = dTarget;
               pattern.stopLoss = pattern.pointX - xaRange * 0.05; // Below X with buffer
               pattern.takeProfit = pattern.pointD + (pattern.pointC - pattern.pointD) * GARTLEY_TAKE_PROFIT;
               pattern.fibAB = abRetrace;
               pattern.fibBC = bcRetrace;
               pattern.fibCD = cdRetrace;
               
               return pattern; // Return first valid pattern found
            }
         }
      }
   }
   
   return pattern;
}

//+------------------------------------------------------------------+
//| Detect Bearish Gartley Pattern                                    |
//| X(high) -> A(low) -> B(high) -> C(low) -> D(high) = SELL         |
//+------------------------------------------------------------------+
GartleyPattern DetectBearishGartley(int lookback=100, int depth=8)
{
   GartleyPattern pattern;
   pattern.isValid = false;
   pattern.isBullish = false;
   
   double swingHighs[50], swingLows[50];
   int highBars[50], lowBars[50];
   
   int counts = FindSwingPoints(lookback, swingHighs, swingLows, highBars, lowBars, depth);
   int highCount = counts / 100;
   int lowCount = counts % 100;
   
   if(highCount < 3 || lowCount < 2) return pattern;
   
   // X(high), A(low), B(high), C(low), D(high) = SELL
   for(int x = highCount - 1; x >= 2; x--)
   {
      for(int a = lowCount - 1; a >= 1; a--)
      {
         if(lowBars[a] >= highBars[x]) continue;
         
         for(int b = x - 1; b >= 1; b--)
         {
            if(highBars[b] >= lowBars[a]) continue;
            
            double xaRange = swingHighs[x] - swingLows[a];
            if(xaRange <= 0) continue;
            
            double abRetrace = (swingHighs[b] - swingLows[a]) / xaRange;
            if(!FibMatch(abRetrace, GARTLEY_AB_RATIO, 0.08)) continue;
            
            for(int c = a - 1; c >= 0; c--)
            {
               if(lowBars[c] >= highBars[b]) continue;
               
               double abRange = swingHighs[b] - swingLows[a];
               if(abRange <= 0) continue;
               
               double bcRetrace = (swingHighs[b] - swingLows[c]) / abRange;
               if(bcRetrace < GARTLEY_BC_RATIO_LO - 0.05 || 
                  bcRetrace > GARTLEY_BC_RATIO_HI + 0.05) continue;
               
               double dTarget = swingHighs[x] - xaRange * GARTLEY_CD_RATIO;
               double currentPrice = (Bid + Ask) / 2.0;
               
               double cdRetrace = (currentPrice - swingLows[c]) / xaRange;
               if(!FibMatch(cdRetrace, 1.0 - GARTLEY_CD_RATIO, 0.10)) continue;
               
               pattern.isValid = true;
               pattern.pointX = swingHighs[x];
               pattern.pointA = swingLows[a];
               pattern.pointB = swingHighs[b];
               pattern.pointC = swingLows[c];
               pattern.pointD = currentPrice;
               pattern.barX = highBars[x];
               pattern.barA = lowBars[a];
               pattern.barB = highBars[b];
               pattern.barC = lowBars[c];
               pattern.barD = 0;
               pattern.entryPrice = dTarget;
               pattern.stopLoss = pattern.pointX + xaRange * 0.05;
               pattern.takeProfit = pattern.pointD - (pattern.pointD - pattern.pointC) * GARTLEY_TAKE_PROFIT;
               pattern.fibAB = abRetrace;
               pattern.fibBC = bcRetrace;
               pattern.fibCD = cdRetrace;
               
               return pattern;
            }
         }
      }
   }
   
   return pattern;
}

//+------------------------------------------------------------------+
//| Execute Gartley trade                                             |
//+------------------------------------------------------------------+
void ExecuteGartleyStrategy(bool enableBullish=true, bool enableBearish=true,
                            double lotSize=0.01, int maxBarsOld=20)
{
   // Detect patterns
   GartleyPattern bullPattern = DetectBullishGartley();
   GartleyPattern bearPattern = DetectBearishGartley();
   
   // Check if we already have open Gartley trades
   int bullTrades = 0, bearTrades = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() == MAGIC_GARTLEY_BULL) bullTrades++;
      if(OrderMagicNumber() == MAGIC_GARTLEY_BEAR) bearTrades++;
   }
   
   // Bullish Gartley entry
   if(enableBullish && bullPattern.isValid && bullTrades == 0)
   {
      // Check pattern is recent (D point within maxBarsOld of current bar)
      if(bullPattern.barX <= maxBarsOld)
      {
         double sl = bullPattern.stopLoss;
         double tp = bullPattern.takeProfit;
         double entry = Ask;
         
         // Check if price is near the D target (within 20 pips)
         if(MathAbs(entry - bullPattern.entryPrice) < 200 * Point)
         {
            int ticket = OrderSend(Symbol(), OP_BUY, lotSize, entry, 3, 
                                   sl, tp, "Gartley_Bull", MAGIC_GARTLEY_BULL, 0, clrGreen);
            if(ticket > 0)
            {
               Print("GARTLEY BULLISH ENTRY: X=", bullPattern.pointX, 
                     " A=", bullPattern.pointA, " B=", bullPattern.pointB,
                     " C=", bullPattern.pointC, " D=", bullPattern.pointD,
                     " AB=", NormalizeDouble(bullPattern.fibAB, 3),
                     " BC=", NormalizeDouble(bullPattern.fibBC, 3),
                     " SL=", sl, " TP=", tp);
            }
         }
      }
   }
   
   // Bearish Gartley entry
   if(enableBearish && bearPattern.isValid && bearTrades == 0)
   {
      if(bearPattern.barX <= maxBarsOld)
      {
         double sl = bearPattern.stopLoss;
         double tp = bearPattern.takeProfit;
         double entry = Bid;
         
         if(MathAbs(entry - bearPattern.entryPrice) < 200 * Point)
         {
            int ticket = OrderSend(Symbol(), OP_SELL, lotSize, entry, 3,
                                   sl, tp, "Gartley_Bear", MAGIC_GARTLEY_BEAR, 0, clrRed);
            if(ticket > 0)
            {
               Print("GARTLEY BEARISH ENTRY: X=", bearPattern.pointX,
                     " A=", bearPattern.pointA, " B=", bearPattern.pointB,
                     " C=", bearPattern.pointC, " D=", bearPattern.pointD,
                     " AB=", NormalizeDouble(bearPattern.fibAB, 3),
                     " BC=", NormalizeDouble(bearPattern.fibBC, 3),
                     " SL=", sl, " TP=", tp);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Gartley pattern on chart (for visual debugging)              |
//+------------------------------------------------------------------+
void DrawGartleyPattern(GartleyPattern &p, string prefix="Gartley")
{
   if(!p.isValid) return;
   
   color lineColor = p.isBullish ? clrLime : clrRed;
   string suffix = p.isBullish ? "_Bull" : "_Bear";
   
   // Draw X-A
   ObjectCreate(0, prefix+"_XA"+suffix, OBJ_TREND, 0, 
                Time[p.barX], p.pointX, Time[p.barA], p.pointA);
   ObjectSetInteger(0, prefix+"_XA"+suffix, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, prefix+"_XA"+suffix, OBJPROP_WIDTH, 2);
   
   // Draw A-B
   ObjectCreate(0, prefix+"_AB"+suffix, OBJ_TREND, 0,
                Time[p.barA], p.pointA, Time[p.barB], p.pointB);
   ObjectSetInteger(0, prefix+"_AB"+suffix, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, prefix+"_AB"+suffix, OBJPROP_WIDTH, 2);
   
   // Draw B-C
   ObjectCreate(0, prefix+"_BC"+suffix, OBJ_TREND, 0,
                Time[p.barB], p.pointB, Time[p.barC], p.pointC);
   ObjectSetInteger(0, prefix+"_BC"+suffix, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, prefix+"_BC"+suffix, OBJPROP_WIDTH, 2);
   
   // Draw C-D
   ObjectCreate(0, prefix+"_CD"+suffix, OBJ_TREND, 0,
                Time[p.barC], p.pointC, Time[0], p.pointD);
   ObjectSetInteger(0, prefix+"_CD"+suffix, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, prefix+"_CD"+suffix, OBJPROP_WIDTH, 2);
   
   // Label points
   string labels[] = {"X", "A", "B", "C", "D"};
   double prices[] = {p.pointX, p.pointA, p.pointB, p.pointC, p.pointD};
   int bars[] = {p.barX, p.barA, p.barB, p.barC, p.barD};
   
   for(int i = 0; i < 5; i++)
   {
      string name = prefix+"_"+labels[i]+suffix;
      ObjectCreate(0, name, OBJ_TEXT, 0, Time[bars[i]], prices[i]);
      ObjectSetString(0, name, OBJPROP_TEXT, labels[i]);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
   }
}

//+------------------------------------------------------------------+
//| Integration notes for DESTROYER QUANTUM:                          |
//|                                                                   |
//| 1. Add to OnInit():                                               |
//|    V23_RegisterStrategy("Gartley", MAGIC_GARTLEY_BULL);           |
//|    V23_RegisterStrategy("Gartley_Bear", MAGIC_GARTLEY_BEAR);      |
//|                                                                   |
//| 2. Add inputs:                                                    |
//|    extern bool InpGartley_Enabled = false;                         |
//|    extern double InpGartley_LotSize = 0.01;                        |
//|    extern int InpGartley_Depth = 8;                                |
//|    extern int InpGartley_Lookback = 100;                           |
//|    extern int InpGartley_MaxBarsOld = 20;                          |
//|                                                                   |
//| 3. Add to OnTick():                                               |
//|    if(InpGartley_Enabled)                                          |
//|       ExecuteGartleyStrategy(true, true, InpGartley_LotSize,       |
//|                              InpGartley_MaxBarsOld);               |
//|                                                                   |
//| 4. Add to g_perfData[]:                                           |
//|    {"Gartley_Bull", MAGIC_GARTLEY_BULL, 0,0,0,0,0.0},             |
//|    {"Gartley_Bear", MAGIC_GARTLEY_BEAR, 0,0,0,0,0.0},             |
//+------------------------------------------------------------------+
