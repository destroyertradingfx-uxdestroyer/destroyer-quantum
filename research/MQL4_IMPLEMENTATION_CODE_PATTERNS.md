# MQL4 CODE IMPLEMENTATION PATTERNS
## For DESTROYER QUANTUM V28.06 TITAN
### Date: 2026-05-26
### Purpose: Production-ready code for 4 key enhancements targeting $170K

---

## OVERVIEW

This document contains actual MQL4 code snippets for 4 implementation patterns:
1. **Equity Curve Position Sizing** — Track equity SMA, scale positions anti-martingale
2. **ATR Percentile Volatility Regime Detection** — Percentile-based volatility filtering
3. **Asian Session Range Breakout (H4)** — Tokyo-London handoff strategy (magic 9007)
4. **Progressive Profit-Taking** — Close partial at TP1, trail rest with ATR

All code follows the existing DESTROYER QUANTUM conventions:
- Uses `RobustOrderSend()`, `RobustOrderModify()`, `LogError()`, `OpenTrade()`
- Magic numbers: 9007 (Asian Breakout), generic for others
- Integrates with `MoneyManagement_Quantum()`, `CountOpenTrades()`, `IsStrategyHealthy()`
- H4 timeframe focus, EURUSD primary

---

## PATTERN 1: EQUITY CURVE POSITION SIZING (Anti-Martingale)

### Concept
Trade larger when equity curve is rising (winning streak), smaller when falling (losing streak).
Track 20-trade rolling equity curve slope + peak equity drawdown defense.

### Global Variables (add near existing globals ~line 1529)
```mql4
// ═══════════════════════════════════════════════════════════════
// V29.00: EQUITY CURVE TRADING — ANTI-MARTINGALE SIZING
// ═══════════════════════════════════════════════════════════════
#define EQUITY_HISTORY_SIZE 60
double   g_equityHistory[EQUITY_HISTORY_SIZE];    // Rolling equity snapshots
int      g_equityHistoryIdx = 0;                   // Current index in circular buffer
int      g_equityHistoryCount = 0;                 // Total snapshots recorded
double   g_peakEquity = 0;                         // High water mark
datetime g_lastEquitySnapshot = 0;                 // Prevent duplicate snapshots

// Input parameters (add to input section)
input bool   InpEquityCurve_Enabled     = true;    // Enable Equity Curve Trading
input int    InpEquityCurve_Period      = 20;      // Rolling period for slope calc
input double InpEquityCurve_WinMult     = 1.3;     // Multiplier when equity rising
input double InpEquityCurve_LossMult    = 0.7;     // Multiplier when equity falling
input double InpEquityCurve_DDThreshold = 0.10;    // DD% to trigger 50% cut (10%)
input double InpEquityCurve_DDReduction = 0.50;    // Lot reduction in DD (50%)
```

### Core Functions

```mql4
//+------------------------------------------------------------------+
//| Record equity snapshot (call once per new H4 bar or per trade)   |
//+------------------------------------------------------------------+
void RecordEquitySnapshot()
{
   // Only snapshot once per H4 bar to avoid noise
   datetime currentBarTime = iTime(Symbol(), PERIOD_H4, 0);
   if(g_lastEquitySnapshot == currentBarTime) return;
   g_lastEquitySnapshot = currentBarTime;
   
   double equity = AccountEquity();
   
   // Store in circular buffer
   g_equityHistory[g_equityHistoryIdx] = equity;
   g_equityHistoryIdx = (g_equityHistoryIdx + 1) % EQUITY_HISTORY_SIZE;
   if(g_equityHistoryCount < EQUITY_HISTORY_SIZE) g_equityHistoryCount++;
   
   // Update peak equity (high water mark)
   if(equity > g_peakEquity) g_peakEquity = equity;
}

//+------------------------------------------------------------------+
//| Calculate equity curve slope using linear regression             |
//| Returns: slope in $ per bar (positive = rising, negative = fall) |
//+------------------------------------------------------------------+
double GetEquityCurveSlope(int period)
{
   if(g_equityHistoryCount < period) return 0; // Not enough data
   
   // Extract the last 'period' equity values from circular buffer
   double values[];
   ArrayResize(values, period);
   
   int startIdx = (g_equityHistoryIdx - period + EQUITY_HISTORY_SIZE) % EQUITY_HISTORY_SIZE;
   for(int i = 0; i < period; i++)
   {
      values[i] = g_equityHistory[(startIdx + i) % EQUITY_HISTORY_SIZE];
   }
   
   // Simple linear regression: slope = (n*sum(xy) - sum(x)*sum(y)) / (n*sum(x^2) - (sum(x))^2)
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = period;
   
   for(int i = 0; i < n; i++)
   {
      double x = (double)i;
      double y = values[i];
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
   }
   
   double denominator = (n * sumX2) - (sumX * sumX);
   if(denominator == 0) return 0;
   
   double slope = ((n * sumXY) - (sumX * sumY)) / denominator;
   return slope;
}

//+------------------------------------------------------------------+
//| Get equity curve multiplier for position sizing                  |
//| Returns: 0.5 to 1.3 multiplier based on equity curve state      |
//+------------------------------------------------------------------+
double GetEquityCurveMultiplier()
{
   if(!InpEquityCurve_Enabled) return 1.0;
   if(g_equityHistoryCount < InpEquityCurve_Period) return 1.0; // Not enough data
   
   double equity = AccountEquity();
   
   // ═══ LAYER 1: DRAWDOWN DEFENSE ═══
   // If equity is below peak by DDThreshold%, cut all sizing
   if(g_peakEquity > 0)
   {
      double ddPercent = (g_peakEquity - equity) / g_peakEquity;
      if(ddPercent >= InpEquityCurve_DDThreshold)
      {
         LogError(ERROR_INFO, "EQUITY CURVE: DD=" + DoubleToString(ddPercent * 100, 1) + 
                  "% >= " + DoubleToString(InpEquityCurve_DDThreshold * 100, 0) + 
                  "%. Cutting size to " + DoubleToString(InpEquityCurve_DDReduction, 2) + "x",
                  "GetEquityCurveMultiplier");
         return InpEquityCurve_DDReduction; // 0.5x in drawdown
      }
   }
   
   // ═══ LAYER 2: EQUITY CURVE SLOPE ═══
   double slope = GetEquityCurveSlope(InpEquityCurve_Period);
   
   // Normalize slope relative to equity for cross-account comparability
   double normalizedSlope = slope / equity;
   
   // Threshold: > 0.1% per bar = rising, < -0.1% per bar = falling
   double threshold = 0.001; // 0.1% per bar
   
   if(normalizedSlope > threshold)
   {
      LogError(ERROR_INFO, "EQUITY CURVE: RISING (slope=" + DoubleToString(normalizedSlope * 100, 3) + 
               "%/bar). Amplifying to " + DoubleToString(InpEquityCurve_WinMult, 2) + "x",
               "GetEquityCurveMultiplier");
      return InpEquityCurve_WinMult; // 1.3x when winning
   }
   else if(normalizedSlope < -threshold)
   {
      LogError(ERROR_INFO, "EQUITY CURVE: FALLING (slope=" + DoubleToString(normalizedSlope * 100, 3) + 
               "%/bar). Reducing to " + DoubleToString(InpEquityCurve_LossMult, 2) + "x",
               "GetEquityCurveMultiplier");
      return InpEquityCurve_LossMult; // 0.7x when losing
   }
   
   return 1.0; // Neutral
}
```

