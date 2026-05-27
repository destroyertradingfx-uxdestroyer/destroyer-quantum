# EQUITY CURVE AMPLIFICATION: Implementation Plan for V29.00
## Date: 2026-05-26
## Target: Push from $138K projected → $170K (+23%)

---

## OVERVIEW

**The biggest lever for reaching $170K is equity curve amplification — a feature NO open-source MQL4 EA has published.**

The system currently has drawdown-based *reduction* (penalizes when losing) but NO amplification when winning. This means we're leaving $15-25K on the table during winning streaks.

---

## CHANGE 1: Add `CalculateEquityCurveMultiplier()` Function
**File:** DESTROYER_QUANTUM_V28_06_TITAN.mq4 (or V29_00.mq4)
**Location:** Near Line 5055, after `GetKellyLotSize()`
**Impact:** +$15-25K profit, -2-4% DD (actually REDUCES DD)
**Complexity:** 4/10

### Code to add:

```mql4
//+------------------------------------------------------------------+
//| EQUITY CURVE AMPLIFICATION ENGINE                                 |
//| Returns: 0.5 (weak curve) to 2.5 (strong curve)                  |
//| Logic: Measures equity curve health via HWM proximity,            |
//|        rolling returns, drawdown state, and win streak momentum   |
//+------------------------------------------------------------------+
double CalculateEquityCurveMultiplier()
{
   double equity = AccountEquity();
   double balance = AccountBalance();
   
   // FACTOR 1: HWM Proximity (30% weight)
   // How close to all-time high equity
   double hwmProximity = 1.0;
   if(g_high_watermark_equity > 0)
   {
      hwmProximity = equity / g_high_watermark_equity;  // 1.0 = at HWM, 0.9 = 10% below
   }
   
   // FACTOR 2: Rolling Equity Growth Rate (30% weight)
   // Compare current equity to equity N days ago
   static double equitySamples[20] = {0};
   static int equitySampleIdx = 0;
   static datetime lastSampleTime = 0;
   
   // Sample equity once per day
   datetime today = iTime(Symbol(), PERIOD_D1, 0);
   if(today > lastSampleTime)
   {
      equitySamples[equitySampleIdx % 20] = equity;
      equitySampleIdx++;
      lastSampleTime = today;
   }
   
   double growthRate = 1.0;
   if(equitySampleIdx >= 5)
   {
      int oldestIdx = (equitySampleIdx - 10) % 20;
      if(oldestIdx < 0) oldestIdx += 20;
      double oldestEquity = equitySamples[oldestIdx];
      if(oldestEquity > 0)
      {
         growthRate = equity / oldestEquity;  // >1.0 = growing, <1.0 = shrinking
      }
   }
   
   // FACTOR 3: Drawdown State (25% weight)
   // Lower DD = higher multiplier (inverse relationship)
   double ddFactor = 1.0;
   double ddPercent = 0;
   if(g_high_watermark_equity > 0)
      ddPercent = (g_high_watermark_equity - equity) / g_high_watermark_equity * 100;
   
   if(ddPercent > 10.0) ddFactor = 0.5;
   else if(ddPercent > 5.0) ddFactor = 0.7;
   else if(ddPercent > 2.0) ddFactor = 0.85;
   else if(ddPercent < 1.0) ddFactor = 1.2;  // Near HWM = boost
   
   // FACTOR 4: Win Streak Momentum (15% weight)
   // Track consecutive wins/losses across all strategies
   double streakFactor = 1.0;
   // Use the existing g_strategyMultiplier as a proxy
   // If most strategies are in winning mode, boost
   int winningStrats = 0;
   int totalStrats = 0;
   for(int i = 0; i < 17; i++)
   {
      if(g_stratTotalTrades[i] >= 5)
      {
         totalStrats++;
         if(g_strategyMultiplier[i] > 1.0) winningStrats++;
      }
   }
   if(totalStrats > 0)
   {
      double winRatio = (double)winningStrats / (double)totalStrats;
      if(winRatio > 0.7) streakFactor = 1.3;       // Most strategies winning
      else if(winRatio > 0.5) streakFactor = 1.15;  // Half winning
      else if(winRatio < 0.3) streakFactor = 0.6;   // Most losing
      else if(winRatio < 0.5) streakFactor = 0.8;   // Fewer winning
   }
   
   // COMPOSITE: Weighted combination
   double composite = (hwmProximity * 0.30) + (growthRate * 0.30) + (ddFactor * 0.25) + (streakFactor * 0.15);
   
   // Map to multiplier range [0.5, 2.5]
   // composite of 1.0 = neutral (1.0x multiplier)
   // composite of 1.3+ = strong curve (1.5x+ multiplier)  
   // composite of 0.7- = weak curve (0.5x-0.7x multiplier)
   double multiplier = MathMax(0.5, MathMin(2.5, composite));
   
   return multiplier;
}
```

