//+------------------------------------------------------------------+
//| FAIR VALUE GAP (FVG) STRATEGY  MQL4 Implementation             |
//| For DESTROYER QUANTUM EA  EURUSD H4                             |
//| Magic: 9007, Index: 18                                           |
//|                                                                  |
//| STRATEGY: After a liquidity sweep (session/prior-day high/low),  |
//| wait for price to retrace into an unmitigated FVG zone, then     |
//| enter in the direction of the sweep.                             |
//+------------------------------------------------------------------+

// 
// 1. INPUT PARAMETERS (add to EA's input section)
// 
/*
sinput string Inp_Header_FVG        = "====== V28.XX: FAIR VALUE GAP (FVG) ======";
input bool    InpFVG_Enabled          = true;       // Enable FVG Strategy
input int     InpFVG_MagicNumber      = 9007;       // Magic number for FVG
input int     InpFVG_MaxConcurrent    = 1;          // Max concurrent FVG trades
input double  InpFVG_MinSizePips      = 5.0;        // Minimum FVG size in pips (filter noise)
input double  InpFVG_MaxSizePips      = 80.0;       // Maximum FVG size (too big = breakaway gap)
input int     InpFVG_MaxFVGAge_Bars   = 20;         // Max age of FVG in H4 bars (older = less relevant)
input int     InpFVG_SweepLookback    = 6;          // H4 bars to look back for session high/low (~1 day)
input double  InpFVG_SL_Buffer_ATR    = 0.3;        // ATR buffer below/above FVG for SL
input double  InpFVG_TP_RR            = 2.5;        // Risk:Reward ratio for TP
input int     InpFVG_MaxSweepRetrace  = 5;          // Max bars between sweep and FVG entry
input int     InpFVG_TradeStartHour   = 7;          // Server hour: London open
input int     InpFVG_TradeEndHour     = 17;         // Server hour: NY close (approx)
input bool    InpFVG_RequireEMAFilter = true;       // Require EMA trend alignment
input int     InpFVG_EMA_Period       = 50;         // EMA period for trend filter
*/

// 
// 2. DATA STRUCTURES
// 

#define MAX_FVG_STORED 50

struct FVGRecord {
   double   top;           // Upper boundary of FVG zone
   double   bottom;        // Lower boundary of FVG zone
   datetime barTime;       // Time of the middle candle (for uniqueness)
   int      direction;     // +1 = bullish FVG, -1 = bearish FVG
   bool     mitigated;     // True once price has filled the gap or trade taken
   int      sweepConfirmed;// 0=none, +1=bullish sweep, -1=bearish sweep
   datetime sweepTime;     // When the sweep was confirmed
};

// 
// 3. GLOBAL VARIABLES
// 

FVGRecord g_fvgStore[MAX_FVG_STORED];
int       g_fvgCount = 0;
datetime  g_lastFVGScanTime = 0;

// 
// 4. HELPER FUNCTIONS
// 

//+------------------------------------------------------------------+
//| Check if current time is within the FVG trading window           |
//+------------------------------------------------------------------+
bool IsFVGTradeWindow()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // No trading on weekends
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   
   // Only during London/NY active hours
   if(dt.hour < InpFVG_TradeStartHour || dt.hour >= InpFVG_TradeEndHour)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check EMA trend alignment                                        |
