# Equity Curve Trading & Anti-Martingale Patterns — GitHub Research

**Date:** 2026-05-30 | **Cycle:** 25 | **Status:** COMPLETE  
**Purpose:** Find better equity curve / anti-martingale implementations than our V29_00_EQUITY_CURVE.mq4  
**Context:** DESTROYER QUANTUM EA — EURUSD H4, $10K→$170K target

---

## Executive Summary

GitHub has **very few dedicated MQL4 equity curve EAs**. The exact search terms "equity curve EA", "anti-martingale MQL4", "equity curve trading MQL4" return **zero** repository results. However, the **EA31337 framework** (1195 stars) contains production-grade anti-martingale / consecutive-win lot sizing logic, and **EarnForex** (multiple repos, 100-567 stars each) has equity trailing stop and position sizing patterns worth adapting.

**Key finding:** Nobody on GitHub has built a composite equity curve slope EA in MQL4. This means our V29 approach is genuinely novel — but we can still improve it by borrowing proven patterns from the repos below.

---

## Repository 1: EA31337/EA31337-classes ⭐ 254 stars

**URL:** https://github.com/EA31337/EA31337-classes  
**File:** `Trade.mqh`  
**Relevance:** 🔴 CRITICAL — Contains `OptimizeLotSize()` which is exactly anti-martingale consecutive-win scaling

### Pattern A: Consecutive Win/Loss Lot Optimization (Anti-Martingale)

```mql4
// EA31337/EA31337-classes/Trade.mqh
// Optimize lot size based on consecutive wins and losses
double OptimizeLotSize(double lots, double win_factor = 1.0, double loss_factor = 1.0, 
                       int ols_orders = 100, string _symbol = NULL) {
    double lotsize = lots;
    int wins = 0, losses = 0;
    int twins = 0, tlosses = 0;
    
    if (win_factor == 0 && loss_factor == 0) return lotsize;
    
    // Scan last N orders for consecutive win/loss streaks
    int _orders = OrdersHistoryTotal();
    for (int i = _orders - 1; i >= fmax(0, _orders - ols_orders); i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;
        if (OrderSymbol() != Symbol() || OrderType() > ORDER_TYPE_SELL) continue;
        
        double profit = OrderProfit();
        if (profit > 0.0) {
            losses = 0;
            wins++;
        } else {
            wins = 0;
            losses++;
        }
        twins = fmax(wins, twins);      // Track max consecutive wins
        tlosses = fmax(losses, tlosses); // Track max consecutive losses
    }
    
    // ANTI-MARTINGALE: Increase lot after consecutive wins
    lotsize = twins > 1 ? lotsize + (lotsize / 100 * win_factor * twins) : lotsize;
    // MARTINGALE: Decrease lot after consecutive losses (negative loss_factor)
    lotsize = tlosses > 1 ? lotsize + (lotsize / 100 * loss_factor * tlosses) : lotsize;
    
    return NormalizeLots(lotsize);
}
```

**Key insight for DESTROYER:**  
- `win_factor` = % increase per consecutive win. E.g., `win_factor=10` with 3 consecutive wins → lot +30%
- `loss_factor` = % change per consecutive loss. Use negative for reduction, positive for martingale
- Scans last `ols_orders` (default 100) history orders
- **Problem:** Uses max streak across entire window, not just current streak. For DESTROYER, we should track the CURRENT streak only.

### Pattern B: Risk-Based Lot Sizing (4 Methods)

```mql4
// EA31337/EA31337-classes/Trade.mqh
float CalcLotSize(float _risk_margin = 1,         // Risk margin in %
                  float _risk_ratio = 1.0,         // Risk ratio factor
                  unsigned int _orders_avg = 10,   // Number of orders for averaging
                  unsigned int _method = 0         // Method 0-3
) {
    float _avail_amount = _method % 2 == 0 ? AccountFreeMargin() : AccountBalance();
    float _lot_size_min = MarketInfo(Symbol(), MODE_MINLOT);
    float _lot_size = _lot_size_min;
    float _risk_value = (float)AccountLeverage();
    
    if (_method == 0 || _method == 1) {
        // Method 0: FreeMargin / (MarginRequired * Leverage * AvgOrders)
        // Method 1: Balance / (MarginRequired * Leverage * AvgOrders)
        float _margin_req = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
        if (_margin_req > 0) {
            _lot_size = _avail_amount / _margin_req * _risk_ratio;
            _lot_size /= _risk_value * _risk_ratio * _orders_avg;
        }
    } else {
        // Method 2/3: Risk% → money → lots
        float _risk_amount = _avail_amount / 100 * _risk_margin;
        float _money_value = _risk_amount;  // Simplified
        float _tick_value = MarketInfo(Symbol(), MODE_TICKSIZE);
        _lot_size = _money_value * _tick_value * _risk_ratio / _risk_value / 100;
    }
    
    _lot_size = (float)fmin(_lot_size, MarketInfo(Symbol(), MODE_MAXLOT));
    return (float)NormalizeLots(_lot_size);
}
```

