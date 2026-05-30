# DESTROYER QUANTUM — Codebase Architecture Analysis

**Date:** 2026-05-29
**Analyst:** Automated Code Review
**Latest Version:** V29.00 (`DESTROYER_QUANTUM_V29_00.mq4`, 15,296 lines, ~654KB)

---

## 1. FILE INVENTORY

### Main Files (in `/home/ubuntu/destroyer-quantum/code/`)
| File | Description |
|---|---|
| `DESTROYER_QUANTUM_V29_00.mq4` | **PRIMARY** — Latest version, 15,296 lines. The "production" file. |
| `DESTROYER_QUANTUM_V28_17_RECKONING.mq4` | Previous version (V28.14 base), 15,483 lines. |
| `DESTROYER_QUANTUM.mq4` | V28.14 base file, identical to RECKONING. |
| `DQ_ExitManagement.mqh` | **Include file** — 6-module exit management system (NOT yet integrated). |
| `V29_00_EQUITY_CURVE.mq4` | **Snippet** — Equity curve multiplier function + GBPUSD correlation filter. NOT integrated into V29_00. |
| `equity_curve_trading_patch.mq4` | **Snippet** — V28.06 equity curve patch for GetLotSize. NOT integrated into V29_00. |
| `FVG_Strategy_Implementation.mq4` | Fair Value Gap strategy snippet. |
| `.set` files | Various backtest configuration presets (V28_06_*, V28_08_*, V29_00_*). |

### Config Files (in `/home/ubuntu/destroyer-quantum/configs/`)
- `V28_06_AGGRESSIVE.set`, `V28_06_MODERATE.set`, `V28_06_CONSERVATIVE.set`
- `V28_06_BASELINE.set` — Baseline backtest settings
- Multiple optimization `.set` files (Queen8, Risk, Kelly, etc.)

---

## 2. STRATEGIES & MAGIC NUMBERS

### Complete Strategy Inventory (20 slots, indices 0–19)

| Index | Strategy Name | Magic Number(s) | Status | Notes |
|---|---|---|---|---|
| 0 | **Mean Reversion** (Cerberus A) | `777001` / `555001` | ✅ ENABLED | BB 15/1.9 + RSI 10 62/38 + CCI 20 + ADX filter |
| 1 | Quantum Oscillator | (retired) | ❌ DISABLED | No active magic number |
| 2 | **Titan** (Cerberus T) | `777008` | ⚠️ DISABLED in code | Commented out in OnNewBar — "7 trades in 6 years, $21 profit" |
| 3 | **Warden** (Cerberus W) | `777009` / `666001` / `666002` | ⚠️ DISABLED in code | Commented out — "8 trades in 6 years, $690 profit" |
| 4 | **Reaper** (Cerberus R) | `888001` (buy), `888002` (sell) | ✅ ENABLED | Grid/martingale, H4 only |
| 5 | **Silicon-X** (Cerberus S) | `984651` | ⚠️ `InpSiliconX_Enabled = false` | Grid/Breakout, Hubble filter, wide pips-step |
| 6 | **Chronos** (M15 Scalper) | `999001` | ✅ ENABLED | M15 HFT, 25-pip SL, 35-pip TP |
| 7 | **Noise Breakout** | `777012` | ✅ ENABLED | BB Squeeze + Breakout (SSRN-4824172) |
| 8 | **Apex** | `InpApex_MagicNumber` | ✅ ENABLED | Session Rollover Reverter |
| 9 | **Phantom** | `InpPhantom_MagicNumber` | ✅ ENABLED | Monday Gap Fader |
| 10 | **Nexus** | `InpNexus_MagicNumber` | ✅ ENABLED | Volatility Compression Breakout |
| 11 | **Vortex** | `InpVortex_MagicNumber` | ✅ ENABLED | Vortex Indicator Trend Crossover |
| 11 | **MathReversal** | `999002` | ❌ DISABLED | `InpMathFirst = false` (V28.01 removed) |
| 12 | **Regime Shift** | `InpRegimeShift_MagicNumber` | ✅ ENABLED | ADX+RSI Regime Change Detector |
| 13 | **Session Momentum** | `9003` | ✅ ENABLED | London Breakout |
| 14 | **Divergence MR** | `9004` | ✅ ENABLED | RSI Divergence + Hurst |
| 15 | **Liquidity Sweep** | `9005` | ❌ DISABLED | `InpLiquiditySweep_Enabled = false` — "PF 0.84, negative EV" |
| 16 | **Structural Retest** | `9006` | ✅ ENABLED | Structural Break & Retest |
| 17 | **Order Block** (V29) | `9008` | ✅ ENABLED | ICT Order Block |
| 18 | **FVG** (V29) | `9007` | ✅ ENABLED | Fair Value Gap + Liquidity Sweep |
| 19 | **ORB** (V29) | `9009` | ✅ ENABLED | 8AM Opening Range Breakout |

