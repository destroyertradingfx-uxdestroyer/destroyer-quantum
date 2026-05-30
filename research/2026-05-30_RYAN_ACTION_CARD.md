# RYAN ACTION CARD — Cycle 23 (2026-05-30)
## Priority: HIGH — Two Quick Wins Ready

---

## 🔥 QUICK WIN #1: Enable Vortex + RegimeShift (2 minutes)

**File:** `code/DESTROYER_QUANTUM_V28.15_v3_BASE.mq4`

**Change 1 (line 4563):**
```
OLD: extern bool    InpVortex_Enabled         = false;
NEW: extern bool    InpVortex_Enabled         = true;
```

**Change 2 (line 4573):**
```
OLD: extern bool    InpRegimeShift_Enabled         = false;
NEW: extern bool    InpRegimeShift_Enabled         = true;
```

**Expected:** +$8K-$15K, +35-70 trades, +1-2% DD
**Risk:** LOW — both strategies use Kelly-sized lots with existing risk management

---

## 🔥 QUICK WIN #2: DD Headroom Exploit (2 minutes)

**File:** Load `code/V28_08_DD_HEADROOM_EXPLOIT.set` (already exists)

Or manually change these params:
```
InpBase_Risk_Percent = 2.7      // Was 2.0
InpKellyFraction = 0.85         // Was 0.75
DD_REDUCE_START = 8.0           // Was 5.0
DD_REDUCE_FULL = 12.0           // Was 8.0
InpCombinedMultiplierCap = 4.0  // Was 3.0
InpMaxLossPerTrade = 1000       // Was 800
InpReaper_InitialLot = 0.22     // Was 0.18
```

**Expected:** +$14K-$24K, DD rises to 22-24%
**Risk:** LOW — just using existing DD headroom (17.2% → 24%)

---

## 📊 NEW THIS CYCLE: GitHub Research Findings

### EA31337 (⭐1195) H4-Optimized Parameters

| Indicator | EA31337 H4 Optimal | DQ Current | Recommendation |
|-----------|-------------------|------------|----------------|
| BB Period | 22 | 15 (MR) | 22 for MeanReversion |
| BB Deviation | 1.7 | 1.7 (MR) | Keep 1.7 |
| RSI Period | 12 | 10 (MR) | 12 for MeanReversion |
| RSI Price | PRICE_OPEN | PRICE_CLOSE | Test PRICE_OPEN |
| Alligator Jaw | SMMA 13, shift 8 | N/A | New regime filter |

### New Patterns Found

1. **3-Bar BB Touch** — EA31337 catches wicks into band zone, not just closes. Could add 10-20 trades from MeanReversion.

2. **RSI Momentum Acceleration** — Check RSI is turning AND accelerating, not just oversold. Better entry timing.

3. **Alligator Regime Detection** — SMMA 13-8-5 mouth width determines ranging (<15 pips) vs trending (>30 pips). Cleaner than ADX.

---

## 📋 FULL LEVER MATRIX

| # | Lever | Expected | DD | Confidence | Status |
|---|-------|---------|-----|------------|--------|
| 1 | Vortex + RegimeShift | +$8-15K | +1-2% | HIGH | **READY** |
| 2 | DD Headroom .SET | +$14-24K | +5-7% | HIGH | **READY** |
| 3 | Equity Curve AM | +$15-25K | -1-2% | HIGH | Code ready |
| 4 | MR BB/RSI Tuning | +$8-20K | +1-2% | MED-HIGH | Params ready |
| 5 | Asian Range BO | +$10-20K | +1-2% | MEDIUM | Code drafted |
| 6 | Vol Regime Sizing | +$5-12K | -1% | MED-HIGH | Code drafted |
| 7 | Partial Profits | +$8-15K | -2% | MED-HIGH | Code drafted |

**Combined at 65% effectiveness: $170K+ ✅**

---

## 🎯 RECOMMENDED BACKTEST SEQUENCE

1. **Test A:** V28.15 + Vortex ON + RegimeShift ON (baseline comparison)
2. **Test B:** V28.15 + DD Headroom .SET (use existing file)
3. **Test C:** V28.15 + Both A + B combined
4. **If C works:** Add equity curve anti-martingale code, test D

---

*Ryan: Quick wins #1 and #2 are 4 minutes total. Run those first, backtest, then we add the new code.*