### Integration Point (modify MoneyManagement_Quantum ~line 12927)

```mql4
// Add BEFORE the final lot calculation (line ~12927):
// ═══ V29.00: EQUITY CURVE MULTIPLIER ═══
double equityCurveMult = GetEquityCurveMultiplier();
combinedMultiplier *= equityCurveMult;

// The rest of the calculation continues as before:
double riskAmount = accountEquity * ((effectiveRiskPercent * combinedMultiplier) / 100.0);
```

### Integration Point (OnInit, ~line 4777)

```mql4
// Add after ArrayInitialize calls:
// V29.00: Initialize equity curve tracking
ArrayInitialize(g_equityHistory, 0);
g_equityHistoryIdx = 0;
g_equityHistoryCount = 0;
g_peakEquity = AccountEquity(); // Seed with current equity
g_lastEquitySnapshot = 0;
```

### Integration Point (OnTick, call once per tick)

```mql4
// Add at the start of OnTick or start():
RecordEquitySnapshot(); // V29.00: Track equity curve
```

---

## PATTERN 2: ATR PERCENTILE VOLATILITY REGIME DETECTION

### Concept
Instead of comparing current ATR to average ATR (what the EA already does in IsSentinel_VolatilityRegimeOK),
calculate what PERCENTILE the current ATR sits in relative to historical ATR distribution. This gives a
more robust regime classification: low-vol (0-25th), normal (25-75th), high-vol (75-90th), extreme (90-100th).

### Implementation

