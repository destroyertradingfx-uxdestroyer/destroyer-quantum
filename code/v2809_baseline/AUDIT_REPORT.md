# V28.09 Oblivion Original — Full Audit Report
**Date:** 2026-05-30
**File:** DESTROYER_QUANTUM_V28_09_Oblivion_original.mq4 (14,920 lines, 642KB)

---

## 1. STRATEGY STATUS MATRIX

| # | Strategy | Magic | Index | Input Enabled | Actually Fires | Status |
|---|----------|-------|-------|---------------|----------------|--------|
| 1 | MeanReversion | 777001 | 0 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 2 | Chronos | 999001 | 6 | ✅ true | ✅ Yes (M15) | ACTIVE |
| 3 | Titan | 777008 | 2 | ✅ true | ❌ NO | **DEAD CODE** |
| 4 | Warden | 777009 | 3 | ✅ true | ❌ NO | **DEAD CODE** |
| 5 | Reaper | 888001/002 | 4 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 6 | Silicon-X | 984651 | 5 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 7 | MathReversal | 999002 | 11 | ❌ false (InpMathFirst) | ❌ NO | DISABLED |
| 8 | NoiseBreakout | 777012 | 7 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 9 | Apex | 777011 | 8 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 10 | Phantom | 777013 | 9 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 11 | Nexus | 777014 | 10 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 12 | Vortex | 9001 | 12 | ❌ false | ❌ NO | DISABLED |
| 13 | RegimeShift | 9002 | 13 | ❌ false | ❌ NO | DISABLED |
| 14 | SessionMomentum | 9003 | 14 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 15 | DivergenceMR | 9004 | 15 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 16 | LiquiditySweep | 9005 | 16 | ❌ false | ❌ NO | DISABLED |
| 17 | StructuralRetest | 9006 | 17 | ✅ true | ✅ Yes (H4) | ACTIVE |
| 18 | Spectre | 420101 | 18 | ✅ true | ⚠️ TWICE (H4) | **BUG** |
| 19 | AetherGap | 777016 | 19 | ✅ true | ⚠️ TWICE (H4) | **BUG** |

**ACTUALLY TRADING (11 strategies):** MeanReversion, Chronos, Reaper, Silicon-X, NoiseBreakout, Apex, Phantom, Nexus, SessionMomentum, DivergenceMR, StructuralRetest

**BUGGED (2 strategies):** Spectre, AetherGap (duplicate dispatch + pending orders)

**DEAD CODE (2 strategies):** Titan, Warden (enabled in inputs, commented out in dispatch)

**DISABLED (4 strategies):** MathReversal, Vortex, RegimeShift, LiquiditySweep

---

## 2. CRITICAL BUGS

### BUG #1: SPECTRE DUPLICATE DISPATCH (Severity: HIGH)
**Lines:** 5633 and 5647 in OnNewBar()
```mql4
// FIRST dispatch (line 5633):
if(InpSpectre_Enabled) { ExecuteSpectre(); ... }

// SECOND dispatch (line 5647) — DUPLICATE!
if(InpSpectre_Enabled) { ExecuteSpectre(); ... }
```
**Impact:** Spectre fires TWICE per H4 bar = double trades, double risk, double spread cost.
**Fix:** Remove the second dispatch block (lines 5647-5651).

### BUG #2: AETHER GAP DUPLICATE DISPATCH (Severity: HIGH)
**Lines:** 5640 and 5654 in OnNewBar()
```mql4
// FIRST dispatch (line 5640):
if(InpAetherGap_Enabled) { ExecuteAetherGap(); ... }

// SECOND dispatch (line 5654) — DUPLICATE!
if(InpAetherGap_Enabled) { ExecuteAetherGap(); ... }
```
**Impact:** AetherGap fires TWICE per H4 bar = double trades, double risk.
**Fix:** Remove the second dispatch block (lines 5654-5658).

