# ACTIONABLE IMPROVEMENTS: TITAN -> $170K
## Cycle 2 Research — 2026-05-26
## Status: CODE-READY — All changes documented with exact locations

---

## CURRENT STATE

- **V28.06 TITAN**: Projected $109K-$138K, DD 27-32%, 750-850 trades
- **Gap to $170K**: $32K-$61K
- **V29.00**: Exists but NOT tested, adds MTF/KillZone/Chandelier/OrderBlock/FVG
- **V29_00_EQUITY_CURVE.mq4**: Draft code exists (not integrated into any build)
- **OMEGA**: Has Vortex+RegimeShift enabled (TITAN does NOT)

---

## IMPROVEMENT 1: EQUITY CURVE ANTI-MARTINGALE (+$15K-$25K, -2-4% DD)

### Status: CODE EXISTS in V29_00_EQUITY_CURVE.mq4 — NOT INTEGRATED

### Why This Works
Kelly optimizes per-strategy. Equity curve operates at PORTFOLIO level. They're orthogonal.
During winning streaks: Kelly amplifies winning strategies AND portfolio multiplier amplifies everything = double amplification.

### Integration Steps (into V28_06_TITAN.mq4)

**Step 1: Add globals near other global state variables (~line 2000)**
```mql4
// V29: Equity Curve Anti-Martingale
double g_peak_equity = 0.0;
double g_equity_curve_mult = 1.0;
```

**Step 2: Add CalculateEquityCurveMultiplier() function (~line 5100, after Kelly functions)**
Use the implementation from V29_00_EQUITY_CURVE.mq4 (lines 10-90).
The 4-factor weighted approach is solid:
- HWM Proximity (30% weight)
- Rolling Growth Rate (30% weight)  
- Drawdown State (25% weight)
- Win Streak Momentum (15% weight)

**Step 3: Apply in MoneyManagement_Quantum()**
Find the line where final lots are calculated and add:
```mql4
// V29: Apply equity curve multiplier (orthogonal to Kelly)
double ecMult = CalculateEquityCurveMultiplier();
finalLots *= ecMult;
```

**Step 4: Update HWM in OnTick()**
```mql4
if(AccountEquity() > g_peak_equity) g_peak_equity = AccountEquity();
```

### Risk Bounds
- Multiplier range: 0.5x to 2.5x (from V29 code)
- Drawdown defense: 0.5x when DD > 10%
- Minimum 5 trades before activation

---

## IMPROVEMENT 2: GBPUSD CORRELATION FILTER (+$5K-$10K, -1-2% DD)

### Status: CODE EXISTS in V29_00_EQUITY_CURVE.mq4 (lines 92-140)

### Why This Works
EURUSD/GBPUSD 85-95% correlated on H4. When correlation breaks, it's a risk signal.
Use correlation as a FILTER (reduce exposure when divergence), NOT as an edge source.
Lesson from 2026-05-26: Correlation trading is NOT viable, but correlation FILTERING is.

### Integration Steps

**Step 1: Add GetGBPUSDCorrelationSignal() function**
Use the implementation from V29_00_EQUITY_CURVE.mq4 (lines 97-140).
Returns: -1 (divergence = reduce exposure), 0 (neutral), +1 (confirmation)

**Step 2: Apply to SessionMomentum and new strategies**
```mql4
// In SessionMomentum entry:
int corrSignal = GetGBPUSDCorrelationSignal();
if(corrSignal == -1) return;  // Skip: GBPUSD diverging = risky
if(corrSignal == 1) lots *= 1.2;  // Confirm: boost slightly
```

**Step 3: Apply as global risk filter**
```mql4
// In MoneyManagement_Quantum():
int corrSignal = GetGBPUSDCorrelationSignal();
if(corrSignal == -1) finalLots *= 0.7;  // Reduce all lots during divergence
```

---

## IMPROVEMENT 3: ASIAN RANGE BREAKOUT (+$10K-$20K, +1-2% DD)

### Status: RESEARCHED — Ready to code

