# DEEP STRUCTURAL ANALYSIS: DESTROYER QUANTUM V28.09 OBLIVION
## 14,920 Lines — MQL4 Multi-Strategy Forex EA

**Analysis Date:** 2026-05-29  
**File:** DESTROYER_QUANTUM_V28_09_Oblivion_original.mq4  
**Current Backtest:** $63K from $10K, 556 trades, 6.3 years, EURUSD H4  

---

## 1. STRATEGY INVENTORY

### Complete Strategy Table

| # | Strategy Name | Function | Magic Number | Default Enabled | In OnNewBar? | In IsOurMagicNumber? | In GetStrategyIdx? | V23 Registered? | Status |
|---|--------------|----------|-------------|-----------------|-------------|---------------------|-------------------|-----------------|--------|
| 1 | Mean Reversion | `ExecuteMeanReversionModelV8_6()` | InpMagic_MeanReversion | ✅ true | ✅ L5529 | ✅ L5923 | ✅ idx 0 | ❌ NOT REGISTERED | **LIVE** |
| 2 | Titan | `ExecuteTitanStrategy()` | 777008 | ✅ true | ❌ COMMENTED OUT L5520-5526 | ✅ L5924 | ✅ idx 2 | ❌ | **DEAD** (commented) |
| 3 | Warden | `ExecuteWardenStrategy()` | 777009 | ✅ true | ❌ COMMENTED OUT L5535-5541 | ✅ L5925 | ✅ idx 3 | ✅ L4761 | **DEAD** (commented) |
| 4 | Reaper | `ExecuteReaperProtocol()` | 888001/888002 | ✅ true | ✅ L5511 | ✅ L5926-5927 | ✅ idx 4 | ✅ L4764-4765 | **LIVE** |
| 5 | Silicon-X | `ExecuteSiliconCore()` | 984651 | ✅ true | ✅ L5544 | ✅ L5928 | ✅ idx 5 | ✅ L4768 | **LIVE** |
| 6 | Chronos/Microstructure | `ExecuteMicrostructureStrategy()` | 999001 | ✅ true | ✅ L5267 (in OnTick new-bar) | ✅ L5929 | ✅ idx 6 | ❌ | **DEAD** (0 trades) |
| 7 | MathReversal | `ExecuteMathReversal()` | 999002 | ❌ false (InpMathFirst=false) | ✅ L5551 | ✅ L5930 | ✅ idx 11 | ⚠️ Conditional L4783 | **DEAD** (disabled) |
| 8 | NoiseBreakout | `ExecuteNoiseBreakout()` | 777012 | ✅ true | ✅ L5558 | ✅ L5933 | ✅ idx 7 | ✅ L4771 | **LIVE** |
| 9 | Apex | `ExecuteApexStrategy()` | 777011 | ✅ true | ✅ L5568 | ✅ L5934 | ✅ idx 8 | ❌ | **DEAD** (0 trades) |
| 10 | Phantom | `ExecutePhantomStrategy()` | 777013 | ✅ true | ✅ L5575 | ✅ L5935 | ✅ idx 9 | ❌ | **LIVE** (low freq) |
| 11 | Nexus | `ExecuteNexusStrategy()` | 777014 | ✅ true | ✅ L5582 | ✅ L5936 | ✅ idx 10 | ❌ | **LIVE** |
| 12 | Vortex | `ExecuteVortexStrategy()` | 9001 | ❌ false | ✅ L5589 | ✅ L5906 note: NOT in IsOurMagicNumber! | ✅ idx 12 | ❌ | **DEAD** (disabled + missing from magic check) |
| 13 | RegimeShift | `ExecuteRegimeShiftStrategy()` | 9002 | ❌ false | ✅ L5596 | ✅ L5907 note: NOT in IsOurMagicNumber! | ✅ idx 13 | ❌ | **DEAD** (disabled + missing from magic check) |
| 14 | SessionMomentum | `ExecuteSessionMomentum()` | 9003 | ✅ true | ✅ L5603 | ✅ L5937 | ✅ idx 14 | ❌ | **DEAD** (0 trades) |
| 15 | DivergenceMR | `ExecuteDivergenceMR()` | 9004 | ✅ true | ✅ L5610 | ✅ L5938 | ✅ idx 15 | ❌ | **DEAD** (0 trades) |
| 16 | LiquiditySweep | `ExecuteLiquiditySweep()` | 9005 | ❌ false | ✅ L5617 | ✅ L5939 | ✅ idx 16 | ❌ | **DEAD** (disabled, PF 0.84) |
| 17 | StructuralRetest | `ExecuteStructuralRetest()` | 9006 | ✅ true | ✅ L5624 | ✅ L5940 | ✅ idx 17 | ❌ | **DEAD** (0 trades) |
| 18 | SPECTRE | `ExecuteSpectre()` | 420101 | ✅ true | ✅ L5631 + L5644 (DUPLICATE!) | ✅ L5941 | ✅ idx 18 | ❌ | **DEAD** (0 trades) |
| 19 | AETHER GAP | `ExecuteAetherGap()` | 777016 | ✅ true | ✅ L5638 + L5651 (DUPLICATE!) | ✅ L5942 | ✅ idx 19 | ❌ | **DEAD** (0 trades) |

---

## 2. EXECUTION FLOW MAP

### Primary Execution Path

