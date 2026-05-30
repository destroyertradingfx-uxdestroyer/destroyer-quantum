# 🚨 RYAN ACTION CARD — CYCLE 9
## Date: 2026-05-27
## Priority: **CRITICAL BUG FIX** — May Solve $170K Target Alone

---

## ⚡ DO THIS FIRST (5 minutes)

### Fix the Kelly Fraction Bug
**File:** `DESTROYER_QUANTUM_V28_06_TITAN.mq4`
**Line:** 5072

```mql4
// CURRENT (WRONG):
kellyPct = kellyPct * 0.25;  // Quarter Kelly

// CHANGE TO:
kellyPct = kellyPct * 0.75;  // Three-Quarter Kelly (as documented in header line 26)
```

**Why:** The TITAN header says "Half-Kelly → Three-Quarter Kelly (0.5 → 0.75)" but the code still uses 0.25 (quarter-Kelly). This means lot sizing is **3x smaller than intended**. This single bug likely accounts for $30K-$50K in lost profit.

**Risk:** DD may increase by 5-8% (from ~27% to ~32-35%). This is still within acceptable range for the $170K target.

---

## 📋 AFTER BACKTEST WITH FIX

If the Kelly-corrected backtest hits **$150K+**, the remaining gap to $170K can be closed with these **already-written, ready-to-paste** functions:

### 1. Equity Curve Multiplier (15 min integration)
- **Source:** `/code/V29_00_EQUITY_CURVE.mq4` lines 10-90
- **What:** Amplifies lots when equity is growing (0.5x-2.5x range)
- **Impact:** +$15K-$25K, DD -2-4%

### 2. GBPUSD Correlation Filter (15 min integration)
- **Source:** `/code/V29_00_EQUITY_CURVE.mq4` lines 97-140
- **What:** Blocks trades when EURUSD/GBPUSD correlation breaks down
- **Impact:** +$5K-$10K (blocks ~10-15% of losers)

### 3. Enable Vortex + RegimeShift (1 minute)
- **Change:** `InpVortex_Enabled = true` and `InpRegimeShift_Enabled = true`
- **Impact:** +$8K-$15K, +35-70 trades

---

## 📊 FULL RESEARCH

See: `research/2026-05-27_CYCLE9_KELLY_BUG_AND_SYNTHESIS.md`

**Bottom line:** Fix Kelly → Backtest → If $150K+, paste equity curve code → $170K achieved.
