# Adaptive Trailing Stop Research — GitHub Code Examples
**Date:** 2026-05-28
**Purpose:** Find new trailing stop approaches for DESTROYER QUANTUM EA (EURUSD H4)

---

## 1. CHANDELIER EXIT (MQL4/MQL5)

### Source: `drsuksaeng-cyber/FlashEASuite` — TrailingStop.mqh
**Repo:** https://github.com/drsuksaeng-cyber/FlashEASuite

This is a **5-method universal trailing stop module** with a clean class architecture. The Chandelier Exit implementation is production-ready:

```mql4
// Method 4: Chandelier Exit
// BUY:  Highest High(period) - ATR(atr_period) × mult
// SELL: Lowest Low(period)   + ATR(atr_period) × mult
double _CalcChandelier(int idx)
{
    int handle = m_records[idx].atr_handle;
    if(handle == INVALID_HANDLE) return 0.0;

    string sym = m_records[idx].symbol;
    ENUM_TIMEFRAMES tf = _GetPositionTimeframe(sym);
    int period = m_params.chandelier_period;  // default: 22 bars

    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    if(CopyBuffer(handle, 0, 0, 1, atr_buf) < 1) return 0.0;
    double atr = atr_buf[0];

    if(m_records[idx].pos_type == POSITION_TYPE_BUY)
    {
        double highest_high = 0.0;
        double high_buf[];
        ArraySetAsSeries(high_buf, true);
        if(CopyHigh(sym, tf, 0, period, high_buf) < period) return 0.0;
        highest_high = high_buf[ArrayMaximum(high_buf, 0, period)];
        return highest_high - atr * m_params.chandelier_mult;  // default: 3.0
    }
    else
    {
        double low_buf[];
        ArraySetAsSeries(low_buf, true);
        if(CopyLow(sym, tf, 0, period, low_buf) < period) return 0.0;
        double lowest_low = low_buf[ArrayMinimum(low_buf, 0, period)];
        return lowest_low + atr * m_params.chandelier_mult;
    }
}
```

**Key Parameters:**
- `chandelier_mult = 3.0` (ATR multiplier — the "rope length")
- `chandelier_period = 22` (lookback for highest high / lowest low)
- `chandelier_atr = 14` (ATR period)

**Adaptation for DESTROYER:** The chandelier naturally adapts to volatility — in high vol, ATR is wider so the stop sits further away. In low vol, the stop tightens. This is the core behavior we want.

---

## 2. ATR-BASED TRAILING STOP (MQL4)

### Source: `syarief02/BU_ATR_Breakeven_Engulfing` — BU_ATR_Breakeven_Engulfing.mq4
**Repo:** https://github.com/syarief02/BU_ATR_Breakeven_Engulfing

This is a complete MQL4 EA with **ATR trailing + breakeven + MA-based stop management**:

```mql4
// ATR Trailing Stop — MQL4 compatible
void ApplyATRTrailingStop(int atrPeriod, double atrMultiplier)
{
    double atrValue = iATR(Symbol(), 0, atrPeriod, 0) * atrMultiplier;
    int trailingPips = (int)(atrValue / Point);

    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            {
                double newStop;
                if (OrderType() == OP_BUY)
                {
                    newStop = NormalizeDouble(Bid - trailingPips * Point, Digits);
                    if (newStop > OrderStopLoss())
                    {
                        OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrNONE);
                    }
                }
                else if (OrderType() == OP_SELL)
                {
                    newStop = NormalizeDouble(Ask + trailingPips * Point, Digits);
                    if (newStop < OrderStopLoss())
                    {
                        OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrNONE);
                    }
                }
            }
        }
    }
}
```

**Breakeven + Trailing Combo:**
```mql4
// Two-phase approach: BE first, then ATR trail
void ApplyTrailingAndBreakeven(int breakevenPips, int trailingPips)
{
    MoveToBreakeven(breakevenPips);          // Phase 1: protect capital
    ApplyATRTrailingStop(ATRPeriod, ATRMultiplier);  // Phase 2: trail with ATR
}
```