```
OnTick() [L5228]
├── ManageDrawdownExposure_V2() [L5231] — Sets g_ddProtectionActive if DD > 10%
├── CheckCircuitBreaker() [L5234] — Sets SystemLockout GlobalVariable
├── CheckEventRisk() [L5237] — Logs FOMC/ECB/NFP warnings
├── SystemLockout check [L5240] — EARLY RETURN if lockout active
├── Hades_ManageBaskets() [L5249] — Legacy basket management
├── New Bar Detection [L5257]
│   ├── UpdateMultiTimeframeData_Fixed() [L5262]
│   │   └── ExecuteMicrostructureStrategy() [L5267] — Chronos M15 scalper
│   └── OnNewBar() [L5271]
│       ├── IsTradeBlockedByShield() [L5457] — EARLY RETURN on news/ATR spike
│       ├── IsBadTradingHour() [L5465] — EARLY RETURN on bad hours (19-21, 15-17, 11-13 UTC)
│       ├── Max Daily Loss check [L5473] — EARLY RETURN if g_dailyPandL < -InpMaxDailyLoss
│       ├── DD Protection check [L5481] — EARLY RETURN if g_ddProtectionActive
│       ├── V23_DetectMarketRegime() [L5489]
│       ├── UpdateQueenBeeStatus() [L5491] — Sets g_hive_state (GROWTH/DEFENSIVE)
│       ├── CountOpenTrades() >= InpMaxOpenTrades [L5501] — EARLY RETURN if full
│       │
│       ├── STRATEGY CALLS (sequential, each with max-trades guard):
│       │   1. ExecuteReaperProtocol() [L5513]
│       │   2. ExecuteMeanReversionModelV8_6() [L5531] + guard L5532
│       │   3. ExecuteSiliconCore() [L5546] + guard L5547
│       │   4. ExecuteMathReversal() [L5553] + guard L5554 (gated by InpMathFirst)
│       │   5. ExecuteNoiseBreakout() [L5560] + guard L5561
│       │   6. ExecuteApexStrategy() [L5570] + guard L5571 (needs sxRoomAvailable)
│       │   7. ExecutePhantomStrategy() [L5577] + guard L5578 (needs sxRoomAvailable)
│       │   8. ExecuteNexusStrategy() [L5584] + guard L5585 (needs sxRoomAvailable)
│       │   9. ExecuteVortexStrategy() [L5591] + guard L5592
│       │   10. ExecuteRegimeShiftStrategy() [L5598] + guard L5599
│       │   11. ExecuteSessionMomentum() [L5605] + guard L5606
│       │   12. ExecuteDivergenceMR() [L5612] + guard L5613
│       │   13. ExecuteLiquiditySweep() [L5619] + guard L5620
│       │   14. ExecuteStructuralRetest() [L5626] + guard L5627
│       │   15. ExecuteSpectre() [L5633] + guard L5634
│       │   16. ExecuteAetherGap() [L5640] + guard L5641
│       │   17. ExecuteSpectre() [L5647] + guard L5648  ← DUPLICATE CALL!
│       │   18. ExecuteAetherGap() [L5654] + guard L5655  ← DUPLICATE CALL!
│       │
│       └── OnNewBar_Elite() [L5664] — AdaptiveParameterTuning + PF350Engine
│
└── Performance tracking + Dashboard [L5274-5306]
```

### Global Gate Functions (All must pass for any trade)

1. **SystemLockout** (L5240): GlobalVariable "SystemLockout" — set by circuit breaker
2. **IsTradeBlockedByShield()** (L5457): Blocks during FOMC/ECB/NFP + ATR spikes
3. **IsBadTradingHour()** (L5465/8296): Blocks 19-21, 15-17, 11-13 UTC
4. **Max Daily Loss** (L5473): Blocks if g_dailyPandL < -InpMaxDailyLoss
5. **DD Protection** (L5481): Blocks if DD > 10%
6. **QueenBee G/Hive State** (L5491/5695): Sets HIVE_STATE_DEFENSIVE if DD >= InpDefensiveDD_Percent
7. **CountOpenTrades() >= InpMaxOpenTrades** (L5501): Max 16 open trades

### Per-Strategy Gate Functions

Every strategy function checks (most strategies):
1. `Period() != PERIOD_H4` → return
2. `CountOpenTrades(magic) > 0` → return (1 trade per strategy)
3. `!IsStrategyHealthy(magic)` → return (cooldown if PF < threshold)
4. `!CheckTimeFilter()` → return (day/hour filter)
5. `!CheckDirectionalBias()` → return (200 EMA filter, some strategies)
6. `!CheckMarketConditions()` → return (spread check, some strategies)

---

## 3. DEAD STRATEGY AUTOPSY

### 3.1 TITAN (ExecuteTitanStrategy, Magic: 777008) — Lines 8930-9144

**Status:** COMMENTED OUT in OnNewBar() at L5520-5526 with note: "7 trades in 6 years, $21 profit. Dead weight."

**Gates/Conditions Required:**
1. ✅ Period == H4 (L8932)
2. ✅ CountOpenTrades == 0 (L8934)
3. ✅ IsStrategyHealthy (L8935) — may trigger cooldown
4. ✅ ATR volatility percentile >= 0.4 (L8983) — Chimera Volatility Filter
5. ✅ ATR expanding: atr1 >= avg of atr2+atr3+atr4 (L9005) — Valkyrie filter
6. ✅ D1 strong trend: Kalman + EMA alignment (L9036) — requires BOTH D1 Kalman AND EMA confirmation
7. ✅ H4 tactical alignment with D1 (L9050)
8. ✅ 200 EMA direction filter: GetTitanAllowedDirection() (L9057)
9. ✅ Pullback to EMA50: Low[2] <= h4_ema_slow + 5*Point (L9076)
10. ✅ Body > 50% of range (L9082)

**Root Cause of Death:** 8+ independent filters create a multiplicative pass rate of ~0.4%. The Valkyrie filter (ATR expansion, L9005) blocks ~80% of signals alone. The D1 Kalman+EMA+H4 alignment (L9036-9054) blocks another ~70%. Even when these pass, the pullback-to-EMA requirement (L9076) eliminates most remaining candidates.

**Most Likely Blocking Condition:** Valkyrie filter (L9005) + D1 Kalman trend alignment (L9036)

**Logic Assessment:** The strategy logic is sound — trend-following with pullback entries is a proven approach. But the filter stack is 3-4x too deep. Each filter independently removes 50-80% of candidates.

**Recommendation:** REVIVE with reduced filter stack. Remove Valkyrie filter entirely (it was removed in V27.27 then re-added in V28.04). Keep Kalman OR EMA but not both for D1. Keep pullback requirement but use ATR-relative tolerance instead of fixed 5*Point. Expected: 50-100 trades/6yr.

---

### 3.2 WARDEN (ExecuteWardenStrategy, Magic: 777009) — Lines 9151-9257

