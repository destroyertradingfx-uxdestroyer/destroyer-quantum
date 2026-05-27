# DESTROYER QUANTUM V28.06 TITAN — Technical Analysis
## Lot Sizing Pipeline & Equity Curve Amplification Injection Points

**Date:** 2026-05-26  
**File:** `/home/ubuntu/destroyer-quantum/code/DESTROYER_QUANTUM_V28_06_TITAN.mq4`  
**Lines:** 14,522 total  
**Purpose:** Map the end-to-end lot sizing pipeline and identify where equity-curve-based amplification can be injected.

---

## 1. LOT SIZING PIPELINE — END-TO-END FLOW

There are **three distinct lot sizing engines** in V28.06 TITAN, used by different strategies:

### Engine A: `MoneyManagement_Quantum()` (Line 12829)
**Used by:** SessionMomentum (9003), DivergenceMR (9004), LiquiditySweep (9005), StructuralRetest (9006), MeanReversion, Warden, NoiseBreakout, Apex, Phantom, Nexus, Vortex, RegimeShift, Chronos

```
Input: magicNumber, baseRiskPercent, stopLossPips
  │
  ├─ 1. High-PF Floor (Line 12839-12844)
  │     Phantom/Warden/Titan → baseRiskPercent = max(baseRiskPercent, 1.5%)
  │
  ├─ 2. Dynamic Tier Cap (Line 12849-12873)
  │     If g_stratTotalTrades[idx] >= 10:
  │       maxMultiplier = g_stratDynamicMaxMult[idx]  ← from rolling PF
  │     Else (fallback hardcoded):
  │       Reaper=0.5x, Warden/SX/Titan=2.0x, SessionMomentum=1.5x,
  │       DivergenceMR=1.0x, LiquiditySweep=0.5x, StructuralRetest=1.0x
  │
  ├─ 3. Adaptive Risk Unwind (Line 12876-12878)
  │     adaptiveMultiplier = min(g_strategyMultiplier[idx], maxMultiplier)
  │     g_strategyMultiplier: starts 1.0, *= 1.1 on win, *= 0.8 on loss (Lines 14318/14325)
  │     Clamped: [0.2, 3.0]
  │
  ├─ 4. Heat-Based Risk Scaling (Line 12885-12894)
  │     heatMultiplier = 0.25 + (g_stratHeatScore[idx] * 1.75)
  │     Clamped: [0.25, 2.0]
  │
  ├─ 5. Kelly Risk Override (Line 12901-12911)
  │     If g_stratTotalTrades[idx] >= 15:
  │       effectiveRiskPercent = (kellyFrac * 100 * 0.8) + (baseRiskPercent * 0.2)
  │       Clamped: [0.1%, 3.0%]
  │     Else: effectiveRiskPercent = baseRiskPercent
  │
  ├─ 6. Combined Multiplier (Line 12920)
  │     combinedMultiplier = min(adaptiveMultiplier * heatMultiplier, 3.0)
  │
  ├─ 7. DD-Based Lot Reduction (Line 12922-12925)
  │     DD >= 8%: combinedMultiplier *= 0.5
  │     DD >= 5%: combinedMultiplier *= 0.75
  │
  ├─ 8. Final Lot Calculation (Line 12927-12931)
  │     riskAmount = equity * ((effectiveRiskPercent * combinedMultiplier) / 100)
  │     rawLots = riskAmount / (stopPips * tickValue)
  │
  ├─ 9. Equity-Based Lot Cap (Line 12938-12942)
  │     equity < $5K: cap 1.0 lot
  │     equity < $10K: cap 2.0 lots
  │     equity < $25K: cap 3.5 lots
  │     else: cap = InpMaxLotSize (15.0)
  │
  └─ 10. Max Loss Per Trade Cap (Line 12946-12948)
        maxLotsForMaxLoss = $800 / (stopPips * tickValue)
        finalLots = min(finalLots, maxLotsForMaxLoss)
```