### V29.00 Additional Systems (Not Strategies — Infrastructure)
1. **Multi-Timeframe Trend Alignment** — Blocks entries if D1/H4/H1 EMAs misaligned
2. **Session Kill Zones** — London 8-12, NY 13-17 (GMT)
3. **Chandelier Trailing Stop** — ATR-based adaptive trailing
4. **Adaptive Volatility Sizing** — ATR-relative lot scaling
5. **ICT Order Blocks**, **FVG**, **ORB** — New institutional strategies

---

## 3. KELLY SIZING IMPLEMENTATION (3 Separate Systems!)

The codebase has **three distinct Kelly implementations** that coexist:

### System A: `CalculateKellyFraction()` (Phase 5 — Lines 3681-3690)
```
f = (win_loss_ratio * win_rate - (1 - win_rate)) / win_loss_ratio
f *= 0.5  (Half-Kelly)
Clamp: [0.01, 0.50]
```
- Uses **default priors** when insufficient data (WR 0.55, AW 1.5x AL)
- 7 hardcoded strategy priors (indices 0-6)
- Called by `CalculateDynamicPositionSize()` which adds performance/conviction/regime multipliers

### System B: `GetKellyLotSize()` (Legacy — Lines 5102-5141)
```
kellyPct = ((b * p) - q) / b
kellyPct *= 0.25  (Quarter-Kelly)
Clamp: [0.001, 0.05]
riskMoney = Equity * kellyPct
lots = riskMoney / (SL_points * tickValue)
```
- **Hardcoded assumptions**: WR 0.65, avgWin $50, avgLoss $40
- Quarter-Kelly (25% of full Kelly)
- Used by grid strategies (Reaper) via `GetKellyLotSize(magic, stopPips)`

### System C: `CalculateRollingKelly()` (V27.19 — Lines 15128-15218)
```
f* = W - ((1-W) / R)    [standard Kelly]
halfKelly = rawKelly * 0.5
Clamp: [0.005, 0.10]
```
- **Per-strategy circular buffer** (60 trades)
- Calculates: Win Rate, Avg Win, Avg Loss, Profit Factor, Sharpe Proxy
- Blended with base risk: `effectiveRiskPercent = (kellyFrac * 100 * 0.6) + (baseRisk * 0.4)`
- This is the **most sophisticated** and likely the one that matters most
- Triggered every 5 trades via `RecordStrategyResult()`

### System D: `Leviathan_GetDynamicLotSize()` (Lines 8359-8404)
```
kelly_f = ((oddsRatio * winRate) - (1 - winRate)) / oddsRatio
baseRiskPercent = kelly_f * g_leviathan_kellyFraction * 100
finalRisk *= confidenceMultiplier  (streak-based)
```
- Uses `g_leviathan_kellyFraction = 0.25` (Quarter-Kelly)
- Confidence boost for win streaks, penalty for loss streaks
- Min/Max risk: `g_Ascension_MinRiskPercent=0.5%` to `g_Ascension_MaxRiskPercent=3.0%`

