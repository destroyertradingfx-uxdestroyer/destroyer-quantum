# Technical Analysis: DESTROYER QUANTUM V28.06 TITAN
## Date: 2026-05-27
## Status: BACKTEST PENDING

---

## 1. FILE INVENTORY

| File | Lines | Size | Status |
|------|-------|------|--------|
| V28_06_TITAN.mq4 | 14,522 | 624KB | Latest built version |
| V29_00.mq4 | 15,296 | 654KB | Next version (adds 7 institutional enhancements, NOT equity curve trading) |

**Key finding**: V29_00 is NOT "equity curve trading" — it adds MTF confluence, KillZone filters, Chandelier trailing stops, OrderBlock/FVG/ORB strategies. It also **downgrades** risk params back to V27.27 levels (conservative). No equity curve trading system exists yet.

---

## 2. KELLY SIZING LOGIC — Current State

### 2A. Multiple Kelly Implementations (PROBLEM: 4 separate systems)

The EA has **4 different Kelly implementations** that can conflict:

1. **`CalculateKellyFraction()` (line 3653)** — Phase 5 static Kelly
   - Uses hardcoded default win/loss ratios per strategy index (0-6 only)
   - Half-Kelly (0.5x multiplier)
   - Clamped: 0.01 to 0.50 (1%-50% of account) — **dangerously wide upper bound**
   - Only covers 7 strategies (indices 0-6), new strategies (9003-9006) have no defaults

2. **`GetKellyLotSize()` (line 5055)** — V18.0 Manhattan Dynamic Sizing
   - Uses hardcoded `winRate = 0.65`, `avgWin = 50.0`, `avgLoss = 40.0`
   - Quarter Kelly (0.25x)
   - Capped at 5% equity
   - **Never actually reads real stats** — always uses defaults

3. **`GetLotSize_Ascension()` (line 3539)** — Project Ascension Engine
   - Uses hardcoded `winRate = 0.7922`, `oddsRatio = 3.81`
   - 25% Fractional Kelly
   - Has compounding modes (Aggressive/Capital Preservation)
   - **Not used by most strategies** — called only from specific paths

4. **`CalculateRollingKelly()` (line 14354)** — V27.19 Dynamic Performance-Based (THE GOOD ONE)
   - Uses actual rolling 60-trade circular buffer per strategy
   - Three-Quarter Kelly (0.75x) — TITAN upgrade from 0.5x
   - Clamped: 0.5% to 10%
   - Calculates real win rate, avg win/loss, profit factor, Sharpe proxy
   - Drives dynamic tier caps based on rolling PF

### 2B. What MoneyManagement_Quantum() Actually Does (line 12829)

This is the **primary lot sizing function** called by all strategies. It:
1. Looks up strategy index from magic number
2. Gets dynamic tier cap from `g_stratDynamicMaxMult[]` (if ≥10 trades) or falls back to hardcoded caps
3. Applies V27.8 adaptive risk unwind multiplier (loss: *=0.8, win: *=1.1)
4. Applies V27.19 heat-based scaling (linear interpolation: `0.25 + heat * 1.75`)
5. Uses Kelly fraction as risk% if ≥15 trades (blended: 80% Kelly + 20% base)
6. Final risk% capped at 3.0% (TITAN, was 2.0%)
7. Combined multiplier capped at 3.0x
8. DD-based reduction: 5%+ DD → 75% size, 8%+ DD → 50% size
9. Equity-based lot cap (scales with account size)
10. Max loss per trade: $800 (TITAN, was $500)

### 2C. Key Risk Parameters (TITAN)