### Engine B: `Leviathan_GetDynamicLotSize()` (Line 7563)
**Used by:** Titan strategy only (Lines 8915, 8951)

```
Input: stopLossPips
  │
  ├─ 1. Scan last 50 closed trades for ALL strategies (Line 7576-7590)
  │     Calculate: winRate, avgWin, avgLoss from real history
  │
  ├─ 2. Raw Kelly Fraction (Line 7597-7602)
  │     kelly_f = ((oddsRatio * winRate) - (1 - winRate)) / oddsRatio
  │
  ├─ 3. Base Risk (Line 7604)
  │     baseRiskPercent = kelly_f * g_leviathan_kellyFraction * 100
  │     g_leviathan_kellyFraction = 0.25 (Line 1497)
  │
  ├─ 4. Confidence Multiplier (Line 7607-7612)
  │     Win streak >= 3: +10% per additional win
  │     Loss streak >= 2: -15% per additional loss
  │     Clamped: [0.5, 2.0]
  │
  ├─ 5. Final Risk (Line 7615-7618)
  │     finalRiskPercent = baseRiskPercent * confidenceMultiplier
  │     Clamped: [g_leviathan_minRisk(0.5%), g_leviathan_maxRisk(5.0%)]
  │
  └─ 6. Lot Calculation (Line 7625-7637)
        lotSize = riskAmount / (stopPips * pipValuePerLot)
```

### Engine C: `GetNextReaperLotSize()` (Line 7529)
**Used by:** Reaper grid strategy exclusively

```
Input: level (grid level number)
  │
  ├─ Level 1: return InpReaper_InitialLot (0.18)
  └─ Level N: InpReaper_InitialLot * InpReaper_LotMultiplier^(N-1)
               InpReaper_LotMultiplier = 1.4
               Hardcap: InpReaper_HardcapLevels = 8
```

---

## 2. EXISTING EQUITY CURVE LOGIC

There is **no dedicated equity-curve-based lot amplification system**. However, there are several related components:

### 2a. Queen Bee Status (Line 5588)
- Tracks `g_high_watermark_equity` (persistent via GlobalVariable)
- Calculates `g_current_drawdown` as % from HWM
- Sets `g_hive_state`: GROWTH or DEFENSIVE (threshold: `InpDefensiveDD_Percent`)
- `QueenBee_GlobalRiskCheck()` (Line 5640): Kill switches at DD thresholds

### 2b. ManageDrawdownExposure_V2 (Line 4367)
- **Level 1** (5-8% DD): Reduce lot sizing by 25%
- **Level 2** (8-10% DD): Reduce lot sizing by 50%
- **Level 3** (10-12% DD): Stop new trades, trim positions > 0.5 lots
- **Level 4** (>12% DD): Emergency trim ALL positions > 0.1 lots
- Sets `g_ddProtectionActive` flag (blocks entries in OnNewBar)

### 2c. Hades Equity Curve Optimization (Line 10257-10286)
- Only affects **exit timing**, not entry sizing
- `Hades_ShouldTakeEarlyProfit()`: Takes profit early if closing would push equity to new HWM
- Smooths equity curve by locking in gains at 70%+ of target

### 2d. Ascension Engine Performance Scaling (Line 3564-3577)
- Win streak boost: +15% (3 wins), +30% (5 wins)
- Equity growth boost: +10% (50% growth), +20% (100% growth)
- DD penalty: *= 0.7 if DD > 3%
- Loss streak penalty: *= 0.6 if 2+ consecutive losses
- **Note:** This appears to be a legacy function, not called by current strategies

### 2e. DD-Based Lot Reduction in MoneyManagement_Quantum (Line 12922-12925)
- DD >= 5%: combinedMultiplier *= 0.75
- DD >= 8%: combinedMultiplier *= 0.5

---

## 3. MEAN REVERSION (Line 6084)