### Key Kelly Parameters
| Parameter | Default | Location |
|---|---|---|
| `g_kelly_fraction` | 0.25 | Global, used by Systems B/D |
| `g_leviathan_kellyFraction` | 0.25 | Leviathan engine |
| Half-Kelly safety | 0.5x | Systems A/C |
| Min Kelly | 0.5% (System C), 0.1% (System B) | |
| Max Kelly | 10% (System C), 5% (System B) | |
| Kelly blend | 60% Kelly + 40% base | System C |
| `InpLeviathan_KellyFraction` | 0.25 | Input parameter |
| `InpLeviathan_MaxRisk` | 5.0% | Input parameter |
| `InpLeviathan_MinRisk` | 0.5% | Input parameter |

---

## 4. HEAT SCORE SYSTEM (V27.19)

**Location:** `CalculateHeatScore()` at line 15225

### Formula
```
heat = (pfScore * 0.30) + (wrScore * 0.15) + (kellyScore * 0.25) + 
       (sharpeScore * 0.15) + (streakMomentum * 0.15)
```

### Component Scoring
| Component | Weight | Max Score At |
|---|---|---|
| PF Score | 30% | PF >= 3.0 |
| Win Rate Score | 15% | WR >= 75% |
| Kelly Score | 25% | Kelly >= 5% |
| Sharpe Score | 15% | Sharpe >= 2.0 |
| Streak Momentum | 15% | 100% recent wins |

### Smoothing & Application
- **EWMA smoothed**: `heat = heat_old * 0.7 + heat_new * 0.3`
- **Range**: [0.0, 1.0]
- **Risk mapping**: `heatMultiplier = 0.25 + (heat * 1.75)` → range [0.25x, 2.0x]
- Applied in `MoneyManagement_V2719()` at line 13648

---

## 5. REAPER BASKET LOGIC

### Architecture
- **Dual-basket**: Separate buy (`888001`) and sell (`888002`) baskets
- **Grid type**: Martingale with geometric lot multiplier
- **Timeframe**: H4 only (hardcoded guard)

### Key Parameters
| Parameter | Default | Description |
|---|---|---|
| `InpReaper_InitialLot` | 0.08 | Starting lot for first grid level |
| `InpReaper_LotMultiplier` | 1.3 | Geometric multiplier per level |
| `InpReaper_MaxLevels` | 8 | Soft cap (structural) |
| `InpReaper_HardcapLevels` | 8 | Hard cap (absolute) |
| `InpReaper_PipStep` | 25 | Base grid step (ATR-adjusted) |
| `InpReaper_ATR_GridMult` | 0.5 | ATR multiplier for dynamic grid |
| `InpReaper_BasketTP_Money` | $400 | Phoenix Protocol basket TP |
| `InpReaper_BasketTP` | $50 | (Legacy, overridden by Money) |
| `InpReaper_CooldownBars` | 2 | Min H4 bars between levels |
| `InpReaper_RegimeADX` | 50.0 | Block grid if ADX > 50 + opposing trend |
| `InpReaper_EnableTrail` | true | Chimera trailing defense |
| `InpReaper_TrailStart_Money` | $150 | Profit to activate trail |
| `InpReaper_TrailStop_Pips` | 300 | Trailing distance (30 pips after fix) |

### Execution Flow (`ExecuteReaperProtocol()`, line 7814)
1. Check H4 timeframe guard
2. `UpdateReaperBasketState()` — Count levels, avg prices, active flags
3. Queen Bee circuit breaker check
4. `ProcessReaperBasket(Buy)` and `ProcessReaperBasket(Sell)`

### `ProcessReaperBasket()` Logic (line 7932)
1. Calculate basket profit + level count
2. **Basket TP**: Close all if `basket_profit >= $400`
3. **Per-level TP**: Close individual levels at 1.5x ATR profit
4. **Trinity Guard**: Block if another grid is active
5. **Hardcap**: Stop at 8 levels
6. **Regime Suppression**: Block if ADX > 50 + opposing trend
7. **Trend Brake**: Stop expansion if ADX > 35 and 4+ levels
8. **ATR Grid Spacing**: `distance = ATR(H4,14) * 0.5`, clamped [15, 200] pips
9. **Cooldown**: Min 2 H4 bars between levels
10. **Entry**: First trade requires Alpha Sentinel; grid levels use ATR-based spacing

