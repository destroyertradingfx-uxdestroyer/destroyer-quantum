//+------------------------------------------------------------------+
//| A+ Strategy (FVG Breakout)                                        |
//| Range breakout + Fair Value Gap entry                             |
//| "No FVG = No Trade"                                               |
//| For DESTROYER QUANTUM strategy library                            |
//+------------------------------------------------------------------+

// Magic number for A+ FVG Breakout
#define MAGIC_APLUS 9013

//+------------------------------------------------------------------+
//| Get previous day range                                            |
//+------------------------------------------------------------------+
void GetPreviousDayRange(double &rangeHigh, double &rangeLow)
{
   rangeHigh = iHigh(Symbol(), PERIOD_D1, 1);
   rangeLow = iLow(Symbol(), PERIOD_D1, 1);
}

//+------------------------------------------------------------------+
//| Detect FVG for A+ strategy on current timeframe                   |
//| Returns: 1 = bullish FVG, -1 = bearish FVG, 0 = no FVG           |
//+------------------------------------------------------------------+
int DetectAPLUSFVG()
{
   // Check last 5 candles for FVG pattern
   // Bullish FVG: candle 1 high < candle 3 low (gap up)
   // Bearish FVG: candle 3 high < candle 1 low (gap down)
   
   for(int i = 1; i <= 3; i++)
   {
      double c1High = High[i + 2];
      double c1Low = Low[i + 2];
      double c3High = High[i];
      double c3Low = Low[i];
      
      // Bullish FVG
      if(c3Low > c1High)
      {
         // Verify this is at a breakout (price outside previous day range)
         double rangeHigh, rangeLow;
         GetPreviousDayRange(rangeHigh, rangeLow);
         
         if(Close[i] > rangeHigh) // Breakout above range
            return 1;
      }
      
      // Bearish FVG
      if(c3High < c1Low)
      {
         double rangeHigh, rangeLow;
         GetPreviousDayRange(rangeHigh, rangeLow);
         
         if(Close[i] < rangeLow) // Breakout below range
            return -1;
      }
   }
   
   return 0; // No FVG
}

//+------------------------------------------------------------------+
//| Get FVG zone prices                                               |
//+------------------------------------------------------------------+
bool GetFVGZone(int bias, double &fvgHigh, double &fvgLow)
{
   for(int i = 1; i <= 3; i++)
   {
      double c1High = High[i + 2];
      double c1Low = Low[i + 2];
      double c3High = High[i];
      double c3Low = Low[i];
      
      if(bias == 1 && c3Low > c1High) // Bullish FVG
      {
         fvgHigh = c3Low;
         fvgLow = c1High;
         return true;
      }
      else if(bias == -1 && c3High < c1Low) // Bearish FVG
      {
         fvgHigh = c1Low;
         fvgLow = c3High;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get candle 1 base for stop loss                                   |
//+------------------------------------------------------------------+
double GetCandle1Base(int bias)
{
   // Candle 1 = the first candle of the 3-candle FVG pattern
   // For bullish: use candle 1 low
   // For bearish: use candle 1 high
   
   if(bias == 1)
      return Low[3];   // Candle 1 low (3 bars back from entry)
   else
      return High[3];  // Candle 1 high
}

//+------------------------------------------------------------------+
//| Check time cutoff (12 PM EST = 17:00 server time)                |
//+------------------------------------------------------------------+
bool IsBeforeCutoff()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Adjust for your broker's server timezone
   // 12 PM EST = 17:00 UTC = adjust for your broker
   return (dt.hour < 17);
}

//+------------------------------------------------------------------+
//| Execute A+ FVG Breakout Strategy                                   |
//+------------------------------------------------------------------+
void ExecuteAPlusBreakout(double lotSize=0.01, double rrRatio=2.0)
{
   // Check if we already have an open A+ trade
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() == MAGIC_APLUS) return;
   }
   
   // Check time cutoff
   if(!IsBeforeCutoff()) return;
   
   // Get previous day range
   double rangeHigh, rangeLow;
   GetPreviousDayRange(rangeHigh, rangeLow);
   
   // Detect FVG
   int fvgBias = DetectAPLUSFVG();
   if(fvgBias == 0) return; // No FVG = No Trade
   
   // Get FVG zone
   double fvgHigh, fvgLow;
   if(!GetFVGZone(fvgBias, fvgHigh, fvgLow)) return;
   
   // Get candle 1 base for stop loss
   double candle1Base = GetCandle1Base(fvgBias);
   
   // Calculate entry, SL, TP
   double entryPrice, stopLoss, takeProfit;
   double slDistance;
   double buffer = 10 * Point;
   
   if(fvgBias == 1) // Long
   {
      // Limit order at FVG zone (use middle of FVG)
      entryPrice = (fvgHigh + fvgLow) / 2;
      stopLoss = candle1Base - buffer;
      slDistance = entryPrice - stopLoss;
      takeProfit = entryPrice + slDistance * rrRatio;
      
      // Check if price is near FVG zone
      if(Ask <= fvgHigh && Ask >= fvgLow)
      {
         int ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3,
                                stopLoss, takeProfit, "APlus_Long", MAGIC_APLUS, 0, clrGreen);
         if(ticket > 0)
         {
            Print("A+ LONG: FVG=", fvgLow, "-", fvgHigh, 
                  " Entry=", Ask, " SL=", stopLoss, " TP=", takeProfit);
         }
      }
   }
   else if(fvgBias == -1) // Short
   {
      entryPrice = (fvgHigh + fvgLow) / 2;
      stopLoss = candle1Base + buffer;
      slDistance = stopLoss - entryPrice;
      takeProfit = entryPrice - slDistance * rrRatio;
      
      if(Bid >= fvgLow && Bid <= fvgHigh)
      {
         int ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3,
                                stopLoss, takeProfit, "APlus_Short", MAGIC_APLUS, 0, clrRed);
         if(ticket > 0)
         {
            Print("A+ SHORT: FVG=", fvgLow, "-", fvgHigh,
                  " Entry=", Bid, " SL=", stopLoss, " TP=", takeProfit);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Integration notes for DESTROYER QUANTUM:                          |
//|                                                                   |
//| 1. Add to OnInit():                                               |
//|    V23_RegisterStrategy("APlus", MAGIC_APLUS);                    |
//|                                                                   |
//| 2. Add inputs:                                                    |
//|    extern bool InpAPlus_Enabled = false;                           |
//|    extern double InpAPlus_LotSize = 0.01;                          |
//|    extern double InpAPlus_RRRatio = 2.0;                           |
//|                                                                   |
//| 3. Add to OnTick():                                               |
//|    if(InpAPlus_Enabled)                                            |
//|       ExecuteAPlusBreakout(InpAPlus_LotSize, InpAPlus_RRRatio);   |
//|                                                                   |
//| 4. Add to g_perfData[]:                                           |
//|    {"APlus", MAGIC_APLUS, 0,0,0,0,0.0},                           |
//+------------------------------------------------------------------+
