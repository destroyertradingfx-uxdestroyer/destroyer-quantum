# Volatility-Adaptive Position Sizing — GitHub Research Report
**Date:** 2026-05-26
**Purpose:** Find MQL4/MQL5 implementations of volatility-adaptive sizing for DESTROYER QUANTUM EA ($10K→$170K target)

---

## Summary

Searched GitHub for MQL4/MQL5 volatility-adaptive position sizing implementations across 5 query categories. Found 8 relevant repos with extractable code patterns. Key finding: **most MQL implementations use simple ATR-based stop-loss distance to compute risk-based lot size**, but few implement true inverse-volatility scaling or regime-adaptive sizing. The most sophisticated examples combine ADX regime detection with ATR-based adaptive thresholds.

---

## FINDINGS BY CATEGORY

### 1. ATR-Based Dynamic Lot Sizing (Scales Inversely with Volatility)

#### 📌 EarnForex/PositionSizer ⭐566
- **URL:** https://github.com/EarnForex/PositionSizer
- **Language:** MQL5
- **Description:** The gold standard MT4/MT5 position sizer. 566 stars. GUI-based EA that calculates lot size from risk %, account balance, and SL distance.
- **Key Code Patterns:**
  - Core formula: `lot_size = (account_balance × risk_percent) / (SL_distance_in_points × point_value_per_lot)`
  - Supports Balance, Equity, and Balance-Risk as account basis
  - Entry types: Instant, Pending, StopLimit
  - Volume share modes: Equal, Decreasing, Increasing (for multi-entry)
  - SL can be set from candle high/low (previous or current)
- **Sizing Formula:**
  ```
  riskMoney = AccountBalance × RiskPercent / 100
  slPoints = |Entry - SL| / Point
  lotSize = riskMoney / (slPoints × TickValue / TickSize)
  ```
- **Relevance to DESTROYER:** This is the foundational pattern. The ATR inverse scaling is NOT directly in this EA — it computes lots from a fixed SL. To get inverse-vol scaling, we set SL = ATR × multiplier, which makes lot size automatically inversely proportional to ATR.

#### 📌 leionion/dynamic-position-sizer-atr-calculator ⭐19
- **URL:** https://github.com/leionion/dynamic-position-sizer-atr-calculator
- **Language:** Python (reference implementation)
- **Description:** ATR-based position sizing calculator with portfolio risk cap. Clean architecture.
- **Key Code Patterns:**
  ```python
  stop_distance = atr * atr_multiplier  # If no explicit SL given
  max_risk_amount = account_balance * risk_percent
  risk_per_unit = stop_distance * tick_value
  raw_units = max_risk_amount / risk_per_unit
  raw_lot_size = raw_units / contract_size
  ```
  - **Portfolio Risk Cap:** Tracks cumulative open risk as fraction of account (e.g., 3% max total). Rejects new trades when cap reached.
  - **Rounding:** Floor/Ceil/Round to lot step with rejection if below min lot.
- **Sizing Formula:**
  ```
  stop_distance = ATR × ATR_multiplier
  lots = (Balance × Risk%) / (stop_distance / tick_size × tick_value)
  ```
- **Relevance to DESTROYER:** Portfolio risk cap is critical for $10K→$170K — prevents over-leveraging across multiple correlated positions.

#### 📌 GuillaumeGirard90/AverageTrueRangePositionSizing ⭐1
- **URL:** https://github.com/GuillaumeGirard90/AverageTrueRangePositionSizing
- **Language:** Jupyter Notebook (Python)
- **Description:** Educational ATR position sizing for volatile stocks. Clean formulas.
- **Key Code Pattern:**
  ```
  Position Size = (Account × Risk%) / (ATR × ATR_Multiplier × Dollar_Per_Point)
  ```
- **Relevance:** Validates the universal formula pattern.

---

### 2. Regime Detection (ADX/ATR Combined — Trending vs Ranging)