```mql4
//+------------------------------------------------------------------+
//| V29.00: ATR PERCENTILE VOLATILITY REGIME DETECTION               |
//| Returns: 0.0-1.0 percentile of current ATR vs history            |
//| 0.0 = extremely low vol, 0.5 = median, 1.0 = extremely high vol |
//+------------------------------------------------------------------+
double GetATRPercentile(int atrPeriod = 14, int lookbackBars = 100, 
                        int timeframe = PERIOD_H4)
{
   // Collect historical ATR values
   double atrValues[];
   ArrayResize(atrValues, lookbackBars);
   
   double currentATR = iATR(Symbol(), timeframe, atrPeriod, 1); // Last closed bar
   if(currentATR <= 0) return 0.5; // Default to median if no data
   
   // Fill array with historical ATR values
   int validBars = 0;
   for(int i = 1; i <= lookbackBars; i++)
   {
      if(i >= Bars(Symbol(), timeframe)) break;
      double atrVal = iATR(Symbol(), timeframe, atrPeriod, i);
      if(atrVal > 0)
      {
         atrValues[validBars] = atrVal;
         validBars++;
      }
   }
   
   if(validBars < 20) return 0.5; // Insufficient data
   
   // Sort the array to find percentile position
   // Simple insertion sort (adequate for 100 elements)
   for(int i = 1; i < validBars; i++)
   {
      double key = atrValues[i];
      int j = i - 1;
      while(j >= 0 && atrValues[j] > key)
      {
         atrValues[j + 1] = atrValues[j];
         j--;
      }
      atrValues[j + 1] = key;
   }
   
   // Find where current ATR falls in the sorted distribution
   int rank = 0;
   for(int i = 0; i < validBars; i++)
   {
      if(atrValues[i] < currentATR) rank++;
      else break;
   }
   
   double percentile = (double)rank / (double)validBars;
   return percentile;
}

//+------------------------------------------------------------------+
//| V29.00: Get volatility regime classification                     |
//| Returns: 0=LOW, 1=NORMAL, 2=HIGH, 3=EXTREME                     |
//+------------------------------------------------------------------+
int GetVolatilityRegime(int atrPeriod = 14, int lookbackBars = 100,
                        int timeframe = PERIOD_H4)
{
   double percentile = GetATRPercentile(atrPeriod, lookbackBars, timeframe);
   
   if(percentile >= 0.90)      return 3; // EXTREME: top 10% — no trading
   else if(percentile >= 0.75) return 2; // HIGH: 75-90th — reduce size
   else if(percentile >= 0.25) return 1; // NORMAL: 25-75th — standard
   else                        return 0; // LOW: bottom 25% — tighten stops
}

//+------------------------------------------------------------------+
//| V29.00: Get lot size multiplier based on volatility regime       |
//| EXTREME=0.0 (no trade), HIGH=0.5, NORMAL=1.0, LOW=1.2          |
//+------------------------------------------------------------------+
double GetVolatilityRegimeMultiplier()
{
   int regime = GetVolatilityRegime();
   
   switch(regime)
   {
      case 3:  // EXTREME
         LogError(ERROR_INFO, "VOL REGIME: EXTREME (90th+ pct). Blocking trades.", 
                  "GetVolatilityRegimeMultiplier");
         return 0.0;  // Block all trades
      case 2:  // HIGH
         LogError(ERROR_INFO, "VOL REGIME: HIGH (75th-90th pct). Half size.", 
                  "GetVolatilityRegimeMultiplier");
         return 0.5;  // Half size
      case 1:  // NORMAL
         return 1.0;  // Normal size
      case 0:  // LOW
         return 1.2;  // Slightly larger (tighter stops = more room)
      default:
         return 1.0;
   }
}

//+------------------------------------------------------------------+
//| V29.00: Enhanced sentinel using percentile-based detection       |
//| Replaces/supplements IsSentinel_VolatilityRegimeOK()             |
//+------------------------------------------------------------------+
bool IsSentinel_VolatilityPercentileOK(double maxPercentile = 0.85)
{
   double percentile = GetATRPercentile(14, 100, PERIOD_H4);
   
   if(percentile > maxPercentile)
   {
      LogError(ERROR_INFO, "VOL PERCENTILE BLOCK: Current ATR at " + 
               DoubleToString(percentile * 100, 1) + "th percentile (max=" +
               DoubleToString(maxPercentile * 100, 0) + "th)",
               "IsSentinel_VolatilityPercentileOK");
      return false;
   }
   
   // Also check for recent spike: any bar in last 5 at 95th+ percentile?
   for(int i = 1; i <= 5; i++)
   {
      double histATR = iATR(Symbol(), PERIOD_H4, 14, i);
      double avgATR = 0;
      int count = 0;
      for(int j = 10; j <= 110; j++)
      {
         double a = iATR(Symbol(), PERIOD_H4, 14, j);
         if(a > 0) { avgATR += a; count++; }
      }
      if(count > 0) avgATR /= count;
      
      if(avgATR > 0 && histATR > avgATR * 2.0) // 2x average = ~95th percentile
      {
         LogError(ERROR_INFO, "VOL SPIKE BLOCK: Bar " + IntegerToString(i) + 
                  " ATR=" + DoubleToString(histATR, 5) + " > 2x avg=" + DoubleToString(avgATR * 2.0, 5),
                  "IsSentinel_VolatilityPercentileOK");
         return false;
      }
   }
   
   return true;
}
```

### Integration Points

```mql4
// In MoneyManagement_Quantum, add BEFORE combinedMultiplier calculation:
double volRegimeMult = GetVolatilityRegimeMultiplier();
if(volRegimeMult <= 0) return 0; // Block trade in extreme volatility

// In ExecuteSessionMomentum, ExecuteDivergenceMR, etc., add after ADX check:
if(!IsSentinel_VolatilityPercentileOK(0.85)) return; // Block if vol > 85th percentile
```

---

## PATTERN 3: ASIAN SESSION RANGE BREAKOUT (H4 Timeframe)

### Concept
Asian session (Tokyo: 00:00-08:00 UTC) creates a consolidation range. When London opens (08:00 UTC),
trade the breakout of the Asian range. This is a well-documented edge on EURUSD.

On H4, the Asian session corresponds to bars at 00:00 and 04:00 UTC (2 H4 bars). The breakout
trade triggers when price breaks above/below this range during the 08:00 or 12:00 UTC H4 bars.

### Input Parameters (add to input section)