| Parameter | Value | Notes |
|-----------|-------|-------|
| InpBase_Risk_Percent | 2.0% | TITAN: raised from 1.5% |
| InpBase_Risk_Percent_H1 | 0.4% | H1 strategies |
| InpMaxTotalRisk_Percent | 25.0% | IMPERATOR: raised from 12% |
| InpMaxRiskPerTrade | 2.0% | IMPERATOR: raised from 0.8% |
| InpLeviathan_KellyFraction | 0.35 | TITAN: raised from 0.25 |
| InpLeviathan_MaxRisk | 7.0% | TITAN: raised from 5% |
| InpReaper_InitialLot | 0.18 | TITAN: raised from 0.12 |
| InpReaper_BasketTP | $75 | AGGRESSIVE |
| InpReaper_BasketTP_Money | $900 | TITAN: raised from $400 |
| MaxLossPerTrade | $800 | TITAN: raised from $500 |

---

## 3. MEAN REVERSION FILTERS — Current State

### 3A. ExecuteMeanReversionModelV8_6() (line 6084) — Legacy Mean Reversion
- Runs on H4 only
- Uses Hurst Exponent for regime-adaptive band stretch:
  - Hurst < 0.50: PRIME_REVERTING (BB 1.8, RSI 65/35)
  - Hurst 0.40-0.60: RANDOM_NOISE (BB 2.2, RSI 70/30)
  - Hurst > 0.60: TRENDING_SNIPER (BB 3.5, RSI 80/20)
- V24 adaptive thresholds with empirical probability (if InpAlphaExpand=true)
- V25 continuous scoring override (if InpElasticScoring=true)
- **GetStrategySpecificRisk() returns 0.0 for MeanReversion (line 4481-4482)** — effectively DEAD TIER, gets zero allocation

### 3B. ExecuteDivergenceMR() (line 9345) — V28.00 New Strategy (Magic: 9004)
- **TITAN-specific filters:**
  - ADX < 40 (raised from 30 — allows fading moderate trends)
  - Hurst < 0.50 (raised from 0.40 — allows mild trends)
  - BB Dev 1.5 (reduced from 2.0 — more overextension signals)
  - RSI oversold < 35 / overbought > 65 (relaxed from strict divergence)
  - Up to 3 concurrent trades (was 1)
- **Issue**: "Divergence" detection is NOT actual divergence — it's just RSI < 35 or RSI > 65
- **Issue**: BB overextension check uses Close[1] (previous bar), not current
- **Issue**: Uses `MoneyManagement_Quantum()` with base 2.0% risk, maxMultiplier = 1.0 (conservative)
- **Lot sizing**: 1.0x multiplier (unproven strategy, conservative default)

---

## 4. SESSION MOMENTUM FILTERS — Current State

### ExecuteSessionMomentum() (line 9267) — Magic: 9003
- **TITAN-specific parameters:**
  - Time: 6-20 UTC (extended from 8-18 — covers Asian→NY handoff)
  - ADX > 15 (lowered from 20 — more breakouts)
  - Lookback: 4 bars (16-hour range, tighter from 6 bars)
  - Up to 2 concurrent trades (was 1)
- **Entry logic**: Close breaks above/below London session high/low
- **Directional bias filter**: Requires alignment with `CheckDirectionalBias()`
- **SL/TP**: ATR-based (1.5x SL, 3.0x TP = 2:1 R:R)
- **Lot sizing**: `MoneyManagement_Quantum()` with base 2.0%, maxMultiplier = 1.5x

### Issues:
1. The "London session range" is calculated from H4 bars (1-4), which is actually 16 hours, not London-specific
2. No volume confirmation for breakout validity
3. No retest/rejection logic (aggressive breakout entry)
4. Time filter uses server time minus offset — can be wrong if broker settings change

---

## 5. HEAT SCORE SYSTEM — Current State

### CalculateHeatScore() (line 14451)
- 5-component weighted score:
  - PF Score (30%): Tiered 0-1 based on rolling PF
  - Win Rate Score (15%): `min(wr / 0.75, 1.0)`
  - Kelly Score (25%): `min(kelly / 0.05, 1.0)`
  - Sharpe Score (15%): `min(max(sharpe, 0) / 2.0, 1.0)`
  - Streak Momentum (15%): Recent 10-trade win rate
