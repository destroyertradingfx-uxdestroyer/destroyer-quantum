# Equity Curve Trading Research - GitHub MQL4 Implementations
## Search Results Summary (2026-05-30)

### KEY FINDING: EA31337 Framework (⭐1195)
**Repo:** https://github.com/EA31337/EA31337
**Classes:** https://github.com/EA31337/EA31337-classes

The most comprehensive open-source MQL4/MQL5 framework with equity curve and adaptive position sizing. Key code patterns extracted:

---

## 1. OptimizeLotSize() - Anti-Martingale by Win/Loss Streaks
**Source:** EA31337-classes/Trade.mqh

```mql4
double OptimizeLotSize(double lots, double win_factor = 1.0, double loss_factor = 1.0, 
                       int ols_orders = 100, string _symbol = NULL) {
    double lotsize = lots;
    int wins = 0, losses = 0;
    int twins = 0, tlosses = 0;
    
    if (win_factor == 0 && loss_factor == 0) return lotsize;
    
    int _orders = TradeHistoryStatic::HistoryOrdersTotal();
    for (int i = _orders - 1; i >= fmax(0, _orders - ols_orders); i--) {
        if (Order::OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false) break;
        if (Order::OrderSymbol() != Symbol() || Order::OrderType() > ORDER_TYPE_SELL) continue;
        double profit = OrderStatic::Profit();
        
        if (profit > 0.0) {
            losses = 0;
            wins++;
        } else {
            wins = 0;
            losses++;
        }
        twins = fmax(wins, twins);
        tlosses = fmax(losses, tlosses);
    }
    
    // ANTI-MARTINGALE: Increase lot on winning streaks
    lotsize = twins > 1 ? lotsize + (lotsize / 100 * win_factor * twins) : lotsize;
    // MARTINGALE: Increase lot on losing streaks (negative loss_factor = decrease)
    lotsize = tlosses > 1 ? lotsize + (lotsize / 100 * loss_factor * tlosses) : lotsize;
    return NormalizeLots(lotsize);
}
```

**Key Parameters:**
- `win_factor = 1.0` → 1% lot increase per consecutive win
- `loss_factor = 1.0` → 1% lot increase per consecutive loss (set negative for anti-martingale)
- `ols_orders = 100` → Look back at last 100 orders

**Anti-Martingale Usage:** Set `win_factor = 2.0, loss_factor = -1.5`
- On 3 wins: lotsize * (1 + 0.06) = 6% increase
- On 3 losses: lotsize * (1 - 0.045) = 4.5% decrease

---

## 2. CalcLotSize() - Equity/Balance-Based Sizing
**Source:** EA31337-classes/Trade.mqh

```mql4
float CalcLotSize(float _risk_margin = 1,         // Risk margin in %
                  float _risk_ratio = 1.0,        // Risk ratio factor
                  unsigned int _orders_avg = 10,  // Number of orders for calculation
                  unsigned int _method = 0) {     // Method (0-3)
    float _avail_amount = _method % 2 == 0 ? account.GetMarginAvail() : account.GetTotalBalance();
    float _lot_size_min = (float)GetChart().GetVolumeMin();
    float _lot_size = _lot_size_min;
    float _risk_value = (float)account.GetLeverage();
    
    if (_method == 0 || _method == 1) {
        float _margin_req = GetMarginRequired();
        if (_margin_req > 0) {
            _lot_size = _avail_amount / _margin_req * _risk_ratio;
            _lot_size /= _risk_value * _risk_ratio * _orders_avg;
        }
    } else {
        float _risk_amount = _avail_amount / 100 * _risk_margin;
        float _money_value = Convert::MoneyToValue(_risk_amount, _lot_size_min, GetChart().GetSymbol());
        float _tick_value = GetChart().GetTickSize();
        _lot_size = _money_value * _tick_value * _risk_ratio / _risk_value / 100;
    }
    _lot_size = (float)fmin(_lot_size, GetChart().GetVolumeMax());
    return (float)NormalizeLots(_lot_size);
}
```