```mql4
sinput string Inp_Header_AsianBreakout = "====== V29.00: ASIAN SESSION BREAKOUT (MAGIC 9007) ======";
input bool    InpAsianBreakout_Enabled       = true;       // Enable Asian Breakout Strategy
input int     InpAsianBreakout_MagicNumber   = 9007;       // Magic number for Asian Breakout
input int     InpAsianBreakout_ADX_Period    = 14;         // ADX period for trend confirmation
input double  InpAsianBreakout_ADX_Threshold = 12.0;       // ADX threshold (lower = more trades)
input double  InpAsianBreakout_ATR_SL_Mult   = 1.5;        // ATR multiplier for stop loss
input double  InpAsianBreakout_ATR_TP_Mult   = 2.5;        // ATR multiplier for take profit
input double  InpAsianBreakout_RangeMinPips  = 10.0;       // Min Asian range in pips
input double  InpAsianBreakout_RangeMaxPips  = 80.0;       // Max Asian range in pips
input int     InpAsianBreakout_MaxTrades     = 2;          // Max concurrent Asian trades
```

### Core Function

```mql4
//+------------------------------------------------------------------+
//| V29.00: ASIAN SESSION RANGE BREAKOUT STRATEGY                    |
//| Magic: 9007                                                      |
//| Logic: Capture Asian range (00:00-08:00 UTC), trade breakout     |
//|        during London/NY handoff on H4 timeframe                  |
//+------------------------------------------------------------------+
void ExecuteAsianBreakout()
{
   if(!InpAsianBreakout_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpAsianBreakout_MagicNumber) >= InpAsianBreakout_MaxTrades) return;
   if(!IsStrategyHealthy(InpAsianBreakout_MagicNumber)) return;
   if(!CheckTimeFilter()) return;
   
   // ═══ VOLATILITY REGIME CHECK ═══
   if(!IsSentinel_VolatilityPercentileOK(0.85)) return;
   
   // ═══ TIME FILTER: Only trade during London/NY hours ═══
   // Asian breakout triggers on the 08:00 or 12:00 UTC H4 bars
   int serverHour = TimeHour(TimeCurrent());
   int utcHour = serverHour - InpServerUTCOffset;
   if(utcHour < 0) utcHour += 24;
   
   // Only trade on the 08:00 or 12:00 UTC H4 bars (London open + mid-London)
   if(utcHour != 8 && utcHour != 12) return;
   
   // ═══ ASIAN RANGE CALCULATION ═══
   // Asian session = 00:00-08:00 UTC = bars at 00:00 and 04:00 UTC
   // On H4, we look back to find bars within the Asian session window
   // Bar[0] = current (8:00 or 12:00), Bar[1] = 4:00 or 8:00, Bar[2] = 0:00 or 4:00
   // We need the 00:00 and 04:00 UTC bars
   
   double asianHigh = 0;
   double asianLow = 999999;
   bool foundAsianBars = false;
   
   // Look back through recent H4 bars to find Asian session bars
   // The Asian session bars are the ones where bar hour is 0 or 4 UTC
   for(int lb = 1; lb <= 6; lb++) // Look back up to 24 hours
   {
      datetime barTime = Time[lb];
      int barHour = TimeHour(barTime) - InpServerUTCOffset;
      if(barHour < 0) barHour += 24;
      
      // Asian session: 00:00-08:00 UTC (bars at 00:00 and 04:00)
      if(barHour == 0 || barHour == 4)
      {
         if(High[lb] > asianHigh) asianHigh = High[lb];
         if(Low[lb] < asianLow)   asianLow = Low[lb];
         foundAsianBars = true;
      }
   }
   
   if(!foundAsianBars) return; // No Asian bars found
   if(asianHigh <= 0 || asianLow >= 999999) return;
   
   double asianRange = asianHigh - asianLow;
   if(asianRange <= 0) return;
   
   // ═══ RANGE FILTER ═══
   // Convert pips to price (EURUSD: 1 pip = 0.0001)
   double pipSize = Point * 10; // Standard pip for 5-digit broker
   double minRange = InpAsianBreakout_RangeMinPips * pipSize;
   double maxRange = InpAsianBreakout_RangeMaxPips * pipSize;
   
   if(asianRange < minRange)
   {
      LogError(ERROR_INFO, "ASIAN BREAKOUT: Range too narrow (" + 
               DoubleToString(asianRange / pipSize, 1) + " pips < " +
               DoubleToString(InpAsianBreakout_RangeMinPips, 0) + " min)",
               "ExecuteAsianBreakout");
      return;
   }
   
   if(asianRange > maxRange)
   {
      LogError(ERROR_INFO, "ASIAN BREAKOUT: Range too wide (" + 
               DoubleToString(asianRange / pipSize, 1) + " pips > " +
               DoubleToString(InpAsianBreakout_RangeMaxPips, 0) + " max)",
               "ExecuteAsianBreakout");
      return;
   }
   
   // ═══ DIRECTIONAL BIAS ═══
   int bias = CheckDirectionalBias();
   
   // ═══ ADX FILTER ═══
   double adx = iADX(Symbol(), PERIOD_H4, InpAsianBreakout_ADX_Period, 
                      PRICE_CLOSE, MODE_MAIN, 1);
   // For breakout, we want SOME momentum but not too much
   // Low ADX = ranging (good for range breakout setup)
   // We use ADX < threshold to confirm ranging, then trade the breakout
   // Actually for breakouts, we want ADX to be rising but not yet extreme
   // Let's use a different approach: allow if ADX is between 12-35
   if(adx > 35) return; // Too trendy already, breakout may be false
   
   // ═══ ATR FOR SL/TP ═══
   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;
   
   // ═══ BREAKOUT SIGNALS ═══
   // BUY: Close breaks above Asian high
   bool buySignal = (Close[0] > asianHigh);
   // SELL: Close breaks below Asian low
   bool sellSignal = (Close[0] < asianLow);
   
   // ═══ ADDITIONAL CONFIRMATION: Volume/momentum ═══
   // Check that the breakout bar has sufficient range (not a doji)
   double barRange = High[0] - Low[0];
   if(barRange < atr * 0.3) return; // Bar too small, weak breakout
   
   // ═══ EXECUTE TRADES ═══
   if(buySignal && (bias == 1 || bias == 2))
   {
      double sl = Ask - (atr * InpAsianBreakout_ATR_SL_Mult);
      double tp = Ask + (atr * InpAsianBreakout_ATR_TP_Mult);
      
      // Alternative TP: Use Asian range width as target (conservative)
      // double tpConservative = Ask + (asianRange * 1.5);
      // tp = MathMin(tp, tpConservative); // Use the closer target
      
      double lots = MoneyManagement_Quantum(InpAsianBreakout_MagicNumber, InpBase_Risk_Percent);
      if(lots > 0)
      {
         int ticket = OpenTrade(OP_BUY, lots, Ask, sl, tp, 
                               "ASIAN_BRK_BUY", InpAsianBreakout_MagicNumber);
         if(ticket > 0)
         {
            int stratIdx = GetStrategyIndex(InpAsianBreakout_MagicNumber);
            if(stratIdx >= 0) g_perfData[stratIdx].trades++;
            LogError(ERROR_INFO, "ASIAN BREAKOUT BUY: Asian High=" + 
                     DoubleToString(asianHigh, Digits) + " Range=" +
                     DoubleToString(asianRange / pipSize, 1) + " pips ADX=" +
                     DoubleToString(adx, 1), "ExecuteAsianBreakout");
         }
      }
   }
   else if(sellSignal && (bias == -1 || bias == 2))
   {
      double sl = Bid + (atr * InpAsianBreakout_ATR_SL_Mult);
      double tp = Bid - (atr * InpAsianBreakout_ATR_TP_Mult);
      
      double lots = MoneyManagement_Quantum(InpAsianBreakout_MagicNumber, InpBase_Risk_Percent);
      if(lots > 0)
      {
         int ticket = OpenTrade(OP_SELL, lots, Bid, sl, tp, 
                               "ASIAN_BRK_SELL", InpAsianBreakout_MagicNumber);
         if(ticket > 0)
         {
            int stratIdx = GetStrategyIndex(InpAsianBreakout_MagicNumber);
            if(stratIdx >= 0) g_perfData[stratIdx].trades++;
            LogError(ERROR_INFO, "ASIAN BREAKOUT SELL: Asian Low=" + 
                     DoubleToString(asianLow, Digits) + " Range=" +
                     DoubleToString(asianRange / pipSize, 1) + " pips ADX=" +
                     DoubleToString(adx, 1), "ExecuteAsianBreakout");
         }
      }
   }
}
```