#### 📌 KVignesh122/MT5-SMC-trading-bot ⭐51
- **URL:** https://github.com/KVignesh122/MT5-SMC-trading-bot
- **Language:** MQL5
- **Description:** Smart Money Concepts EA with **dual regime detection methods** (ADX or Efficiency Ratio), ATR-adaptive thresholds, session filtering, and equity "bagging" risk controls.
- **Key Code Patterns:**

  **Regime Detection — Method 1: ADX**
  ```mql5
  enum ENUM_REGIME { REGIME_ADX=0, REGIME_EFFICIENCY=1 };
  
  bool IsTrendingMarket() {
      if(RegimeMethod == REGIME_ADX) {
          double buffer[1];
          CopyBuffer(adx_handle, 0, 1, 1, buffer);
          return buffer[0] >= 18.0;  // ADX > 18 = trending
      } else {
          return CalculateEfficiencyRatio(30) >= 0.30;
      }
  }
  ```

  **Regime Detection — Method 2: Efficiency Ratio (Kaufman)**
  ```mql5
  double CalculateEfficiencyRatio(int periods) {
      double start = iClose(_Symbol, _Period, periods);
      double end   = iClose(_Symbol, _Period, 1);
      double netMove = MathAbs(end - start);
      double totalMove = 0;
      for(int i = periods; i > 1; i--) {
          totalMove += MathAbs(iClose(_Symbol, _Period, i-1) - iClose(_Symbol, _Period, i));
      }
      return (totalMove > 0) ? netMove / totalMove : 0.0;
  }
  ```

  **ATR-Adaptive Thresholds:**
  ```mql5
  double CalculateAdaptiveThreshold(string type) {
      double atr = GetATR(1);
      double volatility = atr / SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(type == "displacement") {
          return MathMax(1.2, 1.8 - volatility * 100); // Lower threshold in high vol
      }
      else if(type == "fvg_gap") {
          return MathMax(0.10, 0.20 - volatility * 50); // Smaller gaps OK in high vol
      }
  }
  ```

  **Position Sizing:**
  ```mql5
  double CalculateLotSize() {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double lots = LotPerK * (balance / 1000.0);  // 0.02 lots per $1000
      // clamp to min/max/step
  }
  ```

  **ATR-Based SL/TP:**
  ```mql5
  slDistance = 1.5 * atr;
  tpDistance = 2.5 * atr;  // 1.67 R:R
  ```

  **Equity Bagging (Risk Control):**
  ```mql5
  profitThreshold = balance * (1.0 + BagProfitPercent/100.0);  // +8%
  lossThreshold   = balance * (1.0 - BagLossPercent/100.0);    // -4%
  if(equity >= profitThreshold || equity <= lossThreshold) CloseAllTrades();
  ```

- **Relevance to DESTROYER:** This is the **most directly useful repo**. It has:
  1. Dual regime detection (ADX + Efficiency Ratio) ✅
  2. ATR-adaptive thresholds that change with volatility ✅
  3. ATR-based SL/TP ✅
  4. Equity bagging for catastrophic loss prevention ✅
  5. Session filtering (skip Asian) ✅
  **Missing:** True inverse-vol lot sizing (current is flat LotPerK). The DESTROYER should combine this regime detection with inverse-ATR lot scaling.

#### 📌 badalgoverdhan911/Trend-Following-EA-MQL5 ⭐0
- **URL:** https://github.com/badalgoverdhan911/Trend-Following-EA-MQL5
- **Language:** MQL5 (compiled .ex5 only — no source)
- **Description:** Trend-following EA with **ADX + ATR dual volatility gates**, Supertrend entries, RSI confirmation, and prop-firm risk management.
- **Key Strategy Patterns (from docs):**
  - **Volatility Gate 1 — ADX:** `ADX > 25` required. Below 25 = "ranging" = skip trade.
  - **Volatility Gate 2 — ATR Min:** `ATR > ATR_MinVolatility` required. Ensures market isn't flat.
  - **SL/TP:** Both set as `ATR × Multiplier` (default 2×ATR)
  - **Trailing Stop:** ATR-based. Trigger at `ATR_Trail_Trigger` distance, trail at `ATR_Trail_Mult`.
  - **Prop Firm Rules:** Daily loss 5%, max DD 10%, profit target halt.
  - **Dynamic Lot:** `lotSize = (balance × RiskPercent%) / (SL_distance_in_points × point_value)`