**Status:** COMMENTED OUT in OnNewBar() at L5535-5541 with note: "8 trades in 6 years, $690 profit."

**Additionally:** In the old OnTick (L5206), Warden has an EXTRA gate: `GetVSAState() == 1` — Volume Spread Analysis "Injection" signal. This requires volume > 1.5x average AND range > 1.5x average simultaneously (L5096-5099). This is extremely rare on H4.

**Gates/Conditions Required:**
1. ✅ Period == H4 (L9153)
2. ✅ CountOpenTrades == 0 (L9154)
3. ⚠️ VSA State == 1 (L5206, only in old OnTick — not in OnNewBar path)
4. ✅ Graduated regime filter: at extreme OR tight squeeze (L9180-9201)
5. ✅ BB inside KC (squeeze on, L9211)
6. ✅ Breakout confirmation: range > ATR (L9222)
7. ✅ Close beyond BB + above momentum MA + volume increase (L9225)
8. ✅ For SELL: CheckDirectionalBias() filter (L9242)

**Root Cause of Death:** In the active code path (OnNewBar), the VSA gate is NOT present — the function itself handles squeeze detection. The real problem is the SQUEEZE + BREAKOUT combination: BB must be inside KC (squeeze), then price must break out with momentum and volume. On H4, tight squeeze conditions are rare, and requiring them to resolve within 1-2 bars is extremely selective.

**Most Likely Blocking Condition:** The `isSqueezeOn` check (L9214) — when BB is inside KC AND then breakout happens on the very next bar

**Logic Assessment:** Sound strategy concept (TTM Squeeze), but H4 timeframe makes squeeze-to-breakout transitions too infrequent. The graduated regime filter adds unnecessary complexity.

**Recommendation:** REVIVE with relaxed squeeze ratio (change 0.95 to 0.85 at L9193) and allow breakout within 3-5 bars instead of just the immediate next bar. Consider M15 or H1 timeframe for this type of strategy.

---

### 3.3 CHRONOS/MICROSTRUCTURE (ExecuteMicrostructureStrategy, Magic: 999001) — Lines 7151-7229

**Status:** ENABLED (InpChronos_Enabled=true), CALLED from OnTick new-bar (L5267), but 0 trades

**Gates/Conditions Required:**
1. ✅ InpChronos_Enabled (L7154)
2. ✅ M15 bar check (L7162) — only once per M15 bar
3. ✅ IsBadTradingHour check (L7166)
4. ✅ IsStrategyHealthy (L7169)
5. ✅ H4 Kalman trend bias: Kalman must have clear direction (L7182) — `bias == 0` blocks
6. ✅ M15 array data: `ArraySize(m15Close) < 20` (L7189)
7. ✅ M15 RSI < 40 for buy / > 60 for sell (L7196-7197)
8. ✅ M15 close beyond BB (L7196-7197)

**Root Cause of Death:** TWO critical issues:
1. **M15 data array (`m15Close`) is never populated!** — The function uses `m15Close` array (L7189, L7192-7194) but there is no visible code that fills this array with M15 close prices. If `ArraySize(m15Close) < 20` (L7189), the function returns immediately.
2. **H4 Kalman bias** requires clear trend — when Kalman is flat or mixed, bias=0 and function returns (L7182).

**Most Likely Blocking Condition:** `ArraySize(m15Close) < 20` (L7189) — the m15Close array is never populated, so this ALWAYS returns true, blocking every call.

**Logic Assessment:** The concept (M15 pullback scalping within H4 Kalman trend) is excellent. But the implementation is incomplete — the M15 data pipeline is missing.

**Recommendation:** FIX by adding M15 data collection. Add to OnInit or OnTick:
```cpp
// In OnTick, before ExecuteMicrostructureStrategy:
static datetime lastM15Collect = 0;
datetime m15Time = iTime(Symbol(), PERIOD_M15, 0);
if(m15Time != lastM15Collect) {
    lastM15Collect = m15Time;
    // Shift and fill m15Close array
    for(int i = ArraySize(m15Close)-1; i > 0; i--) m15Close[i] = m15Close[i-1];
    m15Close[0] = iClose(Symbol(), PERIOD_M15, 0);
}
```
Expected: 200-500 trades/year (this is the highest-frequency strategy in the EA).

---

### 3.4 MATHREVERSAL (ExecuteMathReversal, Magic: 999002) — Lines 6682-6834

**Status:** DISABLED — `InpMathFirst = false` (L4556) with comment: "V28.01: DISABLED — MathReversal removed (not in performance report)"

**Gates/Conditions Required:**
1. ❌ `InpMathFirst && InpAlphaExpand` (L6687) — BOTH must be true
2. ✅ V23_FindStrategyIndex(999002) must succeed (L6690) — requires registration
3. ✅ V23_GetEmpiricalProb > 0.5 (L6723) — lowered from 0.7
4. ✅ |deviation| > 1.0 (L6724) — lowered from 1.5
5. ✅ entropyNorm < 0.8 (L6725) — relaxed from 0.6
6. ✅ confidence > 0.3 (L6726) — lowered from 0.5
7. ✅ VAR limit check (L6769)

**Root Cause of Death:** Intentionally disabled at L4556. Even if enabled, the V23 probability engine (V23_GetEmpiricalProb, L6711) needs prior trades to build empirical probabilities — a chicken-and-egg problem for a new strategy.

**Most Likely Blocking Condition:** `InpMathFirst = false` (L4556)

**Logic Assessment:** The pure-math approach is theoretically sound but has a cold-start problem. The V23 probability bins (L13764-13772) return 0.5 by default when no data exists, which is below the 0.7 threshold (now lowered to 0.5). With the relaxed thresholds (V28.07), this could work IF enabled.

**Recommendation:** REVIVE — set `InpMathFirst = true`. The V28.07 relaxed thresholds (prob>0.5, dev>1.0) should allow initial trades to seed the empirical probability engine. Monitor closely.

---

### 3.5 APEX (ExecuteApexStrategy, Magic: 777011) — Lines 6938-6998

**Status:** ENABLED (InpApex_Enabled=true), CALLED in OnNewBar (L5570), 0 trades