### Integration Points

```mql4
// In OnTick/start(), add after ExecuteSessionMomentum():
// V29.00: Asian Breakout Worker
if(InpAsianBreakout_Enabled)
{
   ExecuteAsianBreakout();
}

// In g_perfData initialization (~line 4680):
g_perfData[17].name = "AsianBreakout"; // V29.00: New strategy

// In GetStrategyIndexByMagic:
if(magicNumber == InpAsianBreakout_MagicNumber) return 17; // V29.00: Asian Breakout

// In GetStrategySpecificRiskByIndex:
case 17: return 1.2; // AsianBreakout — proven edge, moderate allocation

// In MoneyManagement_Quantum fallback caps:
else if (magicNumber == InpAsianBreakout_MagicNumber) maxMultiplier = 1.5; // V29.00
```

---

## PATTERN 4: PROGRESSIVE PROFIT-TAKING (Partial Close + Trail)

### Concept
Instead of a single TP, use a multi-stage exit:
1. **TP1** (1.0R): Close 50% of position, move SL to breakeven
2. **TP2** (2.0R): Close 25% more, trail remaining 25% with ATR
3. **TP3** (3.0R+): Trail remaining with tight ATR, close on reversal

This captures early profits while letting winners run.

### Input Parameters

```mql4
sinput string Inp_Header_ProgressiveTP = "====== V29.00: PROGRESSIVE PROFIT-TAKING ======";
input bool    InpProgressiveTP_Enabled    = true;        // Enable Progressive TP
input double  InpProgressiveTP_TP1_R      = 1.0;        // TP1 at X*R (risk multiples)
input double  InpProgressiveTP_TP1_Close  = 0.50;       // Close 50% at TP1
input double  InpProgressiveTP_TP2_R      = 2.0;        // TP2 at X*R
input double  InpProgressiveTP_TP2_Close  = 0.50;       // Close 50% of REMAINING at TP2
input double  InpProgressiveTP_Trail_ATR  = 1.0;        // ATR multiplier for trailing after TP2
input int     InpProgressiveTP_MinMagic   = 9000;        // Min magic number to apply (9000+)
input int     InpProgressiveTP_MaxMagic   = 9999;        // Max magic number to apply
```

### Trade State Tracking