**MA-Based Stop Management (additional layer):**
```mql4
void StopLossManagement()
{
    double ma_value = iMA(NULL, 0, 30, 0, MODE_SMA, PRICE_CLOSE, 0);
    double sl_diff = 12 * Point;

    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderType() == OP_BUY && Close[0] > ma_value)
            {
                double new_stop_loss_buy = ma_value - sl_diff;
                if (new_stop_loss_buy > OrderOpenPrice())
                    OrderModify(OrderTicket(), OrderOpenPrice(), new_stop_loss_buy, ...);
            }
        }
    }
}
```

---

## 3. VOLATILITY-BASED ADAPTIVE RISK/TRAILING

### Source: `meococ/ApexPullBack` — RiskOptimizer.mqh + Enums.mqh
**Repo:** https://github.com/meococ/ApexPullBack

This is the most sophisticated system found. Key features:

### Volatility Adjustment Factor (tighten in low vol, widen in high vol):
```mql4
double CRiskOptimizer::GetVolatilityAdjustmentFactorDetailed()
{
    double volatilityRatio = currentATR / m_AverageATR;
    
    // Low vol (< 0.8): SL/TP expand up to 1.2x
    if (volatilityRatio < 0.8) {
        adjustmentFactor = 1.0 + (0.8 - volatilityRatio) * 0.5;
        adjustmentFactor = MathMin(adjustmentFactor, 1.2);
    }
    // Normal vol (0.8-1.2): no adjustment
    // High vol (> 1.2): SL/TP tighten
    else if (volatilityRatio > 1.2) {
        if (volatilityRatio < 2.0) {
            adjustmentFactor = 1.0 - (volatilityRatio - 1.2) * 0.25;
        } else {
            adjustmentFactor = 0.5;  // extreme vol → very tight
        }
    }
    return adjustmentFactor;
}
```

### R-Multiple Trailing Phases:
```mql4
// Progressive trailing: tighter as profit grows
enum ENUM_TRAILING_PHASE {
    TRAILING_NONE,          // No trailing yet
    TRAILING_BREAKEVEN,     // At 1R → move to breakeven
    TRAILING_FIRST_LOCK,    // At 1.5R → lock 30% of profit
    TRAILING_SECOND_LOCK,   // At 2R → lock 50% of profit
    TRAILING_THIRD_LOCK     // At 3R → lock 70% of profit
};
```

### Chandelier Exit Config:
```mql4
void SetChandelierExit(bool useChande, int lookback, double atrMult)
{
    m_Config.UseChandelierExit = useChande;
    m_Config.ChandelierLookback = lookback;
    m_Config.ChandelierATRMultiplier = atrMult;
}
```

### Performance-Based Risk Adjustment (smoothed):
```mql4
// 6-factor weighted risk multiplier
m_CurrentRiskMultiplier = (performanceMultiplier * 0.25 + 
                          drawdownMultiplier * 0.3 +
                          volatilityMultiplier * 0.15 +
                          marketMultiplier * 0.1 +
                          brokerHealthMultiplier * 0.1 +
                          stabilityMultiplier * 0.1);

// EMA-style smoothing: 70% old + 30% new
m_CurrentRiskMultiplier = lastMultiplier * 0.7 + m_CurrentRiskMultiplier * 0.3;
```

### EURUSD H4 Specific Presets Found:
```mql4
enum ENUM_MARKET_PRESET {
    PRESET_EURUSD_H4_CONSERVATIVE,    // EURUSD H4 - Conservative
    PRESET_EURUSD_H4_STANDARD,        // EURUSD H4 - Standard
    PRESET_EURUSD_H4_AGGRESSIVE,      // EURUSD H4 - Aggressive
    ...
};
```

---

## 4. TIME-BASED TRAILING (Move to BE after X bars)

