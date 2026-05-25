# EURUSD H4 DATA ANALYSIS RESULTS
## Date: 2026-05-25

---

## DATA OVERVIEW
- **Bars:** 4,436
- **Period:** July 3, 2023 → April 20, 2026 (~2.8 years)
- **Current Price:** 1.17633

---

## SESSION ANALYSIS

**Best Hours for Trading (H4 bars):**

| Hour (UTC) | Avg Return | Volatility | Bullish % | Verdict |
|-----------|------------|------------|-----------|---------|
| 20:00 (Sydney) | +1.0 pips | 9.8 pips | 52.4% | BEST |
| 12:00 (NY) | +0.7 pips | 27.1 pips | 50.7% | Good |
| 00:00 (Asian) | -0.0 pips | 15.5 pips | 49.8% | Neutral |
| 8:00 (London) | -0.1 pips | 16.9 pips | 47.4% | Weak |
| 16:00 (NY Close) | -0.2 pips | 16.6 pips | 49.0% | Weak |
| 4:00 (Asian) | -0.4 pips | 15.4 pips | 47.7% | Worst |

**Insight:** Sydney open (hour 20) has the strongest bullish bias with lowest volatility. This aligns with our SessionMomentum strategy targeting hours 8-17 — we're MISSING the best hour.

---

## GAP ANALYSIS (Phantom Strategy)

**144 Monday gaps found in 2.8 years**

| Gap Size | Count | Direction |
|----------|-------|-----------|
| ≥ 3 pips | 107 | 49 up, 58 down |
| ≥ 5 pips | 85 | 40 up, 45 down |
| ≥ 8 pips | 66 | 31 up, 35 down |
| ≥ 10 pips | 57 | 27 up, 30 down |
| ≥ 15 pips | 39 | 17 up, 22 down |
| ≥ 20 pips | 25 | 11 up, 14 down |

**Average gap:** 12.2 pips | **Median:** 7.1 pips | **Max:** 115.7 pips

**Insight:** Our current Phantom filter (min 5, max 30) captures ~80 gaps per year. Tightening to min 10 would give ~20 higher-quality gaps with better fill probability.

---

## VOLATILITY REGIMES

| Regime | % of Time | ATR (pips) | Avg Return |
|--------|-----------|------------|------------|
| HIGH | 14% | 41.6 | +0.83 pips |
| NORMAL | 82% | 23.1 | +0.23 pips |
| LOW | 4% | 13.7 | **+5.51 pips** |

**Current ATR(14):** 20.3 pips (below average of 25.4)

**KEY FINDING:** LOW volatility regime has 6.7x better returns than HIGH vol. When the market is quiet, mean reversion and range strategies dominate. When vol spikes, trend-following wins.

**Recommendation:** In the EA, detect ATR regime and switch strategy allocation:
- LOW vol → Boost MeanReversion, Phantom
- HIGH vol → Boost SessionMomentum, NoiseBreakout

---

## MEAN REVERSION ANALYSIS

| BB Settings | Touches | Reversion Rate |
|------------|---------|----------------|
| BB(15, 1.5) | 1,188 | 52.5% |
| BB(15, 2.0) | 420 | 52.9% |
| BB(20, 2.0) | 496 | 50.8% |
| BB(20, 1.7) | 878 | 52.5% |
| BB(25, 1.5) | 1,287 | **53.1%** |
| BB(25, 2.0) | 494 | 52.2% |

**Insight:** Reversion rates are barely above 50% — this is a weak edge. Mean reversion needs additional filters (RSI extremes, session timing, vol regime) to be profitable.

---

## TREND STRUCTURE

**Current Position:**
- SMA(20): 1.17865 (-23.2 pips below) — SHORT-TERM BEARISH
- SMA(50): 1.17485 (+14.8 pips above) — MEDIUM-TERM BULLISH
- SMA(100): 1.16464 (+116.9 pips above) — BULLISH
- SMA(200): 1.16019 (+161.4 pips above) — STRONGLY BULLISH

**Trend Score Distribution:**
- Score 0 (fully bearish): 33.3%
- Score 1: 17.7%
- Score 2: 16.2%
- Score 3 (fully bullish): 32.8%

**Insight:** Market is structurally bullish but in short-term pullback. Gap-fading strategies (Phantom) should work well in this environment.

---

## ACTIONABLE RECOMMENDATIONS

### For MQL4 EA (Parameter Tuning):

1. **Session Filter:** Add hour 20 (Sydney) to SessionMomentum trade_hours
2. **Phantom:** Keep min_gap at 5, but add RSI filter (fade only when RSI < 30 or > 70)
3. **Reaper:** PipStep should adapt to ATR — when ATR < 15, use tighter grid (12 pips)
4. **Mean Reversion:** Only trade in LOW vol regime (ATR < 18 pips)
5. **Risk:** In HIGH vol, reduce position size by 50%

### For Python Training (Next Steps):

1. Build regime detection model (classify LOW/NORMAL/HIGH from ATR)
2. Train strategy selector (which strategy to activate per regime)
3. Build gap fill predictor (when will Monday gap fill?)
4. Optimize entry timing (which hour to enter for each strategy)

---

*Analysis based on 4,436 bars of real EURUSD H4 data*
*July 2023 — April 2026*