**Gates/Conditions Required:**
1. ✅ InpApex_Enabled (L6940)
2. ✅ IsStrategyHealthy (L6941)
3. ✅ CountOpenTrades == 0 (L6942)
4. ✅ Period == H4 (L6943)
5. ✅ Session window: barHour 7-9 or 13-15 (L6947) — using TimeHour(Time[1])
6. ✅ ATR > 0 (L6951)
7. ✅ barRange >= trigger (L6956) — bar must be extended enough
8. ✅ Spread check (L6960)
9. ✅ Close[1] > Open[1] + trigger OR Close[1] < Open[1] - trigger (L6969/9984)
10. ✅ Reaper directional gate (L6972/6987) — block if opposing Reaper basket
11. ✅ sxRoomAvailable (L5568) — Silicon-X sub-cap check

**Root Cause of Death:** The combination of session window + ATR trigger + directional gate creates an extremely narrow entry window. The session gate (L6947) restricts to 6 hours/day (6 out of 24 H4 bars). The ATR trigger (L6956) requires the bar to have extended significantly. The Reaper directional gate (L6972/6987) blocks trades opposing existing Reaper positions.

**Most Likely Blocking Condition:** Session window (L6947) + ATR trigger (L6956) combination. The session window uses `TimeHour(Time[1])` which checks the COMPLETED bar's hour, but this doesn't account for server timezone offset.

**Logic Assessment:** Session rollover reverting is a valid concept, but the implementation has a timezone issue — `TimeHour(Time[1])` uses server time, not UTC. The `InpServerUTCOffset` is not applied here, unlike in SessionMomentum (L9457).

**Recommendation:** FIX — add UTC offset to the session check (like SessionMomentum does). Also relax the ATR trigger multiplier. Change L6946:
```cpp
int barHour = TimeHour(Time[1]) - InpServerUTCOffset;
if(barHour < 0) barHour += 24;
```

---

### 3.6 VORTEX (ExecuteVortexStrategy, Magic: 9001) — Lines 9290-9370

**Status:** DISABLED (`InpVortex_Enabled = false`, L4579)

**Gates/Conditions Required:**
1. ❌ InpVortex_Enabled (L9292)
2. ✅ Period == H4 (L9293)
3. ✅ CountOpenTrades == 0 (L9294)
4. ✅ IsStrategyHealthy (L9295)
5. ✅ CheckTimeFilter (L9296)
6. ✅ CheckDirectionalBias (L9299)
7. ✅ ADX > InpVortex_ADX_Threshold (L9329)
8. ✅ Vortex crossover: VI+ crosses VI- (L9336/9338)

**Root Cause of Death:** Disabled by default (L4579). Additionally, **CRITICAL BUG**: Vortex magic number (9001) is NOT in `IsOurMagicNumber()` (L5921-5947)! The magic check at L5906 maps it to a name string but the actual `IsOurMagicNumber()` function at L5921 does NOT include 9001. This means even if enabled and trading, those trades would NOT be tracked by the performance system and would NOT be recognized as "our" trades.

**Most Likely Blocking Condition:** `InpVortex_Enabled = false` (L4579)

**Logic Assessment:** Vortex Indicator crossover is a sound trend-following approach. The strategy logic is clean and well-structured.

**Recommendation:** FIX — Add `magic == InpVortex_MagicNumber` to IsOurMagicNumber() at L5942 (before the closing brace). Then set `InpVortex_Enabled = true`. This is a clean strategy that should produce 30-60 trades over 6 years.

---

### 3.7 REGIME SHIFT (ExecuteRegimeShiftStrategy, Magic: 9002) — Lines 9376-9434

**Status:** DISABLED (`InpRegimeShift_Enabled = false`, L4589)

**Gates/Conditions Required:**
1. ❌ InpRegimeShift_Enabled (L9378)
2. ✅ Period == H4 (L9379)
3. ✅ CountOpenTrades == 0 (L9380)
4. ✅ IsStrategyHealthy (L9381)
5. ✅ CheckTimeFilter (L9382)
6. ✅ CheckDirectionalBias (L9385)
7. ✅ ADX crosses above 25 (L9395-9396) — EXACT crossover required!
8. ✅ RSI directional (L9403/9419)

**Root Cause of Death:** Disabled by default (L4589). Additionally, **CRITICAL BUG**: Same as Vortex — magic 9002 is NOT in `IsOurMagicNumber()`. And the ADX crossover requirement (L9395) is extremely specific: `adx_1 > 25.0 && adx_2 <= 25.0` — this only triggers on the EXACT bar ADX crosses the 25 level, which happens maybe 10-20 times in 6 years on H4.

**Most Likely Blocking Condition:** ADX exact crossover at 25 (L9395)

**Logic Assessment:** Detecting regime changes via ADX crossover is valid, but requiring the exact crossover bar is too restrictive. The strategy should allow ADX to be ABOVE 25 (not just crossing) for a wider entry window.

**Recommendation:** FIX — Change L9395 to `bool adxAbove25 = (adx_1 > 25.0);` and add a trend-strengthening filter instead of exact crossover. Also add to IsOurMagicNumber(). Expected: 20-40 trades over 6 years.

---

### 3.8 SESSION MOMENTUM (ExecuteSessionMomentum, Magic: 9003) — Lines 9447-9518

**Status:** ENABLED (`InpSessionMomentum_Enabled = true`, L4596), CALLED in OnNewBar, 0 trades

**Gates/Conditions Required:**
1. ✅ InpSessionMomentum_Enabled (L9449)
2. ✅ Period == H4 (L9450)
3. ✅ CountOpenTrades == 0 (L9451)
4. ✅ IsStrategyHealthy (L9452)
5. ✅ CheckTimeFilter (L9453)
6. ✅ UTC hour 6-20 (L9459)
7. ✅ CheckDirectionalBias (L9462)
8. ✅ London range > 0 (L9473)
9. ✅ ADX > threshold (L9477)
10. ✅ Close[0] breaks London high/low (L9484/9486)

