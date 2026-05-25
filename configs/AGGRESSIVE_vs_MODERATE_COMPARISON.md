# AGGRESSIVE vs MODERATE — Full Parameter Comparison

**Date:** 2026-05-25
**Source:** V28_06_AGGRESSIVE.set vs V28_06_MODERATE.set

Legend:
- **↑ Higher** = Aggressive pushes value higher (more exposure/growth)
- **↓ Lower** = Aggressive pushes value lower (looser filters/more signals)
- **↔ Same** = Identical in both profiles

---

## CORE RISK (8 params — ALL differ)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpBase_Risk_Percent | 1.5 | 1.0 | +0.5 | ↑ +50% more risk per trade |
| InpBase_Risk_Percent_H1 | 0.4 | 0.25 | +0.15 | ↑ +60% more H1 risk |
| InpDefensiveDD_Percent | 20.0 | 15.0 | +5.0 | ↑ allows deeper DD before defensive |
| InpDrawdown_Risk_Mult | 0.4 | 0.3 | +0.1 | ↑ slower DD risk reduction |
| InpMaxOpenTrades | 16 | 12 | +4 | ↑ +33% more concurrent trades |
| InpMaxLotSize | 8.0 | 5.0 | +3.0 | ↑ +60% bigger max position |
| InpMaxTotalRisk_Percent | 12.0 | 8.0 | +4.0 | ↑ +50% more total risk cap |
| InpMaxRiskPerTrade | 0.8 | 0.5 | +0.3 | ↑ +60% more per-trade risk |

**Impact Assessment:** 🔴 CRITICAL — Every single core risk param is looser. Combined effect means Aggressive can have ~50% larger positions, 33% more trades open, and tolerates 33% deeper drawdowns before throttling.

---

## LEVIATHAN (3 params — ALL differ)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpLeviathan_KellyFraction | 0.35 | 0.25 | +0.10 | ↑ +40% more aggressive Kelly sizing |
| InpLeviathan_MaxRisk | 7.0 | 5.0 | +2.0 | ↑ +40% higher max risk allocation |
| InpLeviathan_MinRisk | 0.75 | 0.5 | +0.25 | ↑ +50% higher floor (never goes too small) |

**Impact Assessment:** 🟠 HIGH — Kelly-based position sizing is 40% more aggressive. Leviathan will allocate significantly more capital to high-confidence setups.

---

## QUEEN SAFETY (5 params — ALL differ)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpQueen_MaxDrawdownPct | 7.0 | 5.0 | +2.0 | ↑ +40% deeper DD allowed |
| InpQueen_MaxExposureLots | 2.0 | 1.0 | +1.0 | ↑ +100% double the max exposure |
| InpQueen_ReaperDDKillPct | 4.0 | 3.0 | +1.0 | ↑ +33% more Reaper DD tolerance |
| InpQueen_MaxConcurrentBaskets | 3 | 2 | +1 | ↑ +50% more baskets |
| InpHades_BasketStopLoss_Percent | 3.5 | 2.5 | +1.0 | ↑ +40% wider basket stop loss |

**Impact Assessment:** 🔴 CRITICAL — Queen can hold 2x the exposure lots and allow 3 baskets instead of 2. This is the biggest structural difference — Aggressive can stack significantly more positions before safety kicks in.

---

## MEAN REVERSION (5-8 params)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpMR_BB_Period | *(not set = default)* | 15 | — | Aggressive uses EA default |
| InpMR_BB_Dev | 1.7 | 1.9 | -0.2 | ↓ tighter bands = MORE signals |
| InpMR_RSI_Period | *(not set = default)* | 10 | — | Aggressive uses EA default |
| InpMR_RSI_OB | 58.0 | 62.0 | -4.0 | ↓ easier to trigger OB = MORE sells |
| InpMR_RSI_OS | 42.0 | 38.0 | +4.0 | ↓ easier to trigger OS = MORE buys |
| InpMR_CCI_Period | *(not set = default)* | 20 | — | Aggressive uses EA default |
| InpMR_ADX_Threshold | 18.0 | 20.0 | -2.0 | ↓ weaker trend required = MORE trades |
| InpMinTQSForEntry | 0.25 | 0.35 | -0.10 | ↓ -29% lower quality threshold = MORE trades |

**Impact Assessment:** 🟠 HIGH — Aggressive loosens every filter to generate more mean reversion signals. Bollinger bands are 11% tighter, RSI bands are 4 points wider each side, ADX threshold is 10% lower, and minimum quality score is 29% lower. Combined effect: significantly more MR entries.

---

## REAPER GRID (9 params — ALL differ)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpReaper_InitialLot | 0.12 | 0.08 | +0.04 | ↑ +50% bigger initial grid lot |
| InpReaper_LotMultiplier | 1.4 | 1.3 | +0.1 | ↑ +8% faster lot scaling per level |
| InpReaper_MaxLevels | 10 | 8 | +2 | ↑ +25% more grid levels |
| InpReaper_PipStep | 20 | 25 | -5 | ↓ -20% tighter grid spacing |
| InpReaper_BasketTP | 75.0 | 50.0 | +25.0 | ↑ +50% wider basket TP (pips) |
| InpReaper_BasketTP_Money | 600.0 | 400.0 | +200.0 | ↑ +50% wider basket TP (money) |
| InpReaper_TrailStart_Money | 200.0 | 150.0 | +50.0 | ↑ +33% later trail start |
| InpReaper_TrailStop_Pips | 400 | 300 | +100 | ↑ +33% wider trail stop |
| InpSentinel_MaxADX | 30.0 | 25.0 | +5.0 | ↑ +20% allows grid in stronger trends |