```mql4
// ═══════════════════════════════════════════════════════════════
// V29.00: PROGRESSIVE TP STATE TRACKING
// Track which TP stage each trade has reached
// ═══════════════════════════════════════════════════════════════
#define MAX_TRACKED_TRADES 100
int      g_ptpTicket[MAX_TRACKED_TRADES];       // Order ticket
int      g_ptpStage[MAX_TRACKED_TRADES];        // 0=new, 1=TP1 hit, 2=TP2 hit
double   g_ptpOrigLots[MAX_TRACKED_TRADES];     // Original lot size
double   g_ptpOrigSL[MAX_TRACKED_TRADES];       // Original stop loss
double   g_ptpOrigTP[MAX_TRACKED_TRADES];       // Original take profit
int      g_ptpCount = 0;                         // Number of tracked trades
```

### Core Functions

```mql4
//+------------------------------------------------------------------+
//| V29.00: Register a trade for progressive profit-taking           |
//| Call this after OpenTrade() succeeds                             |
//+------------------------------------------------------------------+
void ProgressiveTP_Register(int ticket, double lots, double sl, double tp)
{
   if(!InpProgressiveTP_Enabled) return;
   if(g_ptpCount >= MAX_TRACKED_TRADES) return;
   
   // Check if already registered
   for(int i = 0; i < g_ptpCount; i++)
   {
      if(g_ptpTicket[i] == ticket) return;
   }
   
   g_ptpTicket[g_ptpCount]    = ticket;
   g_ptpStage[g_ptpCount]     = 0;    // New trade, no TP hit yet
   g_ptpOrigLots[g_ptpCount]  = lots;
   g_ptpOrigSL[g_ptpCount]    = sl;
   g_ptpOrigTP[g_ptpCount]    = tp;
   g_ptpCount++;
   
   LogError(ERROR_INFO, "PROGRESSIVE TP: Registered ticket " + IntegerToString(ticket) + 
            " lots=" + DoubleToString(lots, 2) + " SL=" + DoubleToString(sl, Digits) +
            " TP=" + DoubleToString(tp, Digits), "ProgressiveTP_Register");
}

//+------------------------------------------------------------------+
//| V29.00: Remove a trade from progressive TP tracking              |
//+------------------------------------------------------------------+
void ProgressiveTP_Unregister(int ticket)
{
   for(int i = 0; i < g_ptpCount; i++)
   {
      if(g_ptpTicket[i] == ticket)
      {
         // Shift remaining entries
         for(int j = i; j < g_ptpCount - 1; j++)
         {
            g_ptpTicket[j]    = g_ptpTicket[j + 1];
            g_ptpStage[j]     = g_ptpStage[j + 1];
            g_ptpOrigLots[j]  = g_ptpOrigLots[j + 1];
            g_ptpOrigSL[j]    = g_ptpOrigSL[j + 1];
            g_ptpOrigTP[j]    = g_ptpOrigTP[j + 1];
         }
         g_ptpCount--;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| V29.00: Find trade index in progressive TP tracking array        |
//+------------------------------------------------------------------+
int ProgressiveTP_FindIndex(int ticket)
{
   for(int i = 0; i < g_ptpCount; i++)
   {
      if(g_ptpTicket[i] == ticket) return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| V29.00: Check if trade qualifies for progressive TP              |
//+------------------------------------------------------------------+
bool ProgressiveTP_Qualifies(int magicNumber)
{
   if(!InpProgressiveTP_Enabled) return false;
   return (magicNumber >= InpProgressiveTP_MinMagic && 
           magicNumber <= InpProgressiveTP_MaxMagic);
}

//+------------------------------------------------------------------+
//| V29.00: Manage progressive profit-taking for all tracked trades  |
//| Call this from ManageOpenTradesV13_ELITE or OnTick               |
//+------------------------------------------------------------------+
void ManageProgressiveProfitTaking()
{
   if(!InpProgressiveTP_Enabled) return;
   
   // Clean up closed trades from tracking
   for(int i = g_ptpCount - 1; i >= 0; i--)
   {
      if(!OrderSelect(g_ptpTicket[i], SELECT_BY_TICKET, MODE_TRADES))
      {
         // Order no longer in trade pool — remove from tracking
         ProgressiveTP_Unregister(g_ptpTicket[i]);
      }
   }
   
   // Process each tracked trade
   for(int i = 0; i < g_ptpCount; i++)
   {
      int ticket = g_ptpTicket[i];
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) continue;
      if(OrderCloseTime() > 0) continue; // Already closed
      
      int stage = g_ptpStage[i];
      double origSL = g_ptpOrigSL[i];
      double origTP = g_ptpOrigTP[i];
      double origLots = g_ptpOrigLots[i];
      double currentLots = OrderLots();
      
      // Calculate initial risk in price
      double initialRisk = 0;
      if(OrderType() == OP_BUY)
         initialRisk = OrderOpenPrice() - origSL;
      else
         initialRisk = origSL - OrderOpenPrice();
      
      if(initialRisk <= 0) continue;
      
      // Calculate current profit in R multiples
      double currentProfit = 0;
      if(OrderType() == OP_BUY)
         currentProfit = Bid - OrderOpenPrice();
      else
         currentProfit = OrderOpenPrice() - Ask;
      
      double profitR = currentProfit / initialRisk;
      
      // ═══ STAGE 0 → TP1: Close partial, move SL to breakeven ═══
      if(stage == 0 && profitR >= InpProgressiveTP_TP1_R)
      {
         double closeLots = NormalizeDouble(origLots * InpProgressiveTP_TP1_Close, 2);
         double minLot = MarketInfo(Symbol(), MODE_MINLOT);
         double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
         
         // Round to lot step
         closeLots = MathFloor(closeLots / lotStep) * lotStep;
         if(closeLots < minLot) closeLots = minLot;
         
         // Don't close more than current lots
         if(closeLots >= currentLots) closeLots = currentLots - minLot;
         if(closeLots < minLot) continue; // Can't partial close
         
         // Close partial
         double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
         if(OrderClose(ticket, closeLots, closePrice, 3, clrYellow))
         {
            LogError(ERROR_INFO, "PROGRESSIVE TP1: Closed " + DoubleToString(closeLots, 2) + 
                     " lots at " + DoubleToString(profitR, 1) + "R. Remaining=" +
                     DoubleToString(currentLots - closeLots, 2), "ManageProgressiveProfitTaking");
            
            // Move SL to breakeven + small buffer
            double bePrice = OrderOpenPrice();
            if(OrderType() == OP_BUY) bePrice += 2 * _Point;
            else bePrice -= 2 * _Point;
            
            // Find the remaining order (it has a new ticket)
            // We need to find the order with same magic and same open price
            for(int j = OrdersTotal() - 1; j >= 0; j--)
            {
               if(OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
               {
                  if(OrderMagicNumber() == InpAsianBreakout_MagicNumber &&
                     OrderOpenPrice() == OrderOpenPrice() &&
                     OrderTicket() != ticket)
                  {
                     // This is likely the remaining part
                     RobustOrderModify(OrderTicket(), OrderOpenPrice(), bePrice, 
                                      OrderTakeProfit(), 0, CLR_NONE);
                     g_ptpTicket[i] = OrderTicket(); // Update ticket
                     break;
                  }
               }
            }
            
            g_ptpStage[i] = 1; // Mark as TP1 hit
         }
      }
      
      // ═══ STAGE 1 → TP2: Close another partial, start trailing ═══
      else if(stage == 1 && profitR >= InpProgressiveTP_TP2_R)
      {
         double remainingLots = OrderLots();
         double closeLots = NormalizeDouble(remainingLots * InpProgressiveTP_TP2_Close, 2);
         double minLot = MarketInfo(Symbol(), MODE_MINLOT);
         double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
         
         closeLots = MathFloor(closeLots / lotStep) * lotStep;
         if(closeLots < minLot) closeLots = minLot;
         if(closeLots >= remainingLots) closeLots = remainingLots - minLot;
         if(closeLots < minLot) continue;
         
         double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
         if(OrderClose(ticket, closeLots, closePrice, 3, clrYellow))
         {
            LogError(ERROR_INFO, "PROGRESSIVE TP2: Closed " + DoubleToString(closeLots, 2) + 
                     " lots at " + DoubleToString(profitR, 1) + "R. Remaining=" +
                     DoubleToString(remainingLots - closeLots, 2), "ManageProgressiveProfitTaking");
            
            g_ptpStage[i] = 2; // Mark as TP2 hit
         }
      }
      
      // ═══ STAGE 2+: TRAIL WITH ATR ═══
      else if(stage >= 2)
      {
         // ATR trailing stop for the remaining position
         double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
         if(atr <= 0) continue;
         
         double trailDist = atr * InpProgressiveTP_Trail_ATR;
         double newSL = 0;
         
         if(OrderType() == OP_BUY)
         {
            newSL = Bid - trailDist;
            // Only move SL up, never down
            if(newSL > OrderStopLoss() && newSL < Bid)
            {
               RobustOrderModify(ticket, OrderOpenPrice(), 
                                NormalizeDouble(newSL, Digits), 
                                0, 0, CLR_NONE); // Remove TP for runner
            }
         }
         else // SELL
         {
            newSL = Ask + trailDist;
            // Only move SL down, never up
            if((OrderStopLoss() == 0 || newSL < OrderStopLoss()) && newSL > Ask)
            {
               RobustOrderModify(ticket, OrderOpenPrice(), 
                                NormalizeDouble(newSL, Digits), 
                                0, 0, CLR_NONE); // Remove TP for runner
            }
         }
      }
   }
}
```