- **Relevance:** Validates the ADX > 25 + ATR > min dual-gate pattern. No source code available but the strategy docs are excellent reference.

#### 📌 kamleshmehrajr/forex-regime-detector ⭐1
- **URL:** https://github.com/kamleshmehrajr/forex-regime-detector
- **Language:** Python (HMM-based)
- **Description:** Hidden Markov Model regime detector for G10 forex. Classifies into Trending/Ranging/Volatile regimes.
- **Key Patterns:**
  - **Features:** ATR, ADX, RSI, Bollinger Band Width, Autocorrelation
  - **Regime → Strategy Mapping:**
    - Trending → Momentum follow, 100% position size
    - Ranging → Mean reversion (RSI fade), 70% position size
    - Volatile → Flat (no trades), 0% position size
  - **Results:** Sharpe improved from 0.7 → 1.4, Max DD from -18% → -11%
- **Relevance:** The regime→sizing mapping is the key insight for DESTROYER. Scale position size by regime confidence.

---

### 3. Volatility Breakout Strategies (Trade Only During Expanding Volatility)

#### 📌 yannis-montreer/MT5-EA-London-Volatility-Capture-LVC-EA ⭐0
- **URL:** https://github.com/yannis-montreer/MT5-EA-London-Volatility-Capture-LVC-EA
- **Language:** MQL5
- **Description:** Asia-range → London breakout EA on XAUUSD. Full ATR-based volatility filtering.
- **Key Code Patterns:**

  **Range Size Filter (ATR-normalized):**
  ```mql5
  input double InpMinRangeATR = 0.50;  // Asia range must be ≥ 0.5× ATR
  input double InpMaxRangeATR = 2.00;  // Asia range must be ≤ 2.0× ATR
  
  bool RangeFiltersPass(double atr) {
      double rangeAtr = g_rangeSize / atr;
      return (rangeAtr >= InpMinRangeATR && rangeAtr <= InpMaxRangeATR);
  }
  ```

  **Breakout Confirmation (ATR-scaled):**
  ```mql5
  input double InpBreakoutDistanceATR = 0.50;  // Price must break 0.5×ATR above range
  input double InpBreakoutCandleATR   = 1.20;  // Breakout candle body ≥ 1.2×ATR
  ```

  **ATR-Based Risk Management:**
  ```mql5
  input double InpTrueBreakSL_ATR = 0.75;   // SL = 0.75×ATR
  input double InpTrueBreakTP_ATR = 2.00;   // TP = 2.0×ATR  (2.67 R:R)
  input double InpRetestSL_ATR    = 0.75;
  input double InpRetestTP_ATR    = 2.00;
  ```

  **Risk-Based Position Sizing:**
  ```mql5
  double ComputeVolumeFromRisk(double entry, double sl) {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double distance = MathAbs(entry - sl);
      double tickSize = GetTickSize();
      double tickValue = GetTickValue();
      double moneyPerLot = (distance / tickSize) * tickValue;
      double vol = riskMoney / moneyPerLot;
      // clamp to min/max/step
      return vol;
  }
  ```

  **Volatility Expansion Detection (Breakout Candle):**
  ```mql5
  // Breakout candle must have range >= BreakoutCandleATR × ATR
  double candleRange = high - low;
  bool isExpansion = (candleRange >= InpBreakoutCandleATR * atr);
  ```

  **Three Trade Types:**
  1. True Break — immediate breakout entry
  2. Retest — wait for pullback to broken level
  3. Reversal — failed breakout, fade the move

- **Relevance to DESTROYER:** Excellent volatility-expansion filtering. The Asia range sizing relative to ATR ensures we only trade when volatility is in the right zone. The three trade-type pattern (true break, retest, reversal) provides multiple entry opportunities from a single setup.