//+------------------------------------------------------------------+
bool IsEMATrendAligned(int direction)
{
   if(!InpFVG_RequireEMAFilter) return true;
   
   double ema = iMA(Symbol(), PERIOD_H4, InpFVG_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(ema <= 0) return true; // Fail-open if EMA not available
   
   if(direction == OP_BUY)  return (Ask > ema);  // Price above EMA for buys
   if(direction == OP_SELL) return (Bid < ema);   // Price below EMA for sells
   return false;
}

//+------------------------------------------------------------------+
//| Get session high from recent H4 bars                             |
//+------------------------------------------------------------------+
double GetSessionHigh(int lookbackBars)
{
   double highest = 0;
   // Start from bar 2 (skip current forming bar)
   for(int i = 2; i <= lookbackBars + 1; i++)
   {
      if(High[i] > highest) highest = High[i];
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Get session low from recent H4 bars                              |
//+------------------------------------------------------------------+
double GetSessionLow(int lookbackBars)
{
   double lowest = DBL_MAX;
   for(int i = 2; i <= lookbackBars + 1; i++)
   {
      if(Low[i] < lowest) lowest = Low[i];
   }
   return lowest;
}

// 
// 5. FVG STORAGE MANAGEMENT
// 

//+------------------------------------------------------------------+
//| Add a new FVG to the store (with dedup and size filter)          |
//+------------------------------------------------------------------+
void AddFVG(double top, double bottom, datetime barTime, int direction)
{
   // Check if this FVG already exists (avoid duplicates)
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgStore[i].barTime == barTime && g_fvgStore[i].direction == direction)
         return; // Already tracked
   }
   
   // Size filter: FVG must be large enough to trade
   double fvgSizePips = (top - bottom) / (Point * 10);
   if(fvgSizePips < InpFVG_MinSizePips) return;
   if(fvgSizePips > InpFVG_MaxSizePips) return;  // Skip breakaway gaps
   
   // Shift everything down if at capacity (FIFO  oldest removed)
   if(g_fvgCount >= MAX_FVG_STORED)
   {
      for(int j = 0; j < MAX_FVG_STORED - 1; j++)
         g_fvgStore[j] = g_fvgStore[j + 1];
      g_fvgCount = MAX_FVG_STORED - 1;
   }
   
   // Store new FVG
   g_fvgStore[g_fvgCount].top          = top;
   g_fvgStore[g_fvgCount].bottom       = bottom;
   g_fvgStore[g_fvgCount].barTime      = barTime;
   g_fvgStore[g_fvgCount].direction    = direction;
   g_fvgStore[g_fvgCount].mitigated    = false;
   g_fvgStore[g_fvgCount].sweepConfirmed = 0;
   g_fvgStore[g_fvgCount].sweepTime    = 0;
   g_fvgCount++;
}

//+------------------------------------------------------------------+
//| Update mitigation status  mark FVGs that price has filled       |
//+------------------------------------------------------------------+
void UpdateFVG_Mitigation()
{
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgStore[i].mitigated) continue;
      
      // Bullish FVG: mitigated when price drops into/touches the zone
      if(g_fvgStore[i].direction == 1)
      {
         if(Low[0] <= g_fvgStore[i].top)
            g_fvgStore[i].mitigated = true;
      }
      // Bearish FVG: mitigated when price rises into/touches the zone
      else
      {
         if(High[0] >= g_fvgStore[i].bottom)
            g_fvgStore[i].mitigated = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Periodic cleanup  remove expired/mitigated FVGs                 |
//+------------------------------------------------------------------+
void CleanupFVGStore()
{
   int writeIdx = 0;
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgStore[i].mitigated) continue;
      
      // Also expire by age
      int age = iBarShift(Symbol(), PERIOD_H4, g_fvgStore[i].barTime);
      if(age > InpFVG_MaxFVGAge_Bars) continue;
      
      if(writeIdx != i)
         g_fvgStore[writeIdx] = g_fvgStore[i];
      writeIdx++;
   }
   g_fvgCount = writeIdx;
}

// 
// 6. FVG SCANNING (Called once per new bar)
// 

//+------------------------------------------------------------------+
//| Scan completed bars for FVG patterns                             |
//| Convention: shift = index of the RIGHTMOST candle in the 3-bar   |
//| pattern. Candles are at shift+2 (left), shift+1 (middle),       |
//| shift (right).                                                   |
//+------------------------------------------------------------------+
void ScanForNewFVGs()
{
   // Only scan on new bar
   if(Time[0] == g_lastFVGScanTime) return;
   g_lastFVGScanTime = Time[0];
   
   // Scan completed bars for FVG patterns
   // We need at least shift+2 to be a valid bar, so shift goes from 1 to 48
   for(int shift = 1; shift <= 48; shift++)
   {
      // Skip if too old
      if(shift > InpFVG_MaxFVGAge_Bars) continue;
      
      //  BULLISH FVG 
      // Middle candle surged UP so much that:
      // Low of left candle (shift+2) > High of right candle (shift)
      // This creates an upside gap between them
      if(Low[shift + 2] > High[shift])
      {
         double fvgTop    = Low[shift + 2];   // Upper boundary (left candle's low)
         double fvgBottom = High[shift];       // Lower boundary (right candle's high)
         AddFVG(fvgTop, fvgBottom, Time[shift + 1], +1);
      }
      
      //  BEARISH FVG 
      // Middle candle dropped so hard that:
      // High of left candle (shift+2) < Low of right candle (shift)
      // This creates a downside gap between them
      if(High[shift + 2] < Low[shift])
      {
         double fvgTop    = Low[shift];        // Upper boundary (right candle's low)
         double fvgBottom = High[shift + 2];   // Lower boundary (left candle's high)
         AddFVG(fvgTop, fvgBottom, Time[shift + 1], -1);
      }
   }
}

