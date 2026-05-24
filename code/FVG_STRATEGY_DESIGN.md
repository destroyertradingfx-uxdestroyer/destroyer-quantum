# Fair Value Gap (FVG) Strategy — Complete Implementation Design
## For DESTROYER QUANTUM EA on EURUSD H4

---

## 1. CONCEPT OVERVIEW

A **Fair Value Gap** (FVG) is a 3-candle pattern where the middle candle is so large that
candles 1 and 3 don't overlap. This creates an "imbalance" zone that price tends to
revisit ("mitigate") before continuing.

The FVG strategy combines two ICT concepts:
1. **Liquidity Sweep** — Price raids a session/prior-day high or low (stop hunt)
2. **FVG Retracement** — After the sweep, price retraces into an unmitigated FVG zone

This is fundamentally different from the old LiquiditySweep (magic 9005, PF 0.84) which
entered immediately on the sweep candle. The FVG strategy waits for the FVG fill, giving
a much better entry with tighter risk.

---

## 2. FVG IDENTIFICATION LOGIC

### 2.1 Bullish FVG (Upside Gap)

```
Candle layout (bars indexed 1=oldest, 3=newest in the pattern):

  Bar 3:  High[3] ──────┐
                         │ ← GAP (FVG Zone)
  Bar 1:  Low[1]  ──────┘

Condition: Low[1] > High[3]
This means bar 2 was so bullish that bars 1 and 3 don't overlap.
The FVG zone = [High[3], Low[1]]
```

**MQL4 Detection:**
```mql4
bool IsBullishFVG(int shift)
{
   // shift = bar index of the MIDDLE candle (bar 2)
   // Bar 1 (left) = shift+2, Bar 2 (middle) = shift+1, Bar 3 (right) = shift
   double high_candle1 = High[shift + 2];  // oldest candle's high
   double low_candle1  = Low[shift + 2];
   double high_candle3 = High[shift];       // newest candle's high  
   double low_candle3  = Low[shift];

   // Bullish FVG: gap UP — the low of the left candle is ABOVE the high of the right candle
   // This means candle 2 surged so hard that candle 1's low and candle 3's high don't touch
   return (low_candle1 > high_candle3);
}
```

### 2.2 Bearish FVG (Downside Gap)

```
  Bar 1:  High[1] ──────┐
                         │ ← GAP (FVG Zone)  
  Bar 3:  Low[3]  ──────┘

Condition: High[1] < Low[3]
The middle candle was so bearish that bars 1 and 3 don't overlap.
The FVG zone = [High[1], Low[3]]
```

**MQL4 Detection:**
```mql4
bool IsBearishFVG(int shift)
{
   double high_candle1 = High[shift + 2];
   double low_candle3  = Low[shift];
   
   // Bearish FVG: gap DOWN — the high of the left candle is BELOW the low of the right candle
   return (high_candle1 < low_candle3);
}
```

### 2.3 FVG Zone Extraction

```mql4
// For a bullish FVG detected at bar 'shift':
double fvgTop    = Low[shift + 2];     // Low of left candle (upper boundary)
double fvgBottom = High[shift];        // High of right candle (lower boundary)

// For a bearish FVG detected at bar 'shift':
double fvgTop    = Low[shift];         // Low of right candle (upper boundary)
double fvgBottom = High[shift + 2];    // High of left candle (lower boundary)
```

---

## 3. DATA STRUCTURE — FVG STORAGE

### 3.1 FVG Record Structure

```mql4
#define MAX_FVG_STORED 50    // Track up to 50 unmitigated FVGs

struct FVGRecord {
   double   top;           // Upper boundary of FVG zone
   double   bottom;        // Lower boundary of FVG zone
   datetime barTime;       // Time of the middle candle (for uniqueness)
   int      direction;     // +1 = bullish FVG, -1 = bearish FVG
   bool     mitigated;     // True once price has filled the gap
   int      sweepConfirmed; // 0=no sweep, +1=bullish sweep confirmed, -1=bearish sweep confirmed
};

FVGRecord g_fvgStore[MAX_FVG_STORED];
int       g_fvgCount = 0;
```