**Methods:**
- Method 0: Free margin / margin required / leverage / orders_avg
- Method 1: Total balance / margin required / leverage / orders_avg
- Method 2: Free margin with risk amount calculation
- Method 3: Total balance with risk amount calculation

---

## 3. Equity-Based Task Conditions (EA31337 Advanced Mode)
**Source:** EA31337/src/include/common/enum.h + advanced/inputs.mqh

Equity curve triggers for automated actions:
```mql4
enum ENUM_EA_ADV_COND {
    EA_ADV_COND_TRADE_EQUITY_GT_01PC,     // Equity > 1% above init
    EA_ADV_COND_TRADE_EQUITY_GT_02PC,     // Equity > 2% above init
    EA_ADV_COND_TRADE_EQUITY_GT_05PC,     // Equity > 5% above init
    EA_ADV_COND_TRADE_EQUITY_GT_10PC,     // Equity > 10% above init
    EA_ADV_COND_TRADE_EQUITY_LT_01PC,     // Equity < 1% below init
    EA_ADV_COND_TRADE_EQUITY_LT_02PC,     // Equity < 2% below init
    EA_ADV_COND_TRADE_EQUITY_LT_05PC,     // Equity < 5% below init
    EA_ADV_COND_TRADE_EQUITY_LT_10PC,     // Equity < 10% below init
    EA_ADV_COND_TRADE_EQUITY_GT_RMARGIN,  // Equity > Risk margin
    EA_ADV_COND_TRADE_EQUITY_LT_RMARGIN,  // Equity < Risk margin
};

enum ENUM_EA_ADV_ACTION {
    EA_ADV_ACTION_CLOSE_MOST_LOSS,              // Close order with most loss
    EA_ADV_ACTION_CLOSE_MOST_PROFIT,            // Close order with most profit
    EA_ADV_ACTION_ORDERS_CLOSE_ALL,             // Close all active orders
    EA_ADV_ACTION_ORDERS_CLOSE_IN_PROFIT,       // Close orders in profit
    EA_ADV_ACTION_ORDERS_CLOSE_IN_TREND,        // Close orders in trend
    EA_ADV_ACTION_ORDERS_CLOSE_SIDE_IN_LOSS,    // Close orders in loss side
    EA_ADV_ACTION_ORDERS_CLOSE_SIDE_IN_PROFIT,  // Close orders in profit side
};
```

**Default Task Configuration (Advanced mode):**
```mql4
// Task 1: If equity > 5%, close all orders
EA_Task1_If = EA_ADV_COND_TRADE_EQUITY_GT_05PC;
EA_Task1_Then = EA_ADV_ACTION_ORDERS_CLOSE_ALL;

// Task 2: If equity > risk margin, close most profitable
EA_Task2_If = EA_ADV_COND_TRADE_EQUITY_GT_RMARGIN;
EA_Task2_Then = EA_ADV_ACTION_CLOSE_MOST_PROFIT;

// Task 3: If equity < 2%, close most profitable
EA_Task3_If = EA_ADV_COND_TRADE_EQUITY_LT_02PC;
EA_Task3_Then = EA_ADV_ACTION_CLOSE_MOST_PROFIT;
```

---

## 4. SummaryReport - Drawdown & Streak Tracking
**Source:** EA31337-classes/SummaryReport.mqh

Key metrics tracked for equity curve analysis:
```mql4
double max_dd;           // Maximum drawdown in money
double max_dd_pct;       // Maximum drawdown in %
double rel_dd_pct;       // Relative drawdown %
double rel_dd;           // Relative drawdown in money
double profit_factor;    // Gross profit / gross loss
int con_profit_trades1;  // Max consecutive wins count
int con_loss_trades1;    // Max consecutive losses count
int avg_con_wins;        // Average consecutive wins
int avg_con_losses;      // Average consecutive losses
```

---

## 5. Risk Parameters (Optimization Set File)
**Source:** EA31337/sets/optimize/Advanced/risk/MarginMax.set

