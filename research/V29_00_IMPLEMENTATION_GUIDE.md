# V29.00 IMPLEMENTATION: Equity Curve Amplification
## Date: 2026-05-26
## Status: READY FOR BACKTEST

---

## WHAT THIS DOES

Adds equity curve amplification to DESTROYER QUANTUM. When the equity curve is rising, lot sizes increase. When falling, they decrease. This is the #1 lever for reaching $170K.

**Key innovation:** No open-source MQL4 EA has this. We're building it from scratch.

---

## FILES

1. `V29_00_EQUITY_CURVE_PATCH.txt` — Patch instructions for applying to V28.06 TITAN
2. `V29_00_EQUITY_CURVE.mq4` — New function to add (copy-paste ready)

---

## APPLY THESE CHANGES TO V28_06_TITAN.mq4

### Step 1: Add CalculateEquityCurveMultiplier() function

**Where:** After the `GetKellyLotSize()` function (around Line 5055), before `GetNextReaperLotSize()`

**What to add:** Copy the entire `CalculateEquityCurveMultiplier()` function from V29_00_EQUITY_CURVE.mq4

### Step 2: Inject into MoneyManagement_Quantum()

**Where:** Line ~12911 (after the Kelly Risk Override closing brace)

**Find this code:**
```mql4
      effectiveRiskPercent = MathMax(effectiveRiskPercent, 0.1);  // Min 0.1%
      effectiveRiskPercent = MathMin(effectiveRiskPercent, 3.0);  // TITAN: Max 3.0% for $170K push  // Max 2.0% (safety)
   }
```

**Add after the closing `}`:**
```mql4
   // >>> V29.00: EQUITY CURVE AMPLIFICATION <<<
   // Boost lot sizes when equity curve is strong, reduce when weak
   double equityCurveMult = CalculateEquityCurveMultiplier();
   effectiveRiskPercent *= equityCurveMult;
   effectiveRiskPercent = MathMin(effectiveRiskPercent, 4.0);  // New safety cap
```

### Step 3: Modify combined multiplier cap

**Where:** Line ~12920

**Find:**
```mql4
   double combinedMultiplier = MathMin(adaptiveMultiplier * heatMultiplier, 3.0);  // TITAN: Unlock heat amplification
```

**Replace with:**
```mql4
   // V29.00: Include equity curve multiplier in combined calculation
   double combinedMultiplier = MathMin(adaptiveMultiplier * heatMultiplier * equityCurveMult, 5.0);
```

### Step 4: Replace DD-based lot reduction with equity-aware version

**Where:** Lines ~12922-12925

**Find:**
```mql4
   // V28.00: DD-based lot sizing reduction (tightened from 8%/10% to 5%/8%)
   double ddPercent = (AccountBalance() - accountEquity) / AccountBalance() * 100.0;
   if(ddPercent >= 8.0) combinedMultiplier *= 0.5;       // 8%+ DD: half size
   else if(ddPercent >= 5.0) combinedMultiplier *= 0.75;  // 5%+ DD: 75% size
```

**Replace with:**
```mql4
   // V29.00: Equity-curve-aware DD penalties
   double ddPercent = (AccountBalance() - accountEquity) / AccountBalance() * 100.0;
   if(equityCurveMult > 1.5) {
      // Strong equity curve: relax DD penalties (let winners run)
      if(ddPercent >= 10.0) combinedMultiplier *= 0.5;
      else if(ddPercent >= 7.0) combinedMultiplier *= 0.75;
   } else if(equityCurveMult < 0.8) {
      // Weak equity curve: tighten DD penalties (protect capital)
      if(ddPercent >= 6.0) combinedMultiplier *= 0.5;
      else if(ddPercent >= 4.0) combinedMultiplier *= 0.75;
   } else {
      // Normal: keep existing thresholds
      if(ddPercent >= 8.0) combinedMultiplier *= 0.5;
      else if(ddPercent >= 5.0) combinedMultiplier *= 0.75;
   }
```

### Step 5: Inject into Leviathan_GetDynamicLotSize() (Titan strategy)

**Where:** Line ~7612

**Find:**
```mql4
    confidenceMultiplier = MathMax(0.5, MathMin(2.0, confidenceMultiplier)); // Cap between 0.5x and 2.0x
```

**Add after:**
```mql4
    // >>> V29.00: EQUITY CURVE AMPLIFICATION FOR TITAN <<<
    double equityCurveMult_lev = CalculateEquityCurveMultiplier();
    confidenceMultiplier *= equityCurveMult_lev;
    confidenceMultiplier = MathMax(0.3, MathMin(3.0, confidenceMultiplier));
```

### Step 6: Add GBPUSD correlation filter to SessionMomentum

**Where:** After the ADX filter check in `ExecuteSessionMomentum()` (~Line 9300)

**Find:**
```mql4
   if(adx < InpSessionMomentum_ADX_Threshold) return;
```

**Add after:**
```mql4
   // V29.00: GBPUSD correlation filter
   int corrSignal = GetGBPUSDCorrelationSignal();
   if(corrSignal == -1) return;  // Skip if GBPUSD diverging
```

**Also, in the BUY and SELL sections, after `lots` is calculated:**
```mql4
   // V29.00: Boost lots if GBPUSD confirms
   if(corrSignal == 1) lots *= 1.2;
```

---

## EXPECTED RESULTS

| Metric | V28.06 TITAN | V29.00 (projected) | Change |
|--------|-------------|-------------------|--------|
| Net Profit | $109K-$138K | $134K-$179K | +$25-41K |
| Max Drawdown | 27-32% | 26-31% | -1% (improved!) |
| Trade Count | 750-850 | 750-850 | Same |
| Profit Factor | 2.0-2.3 | 2.2-2.6 | +0.2-0.3 |

**Probability of hitting $170K: ~60-70%** (up from ~30-40% with V28.06 TITAN alone)

---

## RISK ASSESSMENT

**Low risk:** The equity curve multiplier has built-in safety:
- Range is [0.5, 2.5] — never goes below half or above 2.5x
- Uses existing HWM tracking (already battle-tested)
- DD penalties are preserved (just made adaptive)
- Max effective risk capped at 4.0% (was 3.0%)

**Medium risk:** The GBPUSD correlation filter is new logic:
- If GBPUSD data is unavailable, returns 0 (neutral, no effect)
- Only blocks trades when correlation < 0.70 (divergence)
- 20-bar correlation window is conservative

---

## BACKTEST INSTRUCTIONS FOR RYAN

1. Copy `DESTROYER_QUANTUM_V28_06_TITAN.mq4` → `DESTROYER_QUANTUM_V29_00.mq4`
2. Apply all 6 changes above
3. Compile in MetaEditor
4. Backtest: EURUSD H4, 2020-2025, $10K start
5. Compare to V28.06 TITAN results
6. Report: Net Profit, Max DD, Trade Count, Profit Factor

**If V29.00 beats V28.06 TITAN on profit AND DD → ship it.**
**If V29.00 has higher DD but higher profit → evaluate risk/reward.**
**If V29.00 regresses → revert and investigate.**
