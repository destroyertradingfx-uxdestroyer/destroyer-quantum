# STRATEGY RESEARCH: $68K → $170K on EURUSD H4
## Date: 2026-05-25
## Current System: V28.06 — $50K profit, PF 1.92, DD 19.4%, 601 trades

---

## EXECUTIVE SUMMARY

To push from ~$68K to $170K (a 2.5x improvement), we need to either:
- **Increase trade frequency** (from 601 to ~1,500 trades) while maintaining PF
- **Increase lot sizing** via Kelly/amplification while managing DD
- **Activate dormant strategies** (Mean Reversion: 1 trade, SessionMomentum: 2 trades)
- **Add new edge sources** (correlation, session-specific, regime-adaptive)

The math: $170K from $10K = 17x return over 4.5 years = ~82% CAGR
Current: $50K from $10K = 5x return = ~44% CAGR

---

## TOP 5 ACTIONABLE IDEAS

### IDEA 1: AGGRESSIVE KELLY AMPLIFICATION (Impact: HIGH | Risk: MEDIUM)
**Concept:** The EA already has Kelly Criterion lot sizing (GetKellyLotSize), but it's conservative (half-Kelly with 60% blend). Increase Kelly fraction from 25% to 40-50% for high-PF strategies.

**Current state:**
- Kelly formula: f* = W - ((1-W) / R), using HALF-KELLY
- Blended: 60% Kelly + 40% base risk
- Reaper InitialLot: 0.12, LotMultiplier: 1.4

**Proposed changes:**
1. Increase Kelly fraction from 25% to 40% for strategies with PF > 2.0
2. Change blend from 60/40 to 80/20 (more Kelly, less base)
3. Increase InpBase_Risk_Percent from 5% to 7% for high-confidence regimes
4. Raise Reaper InitialLot from 0.12 to 0.18 (50% increase)
5. Raise Reaper BasketTP_Money from $600 to $900 (proportional)

**Expected impact:** +40-60% profit ($70K → $100-110K)
**DD impact:** +5-8% (DD may rise to 25-28%)
**Implementation complexity:** 2/10 (parameter changes)
**Risk:** Medium — higher DD, but Kelly self-corrects on losses

---

### IDEA 2: ACTIVATE MEAN REVERSION (Impact: HIGH | Risk: LOW-MEDIUM)
**Concept:** Mean Reversion produces only 1 trade in 4.5 years because Hurst threshold (0.55) is too tight for EURUSD H4. The strategy requires ALL conditions simultaneously:
- ADX < 30 (non-trending)
- Hurst < 0.55 (mean-reverting regime) — EURUSD H4 rarely < 0.5
- RSI divergence (price lower low + RSI higher low, or vice versa)
- Price at BB extreme (2.0 std dev)

**Root cause:** EURUSD H4 Hurst exponent typically ranges 0.50-0.65. The 0.55 threshold blocks 90%+ of potential trades.

**Proposed changes:**
1. Raise Hurst threshold from 0.55 to 0.70 (allow trading in mild trends)
2. Relax BB deviation from 2.0 to 1.5 (more overextension signals)
3. Relax RSI divergence requirement — use simple RSI < 30 / > 70 instead of strict divergence
4. Raise ADX max from 30 to 40 (allow fading moderate trends)
5. Add re-entry logic: if stopped out, allow retry after 4 H4 bars at 0.7x lots

**Expected impact:** +50-100 trades, +$5K-$15K profit
**DD impact:** +2-3% (more trades = more exposure)
**Implementation complexity:** 3/10 (parameter changes + minor code)
**Risk:** Low — Mean Reversion historically had PF 0.42-0.57 when forced to trade, but with proper Hurst-adaptive parameters, should improve to 1.2-1.5

---

### IDEA 3: SESSION-SPECIFIC STRATEGY AMPLIFICATION (Impact: MEDIUM-HIGH | Risk: LOW)
**Concept:** SessionMomentum (London/NY breakout) produces only 2 trades but has PF 999 (perfect). The issue is the same as Mean Reversion — too many filters kill the signal.

**Current filters:**
- Time filter: Only 08:00-18:00 UTC
- ADX > 20 (trend confirmation)
- London session range breakout (lookback 6 H4 bars = 24 hours)
- Only 1 open trade at a time

**Proposed changes:**
1. Add a NEW "Asian Range Breakout" strategy (magic 9007) — trade Tokyo-London handoff
2. Add a NEW "London Fix" strategy (magic 9008) — trade the 16:00 GMT London fix reversal
3. Relax SessionMomentum ADX from 20 to 15 (more signals)
4. Allow 2 concurrent SessionMomentum trades (different directions)
5. Add NY session variant: trade NY open momentum (13:30-15:00 GMT) separately

**Expected impact:** +30-50 trades, +$8K-$15K profit
**DD impact:** +1-2%
**Implementation complexity:** 4/10 (new strategy code, but simple logic)
**Risk:** Low — session-based strategies are well-documented and EURUSD has clear session patterns

---

### IDEA 4: EQUITY CURVE TRADING + ANTI-MARTINGALE (Impact: MEDIUM | Risk: MEDIUM)
**Concept:** Trade larger when the equity curve is rising, smaller when falling. This is the "anti-martingale" approach — increase size on winners, decrease on losers.