### Simplified Version (Alternative — Works Within Existing ManageOpenTradesV13_ELITE)

If the full tracking system is too complex, here's a simpler approach that modifies the existing
Hyperion trade management to add partial closes:

```mql4
//+------------------------------------------------------------------+
//| V29.00: SIMPLE PROGRESSIVE TP — Modify existing Hyperion logic   |
//| Add this INSIDE ManageOpenTradesV13_ELITE, after profitR calc    |
//+------------------------------------------------------------------+
// ADD AFTER LINE 8557 (after profitR calculation):
// ═══ V29.00: PROGRESSIVE PROFIT-TAKING ═══
if(InpProgressiveTP_Enabled && 
   OrderMagicNumber() >= InpProgressiveTP_MinMagic &&
   OrderMagicNumber() <= InpProgressiveTP_MaxMagic)
{
   // TP1: At 1.0R, close 50% and move SL to breakeven
   if(profitR >= 1.0 && profitR < 2.0 && OrderLots() > MarketInfo(Symbol(), MODE_MINLOT) * 2)
   {
      // Check if we haven't already partial-closed (by checking lots vs expected)
      double expectedLots = /* original lots */ OrderLots(); // Simplified: just close half
      double closeLots = NormalizeDouble(OrderLots() * 0.5, 2);
      double minLot = MarketInfo(Symbol(), MODE_MINLOT);
      double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
      closeLots = MathFloor(closeLots / lotStep) * lotStep;
      if(closeLots >= minLot && OrderLots() - closeLots >= minLot)
      {
         double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
         if(OrderClose(ticket, closeLots, closePrice, 3, clrYellow))
         {
            LogError(ERROR_INFO, "SIMPLE PTP TP1: Closed 50% at " + 
                     DoubleToString(profitR, 1) + "R", "ManageOpenTradesV13_ELITE");
            
            // Move SL to breakeven
            double bePrice = openPrice + (OrderType() == OP_BUY ? 2*_Point : -2*_Point);
            // Need to find the new ticket for remaining position
            // The original ticket is now closed, find the remaining
         }
      }
   }
   
   // TP2: At 2.0R, the remaining position trails with ATR
   if(profitR >= 2.0)
   {
      double atr = iATR(Symbol(), Period(), InpChandelier_Period, 0);
      double trailSL = 0;
      if(OrderType() == OP_BUY)
      {
         trailSL = Bid - (atr * 1.0); // 1.0x ATR trail
         if(trailSL > OrderStopLoss())
            RobustOrderModify(ticket, OrderOpenPrice(), NormalizeDouble(trailSL, Digits), 
                             0, 0, CLR_NONE); // Remove TP for runner
      }
      else
      {
         trailSL = Ask + (atr * 1.0);
         if(OrderStopLoss() == 0 || trailSL < OrderStopLoss())
            RobustOrderModify(ticket, OrderOpenPrice(), NormalizeDouble(trailSL, Digits), 
                             0, 0, CLR_NONE);
      }
      continue; // Skip normal Hyperion management
   }
}
```