### Lot Progression at Each Level
| Level | Lot Size (approx) |
|---|---|
| 1 | 0.08 |
| 2 | 0.10 |
| 3 | 0.14 |
| 4 | 0.18 |
| 5 | 0.23 |
| 6 | 0.30 |
| 7 | 0.39 |
| 8 | 0.50 |
| **Total** | **~1.92 lots max** |

---

## 6. EQUITY CURVE TRACKING (Current State)

### What EXISTS in the main codebase:
1. **Queen Bee HWM tracking** (`g_high_watermark_equity`, line 6344) — Updates high watermark, calculates drawdown %
2. **DD-based lot reduction** (line 13686-13688):
   - DD >= 8%: `combinedMultiplier *= 0.5`
   - DD >= 5%: `combinedMultiplier *= 0.75`
3. **DD protection gate** (line 6130): Blocks new entries when `g_ddProtectionActive` (DD > 10%)
4. **Drawdown exposure manager** (`ManageDrawdownExposure_V2()`) — Called first in OnTick

### What EXISTS as SEPARATE FILES (NOT integrated):
1. **`equity_curve_trading_patch.mq4`** — V28.06 patch with EMA-based equity curve trading
   - `UpdateEquityCurveEMA()` — 20-period EMA of AccountEquity
   - `GetEquityCurveMultiplier()` — Returns 1.5x (bull) or 0.5x (bear)
   - **NOT integrated** into V29_00.mq4

2. **`V29_00_EQUITY_CURVE.mq4`** — Advanced equity curve multiplier
   - `CalculateEquityCurveMultiplier()` — 4-factor composite:
     - HWM Proximity (30%) — How close to all-time high
     - Rolling Growth Rate (30%) — 10-day equity growth
     - Drawdown State (25%) — DD-based dampening
     - Win Streak Momentum (15%) — Strategy win ratio
   - Range: [0.5, 2.5]
   - Also includes `GetGBPUSDCorrelationSignal()` — EURUSD/GBPUSD correlation filter
   - **NOT integrated** into V29_00.mq4

3. **`DQ_ExitManagement.mqh`** — 6-module exit management (NOT integrated)
   - Module 1: Partial Close + Breakeven (at R:R)
   - Module 2: Chandelier Exit Adaptive Trailing
   - Module 3: Time-Decay Exit (close stale trades)
   - Module 4: **Equity Curve DD-Based Lot Scaling** (linear interpolation, 5%-20% DD range)
   - Module 5: Session-Aware Lot Sizing (Asian 0.8x, London 1.2x, NY Overlap 1.3x)
   - Module 6: Anti-Martingale Win Streak Sizing (3+ wins=1.3x, 3+ losses=0.5x)
   - Composite via `DQ_GetFinalLotMultiplier()`

---

## 7. LOT SIZING PIPELINE (Complete Flow)

When a strategy wants to place a trade, the lot size goes through:

```
1. GetLotSize_Ascension() OR MoneyManagement_V2719() OR GetKellyLotSize()
   ├── Kelly calculation (which system depends on caller)
   ├── Performance multiplier (from g_perfData[] / PF tiers)
   ├── Conviction multiplier (8-component system)
   ├── Regime multiplier (DD-based)
   └── Returns raw lots

2. GetGeneticRiskMultiplier(magic) — applied after
   ├── PF-based tiers: 0.75x to 4.0x
   ├── Sharpe bonus: +15%/+10%
   └── Absolute cap: 5.0x

3. GetStrategySpecificRisk(magic) — additional override
   ├── 888001/888002/984651: 2.5x
   ├── 777009/777012: 1.0x
   ├── 777001: 0.5x
   └── Fallback: GetGeneticRiskMultiplier()

4. Combined multiplier cap: MathMin(adaptive * heat, 2.0)
   DD adjustments: 8%+ → 0.5x, 5%+ → 0.75x
   Volatility multiplier: GetVolatilityMultiplier()

5. Lot cap: equity-based (1.0/2.0/3.5/5.0) + absolute max ($500 loss cap)
```