**Magic:** `InpMagic_MeanReversion` (777001)  
**Lot Engine:** `MoneyManagement_Quantum()`

### Entry Conditions:
1. H4 timeframe only
2. Strategy enabled + healthy (`IsStrategyHealthy`)
3. Not in DEFENSIVE hive state (unless `InpMR_Allow_Defensive`)
4. Reaper condition filter (optional): RSI outside 45-55, BB width > 10 pips
5. Market conditions + time filters pass
6. **Regime-adaptive bands** based on Hurst Exponent:
   - H < 0.50: PRIME_REVERTING (BB dev 1.8, RSI 35/65)
   - H 0.50-0.60: RANDOM_NOISE (BB dev 2.2, RSI 30/70)
   - H > 0.60: TRENDING_SNIPER (BB dev 3.5, RSI 20/80)
7. ADX < 50 (hard stop) + `IsTrendTooStrong()` (ADX > 30 with volume)
8. `Filter_CounterTrend()` + `IsMeanReversionSafe()`
9. Signal conviction >= 4.5 + multi-timeframe confirmation + TQS check
10. V24/V25: Elastic scoring override (continuous scores replace binary gates)

### Lot Sizing (Line 6369):
```mql4
int atr_stop_pips_mr = GetATRStopLossPips();  // ATR * 1.5, clamped [15, 100]
double lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, atr_stop_pips_mr);
```

### Exit: ATR-based SL (1.5x ATR), TP at 2.2x SL distance

---

## 4. SESSION MOMENTUM (Line 9267)

**Magic:** `InpSessionMomentum_MagicNumber` (9003)  
**Lot Engine:** `MoneyManagement_Quantum()`

### Entry Conditions:
1. H4 timeframe, enabled, healthy
2. Max 2 concurrent trades (TITAN: expanded from 1)
3. Time filter: UTC 06:00-20:00 (TITAN: expanded from 08:00-18:00)
4. Directional bias check
5. London session range: lookback 4 H4 bars (TITAN: tightened from 6)
6. ADX > threshold (`InpSessionMomentum_ADX_Threshold`, default 15)
7. **BUY:** Close breaks above londonHigh
8. **SELL:** Close breaks below londonLow

### Lot Sizing (Line 9312):
```mql4
double lots = MoneyManagement_Quantum(InpSessionMomentum_MagicNumber, InpBase_Risk_Percent);
```
**Note:** No stopLossPips passed → defaults to 50 pips (Line 12930)

### Exit: ATR-based SL/TP using `InpSessionMomentum_ATR_SL_Mult` / `ATR_TP_Mult`

---

## 5. DIVERGENCE MEAN REVERSION (Line 9345)

**Magic:** `InpDivergenceMR_MagicNumber` (9004)  
**Lot Engine:** `MoneyManagement_Quantum()`

### Entry Conditions:
1. H4 timeframe, enabled, healthy
2. Max 3 concurrent trades (TITAN: expanded from 1)
3. Directional bias check
4. ADX < `InpDivergenceMR_ADX_Max` (TITAN: 40, raised from 30)
5. Hurst Exponent < `InpDivergenceMR_Hurst_Threshold` (TITAN: 0.50, lowered from 0.55)
6. RSI oversold (< 35) for bullish divergence (TITAN: relaxed from strict divergence)
7. RSI overbought (> 65) for bearish divergence
8. Price at BB lower/upper band (deviation 1.5, TITAN: tightened from 2.0)

### Lot Sizing (Line 9390):
```mql4
double lots = MoneyManagement_Quantum(InpDivergenceMR_MagicNumber, InpBase_Risk_Percent);
```
**Note:** No stopLossPips passed → defaults to 50 pips

### Exit: ATR-based SL/TP using `InpDivergenceMR_ATR_SL_Mult` / `ATR_TP_Mult`

---

## 6. QUEEN BEE / GRID EXPOSURE LIMITS