**Impact Assessment:** 🔴 CRITICAL — Grid is structurally bigger: 50% larger lots, 2 more levels, tighter spacing, wider targets. The 1.4x multiplier over 10 levels means the last level is ~29x the initial lot (vs ~9.5x for Moderate's 1.3x over 8 levels). This is where most of the profit potential — and risk — comes from.

---

## CHRONOS (3 params — ALL differ)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpChronos_ScalpSL_Pips | 30.0 | 25.0 | +5.0 | ↑ +20% wider stop loss |
| InpChronos_ScalpTP_Pips | 45.0 | 35.0 | +10.0 | ↑ +29% wider take profit |
| InpChronos_LotSizeMultiplier | 0.7 | 0.5 | +0.2 | ↑ +40% bigger scalp lots |

**Impact Assessment:** 🟡 MEDIUM — Wider stops and targets with bigger lots. TP/SL ratio improves slightly (1.5:1 vs 1.4:1) but with 40% bigger positions.

---

## EVENT RISK (4 params — ALL differ)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpATR_SpikeMultiplier | 2.0 | 1.8 | +0.2 | ↑ +11% higher ATR threshold to trigger lockout |
| InpATR_SpikeLockoutHours | 8 | 12 | -4 | ↓ -33% shorter lockout after spike |
| InpMaxConsecutiveLoss | 4 | 3 | +1 | ↑ +33% allows one more loss before lockout |
| InpLossLockoutHours | 18 | 24 | -6 | ↓ -25% shorter cooldown after losses |

**Impact Assessment:** 🟠 HIGH — Aggressive is significantly less defensive: needs bigger ATR spikes to trigger lockout, locks out for shorter periods, tolerates more consecutive losses. This means the EA keeps trading through events that would pause Moderate.

---

## TIME FILTER (5 params — 2 differ, 3 same)

| Parameter | Aggressive | Moderate | Delta | Direction |
|---|---|---|---|---|
| InpEnableTimeFilter | true | true | — | ↔ Same |
| InpTradingStartHour | 7 | 8 | -1 | ↓ -1hr earlier start |
| InpTradingEndHour | 19 | 18 | +1 | ↑ +1hr later end |
| InpTradeWednesday | false | false | — | ↔ Same |
| InpTradeFriday | true | true | — | ↔ Same |

**Impact Assessment:** 🟢 LOW — Aggressive trades 2 extra hours per day (7am-7pm vs 8am-6pm). Marginal impact.

---

## SUMMARY: PARAMETERS BY IMPACT

### 🔴 CRITICAL (biggest Aggressive edge/risk):
1. **Queen_MaxExposureLots**: 2.0 vs 1.0 (+100%) — double the exposure cap
2. **Reaper grid scaling**: 1.4x mult × 10 levels = 29x max lot vs 1.3x × 8 levels = 9.5x — **3x more aggressive grid**
3. **MaxTotalRisk_Percent**: 12% vs 8% (+50%)
4. **Base_Risk_Percent**: 1.5 vs 1.0 (+50%)
5. **MaxLotSize**: 8.0 vs 5.0 (+60%)
6. **MaxRiskPerTrade**: 0.8 vs 0.5 (+60%)

### 🟠 HIGH (significant difference):
7. **MinTQSForEntry**: 0.25 vs 0.35 (-29%) — much lower quality bar
8. **Queen_MaxConcurrentBaskets**: 3 vs 2 (+50%)
9. **Leviathan_KellyFraction**: 0.35 vs 0.25 (+40%)
10. **Event Risk lockout**: shorter, less sensitive, more tolerant
11. **Reaper_BasketTP**: 75 vs 50 pips (+50%)
12. **InpMR_BB_Dev**: 1.7 vs 1.9 — tighter bands, more signals
13. **InpMR_RSI bands**: ±4 points wider — more entries

### 🟡 MEDIUM:
14. Chronos sizing and targets (+40% lots, wider SL/TP)
15. Sentinel_MaxADX: 30 vs 25 (grid in stronger trends)
16. Reaper_PipStep: 20 vs 25 (tighter grid spacing)

### 🟢 LOW:
17. Time filter: +2 hours daily trading window

---

## TOTAL COUNT: 37 out of 40 parameters differ

Only 3 parameters are identical:
- InpEnableTimeFilter = true
- InpTradeWednesday = false
- InpTradeFriday = true

**3 parameters exist ONLY in Moderate** (not set in Aggressive):
- InpMR_BB_Period = 15
- InpMR_RSI_Period = 10
- InpMR_CCI_Period = 20

These suggest Aggressive relies on EA defaults for MR indicator periods, while Moderate explicitly sets them.

---

## BOTTOM LINE

The Aggressive profile achieves its higher return target through **three structural levers**:

1. **Bigger positions everywhere** — 40-100% larger lots across all strategies
2. **Looser safety margins** — Queen allows 2x exposure, DD thresholds 33-40% wider, event risk lockouts shorter
3. **More signals** — Mean reversion filters loosened 20-29%, more grid levels, tighter grid spacing

The **single most impactful difference** is the Reaper Grid: the combination of 1.4x multiplier over 10 levels (vs 1.3x over 8) creates exponentially more risk in grid drawdown scenarios. This is likely where most of the extra profit — and most of the extra drawdown — comes from.