#### 📌 m-root/xliquidex_crypto_bot_tutorial ⭐1
- **URL:** https://github.com/m-root/xliquidex_crypto_bot_tutorial
- **Language:** Python
- **Description:** X-liquidex volatility/breakout EA using Range and Moving Averages. Impulsive/volatility/breakout strategy. (Source code not accessible — 404 on raw files.)

---

### 4. Additional Supporting Repos

#### 📌 Zrakt/MT5-Risk-Management-EA ⭐5
- **URL:** https://github.com/Zrakt/MT5-Risk-Management-EA
- **Language:** C#/MQL5
- **Description:** GUI risk management EA with lot calculation, risk/reward projection, risk gauge.
- **Key Formula:** `lotSize = (AccountBalance × RiskPercent) / (SL_Pips × PipValue)`

#### 📌 HIR0NA/ea-gold ⭐2
- **URL:** https://github.com/HIR0NA/ea-gold
- **Language:** MQL4/5
- **Description:** XAUUSD system with dynamic position sizing. (No source code in repo — README only.)

#### 📌 SkieLabs/mql5-institutional-risk-library ⭐0
- **URL:** https://github.com/SkieLabs/mql5-institutional-risk-library
- **Language:** MQL5
- **Description:** Professional risk management module. Dynamic position sizing, equity protection, volatility filters. (Repo contents inaccessible — likely private or empty.)

---

## KEY SIZING FORMULAS EXTRACTED

### Pattern 1: Basic ATR-Derived Lot Size (Most Common)
```mql5
// SL distance derived from ATR → lot size automatically inversely proportional to ATR
double atr = iATR(NULL, 0, 14, 1);
double sl_distance = atr * sl_multiplier;  // e.g., 1.5× ATR
double risk_money = AccountBalance() * risk_percent / 100.0;
double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
double tick_size  = MarketInfo(Symbol(), MODE_TICKSIZE);
double money_per_lot = (sl_distance / tick_size) * tick_value;
double lots = risk_money / money_per_lot;
lots = MathFloor(lots / lot_step) * lot_step;
lots = MathMax(min_lot, MathMin(max_lot, lots));
```

### Pattern 2: Explicit Inverse-Volatility Scaling (Rare — DESTROYER Target)
```mql5
// Scale lots directly by inverse of normalized ATR
double atr = iATR(NULL, 0, 14, 1);
double atr_normalized = atr / Close[1];  // ATR as % of price
double base_atr_pct = 0.01;              // 1% baseline ATR
double vol_scalar = base_atr_pct / atr_normalized;  // >1 in low vol, <1 in high vol
double base_lots = AccountBalance() / 10000.0 * 0.01;  // 0.01 lots per $10K
double lots = base_lots * vol_scalar;
// Clamp to limits
```

### Pattern 3: ADX-Regime Gated Sizing
```mql5
double adx = iADX(NULL, 0, 14, MODE_MAIN, 1);
double lots = CalculateBaseLots();

if(adx < 20) {
    lots *= 0.0;   // Ranging: no trades
} else if(adx < 25) {
    lots *= 0.5;   // Weak trend: half size
} else if(adx < 40) {
    lots *= 1.0;   // Normal trend: full size
} else {
    lots *= 1.3;   // Strong trend: slightly larger (momentum)
}
```

### Pattern 4: Volatility Expansion Filter (Breakout Only)
```mql5
double atr = iATR(NULL, 0, 14, 1);
double prev_atr = iATR(NULL, 0, 14, 5);  // 5 bars ago
double vol_expansion = atr / prev_atr;

if(vol_expansion < 1.0) return;  // Volatility contracting — skip

// Volatility expanding — trade with size proportional to expansion
double expansion_bonus = MathMin(vol_expansion, 2.0);  // Cap at 2×
lots *= expansion_bonus;
```