### Base Risk Parameters
| Parameter | Default | Description |
|---|---|---|
| `InpBase_Risk_Percent` | 1.0% | Base risk per trade (H4 strategies) |
| `InpBase_Risk_Percent_H1` | 0.25% | Base risk for H1 strategies |
| `InpMaxTotalRisk_Percent` | 8.0% | Portfolio risk budget |
| `InpMaxLotSize` | 5.0 | Absolute max lot per trade |
| `InpMaxOpenTrades` | 12 | Max concurrent trades |
| `InpDefensiveDD_Percent` | 15.0% | DD to trigger defensive mode |
| `InpDrawdown_Risk_Mult` | 0.3 | Risk multiplier in defensive mode |

---

## 8. STRATEGY DISPATCH ARCHITECTURE

### OnTick() Flow (line 5221)
```
OnTick()
├── ManageDrawdownExposure_V2()       // Priority 1: DD management
├── CheckCircuitBreaker()             // Priority 2: Circuit breaker
├── CheckEventRisk()                  // V27.7: Event shield
├── Hades_ManageBaskets()             // Priority 3: Basket management
├── [PER BAR]:
│   ├── UpdateMultiTimeframeData()
│   ├── ExecuteMicrostructureStrategy() // Chronos M15 (independent)
│   ├── OnNewBar()                    // Main strategy dispatch
│   └── UpdatePerformanceV4()         // Track closed trades
└── UpdateDashboard_Realtime()
```

### OnNewBar() Strategy Dispatch (line 6101)
```
OnNewBar()
├── IsTradeBlockedByShield()          // Event + ATR spike
├── IsBadTradingHour()                // Time filter
├── DD protection check               // DD > 10% gate
├── GetMultiTimeframeBias()           // V29: MTF alignment
├── IsInKillZone()                    // V29: Session kill zone
├── V23_DetectMarketRegime()          // Regime detection
├── UpdateQueenBeeStatus()            // HWM + DD tracking
├── [MAX TRADES CHECK]
├── ExecuteReaperProtocol()           // ALWAYS FIRST
├── ExecuteMeanReversionModelV8_6()
├── ExecuteSiliconCore()              // If enabled
├── ExecuteMathReversal()             // If InpMathFirst
├── ExecuteNoiseBreakout()
├── ExecuteApexStrategy()
├── ExecutePhantomStrategy()
├── ExecuteNexusStrategy()
├── ExecuteVortexStrategy()
├── ExecuteRegimeShiftStrategy()
├── ExecuteSessionMomentum()
├── ExecuteDivergenceMR()
├── ExecuteLiquiditySweep()           // Disabled
├── ExecuteStructuralRetest()
├── [MTF-gated V29 strategies]:
│   ├── ExecuteOrderBlockStrategy()
│   ├── ExecuteFVGStrategy()
│   └── ExecuteORBStrategy()
└── OnNewBar_Elite()                  // Elite optimizations
```

### Key Architectural Notes
- **Titan & Warden are DISABLED** — Commented out in OnNewBar, "dead weight"
- **Silicon-X is DISABLED** — `InpSiliconX_Enabled = false` since V27.11-R
- **MathReversal is DISABLED** — `InpMathFirst = false` since V28.01
- **LiquiditySweep is DISABLED** — PF 0.84, negative EV
- **Reaper is ALWAYS FIRST** in dispatch order
- **V29 strategies (OrderBlock, FVG, ORB)** are gated by MTF + KillZone

---

## 9. WHERE NEW STRATEGIES/FEATURES WOULD BE ADDED

### Adding a New Strategy
1. **Add input parameters** after line 4645 (after ORB inputs)
2. **Add magic number** to `GetStrategyIndexByMagic()` at line 15055
3. **Add to strategy slot** in `PerfData g_perfData[20]` (indices 0-19, some unused)
4. **Write `Execute[StrategyName]()` function** — insert near line 6100
5. **Add dispatch call** in `OnNewBar()` after line 6325 (after ORB dispatch)
6. **Add risk multiplier** in `GetStrategySpecificRisk()` at line 4430