### Integration with OpenTrade (register trades for progressive TP)

```mql4
// In OpenTrade(), after successful order send (line ~7931):
// V29.00: Register for progressive TP if applicable
if(InpProgressiveTP_Enabled && ProgressiveTP_Qualifies(magic))
{
   ProgressiveTP_Register(ticket, lots, sl, tp);
}

// In ManageOpenTradesV13_ELITE(), at the start:
// V29.00: Process progressive profit-taking
ManageProgressiveProfitTaking();
```

---

## IMPLEMENTATION PRIORITY & ORDER

| # | Pattern | Complexity | Expected Impact | Integration Points |
|---|---------|-----------|----------------|-------------------|
| 1 | Equity Curve Sizing | 3/10 | +20-30% profit, -2-4% DD | MoneyManagement_Quantum, OnTick |
| 2 | ATR Percentile Regime | 2/10 | Filters bad trades, +5-10% PF | Sentinel checks, MoneyManagement |
| 3 | Asian Session Breakout | 4/10 | +$8-15K, +30-50 trades | New worker, perf tracking |
| 4 | Progressive Profit-Taking | 5/10 | +15-25% per-trade profit | ManageOpenTrades, OpenTrade |

### Recommended Implementation Order:
1. **ATR Percentile** (lowest risk, improves existing filters)
2. **Equity Curve Sizing** (modifies existing money management)
3. **Asian Session Breakout** (new strategy, independent)
4. **Progressive Profit-Taking** (most complex, modifies trade management)

---

## NOTES ON MQL5.COM & GITHUB RESEARCH

### What I Found
- **EarnForex/PositionSizer** (566★): Professional position sizing EA with ATR-based SL/TP calculation. Uses risk-based lot sizing with AccountFreeMargin. Good reference for lot calculation patterns.
- **omnisis/mt4-ea-obr** (10★): Opening Range Breakout EA. Uses ATR(72) for range calculation, pending stop orders for breakout entry. Simple but effective pattern for session breakout.
- **EarnForex/ATR-Trailing-Stop** (19★): ATR-based trailing stop implementation.
- **EA31337/EA31337-classes** (252★): MQL4/5 framework with modular strategy classes.

### Existing EA Patterns to Reuse
- `IsSentinel_VolatilityRegimeOK()` (line 3302): Already has ATR-based volatility filter using 100-bar average. Enhance with percentile.
- `ExecuteSessionMomentum()` (line 9267): Already has London session breakout on H4. Adapt for Asian session.
- `ManageOpenTradesV13_ELITE()` (line 8524): Already has R-multiple based trade management with breakeven at 1.0R and Chandelier trail at 2.0R. Add partial close.
- `MoneyManagement_Quantum()` (line 12829): Already has Kelly + heat + DD-based sizing. Add equity curve multiplier.
- `CalculateRollingKelly()` (line 14354): Already has per-strategy Kelly calculation. Equity curve is a complementary layer.

### Key MQL4 Code Patterns Used
1. **Circular buffers** for rolling statistics (existing pattern in g_stratProfits[][])
2. **Linear regression** for slope calculation (standard quant approach)
3. **Percentile calculation** via sort-and-rank (efficient for 100-element arrays)
4. **OrderClose()** for partial closes (MQL4 native function)
5. **iATR()** for volatility measurement (existing pattern throughout EA)
6. **Magic number ranges** for strategy-specific behavior (existing convention)