### BUG #3: SPECTRE + AETHER GAP USE PENDING ORDERS (Severity: HIGH)
**Lines:** 9859, 9872, 9926, 9938
```mql4
int ticket = OpenTrade(OP_BUYLIMIT, lots, gapMid, sl, tp, ...);  // SPECTRE BUY
int ticket = OpenTrade(OP_SELLLIMIT, lots, gapMid, sl, tp, ...); // SPECTRE SELL
int ticket = OpenTrade(OP_BUYLIMIT, lots, gapMid, sl, tp, ...);  // AETHER BUY
int ticket = OpenTrade(OP_SELLLIMIT, lots, gapMid, sl, tp, ...); // AETHER SELL
```
**Impact:** OP_BUYLIMIT/OP_SELLLIMIT are SILENT BACKTEST KILLERS. They only fill if price reaches the exact level — they do NOT simulate realistic fills. Both strategies produced 0 trades in previous backtests for this exact reason.
**Fix:** Convert to OP_BUY/OP_SELL market orders with price-level check (two-bar pattern).

### BUG #4: TITAN + WARDEN = DEAD CODE (Severity: MEDIUM)
**OnNewBar lines:** 5522-5527 (Titan commented out), 5537-5542 (Warden commented out)
```mql4
// V28.05 FIX #4: DISABLED Titan — 7 trades in 6 years, $21 profit. Dead weight.
// if(InpTitan_Enabled) { ExecuteTitanStrategy(); }

// V28.05 FIX #5: DISABLED Warden — 8 trades in 6 years, $690 profit. Dead weight.
// if(InpWarden_Enabled) { ExecuteWardenStrategy(); }
```
**Impact:** Both show `Enabled = true` in inputs but NEVER execute. The old OnTick_Elite dispatch block (lines 5196-5229) that called them is inside a `*/` comment block — dead code.
**Fix:** Either uncomment in OnNewBar or set inputs to false to avoid confusion.

### BUG #5: ARRAY BOUNDS OVERFLOW (Severity: CRASH RISK)
**GetStrategyIdx returns up to 19** (AetherGap), but several arrays are undersized:

| Array | Declared Size | Max Index Used | Overflow? |
|-------|--------------|----------------|-----------|
| g_stratProfits[15][60] | 15 | 19 | ❌ YES (idx 15-19) |
| g_stratProfitIdx[15] | 15 | 19 | ❌ YES |
| g_stratRollingWinRate[15] | 15 | 19 | ❌ YES |
| g_stratRollingAvgWin[15] | 15 | 19 | ❌ YES |
| g_stratRollingAvgLoss[15] | 15 | 19 | ❌ YES |
| g_stratRollingPF[15] | 15 | 19 | ❌ YES |
| g_stratSharpeProxy[15] | 15 | 19 | ❌ YES |
| g_stratLastCalcTime[15] | 15 | 19 | ❌ YES |
| g_stratTotalTrades[17] | 17 | 19 | ❌ YES (idx 17-19) |
| g_stratKellyFraction[17] | 17 | 19 | ❌ YES |
| g_stratHeatScore[17] | 17 | 19 | ❌ YES |
| g_stratDynamicMaxMult[17] | 17 | 19 | ❌ YES |
| g_strategyCooldown[17] | 17 | 19 | ❌ YES |
| g_perfData[20] | 20 | 19 | ✅ OK |
| g_consecLossTracker[20][2] | 20 | 19 | ✅ OK |
| g_strategyMultiplier[20] | 20 | 19 | ✅ OK |
| g_equityHistory[20] | 20 | 19 | ✅ OK |

**Impact:** Any trade from StructuralRetest (idx 17), Spectre (idx 18), or AetherGap (idx 19) accessing [15] or [17] arrays will cause "array out of range" crash.
**Fix:** Resize all arrays to [20].

---

## 3. DISPATCH CHAIN SUMMARY

### OnTick() — Every Tick
1. ManageDrawdownExposure_V2()
2. CheckCircuitBreaker()
3. CheckEventRisk() (if enabled)
4. Hades_ManageBaskets()
5. On new H4 bar → UpdateMultiTimeframeData_Fixed() → ExecuteMicrostructureStrategy() (Chronos M15)
6. On new H4 bar → OnNewBar()