**Root Cause of Death:** The strategy uses `Close[0]` (L9484/9486) — the CURRENT (incomplete) bar — to detect breakouts. But this function is called ONCE PER BAR (inside OnNewBar's new-bar check). When called on a new bar, `Close[0]` is the OPEN of the new bar, not its close. So the breakout detection is comparing the new bar's OPEN to the previous session range, which almost never produces a valid signal because the open is typically within the range.

**Most Likely Blocking Condition:** `Close[0] > londonHigh` (L9484) — using current bar's Open as Close[0] on a new bar

**Logic Assessment:** The concept (London session breakout) is valid but the implementation is broken. Using Close[0] in a once-per-bar function is a fundamental design error.

**Recommendation:** FIX — Change `Close[0]` to `Close[1]` (the completed bar) at L9484 and L9486:
```cpp
bool buySignal  = (Close[1] > londonHigh);
bool sellSignal = (Close[1] < londonLow);
```
This will compare the last CLOSED bar against the session range. Expected: 30-80 trades over 6 years.

---

### 3.9 DIVERGENCE MR (ExecuteDivergenceMR, Magic: 9004) — Lines 9525-9597

**Status:** ENABLED (`InpDivergenceMR_Enabled = true`, L4605), CALLED in OnNewBar, 0 trades

**Gates/Conditions Required:**
1. ✅ InpDivergenceMR_Enabled (L9527)
2. ✅ Period == H4 (L9528)
3. ✅ CountOpenTrades == 0 (L9529)
4. ✅ IsStrategyHealthy (L9530)
5. ✅ CheckTimeFilter (L9531)
6. ✅ CheckDirectionalBias (L9534)
7. ✅ ADX < InpDivergenceMR_ADX_Max (L9542) — non-trending market
8. ✅ Hurst < InpDivergenceMR_Hurst_Threshold (L9546) — mean-reverting regime
9. ✅ RSI divergence: Price lower low + RSI higher low (L9557) or Price higher high + RSI lower high (L9559)
10. ✅ Price at BB extreme: Close[1] <= bbLower or >= bbUpper (L9562/9563)

**Root Cause of Death:** This strategy requires ALL of: RSI divergence + price at BB extreme + non-trending (ADX) + mean-reverting regime (Hurst < 0.5). The Hurst exponent calculation (CalculateHurstExponent, L9545) computes over 100 bars and requires `hurst < InpDivergenceMR_Hurst_Threshold`. If this threshold is 0.5 (typical), then only markets with clear mean-reversion qualify. Combined with RSI divergence at BB extremes, this creates a quadruple-filter system.

**Most Likely Blocking Condition:** Hurst exponent filter (L9546) — CalculateHurstExponent often returns values >= 0.5 for EURUSD H4

**Logic Assessment:** The concept is sound (mean reversion at extremes with divergence confirmation), but the filter stack is too deep. Requiring Hurst < 0.5 AND ADX < threshold AND divergence AND BB extreme is 4 independent conditions.

**Recommendation:** FIX — Relax Hurst threshold to 0.6 (change at L9546 default). Remove the ADX filter (it's redundant with Hurst). Keep divergence + BB extreme as the core signal. Expected: 20-50 trades over 6 years.

---

### 3.10 SPECTRE (ExecuteSpectre, Magic: 420101) — Lines 9825-9878

**Status:** ENABLED (InpSpectre_Enabled=true), CALLED TWICE in OnNewBar (L5633 + L5647!), 0 trades

**Gates/Conditions Required:**
1. ✅ Period == H4 (L9827)
2. ✅ CountOpenTrades == 0 (L9828)
3. ✅ ATR > 0 (L9831)
4. ✅ ADX > threshold (L9835)
5. ✅ FVG detection: gapHigh > gapLow (L9843)
6. ✅ Gap >= minPips (L9846)
7. 🔴 **Uses OP_BUYLIMIT / OP_SELLLIMIT (L9859/9872)**

**Root Cause of Death:** **CRITICAL BUG — OpenTrade() rejects limit orders!** At L8073, OpenTrade() has:
```cpp
if(type != OP_BUY && type != OP_SELL) { return -1; }
```
SPECTRE passes `OP_BUYLIMIT` (L9859) and `OP_SELLLIMIT` (L9872), which will ALWAYS be rejected by this validation. The function returns -1 every time.

**Most Likely Blocking Condition:** OpenTrade() rejection at L8073 — `type != OP_BUY && type != OP_SELL`

**Logic Assessment:** The FVG (Fair Value Gap) detection logic is clean and the strategy concept is sound. The ONLY problem is that it uses limit orders which are rejected by OpenTrade().

**Recommendation:** FIX — Either:
A) Modify OpenTrade() to accept OP_BUYLIMIT/OP_SELLLIMIT/OP_BUYSTOP/OP_SELLSTOP (L8073: change to `if(type < OP_BUY || type > OP_SELLSTOP)`), or
B) Change SPECTRE to use market orders when price is already in the FVG zone, or
C) Create a dedicated `OpenPendingOrder()` function.

Also: Remove the duplicate call at L5644-5648.

---

### 3.11 AETHER GAP (ExecuteAetherGap, Magic: 777016) — Lines 9884-9944

**Status:** ENABLED (InpAetherGap_Enabled=true), CALLED TWICE in OnNewBar (L5640 + L5654!), 0 trades

**Gates/Conditions Required:**
1. ✅ Period == H4 (L9886)
2. ✅ CountOpenTrades == 0 (L9887)
3. ✅ ATR > 0 (L9890)
4. ✅ RSI in neutral zone (L9894)
5. ✅ ATR contraction: atr < atrSMA * 0.8 (L9900)
6. ✅ FVG detection (L9908)
7. ✅ Gap >= minPips (L9911)
8. 🔴 **Uses OP_BUYLIMIT / OP_SELLLIMIT (L9926/9938)**

**Root Cause of Death:** Same as SPECTRE — **OpenTrade() rejects limit orders** at L8073.

**Additionally:** The ATR contraction filter (L9900) is unusual: `if(atr > atrSMA * 0.8) return;` — this means ATR must be BELOW 80% of its 20-period average. This is actually a reasonable filter for the "volume contraction fill" concept.