- EWMA smoothed: 70% old + 30% new
- Maps to risk scaling: `0.25 + (heat * 1.75)` = range 0.25x to 2.0x
- **Only calculates for strategies with index 0-16**

### Issue:
- Heat score arrays are sized `[17]` but `CalculateHeatScore()` checks `idx >= 17`
- New strategies (9003-9006) get correct indices via `GetStrategyIndexByMagic()` but the circular buffer `g_stratProfits[15][60]` is only sized for 15 strategies — potential buffer overflow for indices 15-16

---

## 6. CODE-LEVEL OPTIMIZATION OPPORTUNITIES

### 6A. CRITICAL: Redundant/Conflicting Kelly Systems
- **4 separate Kelly calculations** exist — some use hardcoded stats, some use real data
- `GetKellyLotSize()` and `GetLotSize_Ascension()` appear to be dead code (not called by main strategies)
- **Fix**: Remove unused Kelly functions, consolidate into single `CalculateRollingKelly()` → `MoneyManagement_Quantum()` pipeline

### 6B. CRITICAL: Array Size Mismatch
- `g_stratProfits[15][60]` — only 15 strategy slots
- `g_stratHeatScore[17]`, `g_stratKellyFraction[17]`, `g_stratDynamicMaxMult[17]` — 17 slots
- `g_stratTotalTrades[17]` — 17 slots
- If strategies with indices 15-16 exist, `g_stratProfits` will overflow
- **Fix**: Change `g_stratProfits` to `[17][60]`

### 6C. HIGH: Hardcoded Win Rate in GetLotSize_Ascension()
- Line 3547: `winRate = 0.7922` — hardcoded from "Silicon EA's proven stats"
- **Fix**: Use actual rolling stats or remove this function

### 6D. HIGH: DivergenceMR is Not Actually Divergence
- Lines 9377-9379: Just checks `rsi_1 < 35` (oversold) or `rsi_1 > 65` (overbought)
- No actual RSI divergence detection (price vs RSI direction disagreement)
- The name is misleading — should be called "RSI Overextension" or implement real divergence
- **Fix**: Implement actual divergence: compare price swing lows/highs with RSI swing lows/highs

### 6E. MEDIUM: SessionMomentum Breakout is Not Session-Specific
- Uses H4 bars 1-4 (16-hour lookback) regardless of actual session boundaries
- No London/NY session detection
- **Fix**: Use hourly data or M15 to define actual London session range

### 6F. MEDIUM: InpMaxTotalRisk_Percent = 25% is Very Aggressive
- Combined with 3.0x multiplier cap and $800 max loss per trade
- Could lead to significant drawdown in correlated losses
- **Consider**: More gradual risk scaling

### 6G. LOW: V29_00 Downgrades All Risk Parameters
- V29_00 reverts to conservative V27.27 levels (base risk 1.0%, max total 8%)
- V29_00 adds 4 new strategies (OrderBlock 9008, FVG 9007, ORB 9009, + Chandelier exit)
- V29_00 does NOT add equity curve trading

### 6H. LOW: SessionMomentum Time Filter Vulnerability
- `int utcHour = serverHour - InpServerUTCOffset;` — if serverHour < offset, utcHour goes negative and then `+= 24`
- This is handled but could cause unexpected behavior if offset is wrong

---

## 7. STRATEGY INVENTORY (TITAN)