```
EA_Risk_MarginMax,1=5    // Risk margin param 1: 5
EA_Risk_MarginMax,2=5    // Risk margin param 2: 5
EA_Risk_MarginMax,3=20   // Risk margin param 3: 20
EA_Risk_MarginMax,F=1    // Enabled
```

---

## 6. Meta Strategy Types (EA31337)
```mql4
STRAT_META_EQUITY,             // (Meta) Equity - equity curve based strategy
STRAT_META_MARTINGALE,         // (Meta) Martingale - martingale sizing
STRAT_OSCILLATOR_MARTINGALE,   // Oscillator Martingale - oscillator + martingale
STRAT_META_RISK,               // (Meta) Risk - risk management meta strategy
STRAT_META_MARGIN,             // (Meta) Margin - margin-based strategy
```

---

## RECOMMENDED IMPLEMENTATION FOR DESTROYER QUANTUM EA

Based on EA31337 patterns, here's the optimal equity curve anti-martingale approach:

### Pattern A: Win/Loss Streak Sizing (from EA31337)
```mql4
input double EC_WinFactor = 2.0;      // % lot increase per consecutive win
input double EC_LossFactor = -1.5;    // % lot decrease per consecutive loss
input int    EC_LookbackTrades = 20;  // Trades to analyze
input double EC_MaxLotMultiplier = 2.5; // Maximum lot multiplier
input double EC_MinLotMultiplier = 0.5; // Minimum lot multiplier

double GetEquityCurveLot(double baseLot) {
    int wins = 0, losses = 0, maxWins = 0, maxLosses = 0;
    
    for (int i = OrdersHistoryTotal() - 1; i >= MathMax(0, OrdersHistoryTotal() - EC_LookbackTrades); i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;
        if (OrderSymbol() != Symbol() || OrderType() > OP_SELL) continue;
        
        if (OrderProfit() > 0) { losses = 0; wins++; }
        else { wins = 0; losses++; }
        maxWins = MathMax(wins, maxWins);
        maxLosses = MathMax(losses, maxLosses);
    }
    
    double multiplier = 1.0;
    if (maxWins > 1) multiplier += (EC_WinFactor / 100.0 * maxWins);
    if (maxLosses > 1) multiplier += (EC_LossFactor / 100.0 * maxLosses);
    
    multiplier = MathMax(multiplier, EC_MinLotMultiplier);
    multiplier = MathMin(multiplier, EC_MaxLotMultiplier);
    
    return NormalizeDouble(baseLot * multiplier, 2);
}
```

### Pattern B: Equity % Based Sizing (from EA31337)
```mql4
input double EC_EquityGrowthTarget = 5.0;  // % growth to trigger action
input double EC_DrawdownThreshold = 2.0;   // % drawdown to reduce size

double GetEquityBasedLot(double baseLot) {
    double equityPctChange = (AccountEquity() - AccountBalance()) / AccountBalance() * 100;
    
    if (equityPctChange > EC_EquityGrowthTarget) {
        // Equity growing - increase size (anti-martingale)
        return NormalizeDouble(baseLot * 1.5, 2);
    } else if (equityPctChange < -EC_DrawdownThreshold) {
        // Equity declining - reduce size
        return NormalizeDouble(baseLot * 0.6, 2);
    }
    return baseLot;
}
```

### RECOMMENDED PARAMETERS FOR $32K GAP BRIDGE:
- **Win Factor:** 2.0-3.0% per consecutive win
- **Loss Factor:** -1.0 to -2.0% per consecutive loss  
- **Lookback:** 20-50 trades
- **Max Multiplier:** 2.0-3.0x base lot
- **Min Multiplier:** 0.3-0.5x base lot
- **Equity Growth Trigger:** 3-5% above balance
- **Drawdown Trigger:** 2-3% below balance

---

## SEARCH LIMITATIONS
- GitHub code search returned 0 results for most MQL4 equity curve queries
- MQL4/.mq4 files are poorly indexed by GitHub search
- No repos found with verified PF > 2.0 backtest results specifically for equity curve trading
- EA31337 is the most comprehensive framework found (1195★) but no specific PF claims in repo
- Most equity curve implementations are embedded within larger EA frameworks, not standalone