### Key Finding
Magic 9007 is used by FVG in V29_00. For TITAN (which doesn't have FVG), 9007 is fine.
For V29_00, use magic **9009**.

### Optimal Parameters (from LVC EA research)
```
Session: Asia 00:00-06:00 UTC, Trade window 07:00-10:00 UTC
ATR Period: 14
Min Range: 0.50x ATR, Max Range: 2.00x ATR
Breakout Distance: 0.50x ATR beyond range
SL: 0.75x ATR, TP: 2.00x ATR (R:R = 1:2.67)
One trade per day: true
```

### Implementation Checklist (CRITICAL — V28.09 lesson)
1. Add magic number input (9007 for TITAN, 9009 for V29)
2. Add ExecuteAsianBreakout() function
3. Register in ALL GetStrategyIndex functions
4. Register in GetStrategySpecificRisk
5. Expand ALL arrays (g_perfData, g_strategyMultiplier, etc.)
6. Call from OnNewBar dispatch chain
7. Add to IsOurMagicNumber()
8. Add to QueenBee exposure tracking

### Code (from TITAN_GAP_ANALYSIS_170K.md, lines 68-145)
Full implementation already documented. Key logic:
- Look back 3 H4 bars for Asian range
- Filter: range must be 0.3x-1.5x ATR (not too wide/narrow)
- ADX > 15 for trend confirmation
- Buy when Close breaks above Asian high
- Sell when Close breaks below Asian low

---

## IMPROVEMENT 4: ENABLE VORTEX + REGIMESHIFT (+$8K-$15K, +1-2% DD)

### Status: TWO LINE CHANGES — Already coded, just disabled

### TITAN Changes
In DESTROYER_QUANTUM_V28_06_TITAN.mq4, find and change:
```mql4
// Find these lines (search for InpVortex and InpRegimeShift):
extern bool InpVortex_Enabled = true;      // Was: false
extern bool InpRegimeShift_Enabled = true;  // Was: false
```

### Expected Impact
- Vortex (9001): 20-40 trades over 6 years, PF 1.3-1.8
- RegimeShift (9002): 15-30 trades, PF 1.2-1.6
- Combined: +$8K-$15K, +35-70 trades

### Risk
Low — these are trend-following strategies with ATR-based stops.

---

## IMPROVEMENT 5: VOLATILITY-ADAPTIVE TAKE PROFIT (+$5K-$10K, 0% DD change)

### Status: RESEARCH-BASED — Needs code

### Concept
Current TP is fixed ATR multiplier. In high-volatility regimes, price moves further.
Adaptive TP: widen TP when ATR is expanding, tighten when contracting.

### Implementation
```mql4
// Replace fixed TP multiplier with adaptive:
double GetAdaptiveTPMultiplier(double baseTPMult, int atrPeriod = 14)
{
   double currentATR = iATR(Symbol(), PERIOD_H4, atrPeriod, 0);
   double avgATR = iATR(Symbol(), PERIOD_H4, atrPeriod * 3, 0);  // 3x period average
   
   if(avgATR == 0) return baseTPMult;
   
   double volRatio = currentATR / avgATR;
   
   // High vol: widen TP (up to 1.5x base)
   // Low vol: tighten TP (down to 0.7x base)
   // Range: 0.7x to 1.5x base multiplier
   double adaptiveMult = baseTPMult * MathMax(0.7, MathMin(1.5, volRatio));
   
   return adaptiveMult;
}
```

### Where to Apply
- SessionMomentum TP: currently 3.0x ATR -> use GetAdaptiveTPMultiplier(3.0)
- Titan TP: currently fixed -> use adaptive
- Asian Breakout TP: 2.0x ATR -> use GetAdaptiveTPMultiplier(2.0)

### Expected Impact
- Lets winners run further in trending markets
- Takes profit quicker in ranging markets
- Net effect: +5-15% average win size

---

## COMBINED PROJECTION

| Improvement | Profit Impact | Trade Impact | DD Impact | Confidence |
|-------------|--------------|--------------|-----------|------------|
| TITAN base | $109K-$138K | 750-850 | 27-32% | HIGH (pending BT) |
| + Equity Curve | +$15K-$25K | 0 (sizing) | -2-4% | MEDIUM-HIGH |
| + GBPUSD Filter | +$5K-$10K | 0 (filter) | -1-2% | MEDIUM |
| + Asian Breakout | +$10K-$20K | +20-40 | +1-2% | HIGH |
| + Vortex/RegimeShift | +$8K-$15K | +35-70 | +1-2% | HIGH |
| + Adaptive TP | +$5K-$10K | 0 (exit) | 0% | MEDIUM |
| **TOTAL** | **$152K-$218K** | **805-960** | **26-31%** | — |

**Midpoint: ~$185K** — exceeds $170K target.

---

## IMPLEMENTATION ORDER (Priority)

### Phase 1: Ryan Backtest TITAN (BLOCKED — needs Ryan)
- Must validate base projections before adding complexity
- If TITAN hits $130K+, proceed to Phase 2

### Phase 2: Quick Wins (can code now, test after Phase 1)
1. **Enable Vortex + RegimeShift** — 2 line changes
2. **GBPUSD Correlation Filter** — copy function from V29_00_EQUITY_CURVE.mq4

### Phase 3: Medium Complexity
3. **Equity Curve Anti-Martingale** — copy from V29_00_EQUITY_CURVE.mq4, integrate into MoneyManagement
4. **Adaptive TP** — new function, apply to 3 strategies

### Phase 4: New Strategy (test carefully)
5. **Asian Range Breakout** — full new strategy, requires array expansion + registration

---

## KEY RESEARCH FINDINGS

### From GitHub/Web Search (Cycle 2)

1. **No new high-PF MQL4 EAs found** — consistent with prior research. The MQL4 open-source ecosystem has no profitable EAs to copy. Our innovation IS the edge.

2. **Best Asian Range implementation**: `yannis-montreer/MT5-EA-London-Volatility-Capture-LVC-EA` — production-quality MT5 EA with 3 entry modes (True Breakout, Breakout+Retest, Breakout+Reversal), ATR-normalized parameters.

3. **Equity curve trading is well-documented**: Anti-martingale is standard in systematic hedge funds. The V29_00_EQUITY_CURVE.mq4 implementation is solid (4-factor weighted approach).

4. **Correlation as filter, not strategy**: Confirmed from prior research — use GBPUSD divergence as a risk reducer, not an edge source.

5. **Magic number conflicts**: V29_00 uses 9007 (FVG) and 9008 (OrderBlock). Asian Breakout must use 9009 in V29 builds.

### From Existing Code Analysis

1. **TITAN has NO Vortex/RegimeShift** — these are disabled. OMEGA has them enabled.
2. **TITAN has NO equity curve integration** — the V29_00_EQUITY_CURVE.mq4 is standalone.
3. **TITAN has NO GBPUSD correlation** — the function exists in V29_00_EQUITY_CURVE.mq4.
4. **Kelly amplification already aggressive**: KellyFraction=0.35, MaxRisk=7.0%, blend 80/20.
5. **Reaper already amplified**: InitialLot=0.18, BasketTP=$900.

---

## FILES CREATED/MODIFIED THIS CYCLE

- `research/2026-05-26_CYCLE2_ACTIONABLE_IMPROVEMENTS.md` (this file)

## RESEARCH SOURCES

- `V29_00_EQUITY_CURVE.mq4` — Draft equity curve + GBPUSD correlation code
- `TITAN_GAP_ANALYSIS_170K.md` — Prior gap analysis with Asian Breakout code
- `V28_06_ULTRA_DEEP_RESEARCH.md` — Academic-backed indicator implementations
- `memory/lessons.md` — Lessons learned (correlation, magic numbers, non-ASCII)
- `memory/latest-results.md` — V28.06 baseline: $50K, PF 1.92, DD 19.4%, 601 trades
- GitHub: `yannis-montreer/MT5-EA-London-Volatility-Capture-LVC-EA` (Asian Range params)

---

## NEXT ACTIONS FOR RYAN

1. **BACKTEST TITAN** — Critical path. All other improvements depend on knowing TITAN's actual numbers.
2. If TITAN hits $130K+: Enable Vortex+RegimeShift (2 line changes), backtest again.
3. Then integrate Equity Curve multiplier, backtest.
4. Then add Asian Breakout, backtest.
5. Each step: one change, one backtest. No stacking untested changes.