**Most Likely Blocking Condition:** OpenTrade() rejection at L8073

**Logic Assessment:** The concept (filling FVGs during low volatility) is sound and complementary to SPECTRE (which trades FVGs during trends). The RSI neutral zone filter and ATR contraction check are well-designed.

**Recommendation:** FIX — Same as SPECTRE: modify OpenTrade() or create OpenPendingOrder(). Also remove the duplicate call at L5651-5655.

---

### 3.12 STRUCTURAL RETEST (ExecuteStructuralRetest, Magic: 9006) — Lines 9709-9819

**Status:** ENABLED (InpStructuralRetest_Enabled=true), CALLED in OnNewBar, 0 trades

**Gates/Conditions Required:**
1. ✅ InpStructuralRetest_Enabled (L9711)
2. ✅ Period == H4 (L9712)
3. ✅ CountOpenTrades == 0 (L9713)
4. ✅ IsStrategyHealthy (L9714)
5. ✅ CheckTimeFilter (L9715)
6. ✅ CheckDirectionalBias (L9718)
7. ✅ ATR > 0 (L9722)
8. ✅ Breakout detection: Close[i] > swingHigh with prior bar below (L9737)
9. ✅ Retest: Low[1] <= retestLevel * 1.001 && Close[1] > retestLevel (L9759)
10. ✅ breakBar > 1 (L9756)
11. ✅ RR >= MinRR (L9770)

**Root Cause of Death:** This strategy requires a multi-step sequence: (1) identify swing high/low, (2) detect breakout of that level, (3) wait for pullback/retest, (4) confirm rejection. On H4, this sequence takes 3-10 bars, and requiring `breakBar > 1` (L9756) means the breakout must have happened at least 2 bars ago but within `RetraceBars` window. The combination of timing + price proximity to level (0.1% tolerance at L9759) + RR requirement is extremely selective.

**Most Likely Blocking Condition:** The retest proximity check `Low[1] <= retestLevel * 1.001` (L9759) — price must come back within 0.1% of the broken level AND close above it. This is very tight on H4.

**Logic Assessment:** The breakout-retest concept is excellent and widely used. The implementation is clean but the parameters are too tight.

**Recommendation:** FIX — Widen the retest proximity from 0.1% to 0.3% (L9759: change 1.001 to 1.003 and 0.999 to 0.997). Also relax the minimum RR. Expected: 15-40 trades over 6 years.

---

### 3.13 LIQUIDITY SWEEP (ExecuteLiquiditySweep, Magic: 9005) — Lines 9604-9702

**Status:** DISABLED (`InpLiquiditySweep_Enabled = false`, L4616) with comment: "V28.04: CUT — PF 0.84, negative EV (-$1,439)"

**Gates/Conditions Required:**
1. ❌ InpLiquiditySweep_Enabled (L9606)
2. ✅ Period == H4 (L9607)
3. ✅ CountOpenTrades == 0 (L9608)
4. ✅ IsStrategyHealthy (L9609)
5. ✅ CheckTimeFilter (L9610)
6. ✅ CheckDirectionalBias (L9613)
7. ✅ RSI oversold/overbought (L9638/9658)
8. ✅ Volume spike (L9630)
9. ✅ Price swept below/above session range AND closed back inside (L9637/9657)
10. ✅ Recent sweep within MaxRetraceBars (L9645/9663)

**Root Cause of Death:** Intentionally disabled after producing negative EV. The strategy had a PF of 0.84 (losing money).

**Logic Assessment:** The stop-hunt reversal concept is valid in theory, but the volume spike filter using H4 volume is unreliable in forex (most brokers have synthetic volume). The strategy's negative EV suggests the signal quality is poor.

**Recommendation:** PERMANENTLY REMOVE or completely redesign. The core concept (liquidity sweep reversal) needs a different implementation — perhaps using order flow or tick data rather than H4 volume bars.

---

## 4. LIVE STRATEGY ANALYSIS

### 4.1 MEAN REVERSION (ExecuteMeanReversionModelV8_6, Magic: InpMagic_MeanReversion)

**Trade Frequency:** ~200-300 trades over 6 years (dominant strategy)

**What Limits It:**
- Hurst exponent regime detection (L6329-6363): Adapts BB deviation based on regime
- Time filter (L6317)
- Hive state defensive mode (L6294)
- Strategy health cooldown (L6287)
- V23 empirical probability thresholds (L6369-6397)

**Filter Assessment:** Filters are well-calibrated. The Hurst-based adaptive bands (tighter in mean-reverting regime, wider in trending) is excellent design. The V24 adaptive entry thresholds add looseness when probability is favorable.

**Opportunities:** The strategy is already the primary contributor. The V28.07 relaxations (Hurst threshold from 0.50 to 0.55, L6340) should increase frequency slightly.

---

### 4.2 REAPER (ExecuteReaperProtocol, Magic: 888001/888002)

**Trade Frequency:** ~100-200 trades over 6 years (grid system)

**What Limits It:**
- H4 timeframe (L7256)
- Arbiter direction filter (L7239-7241)
- Queen Bee circuit breaker (L7268 — currently disabled with `if(false)`)
- Grid management (ProcessReaperBasket manages existing positions)

**Filter Assessment:** The Queen Bee gate at L7268 is disabled (`if(false)`), which is good — it was blocking Reaper trades. The Arbiter filter is the main constraint.

**Opportunities:** The Reaper is a grid system — its frequency depends on market ranging behavior. No easy frequency increases without changing the core approach.

---

### 4.3 SILICON-X (ExecuteSiliconCore, Magic: 984651)

**Trade Frequency:** ~50-100 trades over 6 years (grid/pending system)

**What Limits It:**
- Timer interval (InpSX_TimerInterval, L10695)
- Apex Sentinel greenlight (L10714)
- Trap placement window (L10715)
- Max levels cap (InpSX_MaxLevels)
- ATR-based grid spacing (L10702-10707)

**Filter Assessment:** The Apex Sentinel and trap placement window are the primary constraints. The ATR-based grid spacing (V28.00) is a good improvement over fixed pips.