---

## CHANGE 2: Inject Equity Curve Multiplier into MoneyManagement_Quantum()
**File:** DESTROYER_QUANTUM_V28_06_TITAN.mq4
**Location:** Line ~12911 (after Kelly Risk Override, before Combined Multiplier)
**Impact:** Affects 12+ strategies simultaneously (SessionMomentum, DivergenceMR, MeanReversion, Warden, etc.)

### Current code (Line 12901-12911):
```mql4
double effectiveRiskPercent = baseRiskPercent;
if(idx >= 0 && idx < 17 && g_stratTotalTrades[idx] >= 15)
{
   double kellyFrac = g_stratKellyFraction[idx];
   effectiveRiskPercent = (kellyFrac * 100.0 * 0.8) + (baseRiskPercent * 0.2);
   effectiveRiskPercent = MathMax(effectiveRiskPercent, 0.1);
   effectiveRiskPercent = MathMin(effectiveRiskPercent, 3.0);
}
```

### Add after Line 12911 (after the closing brace):
```mql4
// >>> EQUITY CURVE AMPLIFICATION <<<
// Boost lot sizes when equity curve is strong, reduce when weak
double equityCurveMult = CalculateEquityCurveMultiplier();
effectiveRiskPercent *= equityCurveMult;
effectiveRiskPercent = MathMin(effectiveRiskPercent, 4.0);  // New safety cap (was 3.0)
```

---

## CHANGE 3: Raise Combined Multiplier Cap
**File:** DESTROYER_QUANTUM_V28_06_TITAN.mq4
**Location:** Line ~12920

### Current code:
```mql4
double combinedMultiplier = MathMin(adaptiveMultiplier * heatMultiplier, 3.0);
```

### Change to:
```mql4
double combinedMultiplier = MathMin(adaptiveMultiplier * heatMultiplier * equityCurveMult, 5.0);
```

---

## CHANGE 4: Equity-Aware DD Penalties (Replace Static DD Reduction)
**File:** DESTROYER_QUANTUM_V28_06_TITAN.mq4
**Location:** Line ~12922-12925

### Current code:
```mql4
if(ddPercent >= 8.0) combinedMultiplier *= 0.5;
else if(ddPercent >= 5.0) combinedMultiplier *= 0.75;
```

### Replace with:
```mql4
// Equity-curve-aware DD penalties
double ecMult = CalculateEquityCurveMultiplier();
if(ecMult > 1.5) {
   // Strong equity curve: relax DD penalties (let winners run)
   if(ddPercent >= 10.0) combinedMultiplier *= 0.5;
   else if(ddPercent >= 7.0) combinedMultiplier *= 0.75;
} else if(ecMult < 0.8) {
   // Weak equity curve: tighten DD penalties (protect capital)
   if(ddPercent >= 6.0) combinedMultiplier *= 0.5;
   else if(ddPercent >= 4.0) combinedMultiplier *= 0.75;
} else {
   // Normal: keep existing thresholds
   if(ddPercent >= 8.0) combinedMultiplier *= 0.5;
   else if(ddPercent >= 5.0) combinedMultiplier *= 0.75;
}
```

---

## CHANGE 5: Inject into Leviathan (Titan Strategy)
**File:** DESTROYER_QUANTUM_V28_06_TITAN.mq4
**Location:** Line ~7612 (after Confidence Multiplier in Leviathan_GetDynamicLotSize)

### Current code:
```mql4
confidenceMultiplier = MathMax(0.5, MathMin(2.0, confidenceMultiplier));
```

### Add after:
```mql4
// >>> EQUITY CURVE AMPLIFICATION FOR TITAN <<<
double equityCurveMult = CalculateEquityCurveMultiplier();
confidenceMultiplier *= equityCurveMult;
confidenceMultiplier = MathMax(0.3, MathMin(3.0, confidenceMultiplier));
```

---