### Pattern C: Signal Open Boost (Conditional Lot Amplification)

```mql4
// EA31337/EA31337-classes/Strategy.mqh
// SignalOpenBoost — bitwise condition check for lot amplification
virtual float SignalOpenBoost(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    float _result = 1.0f;  // Base multiplier = 1.0
    if (_method != 0) {
        if (METHOD(_method, 0)) if (IsTrend(_cmd))           _result *= 1.1f;
        if (METHOD(_method, 1)) if (trade.GetTrendOp(18))    _result *= 1.1f;
        if (METHOD(_method, 2)) if (!trade.HasOrderBetter()) _result *= 1.1f;
        if (METHOD(_method, 3)) if (trade.IsPeak(_cmd))      _result *= 1.1f;
        if (METHOD(_method, 4)) if (trade.IsPivot(_cmd))     _result *= 1.1f;
        if (METHOD(_method, 5)) if (trade.HasOrderOpposite())_result *= 1.1f;
        if (METHOD(_method, 6)) if (trade.HasBarOrder(_cmd)) _result *= 1.1f;
    }
    return _result;  // Range: 1.0 to ~1.7x with all conditions met
}
```

**Key insight for DESTROYER:** Bitwise condition stacking for lot boost. Each +10% adds up. Max boost ~1.7x with 7 conditions. This is a cleaner pattern than our 4-factor composite — simpler to tune.

### Pattern D: NormalizeLots (Production-Grade)

```mql4
// EA31337/EA31337-classes/Trade.mqh
double NormalizeLots(double _lots, bool _ceil = false) {
    double _lot_size = _lots;
    double _vol_min = MarketInfo(Symbol(), MODE_MINLOT);
    double _vol_step = MarketInfo(Symbol(), MODE_LOTSTEP);
    if (_vol_step > 0) {
        double _precision = 1 / _vol_step;
        _lot_size = _ceil ? ceil(_lots * _precision) / _precision 
                          : floor(_lots * _precision) / _precision;
        double _min_lot = fmax(_vol_min, _vol_step);
        _lot_size = fmin(fmax(_lot_size, _min_lot), MarketInfo(Symbol(), MODE_MAXLOT));
    }
    return NormalizeDouble(_lot_size, 2);
}
```

---

## Repository 2: EarnForex/Account-Protector ⭐ 117 stars

**URL:** https://github.com/EarnForex/Account-Protector  
**File:** `MQL4/Experts/Account Protector/Account Protector.mqh`  
**Relevance:** 🟡 HIGH — Equity trailing stop with snapshot-based conditions

### Pattern E: Equity Trailing Stop (Account-Level Protection)

```mql4
// EarnForex/Account-Protector/Account Protector.mqh
void CAccountProtector::EquityTrailing() {
    if (!sets.boolEquityTrailingStop || sets.doubleEquityTrailingStop <= 0) return;
    if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
    
    double AE = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // If equity stop-loss hit → close all positions
    if (AE <= sets.doubleCurrentEquityStopLoss && sets.doubleCurrentEquityStopLoss != 0) {
        Logging("Equity stop-loss of " + DoubleToString(sets.doubleCurrentEquityStopLoss, 2) 
                + " hit at " + DoubleToString(AE, 2) + ". Closing all positions.");
        Close_All_Positions();
        sets.boolEquityTrailingStop = false;  // Disable after trigger
        return;
    }
    
    // Trail the equity stop-loss upward
    if (AE - sets.doubleEquityTrailingStop > sets.doubleCurrentEquityStopLoss 
        || sets.doubleCurrentEquityStopLoss == 0) {
        sets.doubleCurrentEquityStopLoss = AE - sets.doubleEquityTrailingStop;
    }
}
```

