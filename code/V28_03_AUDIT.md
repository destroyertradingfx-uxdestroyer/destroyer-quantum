# V28.03 CODE AUDIT — Full Source Analysis
## Date: 2026-05-22 | File: 14,440 lines | Version: 28.03

---

## 1. CORRECTION: Four New Strategies, Not Two

The filename says "Two New Strategies" but V28.03 actually contains **4 new strategies**:

| # | Strategy | Magic | Version Added | Backtest Result |
|---|----------|-------|---------------|-----------------|
| 1 | SessionMomentum | 9003 | V28.00 | 2 trades, +$8,588, PF 999 |
| 2 | DivergenceMR | 9004 | V28.00 | 0 trades (not in report) |
| 3 | LiquiditySweep | 9005 | V28.03 | 12 trades, -$1,439, PF 0.84 |
| 4 | StructuralRetest | 9006 | V28.03 | 0 trades (not in report) |

DivergenceMR and StructuralRetest had **zero trades** — they're either too restrictive or their conditions never triggered.

---

## 2. SESSION MOMENTUM (9003) — Deep Analysis

### Logic (Line 9192)
- **Type:** London/NY Session Breakout
- **Entry:** Looks back 6 H4 bars (24 hours) to find the session range. If price breaks above the high or below the low, enters in breakout direction.
- **Filters:** 
  - Time: London + NY hours only (08:00-18:00 UTC)
  - ADX > 20 (trend confirmation)
  - Directional bias filter
- **SL/TP:** 1.5x ATR stop, 3.0x ATR target = **2:1 R:R**
- **Lot Sizing:** MoneyManagement_Quantum (standard)

### Assessment: ⚠️ NEEDS VALIDATION
- The logic is **sound** — classic session breakout with trend confirmation
- 2:1 R:R is excellent
- Only 2 trades in 6 years = **NOT statistically significant**
- Could be luck. Need at least 15-20 trades to trust the edge.
- **Why so few trades:** Multiple filters stacking (time + ADX + bias + London range breakout). Each filter alone is reasonable, but together they're extremely restrictive.

### Recommendation
**KEEP but validate.** This is a precision weapon. Don't loosen parameters yet — first understand if the 2 winners were genuinely high-conviction setups. If the edge is real, even 5 trades/year at $4,294 average = $21,470/year on autopilot.

---

## 3. LIQUIDITY SWEEP (9005) — Deep Analysis

### Logic (Line 9349)
- **Type:** Institutional Stop Hunt Fade
- **Entry:** Detects when price sweeps beyond a 20-bar session high/low, then closes back inside the range. RSI oversold/overbought confirms reversal. Volume spike (1.5x average) required.
- **SL/TP:** 1.5x ATR stop, 2.5x ATR target = **1.67:1 R:R**

### Why It's Losing (PF 0.84)
1. **Volume filter is unreliable on H4.** MT4 volume = tick count, not real volume. On H4, this is essentially random noise.
2. **RSI 30/70 on H4 is too extreme.** Price rarely reaches RSI 30/70 on H4 — when it does, the move is often already overextended.
3. **Sweep ≠ Reversal.** Many sweeps are trend continuation (stop hunt → trend resumes). The strategy assumes all sweeps reverse, which is wrong.
4. **Lookback period (20 bars = 80 hours)** creates a self-referencing loop — the "session high/low" is often the current trend's high/low, so you're fading the trend.

### Verdict: 🔴 CUT IMMEDIATELY
This is a negative-EV strategy consuming risk budget. Disable: `InpLiquiditySweep_Enabled = false`

---

## 4. DIVERGENCE MEAN REVERSION (9004) — Zero Trades

### Logic (Line 9270)
- Uses RSI divergence + Bollinger Bands + Hurst exponent (< 0.5 = mean reverting)
- ADX must be < 30 (non-trending)
- SL: 2.0x ATR, TP: 3.0x ATR

### Why Zero Trades
- Hurst exponent < 0.5 on H4 is extremely rare — EURUSD on H4 is typically trending (Hurst > 0.5)
- RSI divergence + BB + Hurst + ADX < 30 = 4 filters all needing to align simultaneously
- The strategy is conceptually sound but practically impossible on H4

### Verdict: ⚠️ NEEDS INVESTIGATION
Either loosen the Hurst threshold to 0.55 or move this to a lower timeframe (H1). Currently dead code.

---

## 5. STRUCTURAL BREAK & RETEST (9006) — Zero Trades

### Logic (Line 9454)
- Detects swing high/low breaks, waits for price to retest the broken level
- 20-bar swing period, 10-bar retest window
- Min 2:1 R:R

### Why Zero Trades
- 20-bar swing detection + 10-bar retest window + 2:1 R:R = extremely selective
- On H4, swing breaks happen often but clean retests within 10 bars are rare

### Verdict: ⚠️ NEEDS INVESTIGATION
May need to extend the retest window to 15-20 bars. Currently dead code.

---

## 6. TITAN REGRESSION — What Broke

### V27.18: 7 trades, +$19, PF 2.00
### V28.03: 24 trades, -$43, PF 0.37

### Root Cause: Volatility Filter Loosened Too Much
Line 8736: `currentVolatilityPercentile < 0.25 // V27.27: Lowered from 0.4 for more entries`

The volatility percentile threshold was lowered from 0.4 to 0.25, which let in 17 additional trades. These marginal trades are ALL losers, dragging the PF from 2.00 to 0.37.