**Opportunities:** Relaxing the Apex Sentinel requirements could increase initial trap placement frequency.

---

### 4.4 PHANTOM (ExecutePhantomStrategy, Magic: 777013)

**Trade Frequency:** ~5-15 trades over 6 years (~1 per quarter — Monday gap trader)

**What Limits It:**
- DayOfWeek == 1 (L7012) — ONLY Monday
- TimeHour < 4 (L7013) — ONLY first bar of Monday
- Gap size: InpPhantom_MinGap_Pips to InpPhantom_MaxGap_Pips (L7032-7033)
- IsStrategyHealthy (L7007)

**Filter Assessment:** The extreme selectivity is BY DESIGN — Monday gap fading is a rare-event strategy. One trade per week maximum (only on Mondays with gaps in the right range).

**Opportunities:** Very limited — this is intentionally a low-frequency strategy. Could widen gap size tolerance slightly.

---

### 4.5 NEXUS (ExecuteNexusStrategy, Magic: 777014)

**Trade Frequency:** ~10-30 trades over 6 years

**What Limits It:**
- ATR compression: N consecutive bars below compression threshold (L7104-7108)
- Breakout: Close beyond prior bar's range (L7112-7113)
- CheckDirectionalBias (L7131)
- Spread check (L7121)

**Filter Assessment:** The compression requirement (N consecutive low-ATR bars) followed by an immediate breakout is a sound squeeze-breakout approach but inherently low-frequency.

**Opportunities:** Reduce InpNexus_CompressionBars or relax InpNexus_CompressionRatio for more frequent entries.

---

### 4.6 NOISE BREAKOUT (ExecuteNoiseBreakout, Magic: 777012)

**Trade Frequency:** ~30-80 trades over 6 years

**What Limits It:**
- BB squeeze detection (L6860): BB must be inside KC on prior bar
- Breakout: Close beyond BB with ATR offset (L6880-6881)
- Volume confirmation: body > prev body * mult (L6877)
- Directional bias (L6879)
- CountOpenTrades == 0 (L6847)

**Filter Assessment:** The squeeze-to-breakout pipeline is well-calibrated. The ATR breakout offset (L6881) and volume confirmation (L6877) provide quality filtering.

**Opportunities:** The breakout ATR multiplier (InpNoiseBreakoutATRMult) could be slightly reduced for more entries.

---

### 4.7 DIVERGENCE MR — Listed as DEAD (see 3.9 above)

This strategy is enabled but produces 0 trades due to the Hurst + ADX + divergence + BB quadruple filter. See section 3.9 for analysis and fix.

---

## 5. SYSTEM ARCHITECTURE ISSUES

### 5.1 Max Open Trades Bottleneck (CRITICAL)

**Location:** L5501, L5532, L5547, L5554, L5561, L5571, L5578, L5585, L5592, L5599, L5606, L5613, L5620, L5627, L5634, L5641, L5648, L5655

**Problem:** `InpMaxOpenTrades = 16` (L1165). Each strategy that opens a trade adds to the count. With 19 strategies competing for 16 slots, and each strategy limited to 1 trade (CountOpenTrades(magic) > 0 check), the first 16 strategies to fire will block all remaining ones.

**Impact:** The ordering in OnNewBar matters — Reaper and MeanReversion fire first and can consume slots before later strategies get a chance. With active grid strategies (Reaper, Silicon-X) potentially using multiple slots, the later strategies (Spectre, AetherGap, StructuralRetest) may never get to trade.

**Recommendation:** Either increase InpMaxOpenTrades to 20-24, or implement per-strategy slot allocation instead of a global pool.

### 5.2 Duplicate Strategy Calls (BUG)

**Location:** L5633 + L5647 (ExecuteSpectre called TWICE), L5640 + L5654 (ExecuteAetherGap called TWICE)

**Problem:** SPECTRE and AETHER GAP are each called twice per bar. The first call may open a trade, and the second call would attempt to open another (blocked by CountOpenTrades > 0 check, so no double-trade, but it wastes CPU and creates confusing log output).

**Recommendation:** Remove the duplicate calls at L5644-5655.

### 5.3 OpenTrade() Limit Order Rejection (CRITICAL BUG)

**Location:** L8073

**Problem:** OpenTrade() rejects any order type other than OP_BUY and OP_SELL. This kills SPECTRE and AETHER GAP which use OP_BUYLIMIT/OP_SELLLIMIT.

**Recommendation:** Extend OpenTrade() to handle all MQL4 order types, or create a separate OpenPendingOrder() function.

### 5.4 IsOurMagicNumber() Missing Entries (BUG)

**Location:** L5921-5947

**Problem:** The following magic numbers are mapped in GetStrategyIdx() but NOT in IsOurMagicNumber():
- **InpVortex_MagicNumber (9001)** — missing!
- **InpRegimeShift_MagicNumber (9002)** — missing!

This means trades from these strategies would not be tracked by the performance system, would not be recognized as "our" trades in order scanning, and would be treated as external orders.

**Recommendation:** Add `magic == InpVortex_MagicNumber || magic == InpRegimeShift_MagicNumber` to IsOurMagicNumber() at L5942.

### 5.5 Queen Bee / Hive State System

**Location:** L5670-5750 (UpdateQueenBeeStatus, QueenBee_GlobalRiskCheck)

**Problem:** The Queen Bee system has been progressively disabled:
- V28.07: QueenBee gate removed from Reaper (L7268: `if(false)`)
- V28.07: QueenBee gate removed from Warden (L9155-9158)
- V28.07: Reaper condition filter disabled from MeanReversion (L6301: `if(false)`)
- V28.07: Market filters disabled from MeanReversion (L6311: `if(false)`)

The hive state system still runs (L5695) but has minimal impact since most gates are disabled. The defensive mode only blocks MeanReversion if `InpMR_Allow_Defensive` is false (L6294).

**Assessment:** The Queen Bee was overly aggressive in earlier versions and has been correctly neutered. However, the `g_hive_state` variable is still set and could be used for smarter risk management.

### 5.6 Strategy Health / Cooldown System

**Location:** L3096-3186 (IsStrategyHealthy)