// 
// 7. LIQUIDITY SWEEP DETECTION (Called once per new bar)
// 

//+------------------------------------------------------------------+
//| Detect if the last completed bar swept a key liquidity level     |
//| and mark relevant FVGs with sweep confirmation                   |
//+------------------------------------------------------------------+
void DetectLiquiditySweeps()
{
   // Use the most recently completed bar (shift=1)
   
   // Previous day high/low from D1
   double prevDayHigh = iHigh(Symbol(), PERIOD_D1, 1);
   double prevDayLow  = iLow(Symbol(), PERIOD_D1, 1);
   
   // Session high/low from recent H4 bars (approximates intraday session)
   double sessionHigh = GetSessionHigh(InpFVG_SweepLookback);
   double sessionLow  = GetSessionLow(InpFVG_SweepLookback);
   
   //  BEARISH SWEEP: Price swept above a key level but closed back below 
   bool sweptAbovePDH = (High[1] > prevDayHigh && Close[1] < prevDayHigh);
   bool sweptAboveSH  = (High[1] > sessionHigh && Close[1] < sessionHigh);
   
   if(sweptAbovePDH || sweptAboveSH)
   {
      // A bearish sweep occurred  mark unmitigated bearish FVGs
      // (Price took buy-side liquidity, now likely to reverse down into bearish FVGs)
      for(int i = 0; i < g_fvgCount; i++)
      {
         if(!g_fvgStore[i].mitigated && g_fvgStore[i].direction == -1)
         {
            // Only mark FVGs that are ABOVE the current price (price needs to rally into them)
            if(g_fvgStore[i].bottom > Close[1])
            {
               g_fvgStore[i].sweepConfirmed = -1;
               g_fvgStore[i].sweepTime = Time[1];
            }
         }
      }
   }
   
   //  BULLISH SWEEP: Price swept below a key level but closed back above 
   bool sweptBelowPDL = (Low[1] < prevDayLow && Close[1] > prevDayLow);
   bool sweptBelowSL  = (Low[1] < sessionLow && Close[1] > sessionLow);
   
   if(sweptBelowPDL || sweptBelowSL)
   {
      // A bullish sweep occurred  mark unmitigated bullish FVGs
      // (Price took sell-side liquidity, now likely to reverse up into bullish FVGs)
      for(int i = 0; i < g_fvgCount; i++)
      {
         if(!g_fvgStore[i].mitigated && g_fvgStore[i].direction == +1)
         {
            // Only mark FVGs that are BELOW the current price (price needs to drop into them)
            if(g_fvgStore[i].top < Close[1])
            {
               g_fvgStore[i].sweepConfirmed = +1;
               g_fvgStore[i].sweepTime = Time[1];
            }
         }
      }
   }
}

// 
// 8. MAIN STRATEGY FUNCTION
// 