| # | Strategy | Magic | Enabled | MaxMult | Status |
|---|----------|-------|---------|---------|--------|
| 0 | MeanReversion (legacy) | 777001 | true | 0.0 (DEAD) | Killed by GetStrategySpecificRisk() |
| 1 | QuantumOscillator | 777005 | true | - | Unknown |
| 2 | Titan (Kalman) | 666001/002 | true | 2.0x | Core strategy |
| 3 | Warden (Squeeze) | 777009 | true | 2.0x | Volatile tier |
| 4 | Phantom | 777010 | true | 1.5x | High PF |
| 5 | Nexus | 777011 | true | 2.0x | Compression |
| 6 | Microstructure | 999001 | true | 1.5x | M15 scalper |
| 7 | MathReversal | 999002 | false | - | V28.01: DISABLED |
| 8 | NoiseBreakout | 777012 | true | 1.5x | V27 |
| 9 | Vortex | 9001 | false | - | Disabled |
| 10 | RegimeShift | 9002 | false | - | Disabled |
| 11 | Reaper (Grid) | 888001/002 | true | 0.5x | Grid system |
| 12 | SessionMomentum | 9003 | true | 1.5x | V28.00 NEW |
| 13 | DivergenceMR | 9004 | true | 1.0x | V28.00 NEW |
| 14 | LiquiditySweep | 9005 | false | 0.5x | V28.00 CUT (PF 0.84) |
| 15 | StructuralRetest | 9006 | true | 1.0x | V28.03 NEW |
| 16 | Silicon-X | 984651 | true | 2.0x | Trap system |

---

## 8. WHAT'S DONE vs WHAT'S NEEDED

### DONE in V28.06 TITAN:
- ✅ Rolling Kelly per-strategy (60-trade window)
- ✅ Dynamic tier caps based on rolling PF
- ✅ Heat Score capital allocation (EWMA smoothed)
- ✅ DD-based lot reduction (5%/8% thresholds)
- ✅ Max loss per trade cap ($800)
- ✅ SessionMomentum breakout strategy
- ✅ DivergenceMR mean reversion strategy
- ✅ StructuralRetest breakout-retest strategy
- ✅ V23 empirical probability engine
- ✅ V24 adaptive entry thresholds
- ✅ V25 continuous scoring
- ✅ V26 MathReversal (disabled)

### EQUITY CURVE PATCH STATUS:
- ✅ **Patch file exists**: `/home/ubuntu/destroyer-quantum/equity_curve_trading_patch.mq4` (10.5KB)
- ✅ Patch is designed as a 5-step manual integration guide for V28.06 TITAN
- ✅ Implementation: EMA(20) of AccountEquity(), Bull 1.5x / Bear 0.5x lot multiplier
- ✅ Well-documented with safety bounds and parameter sensitivity analysis
- ❌ **NOT YET INTEGRATED into TITAN** — patch is standalone, needs manual application
- ❌ Patch only modifies `GetLotSizeV8_5_9_FIXED()` — but TITAN uses `MoneyManagement_Quantum()` for most strategies
- ❌ **Integration gap**: Equity curve mult should also apply in `MoneyManagement_Quantum()` (line 12829) where all V28.00+ strategies call

### OTHER NOT DONE / NEEDS WORK:
- ❌ Actual RSI divergence detection (current DivergenceMR is just oversold/overbought check)
- ❌ Session-specific range calculation (currently just H4 bars)
- ❌ Consolidation of 4 Kelly systems into 1
- ❌ Array size fix (15 vs 17 strategy slots)
- ❌ Real backtest validation of TITAN parameters

---

## 9. V29_00 vs V28_06_TITAN: KEY DIFFERENCES

| Aspect | V28.06 TITAN | V29.00 |
|--------|-------------|--------|
| Base Risk | 2.0% | 1.0% |
| Max Total Risk | 25.0% | 8.0% |
| Max Risk Per Trade | 2.0% | 0.5% |
| Reaper InitialLot | 0.18 | 0.08 |
| Reaper BasketTP | $75 | $50 |
| Reaper BasketTP_Money | $900 | $400 |
| New Strategies | SessionMomentum, DivergenceMR, StructuralRetest | OrderBlock (9008), FVG (9007), ORB (9009) |
| KillZone Filter | No | Yes (London 8-12, NY 13-17) |
| Chandelier Exit | No | Yes (22-period, 3x ATR) |
| Kelly Fraction | 0.75x (3/4 Kelly) | Presumably 0.5x (half Kelly) |

**V29.00 appears to be a more conservative base** with new ICT-style strategies. It does NOT implement equity curve trading.