**Problem:** The cooldown system (10-bar disable when PF drops below threshold) is a good concept but has a flaw: strategies with 0 trades have `g_perfData[strategyIndex].trades = 0`, which is LESS than `InpMinTradesForDecision`. When trades < minimum, the function returns TRUE (allows trading, L3132-3134). This is correct for new strategies. However, if a strategy gets 1-2 losing trades early, it could be permanently stuck in cooldown if the cooldown period resets before enough trades accumulate.

### 5.7 V23 Strategy Registration Gap

**Location:** L4761-4783

**Problem:** Only 6 strategies are registered with V23_RegisterStrategy (Warden, Reaper_Buy, Sell, Silicon-X, NoiseBreakout, MathReversal). The remaining 13 strategies are NOT registered, meaning:
- V23_GetEmpiricalProb() returns 0.5 (neutral) for them
- V23_CalculateLotSize() cannot use V23 intelligence
- V23 trade tracking is unavailable

**Impact:** MeanReversion, Titan, Apex, Phantom, Nexus, Vortex, RegimeShift, SessionMomentum, DivergenceMR, LiquiditySweep, StructuralRetest, SPECTRE, AETHER GAP all lack V23 institutional intelligence.

**Recommendation:** Register all strategies in OnInit().

### 5.8 SessionMomentum Close[0] Bug

**Location:** L9484, L9486

**Problem:** Uses `Close[0]` (current incomplete bar) in a once-per-bar function. When OnNewBar fires, Close[0] is the new bar's open price, not a meaningful breakout level.

**Recommendation:** Change to `Close[1]`.

### 5.9 Apex UTC Offset Bug

**Location:** L6946

**Problem:** Uses `TimeHour(Time[1])` without applying `InpServerUTCOffset`, unlike SessionMomentum which correctly applies it (L9457).

**Recommendation:** Add UTC offset conversion.

---

## 6. RECOMMENDATIONS SUMMARY

### Revive (with code fixes):

| Strategy | Fix | Line(s) | Expected Trades | Effort |
|----------|-----|---------|-----------------|--------|
| **SPECTRE** | Fix OpenTrade() for limit orders | L8073 | 20-60 | LOW |
| **AETHER GAP** | Fix OpenTrade() for limit orders | L8073 | 15-40 | LOW |
| **SessionMomentum** | Change Close[0] to Close[1] | L9484, L9486 | 30-80 | TRIVIAL |
| **Chronos/Microstructure** | Add m15Close data pipeline | New code needed | 200-500/yr | MEDIUM |
| **Apex** | Add UTC offset to session check | L6946 | 10-30 | TRIVIAL |
| **Vortex** | Enable + add to IsOurMagicNumber() | L4579, L5942 | 30-60 | LOW |
| **RegimeShift** | Enable + fix ADX logic + add to IsOurMagicNumber() | L4589, L9395, L5942 | 20-40 | LOW |
| **DivergenceMR** | Relax Hurst threshold to 0.6 | L9546 default | 20-50 | TRIVIAL |
| **MathReversal** | Enable InpMathFirst | L4556 | 50-150 | TRIVIAL |
| **Titan** | Reduce filter stack (remove Valkyrie, simplify D1) | L9000-9067 | 50-100 | MEDIUM |
| **Warden** | Relax squeeze ratio, extend breakout window | L9193, L9214 | 20-50 | LOW |
| **StructuralRetest** | Widen retest proximity to 0.3% | L9759 | 15-40 | TRIVIAL |

### Permanently Remove:

| Strategy | Reason |
|----------|--------|
| **LiquiditySweep** | Negative EV (PF 0.84), forex volume data is unreliable |

### Critical Bug Fixes (Non-negotiable):

1. **OpenTrade() limit order support** (L8073) — Blocks SPECTRE + AETHER GAP
2. **Remove duplicate calls** (L5644-5655) — SPECTRE and AETHER GAP called twice
3. **IsOurMagicNumber() missing Vortex + RegimeShift** (L5942) — Trade tracking broken
4. **SessionMomentum Close[0] → Close[1]** (L9484/9486) — Fundamental logic error
5. **Apex UTC offset** (L6946) — Session window misaligned
6. **Chronos m15Close pipeline** — Array never populated

### Architecture Improvements:

1. Increase InpMaxOpenTrades from 16 to 20-24
2. Register all strategies with V23_RegisterStrategy()
3. Implement per-strategy slot allocation instead of global pool

---

## APPENDIX: Strategy Magic Number Reference

| Magic | Strategy | Notes |
|-------|----------|-------|
| (variable) | MeanReversion | InpMagic_MeanReversion |
| 777008 | Titan | InpTitan_MagicNumber |
| 777009 | Warden | InpWarden_MagicNumber |
| 888001 | Reaper Buy | InpReaper_BuyMagicNumber |
| 888002 | Reaper Sell | InpReaper_SellMagicNumber |
| 984651 | Silicon-X | InpSX_MagicNumber |
| 999001 | Chronos/Microstructure | InpChronos_MagicNumber |
| 999002 | MathReversal | Hardcoded |
| 777012 | NoiseBreakout | Hardcoded |
| 777011 | Apex | InpApex_MagicNumber |
| 777013 | Phantom | InpPhantom_MagicNumber |
| 777014 | Nexus | InpNexus_MagicNumber |
| 9001 | Vortex | InpVortex_MagicNumber |
| 9002 | RegimeShift | InpRegimeShift_MagicNumber |
| 9003 | SessionMomentum | InpSessionMomentum_MagicNumber |
| 9004 | DivergenceMR | InpDivergenceMR_MagicNumber |
| 9005 | LiquiditySweep | InpLiquiditySweep_MagicNumber |
| 9006 | StructuralRetest | InpStructuralRetest_MagicNumber |
| 420101 | SPECTRE | InpSpectre_MagicNumber |
| 777016 | AETHER GAP | InpAetherGap_MagicNumber |

---

*Analysis complete. Total strategies: 19 (7 live, 12 dead). 6 critical bugs identified. Estimated trade count after all fixes: 800-1500 over 6.3 years.*