### Pattern 5: Dual ATR Gate (Asia Range Breakout)
```mql5
double range_size = asia_high - asia_low;
double atr = iATR(NULL, 0, 14, 1);
double range_atr_ratio = range_size / atr;

if(range_atr_ratio < 0.5) return;  // Range too tight — no breakout potential
if(range_atr_ratio > 2.0) return;  // Range too wide — already expanded

// Sweet spot: trade the breakout
double breakout_candle_range = High[1] - Low[1];
if(breakout_candle_range < 1.2 * atr) return;  // Breakout candle not impulsive enough
```

---

## SYNTHESIS: DESTROYER QUANTUM INTEGRATION PLAN

### What DESTROYER Currently Has (Kelly Sizing)
- Kelly criterion for optimal f based on win rate and payoff ratio
- No volatility adaptation — same sizing in calm and volatile markets

### What DESTROYER Needs (Volatility-Adaptive Layer)
1. **Inverse-Vol Scaling (Pattern 2):** Scale Kelly lots inversely by ATR. Low vol = larger size (tighter stops), high vol = smaller size (wider stops). This is the highest-impact addition.

2. **Regime Detection (from MT5-SMC-bot):** Use ADX + Efficiency Ratio dual detection:
   - ADX > 25 OR EfficiencyRatio > 0.30 → Trending → full Kelly
   - ADX 18-25 OR ER 0.15-0.30 → Weak trend → 50% Kelly
   - ADX < 18 AND ER < 0.15 → Ranging → 0% or mean-revert mode

3. **Volatility Expansion Filter (from LVC EA):** Only take breakout trades when:
   - Current ATR > ATR_N bars ago (expanding vol)
   - Breakout candle range ≥ 1.2× ATR (impulsive move)
   - Asia range is 0.5-2.0× ATR (right volatility zone)

4. **Equity Bagging (from SMC-bot):** Close all at +8% equity / -4% equity per cycle. Prevents catastrophic drawdown on path to $170K.

5. **Portfolio Risk Cap (from dynamic-position-sizer):** Max 3% aggregate open risk. Prevents over-leveraging when multiple signals fire simultaneously.

### Recommended DESTROYER Sizing Formula
```mql5
// Step 1: Base Kelly lots
double kelly_f = (win_rate * avg_win - (1-win_rate) * avg_loss) / avg_win;
double base_lots = AccountBalance() * kelly_f / sl_distance;

// Step 2: Inverse-volatility scaling
double atr = iATR(NULL, 0, 14, 1);
double atr_pct = atr / iClose(NULL, 0, 1);
double baseline_atr_pct = 0.008;  // ~0.8% for EURUSD M15
double vol_scalar = baseline_atr_pct / atr_pct;  // Clamp 0.5-2.0
vol_scalar = MathMax(0.5, MathMin(2.0, vol_scalar));

// Step 3: Regime scaling
double adx = iADX(NULL, 0, 14, MODE_MAIN, 1);
double regime_scalar = 1.0;
if(adx < 18) regime_scalar = 0.0;       // No trades in ranging
else if(adx < 25) regime_scalar = 0.5;   // Half size in weak trend

// Step 4: Combine
double lots = base_lots * vol_scalar * regime_scalar;

// Step 5: Portfolio risk cap
double total_open_risk = CalculateOpenRiskPercent();
if(total_open_risk > 3.0) lots = 0;  // Max 3% aggregate
```

---

## FILES REFERENCED
- EarnForex/PositionSizer — `MQL5/Experts/Position Sizer/Position Sizer.mqh` (499KB main logic)
- KVignesh122/MT5-SMC-trading-bot — `EA_Script.mq5` (full source, 600+ lines)
- yannis-montreer/MT5-EA-London-Volatility-Capture-LVC-EA — `LVC_EA.mq5` (745 lines)
- leionion/dynamic-position-sizer-atr-calculator — `dynamic_position_sizer/calculator.py`
- badalgoverdhan911/Trend-Following-EA-MQL5 — `docs/strategy-explanation.md` (no source)
- kamleshmehrajr/forex-regime-detector — README (HMM architecture docs)

---

*Next action: Implement Pattern 2 (inverse-vol scaling) + Pattern 3 (ADX regime gating) into DESTROYER's existing Kelly framework.*