//+------------------------------------------------------------------+
//| ExecuteFVGStrategy  Main entry point, called from OnTick        |
//| Integrates with DESTROYER_QUANTUM's strategy dispatch pattern    |
//+------------------------------------------------------------------+
void ExecuteFVGStrategy()
{
   //  Pre-checks 
   if(!InpFVG_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpFVG_MagicNumber) >= InpFVG_MaxConcurrent) return;
   if(!IsStrategyHealthy(InpFVG_MagicNumber)) return;
   if(!IsFVGTradeWindow()) return;
   
   double spread = (Ask - Bid) / Point;
   if(spread > InpMax_Spread_Pips * 10) return;
   
   //  STEP 1: Scan for new FVGs (once per bar) 
   ScanForNewFVGs();
   
   //  STEP 2: Detect sweeps and mark FVGs (once per bar) 
   DetectLiquiditySweeps();
   
   //  STEP 3: Cleanup expired/mitigated FVGs 
   CleanupFVGStore();
   
   //  STEP 4: Update mitigation status (every tick  for live entries) 
   UpdateFVG_Mitigation();
   
   //  STEP 5: Look for entry 
   double atr = iATR(Symbol(), PERIOD_H4, 14, 0);
   if(atr <= 0) return;
   
   int stratIdx = GetStrategyIndex(InpFVG_MagicNumber);
   
   // Scan all stored FVGs for a valid entry
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgStore[i].mitigated) continue;
      if(g_fvgStore[i].sweepConfirmed == 0) continue;
      
      // Check FVG age  don't trade stale FVGs
      int fvgBarAge = iBarShift(Symbol(), PERIOD_H4, g_fvgStore[i].barTime);
      if(fvgBarAge > InpFVG_MaxFVGAge_Bars)
      {
         g_fvgStore[i].mitigated = true; // Expire it
         continue;
      }
      
      // Check if sweep is still fresh (within MaxSweepRetrace bars)
      int sweepAge = iBarShift(Symbol(), PERIOD_H4, g_fvgStore[i].sweepTime);
      if(sweepAge > InpFVG_MaxSweepRetrace) continue;
      
      // 
      // BUY ENTRY: Bullish FVG + Bullish sweep + Price inside FVG
      // 
      if(g_fvgStore[i].direction == +1 && g_fvgStore[i].sweepConfirmed == +1)
      {
         // Price must be touching/inside the FVG zone
         if(Ask >= g_fvgStore[i].bottom && Ask <= g_fvgStore[i].top)
         {
            if(!IsEMATrendAligned(OP_BUY)) continue;
            
            // SL: Below the FVG zone + ATR buffer
            double slPrice = g_fvgStore[i].bottom - (atr * InpFVG_SL_Buffer_ATR);
            double slDist  = Ask - slPrice;
            
            // Sanity: SL distance must be reasonable (0.5 - 4.0 ATR)
            double slInATR = slDist / atr;
            if(slInATR < 0.5 || slInATR > 4.0) continue;
            
            // TP: R:R based
            double tpPrice = Ask + (slDist * InpFVG_TP_RR);
            
            double lots = MoneyManagement_Quantum(InpFVG_MagicNumber, InpBase_Risk_Percent);
            if(lots <= 0) continue;
            
            int ticket = OpenTrade(OP_BUY, lots, Ask, slPrice, tpPrice,
                                   "FVG_BUY", InpFVG_MagicNumber);
            if(ticket > 0)
            {
               g_fvgStore[i].mitigated = true; // Consume this FVG
               if(stratIdx >= 0) g_perfData[stratIdx].trades++;
               LogError(ERROR_INFO,
                  "FVG BUY: Zone[" + DoubleToString(g_fvgStore[i].bottom, 5) + "-" +
                  DoubleToString(g_fvgStore[i].top, 5) + "] SL=" + DoubleToString(slPrice, 5) +
                  " TP=" + DoubleToString(tpPrice, 5), "ExecuteFVGStrategy");
            }
            return; // One trade per tick
         }
      }
      
      // 
      // SELL ENTRY: Bearish FVG + Bearish sweep + Price inside FVG
      // 
      if(g_fvgStore[i].direction == -1 && g_fvgStore[i].sweepConfirmed == -1)
      {
         // Price must be touching/inside the FVG zone
         if(Bid >= g_fvgStore[i].bottom && Bid <= g_fvgStore[i].top)
         {
            if(!IsEMATrendAligned(OP_SELL)) continue;
            
            // SL: Above the FVG zone + ATR buffer
            double slPrice = g_fvgStore[i].top + (atr * InpFVG_SL_Buffer_ATR);
            double slDist  = slPrice - Bid;
            
            double slInATR = slDist / atr;
            if(slInATR < 0.5 || slInATR > 4.0) continue;
            
            // TP: R:R based
            double tpPrice = Bid - (slDist * InpFVG_TP_RR);
            
            double lots = MoneyManagement_Quantum(InpFVG_MagicNumber, InpBase_Risk_Percent);
            if(lots <= 0) continue;
            
            int ticket = OpenTrade(OP_SELL, lots, Bid, slPrice, tpPrice,
                                   "FVG_SELL", InpFVG_MagicNumber);
            if(ticket > 0)
            {
               g_fvgStore[i].mitigated = true;
               if(stratIdx >= 0) g_perfData[stratIdx].trades++;
               LogError(ERROR_INFO,
                  "FVG SELL: Zone[" + DoubleToString(g_fvgStore[i].bottom, 5) + "-" +
                  DoubleToString(g_fvgStore[i].top, 5) + "] SL=" + DoubleToString(slPrice, 5) +
                  " TP=" + DoubleToString(tpPrice, 5), "ExecuteFVGStrategy");
            }
            return;
         }
      }
   }
}