### Concept from FlashEASuite (adapted to MQL4):
```mql4
// NOT YET IMPLEMENTED — here's the MQL4 adaptation we should build:

// Time-based trailing: move to breakeven after X H4 bars
void TimeBasedTrailingStop(int magic, int barsToBreakeven, double beOffset)
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderMagicNumber() != magic || OrderSymbol() != Symbol()) continue;
        
        // Count bars since entry
        int barsSinceEntry = iBarShift(Symbol(), PERIOD_H4, OrderOpenTime(), false);
        
        if (barsSinceEntry >= barsToBreakeven)
        {
            double entryPrice = OrderOpenPrice();
            if (OrderType() == OP_BUY)
            {
                // Move SL to entry + small buffer after X bars
                double newSL = entryPrice + beOffset * Point;
                if (newSL > OrderStopLoss() && Bid > entryPrice)
                {
                    OrderModify(OrderTicket(), entryPrice, newSL, OrderTakeProfit(), 0, clrNONE);
                }
            }
            else if (OrderType() == OP_SELL)
            {
                double newSL = entryPrice - beOffset * Point;
                if (newSL < OrderStopLoss() && Ask < entryPrice)
                {
                    OrderModify(OrderTicket(), entryPrice, newSL, OrderTakeProfit(), 0, clrNONE);
                }
            }
        }
    }
}
```

---

## 5. RECOMMENDED COMPOSITE APPROACH FOR DESTROYER

### "Quantum Adaptive Trail" — 3-Phase System for EURUSD H4:

**Phase 1: Breakeven Protection (0-2 bars)**
- After 2 H4 bars (8 hours), if price has moved 1× ATR in our favor → move SL to breakeven + 2 pip buffer

**Phase 2: Chandelier Trail (2+ bars, below 2R profit)**
- Trail using: Highest High(22) - ATR(14) × 2.5
- In low vol (ATR < 0.8× average): tighten multiplier to 2.0
- In high vol (ATR > 1.2× average): widen multiplier to 3.0

**Phase 3: R-Multiple Lock (above 2R profit)**
- At 2R: lock 40% of unrealized profit
- At 3R: lock 60% of unrealized profit  
- At 4R: lock 80% of unrealized profit (aggressive trailing)

### MQL4 Implementation Skeleton:
```mql4
//--- Inputs
extern int    ATR_Period = 14;
extern double Chandelier_Mult = 2.5;
extern int    Chandelier_Lookback = 22;
extern int    BE_Bars = 2;        // Bars to wait before BE
extern double BE_ATR_Trigger = 1.0; // ATR multiples for BE trigger
extern double LowVol_Mult = 2.0;    // Tighter in low vol
extern double HighVol_Mult = 3.0;   // Wider in high vol
extern double R2_LockPercent = 40;
extern double R3_LockPercent = 60;
extern double R4_LockPercent = 80;

double AdaptiveATRMultiplier()
{
    double currentATR = iATR(Symbol(), 0, ATR_Period, 1);
    double avgATR = 0;
    for(int i = 1; i <= 20; i++) avgATR += iATR(Symbol(), 0, ATR_Period, i);
    avgATR /= 20.0;
    
    double ratio = currentATR / avgATR;
    
    if(ratio < 0.8)      return LowVol_Mult;   // Tighten in low vol
    else if(ratio > 1.3) return HighVol_Mult;   // Widen in high vol
    else                  return Chandelier_Mult; // Normal
}
```

---

## Files Researched
| Repo | File | What It Contains |
|------|------|-----------------|
| `drsuksaeng-cyber/FlashEASuite` | `TrailingStop.mqh` | 5-method trailing: Fixed, ATR, Parabolic SAR, Chandelier, Breakeven |
| `syarief02/BU_ATR_Breakeven_Engulfing` | `.mq4` | MQL4 ATR trailing + BE + MA stop management |
| `meococ/ApexPullBack` | `Enums.mqh` + `RiskOptimizer.mqh` | R-multiple phased trailing, volatility adaptation, chandelier config, EURUSD H4 presets |

## Profit Factor Note
None of the open-source repos publish profit factor > 2.0 backtest results directly. The ApexPullBack EA defines `PERFORMANCE_EXCELLENT` as PF > 2.0 as a monitoring threshold, suggesting it targets but doesn't guarantee that level. The chandelier + adaptive volatility approach is the most promising path to PF > 2.0 on EURUSD H4 because it lets winners run in calm markets and protects profits aggressively in volatile swings.