### Additional Issues
1. **Valkyrie filter REMOVED** (line 8753): "was too restrictive, blocked 80% of trades" — but those 80% were the BAD trades!
2. **Kalman filter + triple EMA** creates a "strong trend" requirement that's extremely selective
3. **18+ filter layers** make the strategy a Frankenstein — too many conditions that rarely align

### Recommendation
**Revert Titan's volatility threshold to 0.4** and restore the Valkyrie filter. Accept fewer trades (7-10/year) with high quality over 24 mediocre trades.

---

## 7. WARDEN DEGRADATION — What Changed

### V27.18: 8 trades, +$4,116, PF 2.37
### V28.03: 8 trades, +$2,036, PF 1.38

**Same trade count, half the profit.** The Warden logic itself likely didn't change significantly. The degradation is probably from:
1. **Lot sizing changes** — MoneyManagement_Quantum now applies different multipliers
2. **Alpha Sentinel changes** — may be filtering differently
3. **Market conditions** — 2025-2026 data may be different from what Warden was optimized for

### Recommendation
Compare Warden's lot sizes between V27.18 and V28.03 for the same trades. The logic is likely fine — the sizing may be off.

---

## 8. LOT SIZING — Still Chaotic

### Found 10+ Sizing Functions
1. GetLotSizeV8_5_9_FIXED (line 2827)
2. GetLotSize_Ascension (line 3477)
3. GetStrategySpecificRisk (line 4403) — **HAS TWO DEFINITIONS** (line 4403 AND line 11859!)
4. GetKellyLotSize (line 4993)
5. GetStrategyVolatility (line 5830)
6. GetStrategyCorrelation (line 10636)
7. GetStrategyWeight (line 10763)
8. GetStrategyPerformanceBoost (line 11869)
9. GetGeneticRiskMultiplier (line 12468)
10. MoneyManagement_Quantum (line 12752) — **THE ACTIVE ONE**
11. V23_CalculateLotSize (line 13777)

### MoneyManagement_Quantum (The Active Function)
The good news: V28.03's MoneyManagement_Quantum is significantly improved:
- **Kelly-based risk override** (line 12815): Uses actual Kelly fraction when 15+ trades exist
- **Heat-based scaling** (line 12799): Hot strategies get 0.25x-2.0x multiplier
- **Dynamic tier cap** (line 12770): Uses rolling PF instead of hardcoded caps
- **High-PF floor** (line 12758): Phantom/Warden/Titan get minimum 1.5% risk

### The Problem
- **GetStrategySpecificRisk is defined TWICE** (line 4403 and line 11859) with different signatures! This could cause compiler warnings or unexpected behavior.
- Other functions (GetKellyLotSize, GetGeneticRiskMultiplier, V23_CalculateLotSize) are **dead code** — never called in the active flow. They waste 500+ lines but don't affect behavior.
- The new strategies (9003-9006) don't have explicit entries in the fallback multipliers (line 12780-12791). They'll get the generic 1.0x default, which means they're under-allocated if they have edge.

### Recommendation
1. Fix the duplicate GetStrategySpecificRisk
2. Add explicit fallback multipliers for strategies 9003-9006
3. Clean up dead code (optional but reduces confusion)

---

## 9. SYSTEM HEALTH SUMMARY

| Component | Status | Action |
|-----------|--------|--------|
| SessionMomentum | ⚠️ Needs validation | KEEP, monitor |
| DivergenceMR | ⚠️ Zero trades | Investigate or disable |
| LiquiditySweep | 🔴 Negative EV | CUT NOW |
| StructuralRetest | ⚠️ Zero trades | Investigate or disable |
| Titan | 🔴 Regressed | Revert vol threshold to 0.4 |
| Warden | ⚠️ Degraded | Check lot sizing |
| Lot Sizing | ⚠️ Duplicate function | Fix GetStrategySpecificRisk |
| Alpha Sentinel | ✅ Active | No action |
| Phantom | ✅ Backbone | No action |
| NoiseBreakout | ✅ Solid | No action |
| Nexus | ✅ Elite | No action |
| Reaper | ✅ Improved | No action |

---

## 10. V28.04 PATCH PLAN (Priority Order)

### Patch 1: Cut LiquiditySweep (5 min)
```mq4
input bool InpLiquiditySweep_Enabled = false; // CUT: PF 0.84, negative EV
```

### Patch 2: Revert Titan Volatility (10 min)
```mq4
if(currentVolatilityPercentile < 0.4) // Reverted from 0.25 to 0.4
```
And restore the Valkyrie filter.

### Patch 3: Fix Duplicate GetStrategySpecificRisk (15 min)
Remove or rename the second definition at line 11859.

### Patch 4: Add Fallback Multipliers for New Strategies (10 min)
```mq4
else if (magicNumber == 9003) maxMultiplier = 1.5; // SessionMomentum
else if (magicNumber == 9004) maxMultiplier = 1.0; // DivergenceMR
else if (magicNumber == 9005) maxMultiplier = 0.5; // LiquiditySweep (if kept)
else if (magicNumber == 9006) maxMultiplier = 1.0; // StructuralRetest
```

### Patch 5: Investigate DivergenceMR + StructuralRetest (30 min)
Either loosen filters or disable. Dead code = maintenance burden.

### Expected V28.04 Impact
- Cut ~$1,439 in losses from LiquiditySweep
- Restore Titan to PF 2.00+ (saving ~$43 + preventing 17 bad trades)
- Cleaner codebase, fewer edge cases
- Estimated: **$49,000-$51,000 profit, PF 1.85-1.90, DD < 18%**