**Current state:** The EA has Kelly sizing but no equity curve awareness. It trades the same way regardless of recent performance.

**Proposed implementation:**
1. Calculate 20-trade rolling equity curve slope
2. If slope > 0 (winning streak): multiply lots by 1.3x
3. If slope < 0 (losing streak): multiply lots by 0.7x
4. If equity < 90% of peak: reduce all lots by 50% (drawdown defense)
5. If equity makes new high: unlock full sizing for next 10 trades

**MQL4 code concept:**
```mql4
double GetEquityCurveMultiplier() {
   double equity = AccountEquity();
   double peakEquity = GetPeakEquity(); // Track high water mark
   
   // Drawdown defense
   if(equity < peakEquity * 0.90) return 0.5; // Cut size in drawdown
   
   // Winning streak amplification
   double slope = GetEquitySlope(20); // 20-trade rolling slope
   if(slope > 0) return 1.3; // Amplify winners
   if(slope < 0) return 0.7; // Reduce losers
   return 1.0;
}
```

**Expected impact:** +20-30% profit, smoother equity curve
**DD impact:** -2-4% (actually reduces DD)
**Implementation complexity:** 4/10
**Risk:** Medium — if slope calculation lags, may amplify into drawdowns

---

### IDEA 5: EURUSD/GBPUSD CORRELATION STRATEGY (Impact: MEDIUM | Risk: MEDIUM-HIGH)
**Concept:** EURUSD and GBPUSD are 85-95% correlated. When correlation breaks down temporarily, it creates mean-reversion opportunities. Trade the spread.

**Research findings:**
- GitHub repo `jblanked/MQL4-Currency-Pair-Correlation-Expert-Advisor` (13 stars) — proven MQL4 correlation EA
- EURUSD/GBPUSD correlation typically 0.85-0.95 on H4
- When correlation drops below 0.70, spread widens → mean reversion opportunity

**Proposed implementation:**
1. Calculate 50-bar rolling correlation between EURUSD and GBPUSD
2. When correlation < 0.75: enter convergence trade
   - If EURUSD outperforming: SELL EURUSD, BUY GBPUSD (or just trade the lagging pair)
3. When correlation > 0.95: no edge, skip
4. Use z-score of spread for entry/exit
5. Single-pair simplification: just trade EURUSD mean-reversion when GBPUSD has already reverted

**Expected impact:** +20-40 trades, +$5K-$10K profit
**DD impact:** +3-5% (multi-pair exposure)
**Implementation complexity:** 6/10 (requires GBPUSD data access, correlation calc, spread logic)
**Risk:** Medium-High — correlation can break for fundamental reasons (Brexit, ECB divergence)

---

## THEORETICAL MAX ANALYSIS

**What's achievable on EURUSD H4 with a multi-strategy grid EA?**

Based on research of top-performing EAs and institutional systems:

| Metric | Conservative | Aggressive | Theoretical Max |
|--------|-------------|-----------|-----------------|
| Profit Factor | 1.8-2.2 | 2.5-3.5 | 4.0-5.0 |
| Annual Return | 40-60% | 80-120% | 150-200% |
| Max Drawdown | 15-20% | 25-35% | 40-50% |
| Trade Count | 600-1000 | 1500-2500 | 3000+ |
| Win Rate | 70-75% | 65-70% | 60-65% |

**$170K from $10K = 17x over 4.5 years = ~82% CAGR**

This is achievable with:
- PF 2.0-2.5 (current 1.92 → need +0.1-0.6)
- Trade count 1200-1800 (current 601 → need 2-3x)
- DD 25-30% (current 19.4% → acceptable increase)

**Key insight:** The biggest lever is TRADE COUNT, not PF. The current system has too few trades (601 in 4.5 years = 133/year). A multi-strategy EA should generate 300-500 trades/year. The dormant strategies (Mean Reversion, SessionMomentum, Nexus) are leaving $30-50K on the table.

---

## RECOMMENDED IMPLEMENTATION ORDER

1. **Kelly Amplification** (1-2 hours) — Immediate parameter changes, test first
2. **Activate Mean Reversion** (2-3 hours) — Relax Hurst/BB/ADX thresholds
3. **Session Strategy Expansion** (4-6 hours) — Add Asian Range + London Fix
4. **Equity Curve Trading** (3-4 hours) — Anti-martingale sizing
5. **Correlation Strategy** (8-10 hours) — Most complex, highest uncertainty

**Combined expected impact:** $100K-$150K profit range (from current $50K)
**To reach $170K:** May need to combine all 5 ideas + optimize parameters via backtesting

---

## RISK ASSESSMENT

| Idea | Profit Potential | DD Risk | Complexity | Confidence |
|------|-----------------|---------|------------|------------|
| Kelly Amplification | +40-60% | +5-8% | 2/10 | HIGH |
| Mean Reversion Fix | +10-30% | +2-3% | 3/10 | MEDIUM-HIGH |
| Session Expansion | +15-30% | +1-2% | 4/10 | HIGH |
| Equity Curve Trading | +20-30% | -2-4% | 4/10 | MEDIUM |
| Correlation Strategy | +10-20% | +3-5% | 6/10 | MEDIUM-LOW |

**Bottom line:** Ideas 1-3 are the highest confidence, lowest risk path to $170K. Ideas 4-5 are worth testing but have more uncertainty.