// 
// 9. VISUAL OVERLAY (Optional  for debugging/monitoring)
// 

//+------------------------------------------------------------------+
//| Draw FVG zones on chart as colored rectangles                    |
//| Call from OnTick or OnChartEvent for live monitoring              |
//+------------------------------------------------------------------+
void DrawFVGZones()
{
   // Delete old FVG objects
   ObjectsDeleteAll(0, "FVG_");
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgStore[i].mitigated) continue;
      
      string name = "FVG_" + IntegerToString(i);
      datetime t1 = g_fvgStore[i].barTime;
      datetime t2 = Time[0] + PeriodSeconds();
      
      color clr;
      if(g_fvgStore[i].sweepConfirmed != 0)
         clr = clrGold;         // Highlighted = ready to trade
      else if(g_fvgStore[i].direction == 1)
         clr = clrDodgerBlue;   // Bullish FVG
      else
         clr = clrOrangeRed;    // Bearish FVG
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, g_fvgStore[i].top, t2, g_fvgStore[i].bottom);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   }
}

// 
// 10. EA INTEGRATION POINTS (Changes needed in main EA file)
// 
/*

CHANGE 1: Resize g_perfData array (line ~1693)
   OLD: PerfData g_perfData[18];
   NEW: PerfData g_perfData[19];

CHANGE 2: Add g_perfData name in OnInit (after line 4703)
   ADD: g_perfData[18].name = "FairValueGap";

CHANGE 3: Add to IsOurMagicNumber (after line 5884)
   ADD: magic == InpFVG_MagicNumber)  // V28.XX: Fair Value Gap

CHANGE 4: Add to GetStrategyIndexFromMagic (after line 5915)
   ADD: if(magicNumber == InpFVG_MagicNumber) return 18;

CHANGE 5: Add to GetStrategyIndex (after line 6789)
   ADD: if(magic == InpFVG_MagicNumber) return 18;

CHANGE 6: Add to GetStrategyIndexByMagic (after line 14419)
   ADD: if(magicNumber == InpFVG_MagicNumber) return 18;

CHANGE 7: Add to GetMagicName (after ~line 5855)
   ADD: if(magic == InpFVG_MagicNumber) return "FairValueGap";

CHANGE 8: Add to GetStrategySpecificRisk (after line 4489)
   ADD: if(magicNumber == InpFVG_MagicNumber) return 0.8; // Conservative

CHANGE 9: Add dispatch in OnTick (after Sentinel dispatch, ~line 5600)
   ADD:
   // V28.XX BEEHIVE  Fair Value Gap Worker (ICT FVG + Liquidity Sweep)
   if(InpFVG_Enabled)
   {
      ExecuteFVGStrategy();
      if(CountOpenTrades() >= InpMaxOpenTrades) {
         if(!IsOptimization()) UpdateDashboard_StaticV8_6();
         return;
      }
   }

CHANGE 10: All loops iterating g_perfData[] must use < 19 instead of < 18
   - ReconcileFinalPerformance loop
   - Any other array bounds checks

CHANGE 11: Add FVG globals near other strategy globals (after ~line 1693)
   ADD: (paste the FVGRecord struct, g_fvgStore[], g_fvgCount, g_lastFVGScanTime)

CHANGE 12: Add MoneyManagement_Quantum fallback for FVG
   In the lot sizing function, add FVG magic with 1.0x multiplier (standard)

*/
//+------------------------------------------------------------------+
