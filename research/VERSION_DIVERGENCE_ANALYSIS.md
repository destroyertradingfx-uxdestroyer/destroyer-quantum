# CRITICAL FINDING: V28.07 RESURRECTION vs TITAN Divergence
## Date: 2026-05-25
## Status: REQUIRES RYAN'S DECISION

---

## THE PROBLEM

Two parallel versions exist with DIFFERENT feature sets. Neither is complete.

### V28.06 TITAN (Latest commit: BEFORE 2fd1394)
**Base:** IMPERATOR (Queen unlocked, full grid)
**Adds:** Kelly amplification + Session expansion + Nexus relaxation

| Feature | TITAN Value | V28.07 Value | Gap |
|---------|-------------|--------------|-----|
| Kelly Fraction | 0.75 (three-quarter) | 0.25 (quarter) | TITAN is 3x more aggressive |
| Queen_MaxExposureLots | 8.0 | 2.0 | TITAN is 4x more |
| SessionMomentum ADX | 15 | 20 | TITAN is looser |
| Session Time | 6-20 UTC | 8-18 UTC | TITAN is wider |
| Nexus Lookback | 30 | 50 | TITAN is tighter |
| Nexus CompressionBars | 2 | 3 | TITAN is looser |
| Nexus CompressionRatio | 0.85 | 0.75 | TITAN is looser |
| **Silicon-X** | **DISABLED** | **ENABLED** | **TITAN is correct** |
| Equity Curve Multiplier | ❌ | ✅ | V28.07 has it |
| Regime Detection | ❌ | ✅ | V28.07 has it |
| Volatility Targeting | ❌ | ✅ | V28.07 has it |
| ML-Inspired Filter | ❌ | ✅ | V28.07 has it |
| Data-Optimized MR | ❌ | ✅ | V28.07 has it |
| Asian Breakout | ❌ | ❌ | Neither has it |

### V28.07 RESURRECTION (Latest commit: 2fd1394)
**Base:** RESURRECTION (Aggressive settings, Silicon-X revived)
**Adds:** Equity curve + Regime detection + Volatility targeting + ML filter + Data-optimized MR

---

## THE VERDICT

**V28.07 RESURRECTION has more features but is built on the WRONG base.**

1. **Silicon-X ENABLED** — 3 backtests proved it's net negative (Aggressive $68K > RESURRECTION $65K > VENDETTA $64K)
2. **Queen_MaxExposureLots = 2.0** — starves Reaper of grid entries
3. **Kelly at 0.25** — missing TITAN's 3x amplification
4. **Session time 8-18** — missing TITAN's 6-20 expansion
5. **Nexus at old settings** — missing TITAN's relaxation

**TITAN has the right base but is missing V28.07's innovations.**

---

## RECOMMENDED PATH

### Option A: Merge TITAN improvements into V28.07 RESURRECTION (RECOMMENDED)
Take V28.07 RESURRECTION and apply TITAN's changes:
1. Disable Silicon-X: `InpSiliconX_Enabled = false`
2. Queen 2.0 → 8.0
3. Kelly 0.25 → 0.75
4. SessionMomentum ADX 20 → 15
5. Session time 8-18 → 6-20
6. Nexus: Lookback 50→30, CompressionBars 3→2, CompressionRatio 0.75→0.85
7. Add Asian Breakout (new strategy)

**Result:** All features combined. Expected: $150K-$200K+

### Option B: Merge V28.07 features into TITAN
Take TITAN and add:
1. Equity curve multiplier
2. Regime detection system
3. Volatility targeting
4. ML-inspired trade filter
5. Data-optimized Mean Reversion
6. Disable Silicon-X (already done in TITAN)

**Result:** Same as Option A, different starting point.

### Option C: Use V28.07 RESURRECTION as-is (NOT RECOMMENDED)
- Silicon-X will drag profits down
- Queen at 2.0 limits Reaper
- Kelly at 0.25 limits growth

---

## ASIAN BREAKOUT STATUS

**Neither version has Asian Range Breakout.** Full implementation code is ready in `research/implementation_guide_170k.md`. Needs to be added to whichever version becomes the base.

---

## EXPECTED IMPACT OF FULL MERGE

| Component | Profit | Trades | DD |
|-----------|--------|--------|-----|
| TITAN base (projected) | $109K-$138K | 750-850 | 27-32% |
| + V28.07 Equity Curve | +$15K-$25K | 0 | -2-4% |
| + V28.07 Regime Detection | +$5K-$10K | +20-50 | ±1% |
| + V28.07 Volatility Targeting | +$5K-$10K | 0 | -1-2% |
| + V28.07 ML Filter | +$3K-$5K | -50-100 | -1-2% |
| + Asian Breakout | +$10K-$20K | +20-40 | +1-2% |
| **TOTAL** | **$147K-$208K** | **740-890** | **22-31%** |

**Midpoint: ~$178K** — exceeds $170K target.

---

## ACTION ITEMS

1. **Ryan decides:** Option A or Option B (same result, different starting file)
2. **I implement:** The merge (5-10 parameter changes + Asian Breakout registration)
3. **Ryan backtests:** The merged version
4. **If below $170K:** Fine-tune individual components

**This is the fastest path to $170K.**