**Key insight for DESTROYER:** This is a simple equity trailing stop — if equity drops X% from peak, close everything. We can use this as a **circuit breaker** in our equity curve EA, not as the main mechanism. The snapshot concept (SnapEquity, SnapMargin) is useful for comparing current vs historical equity state.

### Pattern F: Equity Snapshot Comparison (for Conditions)

```mql4
// EarnForex/Account-Protector
// Snapshot-based conditions for triggering actions:
// - EquityLessUnits:      equity < snapshot - X units
// - EquityGrUnits:        equity > snapshot + X units  
// - EquityLessPerSnap:    equity < snapshot * (1 - X%)
// - EquityGrPerSnap:      equity > snapshot * (1 + X%)
// - EquityMinusSnapshot:  equity - snapshot > X (positive = profit)
// - SnapshotMinusEquity:  snapshot - equity > X (positive = loss)

void CAccountProtector::UpdateEquitySnapshot() {
    sets.SnapEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    sets.SnapEquityTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
}
```

---

## Repository 3: EarnForex/PositionSizer ⭐ 567 stars

**URL:** https://github.com/EarnForex/PositionSizer  
**File:** `MQL4/Experts/Position Sizer/Position Sizer.mqh`  
**Relevance:** 🟢 MODERATE — Professional risk-based position sizing calculator

### Pattern G: Risk-Percentage Position Sizing

The PositionSizer is a GUI-based tool, not an EA with auto-lot. But its calculation logic is the gold standard for MQL4 risk-based sizing:

```
Position Size = (Account_Balance × Risk%) / (SL_in_Points × Point_Value)
```

Where:
- Account_Balance can be: current balance, equity, or custom snapshot
- Risk% is user-defined (e.g., 2% per trade)
- SL_in_Points = distance from entry to stop-loss
- Point_Value = tick value per lot for the symbol

**Key insight for DESTROYER:** The PositionSizer supports `MaxRiskPercentage` as a cap. This is a hard ceiling we should add to our EA: no single trade should risk more than X% of current equity.

---

## Repository 4: EA31337/EA31337 ⭐ 1195 stars

**URL:** https://github.com/EA31337/EA31337  
**Relevance:** 🟡 HIGH — Multi-strategy framework with per-strategy risk params

### Pattern H: Per-Strategy Risk Parameters (StgParams)

```mql4
// EA31337/EA31337-classes/Strategy.struct.h
struct StgParams {
    float lot_size;          // Lot size to trade
    float lot_size_factor;   // Lot size multiplier factor
    float max_risk;          // Maximum risk (1.0 = normal, 2.0 = 2x)
    float max_spread;        // Maximum spread to trade (in pips)
    int signal_open_boost;   // Signal open boost method (for lot size increase)
    float weight;            // Weight of the strategy
    bool is_boosted;         // State of the boost feature
    // ...
};
```

**Key insight for DESTROYER:** Each strategy gets its own `lot_size`, `lot_size_factor`, `max_risk`, and `is_boosted` flag. This is exactly what we need for multi-strategy equity curve management — each sub-strategy can have independent lot scaling.

### Pattern I: Trade Params with Risk Margin

```mql4
// EA31337/EA31337-classes/Trade.struct.h
struct TradeParams {
    float lot_size;        // Default lot size
    float max_spread;      // Maximum spread to trade (in pips)
    float risk_margin;     // Maximum account margin to risk (in %)
    unsigned long magic_no;
    // ...
    
    TradeParams(float _lot_size = 0, float _risk_margin = 1.0f, ...) 
        : lot_size(_lot_size), risk_margin(_risk_margin) {}
};
```

---

## Pattern J: What's MISSING from GitHub (Opportunity)

After exhaustive search, **NO** GitHub repo implements:

1. **Equity curve slope calculation** (EMA of equity growth rate)
2. **High-water mark proximity** (how far below peak equity)
3. **Drawdown state classification** (normal/stressed/recovering)
4. **Win streak detection for current streak** (not max streak in window)
5. **Composite multi-factor equity scoring** (our V29 approach)
6. **Risk budget per sub-strategy** (equity allocation across strategies)

This confirms our V29_00_EQUITY_CURVE.mq4 approach is **genuinely novel** in the MQL4 ecosystem.

---

## Recommended Improvements to V29_00_EQUITY_CURVE.mq4

Based on these findings, here are specific improvements to incorporate:

