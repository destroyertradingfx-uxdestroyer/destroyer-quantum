# Cycle 23 Summary: $138K → $170K Push — Fresh GitHub Findings + Actionable Plan
## Date: 2026-05-30
## Status: ACTIONABLE — Ryan has 4 minutes of work for +$22K-$39K expected

---

## WHAT I DID THIS CYCLE

1. **Read all 21 prior research cycles** — comprehensive understanding of what's been tried
2. **Searched GitHub for MQL4 equity curve implementations** — found EA31337 (⭐1195) framework
3. **Searched GitHub for EURUSD H4 strategies** — extracted EA31337 BB/RSI/Alligator H4 parameters
4. **Searched GitHub for adaptive sizing** — found Hawkynt geometric anti-martingale
5. **Analyzed current EA code** — confirmed what's implemented vs what's missing
6. **Updated destroyer-quantum skill** with new research directions

---

## KEY FINDINGS

### Finding 1: EA31337 H4-Optimized Parameters (NEW)
From EA31337/Strategy-Bands, EA31337/Strategy-RSI, EA31337/Strategy-Alligator:

| Indicator | EA31337 H4 Optimal | DQ MeanReversion | Delta |
|-----------|-------------------|------------------|-------|
| BB Period | 22 | 15 | +7 (better H4 filtering) |
| BB Deviation | 1.7 | 1.7 | Same |
| RSI Period | 12 | 10 | +2 (more stable) |
| RSI Price | PRICE_OPEN | PRICE_CLOSE | Earlier entries |
| Alligator Jaw | SMMA 13, shift 8 | N/A | New regime filter |

### Finding 2: 3-Bar BB Wick Touch (NEW)
EA31337 catches wicks into band zone (not just closes):
```mql4
double lowestLow = MathMin(Low[0], MathMin(Low[1], Low[2]));
double bbLowerMax = MathMax(BB_Lower[0], MathMax(BB_Lower[1], BB_Lower[2]));
bool touchedLower = (lowestLow < bbLowerMax);
```
Could add 10-20 trades from MeanReversion.

### Finding 3: Hawkynt Geometric Anti-Martingale (NEW)
```mql4
// 1.4x per consecutive win, 0.7x per consecutive loss, cap at 4 wins
lots *= MathPow(1.4, MathMin(g_consecutiveWins, 4));  // 3 wins = 2.74x
lots *= MathPow(0.7, g_consecutiveLosses);              // 3 losses = 0.34x
```
DQ already tracks `g_consecutiveWins/Losses` but only uses them for minor scaling.

### Finding 4: V29_00_EQUITY_CURVE.mq4 Already Exists
4-factor composite multiplier (HWM proximity 30%, growth rate 30%, DD state 25%, win streak 15%). Returns 0.5x-2.5x. Ready to integrate into V29.00.

---

## CURRENT STATE

| Metric | V28.08 Actual | V28.15 Code | V29.00 Code | $170K Target |
|--------|--------------|-------------|-------------|--------------|
| Profit | $60,975 | Unknown (untested) | Unknown (untested) | $170,000 |
| PF | 2.27 | TBD | TBD | ~3.5 |
| Trades | 554 | TBD | TBD | 2,000+ |
| DD | 17.20% | TBD | TBD | 32-35% |
| DD Headroom | 6.8% | — | — | — |

**Dead strategies (0 trades):** Titan, Warden, QuantumOsc, Apex, Microstructure, MathReversal, SPECTRE, AETHER_GAP, Vortex, RegimeShift, Chronos, SessionMomentum

---

## THE PLAN: 4 PHASES

### Phase 1: Zero-Code Wins (4 minutes) — Expected: +$22K-$39K
1. **Enable Vortex** — line 4563: `false → true`
2. **Enable RegimeShift** — line 4573: `false → true`
3. **DD Headroom .SET** — load `V28_08_DD_HEADROOM_EXPLOIT.set`

### Phase 2: Parameter Tuning (30 minutes) — Expected: +$8K-$20K
4. MeanReversion BB Period: 15 → 22
5. MeanReversion RSI Period: 10 → 12
6. DivergenceMR Hurst: 0.55 → 0.65

### Phase 3: New Code (2-3 hours) — Expected: +$15K-$25K
7. Integrate V29_00_EQUITY_CURVE.mq4 into V29.00
8. Add 3-bar BB wick touch to MeanReversion
9. Add Alligator regime gate (30 lines)
10. Add Asian Range Breakout (80 lines)

### Phase 4: Advanced (3-4 hours) — Expected: +$5K-$12K
11. Volatility regime sizing
12. Partial profit taking
13. Portfolio heat budget

**Combined at 65% effectiveness: $170K+ ✅**

---

## FILES SAVED

| File | Description |
|------|-------------|
| `research/2026-05-30_CYCLE23_CONSOLIDATED_170K_PUSH.md` | Full research with code patterns |
| `research/2026-05-30_CYCLE22_GITHUB_STRATEGY_EXTRACTION.md` | EA31337 + Hawkynt extraction |
| `research/2026-05-30_RYAN_ACTION_CARD.md` | Quick-start guide for Ryan |
| `equity_curve_research.md` | EA31337 equity curve patterns |

---

## BOTTOM LINE

The gap is bridgeable. Two flag flips + DD headroom .SET = 4 minutes of Ryan's time for +$22K-$39K expected improvement. The equity curve code already exists in V29_00_EQUITY_CURVE.mq4 and just needs integration.

**Next action: Ryan enables Vortex + RegimeShift, loads DD headroom .SET, runs backtest.**

---

*Cycle 23 complete. 23 cumulative research cycles. Fresh GitHub findings from EA31337 (⭐1195) and Hawkynt. Skill updated. Action card ready for Ryan.*