### QueenBee_AllowsStrategy() (Line 5731)
- Global kill switch: `g_queen_kill_all` blocks everything
- Reaper-specific kill: `g_queen_kill_reaper`
- Exposure limit: `g_queen_total_exposure_lots >= InpQueen_MaxExposureLots` blocks new grid entries for Reaper/SX

### QueenBee_GlobalRiskCheck() (Line 5640)
- Calculates DD% from balance vs equity
- Level 1 kill: DD >= `InpQueen_MaxDrawdownPct` → `g_queen_kill_all = true`
- Reset when DD recovers to 50% of threshold
- Exposure tracking: sums lots for all magic numbers

### Reaper Grid Limits:
- Hardcap: `InpReaper_HardcapLevels = 8` levels per direction
- ATR-based grid spacing: `atr * InpReaper_ATR_GridMult` (min 15 pips, max 200 pips)
- Cooldown: `InpReaper_CooldownBars` between levels
- Regime suppression: ADX > `InpReaper_RegimeADX` with opposing trend
- Trend brake: ADX > 35 with >= 4 levels → stop expansion
- Trinity Guard: blocks if another grid strategy is active
- Basket TP: $900 (TITAN: raised from $400)
- Per-level TP: 1.5x ATR profit per level

---

## 7. INJECTION POINTS FOR EQUITY-CURVE-BASED AMPLIFICATION

### Priority 1: MoneyManagement_Quantum() — Central Hub (Line 12829)

**This is the single best injection point.** 12+ strategies flow through this function.

#### Injection Point A: After Kelly Risk Override, Before Combined Multiplier
**Location:** Line 12911 → after `effectiveRiskPercent` is computed, before `combinedMultiplier`

```mql4
// EXISTING (Line 12901-12911):
double effectiveRiskPercent = baseRiskPercent;
if(idx >= 0 && idx < 17 && g_stratTotalTrades[idx] >= 15)
{
   double kellyFrac = g_stratKellyFraction[idx];
   effectiveRiskPercent = (kellyFrac * 100.0 * 0.8) + (baseRiskPercent * 0.2);
   effectiveRiskPercent = MathMax(effectiveRiskPercent, 0.1);
   effectiveRiskPercent = MathMin(effectiveRiskPercent, 3.0);
}

// >>> INJECT EQUITY CURVE MULTIPLIER HERE <<<
// After Line 12911, before Line 12917
double equityCurveMult = CalculateEquityCurveMultiplier();
effectiveRiskPercent *= equityCurveMult;
effectiveRiskPercent = MathMin(effectiveRiskPercent, 4.0);  // New safety cap
```

#### Injection Point B: After Combined Multiplier, Before Final Calculation
**Location:** Line 12920 → after `combinedMultiplier` is computed

```mql4
// EXISTING (Line 12920):
double combinedMultiplier = MathMin(adaptiveMultiplier * heatMultiplier, 3.0);

// >>> INJECT HERE <<<
combinedMultiplier *= equityCurveMult;  // Amplify when equity curve is strong
combinedMultiplier = MathMin(combinedMultiplier, 5.0);  // Raise cap from 3.0 to 5.0
```

#### Injection Point C: Override DD-Based Lot Reduction (Line 12922-12925)
**Replace the static DD penalties with equity-curve-aware logic:**

```mql4
// EXISTING:
if(ddPercent >= 8.0) combinedMultiplier *= 0.5;
else if(ddPercent >= 5.0) combinedMultiplier *= 0.75;

// >>> REPLACE WITH <<<
double ecMult = CalculateEquityCurveMultiplier();
if(ecMult > 1.5) {
   // Strong equity curve: relax DD penalties
   if(ddPercent >= 10.0) combinedMultiplier *= 0.5;
   else if(ddPercent >= 7.0) combinedMultiplier *= 0.75;
} else if(ecMult < 0.8) {
   // Weak equity curve: tighten DD penalties
   if(ddPercent >= 6.0) combinedMultiplier *= 0.5;
   else if(ddPercent >= 4.0) combinedMultiplier *= 0.75;
} else {
   // Normal: keep existing
   if(ddPercent >= 8.0) combinedMultiplier *= 0.5;
   else if(ddPercent >= 5.0) combinedMultiplier *= 0.75;
}
```