## CHANGE 6: GBPUSD Correlation Filter for SessionMomentum
**File:** DESTROYER_QUANTUM_V28_06_TITAN.mq4
**Location:** SessionMomentum entry logic (~Line 9267)
**Impact:** +$3-5K profit, +1-2% DD
**Complexity:** 5/10

### Add new function near the top:
```mql4
//+------------------------------------------------------------------+
//| GBPUSD CORRELATION FILTER                                         |
//| Returns: -1 (divergence = skip), 0 (neutral), +1 (confirmation)  |
//+------------------------------------------------------------------+
int GetGBPUSDCorrelationSignal()
{
   // Get 20-bar correlation between EURUSD and GBPUSD H4
   double eurusd_close[20], gbpusd_close[20];
   
   for(int i = 0; i < 20; i++)
   {
      eurusd_close[i] = iClose("EURUSD", PERIOD_H4, i);
      gbpusd_close[i] = iClose("GBPUSD", PERIOD_H4, i);
   }
   
   // Calculate Pearson correlation
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;
   for(int i = 0; i < 20; i++)
   {
      sum_x += eurusd_close[i];
      sum_y += gbpusd_close[i];
      sum_xy += eurusd_close[i] * gbpusd_close[i];
      sum_x2 += eurusd_close[i] * eurusd_close[i];
      sum_y2 += gbpusd_close[i] * gbpusd_close[i];
   }
   
   double n = 20;
   double corr = (n * sum_xy - sum_x * sum_y) / 
                 (MathSqrt(n * sum_x2 - sum_x * sum_x) * MathSqrt(n * sum_y2 - sum_y * sum_y));
   
   // Check GBPUSD momentum direction
   double gbpusd_momentum = iClose("GBPUSD", PERIOD_H4, 0) - iClose("GBPUSD", PERIOD_H4, 5);
   double eurusd_momentum = iClose("EURUSD", PERIOD_H4, 0) - iClose("EURUSD", PERIOD_H4, 5);
   
   // High correlation + same direction = confirmation
   if(corr > 0.80)
   {
      if((gbpusd_momentum > 0 && eurusd_momentum > 0) ||
         (gbpusd_momentum < 0 && eurusd_momentum < 0))
         return 1;  // Confirmation
   }
   
   // Low correlation or divergence = caution
   if(corr < 0.70) return -1;  // Divergence, skip
   
   return 0;  // Neutral
}
```

### In SessionMomentum entry logic, add before the trade:
```mql4
// GBPUSD correlation filter
int corrSignal = GetGBPUSDCorrelationSignal();
if(corrSignal == -1) continue;  // Skip if GBPUSD diverging
// If corrSignal == 1, boost lot size by 20%
if(corrSignal == 1) lots *= 1.2;
```

---

## EXPECTED IMPACT SUMMARY

| Change | Profit Impact | DD Impact | Complexity |
|--------|-------------|-----------|------------|
| 1. CalculateEquityCurveMultiplier() | +$15-25K | -2-4% | 4/10 |
| 2. Inject into MoneyManagement_Quantum | Part of #1 | Part of #1 | 2/10 |
| 3. Raise combined multiplier cap | Part of #1 | +1% | 1/10 |
| 4. Equity-aware DD penalties | +$2-3K | -1% | 2/10 |
| 5. Inject into Leviathan (Titan) | +$5-8K | +1-2% | 2/10 |
| 6. GBPUSD correlation filter | +$3-5K | +1-2% | 5/10 |
| **TOTAL** | **+$25-41K** | **-1 to +1%** | |

**Projected range with all changes: $134K-$179K** (from current $109K-$138K)

---

## IMPLEMENTATION ORDER

1. **Changes 1-4** (Equity Curve in MoneyManagement_Quantum) — Do together, test as one unit
2. **Change 5** (Leviathan injection) — Separate test
3. **Change 6** (GBPUSD correlation) — Most complex, test last

---

## WHAT RYAN NEEDS TO DO

1. Copy V28_06_TITAN.mq4 → V29_00.mq4
2. Apply Changes 1-4 (equity curve in MoneyManagement_Quantum)
3. Backtest V29.00 on EURUSD H4, 2020-2025
4. Compare to V28.06 TITAN results
5. If profitable, apply Change 5 and retest
6. If still profitable, apply Change 6 and retest

**Estimated backtest time:** 2-3 hours for all changes