### 3.2 Adding a New FVG

```mql4
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
   
   // Shift everything down if at capacity (FIFO)
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
   g_fvgCount++;
}
```

### 3.3 Mitigation Check — When Is an FVG "Filled"?

An FVG is **mitigated** when price has returned into the gap zone. On H4:

```mql4
void UpdateFVG_Mitigation()
{
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgStore[i].mitigated) continue;
      
      // Bullish FVG is mitigated when price drops INTO the gap
      if(g_fvgStore[i].direction == 1)
      {
         // Mitigated if any subsequent candle's low touches the FVG zone
         // Use current bar's low (live) and completed bars since formation
         if(Low[0] <= g_fvgStore[i].top)
            g_fvgStore[i].mitigated = true;
      }
      // Bearish FVG is mitigated when price rises INTO the gap
      else
      {
         if(High[0] >= g_fvgStore[i].bottom)
            g_fvgStore[i].mitigated = true;
      }
   }
}
```

**Key design decision:** Full mitigation = price reaches the FVG zone boundary.
Partial mitigation (price enters but doesn't fully traverse) is still considered
"active" for entry — the entry fires when price first touches the zone.

---

## 4. LIQUIDITY SWEEP DETECTION

### 4.1 Session Definitions (Server Time — adjust for broker GMT offset)

```mql4
// Session times in SERVER time (most MT4 brokers use GMT+2 or GMT+3)
// Adjust these via inputs for the broker

struct SessionDef {
   string name;
   int    startHour;  // Server hour
   int    endHour;
};

// Typical GMT+2 broker:
// Asian:   00:00 - 08:00 server (22:00-06:00 GMT)
// London:  08:00 - 16:00 server (06:00-14:00 GMT) 
// NY:      13:00 - 22:00 server (11:00-20:00 GMT)
// Overlap: 13:00 - 16:00 server (London/NY overlap)
```

### 4.2 Previous Day High/Low Sweep

This is the most reliable sweep on H4. The EA already has access to D1 data.

```mql4
// Get previous day's high and low
double GetPrevDayHigh()
{
   return iHigh(Symbol(), PERIOD_D1, 1);
}

double GetPrevDayLow()
{
   return iLow(Symbol(), PERIOD_D1, 1);
}

// Detect sweep: Did the current H4 bar wick beyond the level?
bool IsSweepAboveLevel(double level, int shift)
{
   // Price swept above the level but closed back below it
   return (High[shift] > level && Close[shift] < level);
}

bool IsSweepBelowLevel(double level, int shift)
{
   // Price swept below the level but closed back above it
   return (Low[shift] < level && Close[shift] > level);
}
```

### 4.3 Session High/Low Sweep

On H4, each bar represents a 4-hour session window. We can approximate session
highs/lows using the lookback approach (similar to the old LiquiditySweep):

```mql4
// Get the high/low of the last N completed H4 bars (approximates a session)
double GetSessionHigh(int lookbackBars)
{
   double highest = 0;
   for(int i = 1; i <= lookbackBars; i++)
   {
      if(High[i] > highest) highest = High[i];
   }
   return highest;
}

double GetSessionLow(int lookbackBars)
{
   double lowest = DBL_MAX;
   for(int i = 1; i <= lookbackBars; i++)
   {
      if(Low[i] < lowest) lowest = Low[i];
   }
   return lowest;
}
```

### 4.4 Sweep Confirmation with Close-Back-Inside

The critical filter that separates a real sweep from a breakout:

```mql4
bool IsBearishSweepConfirmed(int shift)
{
   // Price swept above a key level BUT closed back below it
   // This is a "rejection" — liquidity was taken and price reversed
   double prevDayHigh = GetPrevDayHigh();
   double sessionHigh = GetSessionHigh(InpFVG_SweepLookback);
   
   double keyLevel = MathMax(prevDayHigh, sessionHigh);
   
   return (High[shift] > keyLevel && Close[shift] < keyLevel);
}

bool IsBullishSweepConfirmed(int shift)
{
   double prevDayLow = GetPrevDayLow();
   double sessionLow = GetSessionLow(InpFVG_SweepLookback);
   
   double keyLevel = MathMin(prevDayLow, sessionLow);
   
   return (Low[shift] < keyLevel && Close[shift] > keyLevel);
}
```

---

## 5. COMPLETE ENTRY LOGIC

### 5.1 Signal Flow

```
1. SCAN for new FVGs on every H4 bar close
   → Store unmitigated FVGs in g_fvgStore[]

2. CHECK for liquidity sweep on current bar
   → If sweep detected, mark relevant FVGs with sweepConfirmed flag

3. MONITOR price — on every tick:
   → If price retraces into an FVG that has sweepConfirmed:
     → ENTER the trade (BUY for bullish FVG, SELL for bearish FVG)
     → SL = opposite side of FVG + buffer
     → TP = next liquidity level or opposing FVG

4. UPDATE mitigation status on every tick
   → If price fills an FVG without triggering entry, mark as mitigated
```

### 5.2 Entry Conditions (All Must Be True)

For a **BUY** entry:
```
1. Unmitigated BULLISH FVG exists in g_fvgStore[]
2. That FVG has sweepConfirmed == +1 (bullish sweep occurred after FVG formation)
3. Current Ask is INSIDE the FVG zone (bottom <= Ask <= top)
4. No existing FVG trade open
5. Spread is acceptable (< InpMax_Spread_Pips)
6. Time filter passes (London/NY hours)
7. Max concurrent trades not exceeded
```

For a **SELL** entry:
```
1. Unmitigated BEARISH FVG exists in g_fvgStore[]
2. That FVG has sweepConfirmed == -1 (bearish sweep occurred after FVG formation)
3. Current Bid is INSIDE the FVG zone (bottom <= Bid <= top)
4. No existing FVG trade open
5. Spread is acceptable
6. Time filter passes
7. Max concurrent trades not exceeded
```

### 5.3 SL/TP Calculation

```mql4
// BUY trade from bullish FVG:
double sl = fvgBottom - (atr * InpFVG_SL_Buffer_ATR);  // Below FVG + ATR buffer
double tp = Ask + (InpFVG_TP_RR * (Ask - sl));          // R:R based TP

// SELL trade from bearish FVG:
double sl = fvgTop + (atr * InpFVG_SL_Buffer_ATR);     // Above FVG + ATR buffer  
double tp = Bid - (InpFVG_TP_RR * (sl - Bid));          // R:R based TP

// Alternative TP: Next unmitigated FVG in the opposing direction
// Scan g_fvgStore[] for the nearest opposing FVG beyond the entry
```

### 5.4 Alternative: TP at Next Liquidity Level

```mql4
double FindNextLiquidityTarget(int direction, double entryPrice)
{
   // For BUY: Target the most recent swing high or previous day high
   if(direction == OP_BUY)
   {
      double pdHigh = GetPrevDayHigh();
      double sessHigh = GetSessionHigh(InpFVG_SweepLookback);
      // Target the nearest one above entry
      double target = pdHigh;
      if(sessHigh > entryPrice && sessHigh < target) target = sessHigh;
      if(target <= entryPrice) target = entryPrice + 100 * Point * 10; // Fallback: 100 pips
      return target;
   }
   else
   {
      double pdLow = GetPrevDayLow();
      double sessLow = GetSessionLow(InpFVG_SweepLookback);
      double target = pdLow;
      if(sessLow < entryPrice && sessLow > target) target = sessLow;
      if(target >= entryPrice) target = entryPrice - 100 * Point * 10;
      return target;
   }
}
```

---

## 6. RISK MANAGEMENT

### 6.1 Input Parameters

```mql4
sinput string Inp_Header_FVG = "====== FAIR VALUE GAP (FVG) STRATEGY ======";
input bool    InpFVG_Enabled          = true;       // Enable FVG Strategy
input int     InpFVG_MagicNumber      = 9007;       // Magic number for FVG
input int     InpFVG_MaxConcurrent    = 1;          // Max concurrent FVG trades
input double  InpFVG_MinSizePips      = 5.0;        // Minimum FVG size in pips
input double  InpFVG_MaxSizePips      = 80.0;       // Maximum FVG size (too big = likely breakaway)
input int     InpFVG_MaxFVGAge_Bars   = 20;         // Max age of FVG in H4 bars (older = less relevant)
input int     InpFVG_SweepLookback    = 6;          // H4 bars to look back for session high/low (~1 day)
input double  InpFVG_SL_Buffer_ATR    = 0.3;        // ATR buffer below/above FVG for SL
input double  InpFVG_TP_RR            = 2.5;        // Risk:Reward ratio for TP
input int     InpFVG_MaxSweepRetrace  = 5;          // Max bars between sweep and FVG entry
input int     InpFVG_TradeStartHour   = 7;          // Server hour: London open
input int     InpFVG_TradeEndHour     = 17;         // Server hour: NY close (approx)
input bool    InpFVG_RequireEMAFilter = true;       // Require EMA trend alignment
input int     InpFVG_EMA_Period       = 50;         // EMA period for trend filter
```

### 6.2 Minimum FVG Size Filter

```mql4
// Already integrated into AddFVG():
double fvgSizePips = (top - bottom) / (Point * 10);
if(fvgSizePips < InpFVG_MinSizePips) return;  // Skip micro-gaps
if(fvgSizePips > InpFVG_MaxSizePips) return;  // Skip breakaway gaps
```

### 6.3 Time Filter — London/NY Overlap

```mql4
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
```

### 6.4 EMA Trend Filter (Optional)

```mql4
bool IsEMATrendAligned(int direction)
{
   if(!InpFVG_RequireEMAFilter) return true;
   
   double ema = iMA(Symbol(), PERIOD_H4, InpFVG_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   if(direction == OP_BUY)  return (Ask > ema);  // Price above EMA for buys
   if(direction == OP_SELL) return (Bid < ema);   // Price below EMA for sells
   return false;
}
```

### 6.5 ATR-Based SL Distance Validation

```mql4
// Ensure SL isn't too tight or too wide
double atr = iATR(Symbol(), PERIOD_H4, 14, 0);
double slDistance = MathAbs(entryPrice - slPrice);
double slInATR = slDistance / atr;

if(slInATR < 0.5) return false;  // SL too tight (< 0.5 ATR)
if(slInATR > 4.0) return false;  // SL too wide (> 4 ATR)
```

---

## 7. COMPLETE MQL4 IMPLEMENTATION

### 7.1 Global Variables & Constants

```mql4
// ─── FVG Strategy Globals ───
#define MAX_FVG_STORED 50

struct FVGRecord {
   double   top;
   double   bottom;
   datetime barTime;
   int      direction;      // +1 bullish, -1 bearish
   bool     mitigated;
   int      sweepConfirmed; // 0=none, +1=bullish sweep, -1=bearish sweep
   datetime sweepTime;      // When the sweep was confirmed
};

FVGRecord g_fvgStore[MAX_FVG_STORED];
int       g_fvgCount = 0;
datetime  g_lastFVGScanTime = 0;  // Prevent re-scanning same bar
```

### 7.2 FVG Scanning Function (Called Once Per Bar)

```mql4
void ScanForNewFVGs()
{
   // Only scan on new bar
   if(Time[0] == g_lastFVGScanTime) return;
   g_lastFVGScanTime = Time[0];
   
   // Scan completed bars (shift 1..lookback) for FVG patterns
   // We look at the middle candle at shift 'i'
   // i.e., candles i-1 (left), i (middle), i+1 (right) 
   // But using our convention: shift = rightmost candle
   // So candles are at shift+2, shift+1, shift
   
   for(int shift = 1; shift <= 50; shift++)  // Scan last 50 bars
   {
      // Skip if too old
      int barAge = iBarShift(Symbol(), PERIOD_H4, Time[shift]);
      if(barAge > InpFVG_MaxFVGAge_Bars) continue;
      
      // ── BULLISH FVG ──
      // Middle candle (shift+1) surged UP so much that:
      // Low of left candle (shift+2) > High of right candle (shift)
      if(Low[shift + 2] > High[shift])
      {
         double fvgTop    = Low[shift + 2];
         double fvgBottom = High[shift];
         AddFVG(fvgTop, fvgBottom, Time[shift + 1], +1);
      }
      
      // ── BEARISH FVG ──
      // Middle candle (shift+1) dropped so hard that:
      // High of left candle (shift+2) < Low of right candle (shift)
      if(High[shift + 2] < Low[shift])
      {
         double fvgTop    = Low[shift];
         double fvgBottom = High[shift + 2];
         AddFVG(fvgTop, fvgBottom, Time[shift + 1], -1);
      }
   }
}
```

### 7.3 Sweep Detection & FVG Marking (Called Once Per Bar)

```mql4
void DetectLiquiditySweeps()
{
   // Check if the most recently completed bar (shift=1) swept a key level
   
   double prevDayHigh = iHigh(Symbol(), PERIOD_D1, 1);
   double prevDayLow  = iLow(Symbol(), PERIOD_D1, 1);
   
   // Get session high/low from recent H4 bars
   double sessionHigh = High[iHighest(Symbol(), PERIOD_H4, MODE_HIGH, InpFVG_SweepLookback, 2)];
   double sessionLow  = Low[iLowest(Symbol(), PERIOD_H4, MODE_LOW, InpFVG_SweepLookback, 2)];
   
   // ── BEARISH SWEEP (swept above, closed back below) ──
   // Swept above previous day high OR session high
   bool sweptAbovePDH = (High[1] > prevDayHigh && Close[1] < prevDayHigh);
   bool sweptAboveSH  = (High[1] > sessionHigh && Close[1] < sessionHigh);
   
   if(sweptAbovePDH || sweptAboveSH)
   {
      // Mark all unmitigated bearish FVGs as sweep-confirmed (sell setup)
      for(int i = 0; i < g_fvgCount; i++)
      {
         if(!g_fvgStore[i].mitigated && g_fvgStore[i].direction == -1)
         {
            g_fvgStore[i].sweepConfirmed = -1;
            g_fvgStore[i].sweepTime = Time[1];
         }
      }
   }
   
   // ── BULLISH SWEEP (swept below, closed back above) ──
   bool sweptBelowPDL = (Low[1] < prevDayLow && Close[1] > prevDayLow);
   bool sweptBelowSL  = (Low[1] < sessionLow && Close[1] > sessionLow);
   
   if(sweptBelowPDL || sweptBelowSL)
   {
      // Mark all unmitigated bullish FVGs as sweep-confirmed (buy setup)
      for(int i = 0; i < g_fvgCount; i++)
      {
         if(!g_fvgStore[i].mitigated && g_fvgStore[i].direction == +1)
         {
            g_fvgStore[i].sweepConfirmed = +1;
            g_fvgStore[i].sweepTime = Time[1];
         }
      }
   }
}
```

### 7.4 Main Entry Function

```mql4
void ExecuteFVGStrategy()
{
   if(!InpFVG_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpFVG_MagicNumber) >= InpFVG_MaxConcurrent) return;
   if(!IsStrategyHealthy(InpFVG_MagicNumber)) return;
   if(!IsFVGTradeWindow()) return;
   
   double spread = (Ask - Bid) / Point;
   if(spread > InpMax_Spread_Pips * 10) return;
   
   // ── STEP 1: Scan for new FVGs (once per bar) ──
   ScanForNewFVGs();
   
   // ── STEP 2: Detect sweeps and mark FVGs (once per bar) ──
   DetectLiquiditySweeps();
   
   // ── STEP 3: Update mitigation status (every tick) ──
   UpdateFVG_Mitigation();
   
   // ── STEP 4: Look for entry ──
   double atr = iATR(Symbol(), PERIOD_H4, 14, 0);
   if(atr <= 0) return;
   
   int    stratIdx = GetStrategyIndex(InpFVG_MagicNumber);
   
   // Find the best unmitigated, sweep-confirmed FVG to trade
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgStore[i].mitigated) continue;
      if(g_fvgStore[i].sweepConfirmed == 0) continue;
      
      // Check FVG age — don't trade stale FVGs
      int fvgBarAge = iBarShift(Symbol(), PERIOD_H4, g_fvgStore[i].barTime);
      if(fvgBarAge > InpFVG_MaxFVGAge_Bars)
      {
         g_fvgStore[i].mitigated = true; // Expire it
         continue;
      }
      
      // Check if sweep is still fresh (within MaxSweepRetrace bars)
      int sweepAge = iBarShift(Symbol(), PERIOD_H4, g_fvgStore[i].sweepTime);
      if(sweepAge > InpFVG_MaxSweepRetrace) continue;
      
      // ── BUY ENTRY: Bullish FVG + Bullish sweep + Price inside FVG ──
      if(g_fvgStore[i].direction == +1 && g_fvgStore[i].sweepConfirmed == +1)
      {
         double fvgMid = (g_fvgStore[i].top + g_fvgStore[i].bottom) / 2.0;
         
         // Price must be touching the FVG zone
         if(Ask >= g_fvgStore[i].bottom && Ask <= g_fvgStore[i].top)
         {
            if(!IsEMATrendAligned(OP_BUY)) continue;
            
            double slPrice = g_fvgStore[i].bottom - (atr * InpFVG_SL_Buffer_ATR);
            double slDist  = Ask - slPrice;
            double tpPrice = Ask + (slDist * InpFVG_TP_RR);
            
            // Sanity checks
            double slInATR = slDist / atr;
            if(slInATR < 0.5 || slInATR > 4.0) continue;
            
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
      
      // ── SELL ENTRY: Bearish FVG + Bearish sweep + Price inside FVG ──
      if(g_fvgStore[i].direction == -1 && g_fvgStore[i].sweepConfirmed == -1)
      {
         if(Bid >= g_fvgStore[i].bottom && Bid <= g_fvgStore[i].top)
         {
            if(!IsEMATrendAligned(OP_SELL)) continue;
            
            double slPrice = g_fvgStore[i].top + (atr * InpFVG_SL_Buffer_ATR);
            double slDist  = slPrice - Bid;
            double tpPrice = Bid - (slDist * InpFVG_TP_RR);
            
            double slInATR = slDist / atr;
            if(slInATR < 0.5 || slInATR > 4.0) continue;
            
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
```

### 7.5 Periodic Cleanup

```mql4
void CleanupFVGStore()
{
   // Remove old/mitigated FVGs periodically
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
```

---

## 8. EA INTEGRATION CHECKLIST

To add FVG as strategy #18 (index 18) to DESTROYER QUANTUM:

### 8.1 Inputs (add near line 4620, after Sentinel inputs)

```mql4
sinput string Inp_Header_FVG = "====== V28.XX: FAIR VALUE GAP (FVG) ======";
input bool    InpFVG_Enabled          = true;
input int     InpFVG_MagicNumber      = 9007;
input int     InpFVG_MaxConcurrent    = 1;
input double  InpFVG_MinSizePips      = 5.0;
input double  InpFVG_MaxSizePips      = 80.0;
input int     InpFVG_MaxFVGAge_Bars   = 20;
input int     InpFVG_SweepLookback    = 6;
input double  InpFVG_SL_Buffer_ATR    = 0.3;
input double  InpFVG_TP_RR            = 2.5;
input int     InpFVG_MaxSweepRetrace  = 5;
input int     InpFVG_TradeStartHour   = 7;
input int     InpFVG_TradeEndHour     = 17;
input bool    InpFVG_RequireEMAFilter = true;
input int     InpFVG_EMA_Period       = 50;
```

### 8.2 Resize g_perfData (line ~1693)

```mql4
PerfData g_perfData[19];  // Was [18], now [19] for FVG at index 18
```

### 8.3 Init g_perfData name (after line 4703)

```mql4
g_perfData[18].name = "FairValueGap"; // V28.XX: New strategy
```

### 8.4 Add to IsOurMagicNumber (after line 5884)

```mql4
magic == InpFVG_MagicNumber)              // V28.XX: Fair Value Gap
```

### 8.5 Add to all three GetStrategyIndex functions

```mql4
if(magicNumber == InpFVG_MagicNumber) return 18; // V28.XX: Fair Value Gap
if(magic == InpFVG_MagicNumber) return 18;       // V28.XX: Fair Value Gap
```

### 8.6 Add to GetMagicName (after ~line 5855)

```mql4
if(magic == InpFVG_MagicNumber) return "FairValueGap"; // V28.XX
```

### 8.7 Add to GetStrategySpecificRisk (after line 4489)

```mql4
// V28.XX: FVG (conservative — new unproven strategy, depends on sweep quality)
if(magicNumber == InpFVG_MagicNumber)
   return 0.8;
```

### 8.8 Add to dispatch loop (after Sentinel, ~line 5600)

```mql4
// V28.XX BEEHIVE — Fair Value Gap Worker (ICT FVG + Liquidity Sweep)
if(InpFVG_Enabled)
{
   ExecuteFVGStrategy();
   if(CountOpenTrades() >= InpMaxOpenTrades) { if(!IsOptimization()) UpdateDashboard_StaticV8_6(); return; }
}
```

### 8.9 Add MoneyManagement fallback (in MoneyManagement_Quantum)

Add FVG magic to the lot sizing fallback with 1.0x multiplier (standard).

### 8.10 Loop bounds fix

All loops that iterate g_perfData[] must use `< 19` instead of `< 18`.

---

## 9. VISUAL OVERLAY (Optional — For Debugging)

Draw FVG zones on chart as rectangles:

```mql4
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
      
      color clr = (g_fvgStore[i].direction == 1) ? clrDodgerBlue : clrOrangeRed;
      if(g_fvgStore[i].sweepConfirmed != 0) clr = clrGold; // Highlighted = ready to trade
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, g_fvgStore[i].top, t2, g_fvgStore[i].bottom);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}
```

---

## 10. STRATEGY DIFFERENTIATION FROM OLD LIQUIDITYSWEEP (9005)

| Aspect | Old LiquiditySweep (9005) | New FVG (9007) |
|--------|---------------------------|----------------|
| Entry | Immediate on sweep candle | Waits for FVG retrace |
| SL | ATR-based (loose) | FVG boundary (tight) |
| TP | ATR-based (fixed) | R:R ratio or next liquidity |
| Confirmation | RSI OB/OS + Volume | FVG zone + sweep + EMA |
| Filter quality | Low (RSI alone) | Structural (ICT framework) |
| Expected PF | 0.84 (failed) | 1.5+ (better entry timing) |

The FVG strategy is fundamentally better because:
1. It doesn't enter on the sweep candle (too early, against momentum)
2. It waits for the FVG fill (institutional order flow rebalancing)
3. SL is at the FVG boundary (logical invalidation, not arbitrary ATR)
4. Sweep confirmation adds directional conviction

---

## 11. RISK NOTES

1. **FVGs are more common on lower timeframes** — on H4, they're less frequent but more significant
2. **Not all FVGs should be traded** — the sweep confirmation is critical filter
3. **EURUSD H4 may produce ~2-5 FVG setups per week** with sweep confirmation
4. **Start conservative** — 0.8x risk multiplier, max 1 concurrent trade
5. **Backtest key parameters to optimize:**
   - `InpFVG_MinSizePips` (5-15 range)
   - `InpFVG_TP_RR` (1.5-3.0 range)
   - `InpFVG_MaxFVGAge_Bars` (10-30 range)
   - `InpFVG_SweepLookback` (4-12 range)
   - `InpFVG_MaxSweepRetrace` (3-8 range)

---

## 12. EXPECTED PERFORMANCE

Based on ICT FVG strategy literature and EURUSD H4 characteristics:
- **Trade frequency:** 30-60 trades per year (with sweep confirmation)
- **Win rate:** 55-65% (FVG fills are statistically common)
- **Average R:R:** 2.0-2.5:1
- **Expected PF:** 1.3-2.0
- **Key risk:** Extended trends where FVGs don't get swept before continuation