### Integrating Equity Curve Trading
- **Best candidate**: `V29_00_EQUITY_CURVE.mq4` `CalculateEquityCurveMultiplier()` (line 10-90)
- **Integration point**: Apply in `MoneyManagement_V2719()` at line 13690, before final lot calculation
- **Alternative**: Integrate `DQ_ExitManagement.mqh` — add `#include` after line 12, call `DQ_InitExitManagement()` in `OnInit()`, call `DQ_ManageExits()` in `OnTick()`

### Integrating DQ_ExitManagement.mqh
1. Add `#include "DQ_ExitManagement.mqh"` after line 12
2. Call `DQ_InitExitManagement()` in `OnInit()` (line 4659)
3. Call `DQ_ManageExits(magicBase, magicRange)` at start of `OnTick()` (line 5222)
4. Call `DQ_GetFinalLotMultiplier()` in lot sizing functions
5. Call `DQ_RecordTradeResult(isWin)` in `RecordStrategyResult()`

### Key Files to Modify
| File | Purpose |
|---|---|
| `DESTROYER_QUANTUM_V29_00.mq4` | Main EA — all strategy/risk code |
| `DQ_ExitManagement.mqh` | Exit management module (pre-built, not integrated) |
| `V29_00_EQUITY_CURVE.mq4` | Equity curve + GBPUSD filter (pre-built, not integrated) |
| `equity_curve_trading_patch.mq4` | Simpler equity curve patch (pre-built, not integrated) |

---

## 10. KNOWN ISSUES & TECHNICAL DEBT

1. **Three competing Kelly systems** — Systems A, B, C, D all calculate Kelly differently. The V27.19 system (C) is most sophisticated but may conflict with others.
2. **Hardcoded priors in GetKellyLotSize()** — WR 0.65, avgWin $50, avgLoss $40 are not strategy-specific.
3. **Equity curve code written but not integrated** — Two separate equity curve implementations exist as snippets but neither is wired into the main EA.
4. **DQ_ExitManagement.mqh not integrated** — Full 6-module exit management system is ready but not included.
5. **Silicon-X disabled since V27.11-R** — Was PF 10.98 beast, disabled during refactor. Pips-vs-points bugs were fixed in V28.06 RESURRECTION but still disabled.
6. **Titan/Warden dead weight** — Both commented out ("7-8 trades in 6 years"). Need redesign before re-enabling.
7. **MathReversal index collision** — Both MathReversal (999002) and Vortex map to index 11 in `GetStrategyIndexByMagic()`.
8. **Comment-based order identification** — Some functions filter by `OrderComment() == InpTradeComment` which is fragile.

---

## 11. VERSION HISTORY QUICK REFERENCE

| Version | Codename | Key Change |
|---|---|---|
| V17.8 | Titanium | Reaper PF 16.79, Silicon-X PF 10.98 |
| V17.9 | Profit Ratchet | HWM protection, asymmetric allocation |
| V18.0 | Institutional | APEX-only risk (kill Warden/MR) |
| V18.3 | Chronos | M15 HFT scalper addition |
| V23 | Empirical Probability | EWMA probability bins, R-expectancy, entropy |
| V24 | Alpha Expansion | Conditional VAR relaxation, adaptive thresholds |
| V25 | Elastic Scoring | Continuous signal generation from math |
| V26 | Math-First | MathReversal strategy, pure math signals |
| V27.19 | Kelly + Heat Score | Rolling Kelly, dynamic tier caps, heat allocation |
| V28.00 | Session Momentum | London breakout, Divergence MR, per-level TP |
| V28.04 | Surgical Patch | Cut LiquiditySweep, fixed Titan, adjusted DivergenceMR |
| V28.06 | RESURRECTION | Fixed pips-vs-points bugs, aggressive settings |
| V29.00 | VENI VIDI VICI | MTF + KillZone + Chandelier + VolSizing + OrderBlock + FVG + ORB |