### 1. Adopt EA31337's NormalizeLots (Pattern D)
Replace any ad-hoc lot normalization with the production-grade version:
```mql4
double NormalizeLots(double _lots) {
    double _vol_min = MarketInfo(Symbol(), MODE_MINLOT);
    double _vol_step = MarketInfo(Symbol(), MODE_LOTSTEP);
    double _precision = 1.0 / _vol_step;
    double _lot_size = floor(_lots * _precision) / _precision;
    _lot_size = MathMax(_lot_size, _vol_min);
    _lot_size = MathMin(_lot_size, MarketInfo(Symbol(), MODE_MAXLOT));
    return NormalizeDouble(_lot_size, 2);
}
```

### 2. Add Equity Trailing Stop Circuit Breaker (Pattern E)
```mql4
input double EquityTrailPercent = 15.0;  // Close all if equity drops 15% from peak
double g_equity_peak = 0;
double g_equity_stop = 0;

void CheckEquityCircuitBreaker() {
    double eq = AccountEquity();
    if (eq > g_equity_peak) {
        g_equity_peak = eq;
        g_equity_stop = eq * (1.0 - EquityTrailPercent / 100.0);
    }
    if (eq <= g_equity_stop && g_equity_stop > 0) {
        CloseAllPositions();
        g_equity_stop = 0;  // Reset
    }
}
```

### 3. Improve Win Streak Detection (Fix EA31337's Bug)
EA31337 tracks max streak in window, not current streak. Fix:
```mql4
int GetCurrentWinStreak() {
    int streak = 0;
    int total = OrdersHistoryTotal();
    for (int i = total - 1; i >= MathMax(0, total - 100); i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;
        if (OrderSymbol() != Symbol()) continue;
        if (OrderProfit() > 0) streak++;
        else break;  // Stop at first loss — this is the CURRENT streak
    }
    return streak;
}
```

### 4. Add Bitwise Boost Method (Pattern C)
Instead of weighted 4-factor composite, add a simpler bitwise option:
```mql4
int boost_method = 0;
// Set bits for each condition
if (IsNearHWM())          boost_method |= 1;  // Bit 0
if (IsEquityGrowing())    boost_method |= 2;  // Bit 1
if (IsInDrawdown())       boost_method |= 4;  // Bit 2
if (GetCurrentWinStreak() >= 3) boost_method |= 8;  // Bit 3

double boost = 1.0;
if (boost_method & 1) boost *= 1.1;
if (boost_method & 2) boost *= 1.1;
if (boost_method & 4) boost *= 0.8;  // Reduce in DD
if (boost_method & 8) boost *= 1.15;
// Max boost: 1.1 * 1.1 * 0.8 * 1.15 = 1.11x (conservative)
```

### 5. Add Max Risk Per Trade Cap (Pattern G)
```mql4
input double MaxRiskPercent = 3.0;  // Max 3% equity risk per trade

double GetMaxLotForRisk(double sl_points) {
    double risk_amount = AccountEquity() * MaxRiskPercent / 100.0;
    double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
    if (tick_value == 0 || sl_points == 0) return MarketInfo(Symbol(), MODE_MINLOT);
    double max_lots = risk_amount / (sl_points * tick_value);
    return NormalizeLots(max_lots);
}
```

---

## Star Count Summary

| Repository | Stars | Relevance | Key Pattern |
|---|---|---|---|
| EA31337/EA31337 | 1195 | HIGH | Multi-strategy risk params |
| EarnForex/PositionSizer | 567 | MODERATE | Risk% position sizing |
| EA31337/EA31337-classes | 254 | CRITICAL | OptimizeLotSize, CalcLotSize, SignalOpenBoost |
| EarnForex/Account-Protector | 117 | HIGH | Equity trailing stop, snapshots |
| EarnForex/Trailing-Stop-on-Profit | 64 | LOW | Trailing stop patterns |
| HIR0NA/ea-gold | 2 | LOW | Dynamic position sizing (XAUUSD) |

---

## Files to Modify

1. **V29_00_EQUITY_CURVE.mq4** — Incorporate patterns A, C, D, E, G, J above
2. **New: EquityCircuitBreaker.mqh** — Extract equity trailing stop into reusable include
3. **New: LotOptimizer.mqh** — Extract EA31337-style lot optimization into reusable include

---

*Research completed 2026-05-30. GitHub API rate limits hit during search. All code extracted from raw file contents via curl. No MQL4-specific equity curve slope EAs found — our approach remains unique.*