### Priority 2: Leviathan_GetDynamicLotSize() — Titan Engine (Line 7563)

#### Injection Point D: After Confidence Multiplier (Line 7612)
```mql4
// EXISTING (Line 7612):
confidenceMultiplier = MathMax(0.5, MathMin(2.0, confidenceMultiplier));

// >>> INJECT HERE <<<
double equityCurveMult = CalculateEquityCurveMultiplier();
confidenceMultiplier *= equityCurveMult;
confidenceMultiplier = MathMax(0.3, MathMin(3.0, confidenceMultiplier));
```

### Priority 3: Ascension Engine Performance Scaling (Line 3564)

#### Injection Point E: Equity Growth Boost (Line 3570-3572)
```mql4
// EXISTING:
double equityGrowth = (AccountEquity() - 10000) / 10000;
if(equityGrowth > 1.0) scalingFactor += 0.2;
else if(equityGrowth > 0.5) scalingFactor += 0.1;

// >>> REPLACE WITH equity-curve-aware version <<<
double equityCurveMult = CalculateEquityCurveMultiplier();
scalingFactor *= equityCurveMult;
```

### Priority 4: New Global Function — `CalculateEquityCurveMultiplier()`

**Recommended implementation (inject near Line 5055, after GetKellyLotSize):**

```mql4
//+------------------------------------------------------------------+
//| EQUITY CURVE AMPLIFICATION ENGINE                                 |
//| Returns: 0.5 (weak curve) to 2.5 (strong curve)                  |
//| Logic: Measures equity curve health via HWM proximity,            |
//|        rolling returns, and drawdown state                        |
//+------------------------------------------------------------------+
double CalculateEquityCurveMultiplier()
{
   double equity = AccountEquity();
   double balance = AccountBalance();
   
   // FACTOR 1: HWM Proximity (how close to all-time high)
   double hwmProximity = 1.0;
   if(g_high_watermark_equity > 0)
   {
      hwmProximity = equity / g_high_watermark_equity;  // 1.0 = at HWM, 0.9 = 10% below
   }
   
   // FACTOR 2: Rolling Equity Growth Rate
   // Compare current equity to equity N trades ago
   static double equitySamples[20] = {0};
   static int equitySampleIdx = 0;
   static datetime lastSampleTime = 0;
   
   // Sample equity once per day
   datetime today = iTime(Symbol(), PERIOD_D1, 0);
   if(today > lastSampleTime)
   {
      equitySamples[equitySampleIdx % 20] = equity;
      equitySampleIdx++;
      lastSampleTime = today;
   }
   
   double growthRate = 1.0;
   if(equitySampleIdx >= 5)
   {
      int oldestIdx = (equitySampleIdx - 10) % 20;
      if(oldestIdx < 0) oldestIdx += 20;
      double oldestEquity = equitySamples[oldestIdx];
      if(oldestEquity > 0)
      {
         growthRate = equity / oldestEquity;  // >1.0 = growing, <1.0 = shrinking
      }
   }
   
   // FACTOR 3: Drawdown State (inverse — lower DD = higher multiplier)
   double ddFactor = 1.0;
   if(g_current_drawdown > 10.0) ddFactor = 0.5;
   else if(g_current_drawdown > 5.0) ddFactor = 0.7;
   else if(g_current_drawdown > 2.0) ddFactor = 0.85;
   else if(g_current_drawdown < 1.0) ddFactor = 1.2;  // Near HWM = boost
   
   // FACTOR 4: Win Streak Momentum
   double streakFactor = 1.0;
   if(g_consecutiveWins >= 5) streakFactor = 1.3;
   else if(g_consecutiveWins >= 3) streakFactor = 1.15;
   else if(g_consecutiveLosses >= 3) streakFactor = 0.6;
   else if(g_consecutiveLosses >= 2) streakFactor = 0.8;
   
   // COMPOSITE: Weighted combination
   double composite = (hwmProximity * 0.3) + (growthRate * 0.3) + (ddFactor * 0.25) + (streakFactor * 0.15);
   
   // Map to multiplier range [0.5, 2.5]
   // composite of 1.0 = neutral (1.0x multiplier)
   // composite of 1.3+ = strong curve (1.5x+ multiplier)
   // composite of 0.7- = weak curve (0.5x-0.7x multiplier)
   double multiplier = MathMax(0.5, MathMin(2.5, composite));
   
   return multiplier;
}
```