### OnNewBar() — Every H4 Bar
1. V23_DetectMarketRegime()
2. UpdateQueenBeeStatus()
3. CountOpenTrades() guard
4. ExecuteReaperProtocol()
5. ~~ExecuteTitanStrategy()~~ (COMMENTED OUT)
6. ExecuteMeanReversionModelV8_6()
7. ~~ExecuteWardenStrategy()~~ (COMMENTED OUT)
8. ExecuteSiliconCore()
9. ExecuteMathReversal() (disabled — InpMathFirst=false)
10. ExecuteNoiseBreakout()
11. ExecuteApexStrategy() (if sxRoomAvailable)
12. ExecutePhantomStrategy() (if sxRoomAvailable)
13. ExecuteNexusStrategy() (if sxRoomAvailable)
14. ExecuteVortexStrategy() (disabled — InpVortex_Enabled=false)
15. ExecuteRegimeShiftStrategy() (disabled — InpRegimeShift_Enabled=false)
16. ExecuteSessionMomentum()
17. ExecuteDivergenceMR()
18. ExecuteLiquiditySweep() (disabled — InpLiquiditySweep_Enabled=false)
19. ExecuteStructuralRetest()
20. **ExecuteSpectre() — FIRST call**
21. **ExecuteAetherGap() — FIRST call**
22. **ExecuteSpectre() — DUPLICATE!**
23. **ExecuteAetherGap() — DUPLICATE!**

---

## 4. ARRAY SIZING AUDIT (Complete)

### Global Arrays — All declarations:
```
g_equityHistory[20]           ✅ OK
g_perfData[20]                ✅ OK (PerfData struct array)
g_strategyCooldown[17]        ❌ NEEDS [20]
g_consecLossTracker[20][2]    ✅ OK
g_strategyMultiplier[20]      ✅ OK
g_stratProfits[15][60]        ❌ NEEDS [20]
g_stratProfitIdx[15]          ❌ NEEDS [20]
g_stratTotalTrades[17]        ❌ NEEDS [20]
g_stratRollingWinRate[15]     ❌ NEEDS [20]
g_stratRollingAvgWin[15]      ❌ NEEDS [20]
g_stratRollingAvgLoss[15]     ❌ NEEDS [20]
g_stratRollingPF[15]          ❌ NEEDS [20]
g_stratKellyFraction[17]      ❌ NEEDS [20]
g_stratSharpeProxy[15]        ❌ NEEDS [20]
g_stratHeatScore[17]          ❌ NEEDS [20]
g_stratLastCalcTime[15]       ❌ NEEDS [20]
g_stratDynamicMaxMult[17]     ❌ NEEDS [20]
```

### Loop Bounds:
```
g_perfData init: for(i=0; i<17; i++)     ❌ NEEDS i<20
g_strategyCooldown init: for(i=0; i<17; i++)  ❌ NEEDS i<20
ReconcileFinalPerformance: local rd[20]   ✅ OK
```

---

## 5. RISK MANAGEMENT

- **Kelly Criterion:** Per-strategy fractional Kelly with Huntsman risk scaling
- **Huntsman:** Defensive mode during priming period (50 bars), 0.5x risk scale
- **DD Protection:** Activates at 10% DD, blocks new trades
- **Circuit Breaker:** System lockout mechanism
- **Event Risk:** FOMC/ECB/NFP window blocking
- **Queen Bee:** Portfolio-level exposure management
- **Leviathan:** Adaptive Kelly engine (master switch)
- **Max Open Trades:** InpMaxOpenTrades guard at each strategy dispatch

---

## 6. PRIORITY FIX ORDER

1. **FIX:** Remove duplicate Spectre + AetherGap dispatch (immediate — double trades)
2. **FIX:** Convert Spectre + AetherGap from pending orders to market orders (silent backtest killer)
3. **FIX:** Resize all [15]/[17] arrays to [20] (crash risk)
4. **FIX:** Uncomment Titan + Warden in OnNewBar, OR set inputs to false
5. **VERIFY:** Chronos M15 execution path is correct
6. **AUDIT:** Each strategy function for filter stacking (5+ independent if-return guards)