---

## 8. SUMMARY TABLE

| Strategy | Magic | Lot Engine | Current Base Risk | Stop Loss Source | Injection Point |
|----------|-------|------------|-------------------|------------------|-----------------|
| MeanReversion | 777001 | MM_Quantum | 2.0% | ATR*1.5 [15,100] pips | A, B, C |
| SessionMomentum | 9003 | MM_Quantum | 2.0% | Default 50 pips | A, B, C |
| DivergenceMR | 9004 | MM_Quantum | 2.0% | Default 50 pips | A, B, C |
| LiquiditySweep | 9005 | MM_Quantum | 2.0% | Default 50 pips | A, B, C |
| StructuralRetest | 9006 | MM_Quantum | 2.0% | Default 50 pips | A, B, C |
| Titan | N/A | Leviathan | Kelly-based | ATR*1.2 | D |
| Reaper Buy | 888001 | GetNextReaper | Fixed 0.18 lots | None (basket) | N/A (grid) |
| Reaper Sell | 888002 | GetNextReaper | Fixed 0.18 lots | None (basket) | N/A (grid) |
| Warden | N/A | MM_Quantum | 2.0% (floor 1.5%) | ATR-based | A, B, C |
| NoiseBreakout | 777012 | MM_Quantum | 2.0% | Default 50 pips | A, B, C |

---

## 9. KEY OBSERVATIONS

1. **No equity curve amplification exists.** The system only has drawdown-based *reduction* (penalty when losing). There is no mechanism to amplify when winning.

2. **MoneyManagement_Quantum is the central bottleneck.** 12+ strategies flow through it. One injection point here affects all of them.

3. **SessionMomentum and DivergenceMR pass no stopLossPips** — they default to 50 pips. This means their lot sizes are not ATR-adaptive. Consider passing actual ATR stops.

4. **Reaper grid is isolated** — it uses its own geometric progression and doesn't benefit from Kelly/Heat/EquityCurve systems.

5. **The Leviathan engine (Titan) uses a different Kelly calculation** than MoneyManagement_Quantum. Titan's Kelly scans ALL strategy history; MM_Quantum uses per-strategy rolling data.

6. **DD-based lot reduction is already in MoneyManagement_Quantum** (Lines 12922-12925). The equity curve amplifier should work *alongside* this, not replace it.

7. **The `g_strategyMultiplier` adaptive unwind** (win *= 1.1, loss *= 0.8) is a crude form of performance-based scaling. An equity curve multiplier would be a more sophisticated version of this concept.

8. **InpMaxTotalRisk_Percent = 25%** (Line 1159) — very high. The equity curve amplifier should respect this ceiling.

9. **InpMaxLotSize = 15.0** (Line 1154) — per-trade lot cap. Equity curve amplification should not bypass this.

10. **SessionMomentum and DivergenceMR are the highest-value injection targets** — they're new strategies with high projected PF but conservative fallback allocations (1.5x and 1.0x maxMultiplier). Equity curve amplification could dynamically raise these when the system is hot.
