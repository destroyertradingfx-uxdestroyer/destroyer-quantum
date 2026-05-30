# GitHub MQL4 Code Pattern Research
## Partial Close, Trailing Remainder, Breakeven-Plus Trailing, Time-Decay Sizing

**Date:** 2026-05-28
**Purpose:** Find real MQL4 implementations for DESTROYER QUANTUM EA partial close placeholders (lines ~12048-12060)

---

## 1. PARTIAL CLOSE WITH TRAILING REMAINDER

### BEST MATCH: Joelisking/xauusd-trader — SwingExitManager.mqh
**Repo:** https://github.com/Joelisking/xauusd-trader
**File:** `gold_swing_ea/Include/SwingExitManager.mqh`
**Language:** MQL5 (but patterns directly portable to MQL4)

This is the **gold standard** for partial close + trailing remainder. The EA implements a multi-tier exit system:

#### Exit Priority System:
1. H4 structural breakdown — 100% close, immediate
2. H4 200 EMA flip — 100% close, immediate
3. 72-hour time limit — 100% close
4. Initial SL hit — handled by broker (server SL)
5. Major news proximity — reduce to 50%, SL to BE
6. DXY 3-candle headwind — close 50%
7. AI trend exhaustion — close 50%, trail rest
8. TP1 hit — close 40%, SL to BE
9. TP2 hit — close remaining 60%

#### Key Code Pattern — Partial Close Function (MQL5, adapt to MQL4):
```mql5
bool ClosePartialPosition(ulong ticket, double close_lots, string reason)
{
    if(close_lots <= 0) return false;
    
    if(!m_pos_info.SelectByTicket(ticket)) return false;
    
    double current_lots = m_pos_info.Volume();
    double vol_min = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    
    // If partial would leave less than minimum, close all
    if(close_lots >= current_lots)
        return CloseFullPosition(ticket, reason + "(all)");
    
    if(current_lots - close_lots < vol_min)
        return CloseFullPosition(ticket, reason + "(all-min)");
    
    bool result = m_trade.PositionClosePartial(ticket, close_lots);
    return result;
}
```

#### MQL4 Adaptation:
```mql4
bool ClosePartialPosition(int ticket, double close_lots, string reason)
{
    if(close_lots <= 0) return false;
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
    
    double current_lots = OrderLots();
    double vol_min = MarketInfo(OrderSymbol(), MODE_MINLOT);
    
    if(close_lots >= current_lots || current_lots - close_lots < vol_min)
    {
        // Close all
        if(OrderType() == OP_BUY)
            return OrderClose(ticket, current_lots, MarketInfo(OrderSymbol(), MODE_BID), 5);
        else
            return OrderClose(ticket, current_lots, MarketInfo(OrderSymbol(), MODE_ASK), 5);
    }
    
    double price = (OrderType() == OP_BUY) 
                   ? MarketInfo(OrderSymbol(), MODE_BID) 
                   : MarketInfo(OrderSymbol(), MODE_ASK);
    return OrderClose(ticket, close_lots, price, 5);
}
```

#### TP1 Hit Pattern — Close 40%, Move SL to BE, Trail Rest:
```mql4
// PRIORITY 8: TP1 hit — close 40%, move SL to BE
if(HasTP1Hit(state))
{
    double close_lots = state.current_lots * 0.4;  // Close 40%
    ClosePartialPosition(state.ticket, close_lots, "TP1_40PCT");
    
    MoveSLToBreakeven(state.ticket, state.entry_price);
    
    // Apply trailing stop on remaining 60%
    ApplyTrailingStop(state.ticket, state.direction, 25.0);
}
```

#### Trailing Stop Pattern:
```mql4
void ApplyTrailingStop(int ticket, int direction, double trail_pips = 20.0)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double pip = point * 10.0;
    double trail_d = trail_pips * pip;
    
    double current_sl = OrderStopLoss();
    double new_sl;
    
    if(direction == OP_BUY)
    {
        double bid = MarketInfo(OrderSymbol(), MODE_BID);
        new_sl = bid - trail_d;
        // Only tighten — never widen
        if(new_sl <= current_sl && current_sl > 0) return;
    }
    else
    {
        double ask = MarketInfo(OrderSymbol(), MODE_ASK);
        new_sl = ask + trail_d;
        if(new_sl >= current_sl && current_sl > 0) return;
    }
    
    OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0);
}
```

---

## 2. BREAKEVEN-PLUS TRAILING LOGIC

### BEST MATCH: peterthomet/MetaTrader-5-and-4-Tools — Trade Manager.mq4
**Repo:** https://github.com/peterthomet/MetaTrader-5-and-4-Tools
**File:** `Trade Manager/Trade Manager.mq4`
**Language:** Pure MQL4 (also supports MQL5)

This is a **complete, production-quality Trade Manager** with:
- Hard Single Break Even (per-trade SL to BE)
- Soft Basket Break Even (basket-level BE lock)
- Trailing stop with configurable factor
- Full commission-aware BE calculation

#### Key Parameters:
```mql4
input double BreakEvenAfterPips = 5;    // Pips profit before BE activates
input double AboveBEPips = 1;           // Pips above entry for BE SL (covers spread)
input double StartTrailingPips = 7;     // Pips profit before trailing starts
input bool ActivateTrailing = false;
input double TrailingFactor = 0.6;      // Trail at 60% of peak gain
```

#### Hard Single Break Even Pattern (MQL4):
```mql4
// In ManageOrders() loop:
double BESL = 0;
bool NeedSetSL = false;

if(OrderType() == OP_SELL)
{
    BESL = OrderOpenPrice() - (_AboveBEPips * SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT));
    if(OrderStopLoss() == 0 || OrderStopLoss() > BESL)
        NeedSetSL = true;
}
if(OrderType() == OP_BUY)
{
    BESL = OrderOpenPrice() + (_AboveBEPips * SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT));
    if(OrderStopLoss() == 0 || OrderStopLoss() < BESL)
        NeedSetSL = true;
}

// Move to BE when profit exceeds threshold
if(WS.StopMode == HardSingle && gainpips >= _BreakEvenAfterPips && NeedSetSL)
    OrderModify(OrderTicket(), OrderOpenPrice(), BESL, OrderTakeProfit(), 0);
```

#### Soft Basket Break Even Pattern:
```mql4
// After reaching BE threshold, lock the basket
if(WS.StopMode == SoftBasket && _BreakEvenAfterPips > 0 && WS.peakpips >= _BreakEvenAfterPips)
    WS.SoftBEStopLocked = true;

// Close basket if it drops back below BE buffer
if(WS.SoftBEStopLocked && BI.gainpipsglobal < _AboveBEPips)
    closeall = true;
```

#### Trailing Stop with Peak Tracking:
```mql4
// Track peak gain
WS.peakgain = MathMax(WS.globalgain, WS.peakgain);

// Activate trailing when profit threshold hit
if(ActivateTrailing && _StartTrailingPips > 0 && BI.gainpipsglobal >= _StartTrailingPips)
    WS.TrailingActivated = true;

// Trail at TrailingFactor of peak
double GetTrailingLimit()
{
    return WS.peakgain * TrailingFactor;  // e.g., 60% of peak
}

// Close if profit drops below trail limit
if(WS.TrailingActivated && WS.globalgain <= GetTrailingLimit())
    closeall = true;
```

---

## 3. TIME-DECAY POSITION SIZING

**No exact MQL4 implementations found on GitHub.** This is a niche feature. However, here are the conceptual patterns:

### Approach A: Bars-Since-Entry Decay
```mql4
double TimeDecayLots(double base_lots, int ticket, double decay_rate_per_hour = 0.02)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return base_lots;
    
    int bars_held = iBarShift(Symbol(), Period(), OrderOpenTime());
    double hours_held = bars_held * Period() / 60.0;
    
    // Decay: reduce lots by decay_rate per hour, min 50% of original
    double decay_factor = MathMax(0.5, 1.0 - (hours_held * decay_rate_per_hour));
    
    return NormalizeLots(base_lots * decay_factor);
}

double NormalizeLots(double lots)
{
    double min_lot = MarketInfo(Symbol(), MODE_MINLOT);
    double max_lot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    lots = MathFloor(lots / lot_step) * lot_step;
    lots = MathMax(min_lot, MathMin(max_lot, lots));
    return lots;
}
```

### Approach B: Time-Based Partial Close (Reduce exposure as trade ages)
```mql4
void TimeDecayPartialClose(int ticket, int max_hours = 48, double close_pct_per_12h = 0.15)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    int hours_held = (int)((TimeCurrent() - OrderOpenTime()) / 3600);
    double lots = OrderLots();
    double min_lot = MarketInfo(OrderSymbol(), MODE_MINLOT);
    
    // Every 12 hours, close 15% of remaining position
    int decay_cycles = hours_held / 12;
    double target_pct = 1.0 - (decay_cycles * close_pct_per_12h);
    target_pct = MathMax(0.25, target_pct);  // Never go below 25%
    
    double target_lots = NormalizeLots(lots * target_pct);
    double close_lots = lots - target_lots;
    
    if(close_lots >= min_lot)
    {
        double price = (OrderType() == OP_BUY) 
                       ? MarketInfo(OrderSymbol(), MODE_BID) 
                       : MarketInfo(OrderSymbol(), MODE_ASK);
        OrderClose(ticket, close_lots, price, 5);
    }
}
```

### Approach C: Kelly-Based Decay (already exists in DESTROYER)
The DESTROYER EA already has Kelly-based lot sizing. Time-decay can be layered:
```mql4
double TimeDecayKellyLots(double kelly_lots, datetime open_time)
{
    double hours = (TimeCurrent() - open_time) / 3600.0;
    // Exponential decay: half-life of 24 hours
    double decay = MathExp(-0.693 * hours / 24.0);  // ln(2) / 24
    return NormalizeLots(kelly_lots * MathMax(0.3, decay));  // Min 30%
}
```

---

## 4. HOSOPI-3 — MQL4 MARTINGALE WITH TRAILING

**Repo:** https://github.com/harukihosono/Hosopi-3
**File:** `Hosopi3_AllParams_MQL4.mqh`

Relevant parameters for breakeven/trailing:
```mql4
input bool EnableBreakEvenByPositions = false;    // BE by position count
input int BreakEvenMinPositions = 3;               // Min positions for BE
input double BreakEvenProfit = 0.0;                // Min profit for BE
input bool EnableTrailingStop = false;
input int TrailingTrigger = 1000;                  // Trail start profit (points)
input int TrailingOffset = 500;                    // Trail offset (points)
```

---

## 5. RECOMMENDED IMPLEMENTATION FOR DESTROYER QUANTUM

### For the empty partial close placeholders (lines ~12048-12060):

```mql4
//+------------------------------------------------------------------+
//| PARTIAL CLOSE WITH TRAILING REMAINDER                            |
//| Based on patterns from Joelisking/xauusd-trader                  |
//+------------------------------------------------------------------+
void ExecutePartialCloseAndTrail(int ticket, double close_pct, double trail_pips)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double current_lots = OrderLots();
    double close_lots = NormalizeDouble(current_lots * close_pct, 2);
    double min_lot = MarketInfo(OrderSymbol(), MODE_MINLOT);
    
    // Ensure remainder is at least min_lot
    if(current_lots - close_lots < min_lot)
        close_lots = current_lots - min_lot;
    
    if(close_lots < min_lot) return;  // Nothing to close
    
    // Execute partial close
    double price = (OrderType() == OP_BUY) 
                   ? MarketInfo(OrderSymbol(), MODE_BID) 
                   : MarketInfo(OrderSymbol(), MODE_ASK);
    
    if(OrderClose(ticket, close_lots, price, 5))
    {
        // Move SL to breakeven + 1 pip buffer
        if(OrderSelect(ticket, SELECT_BY_TICKET))
        {
            double be_buffer = 10 * _Point;  // 1 pip
            double new_sl;
            
            if(OrderType() == OP_BUY)
                new_sl = OrderOpenPrice() + be_buffer;
            else
                new_sl = OrderOpenPrice() - be_buffer;
            
            OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0);
        }
    }
}

//+------------------------------------------------------------------+
//| BREAKEVEN-PLUS TRAILING                                           |
//| Based on pattern from peterthomet/MetaTrader-5-and-4-Tools       |
//+------------------------------------------------------------------+
void ManageBreakevenPlusTrail(int ticket, double be_trigger_pips, double trail_start_pips, double trail_factor)
{
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    
    double point = MarketInfo(OrderSymbol(), MODE_POINT);
    double digits = MarketInfo(OrderSymbol(), MODE_DIGITS);
    double open_price = OrderOpenPrice();
    double current_sl = OrderStopLoss();
    
    double profit_pips = 0;
    if(OrderType() == OP_BUY)
        profit_pips = (MarketInfo(OrderSymbol(), MODE_BID) - open_price) / (point * 10);
    else
        profit_pips = (open_price - MarketInfo(OrderSymbol(), MODE_ASK)) / (point * 10);
    
    double be_buffer = 1.0;  // 1 pip above entry for BE
    double new_sl = 0;
    
    // Step 1: Move to breakeven when triggered
    if(profit_pips >= be_trigger_pips)
    {
        if(OrderType() == OP_BUY)
        {
            new_sl = NormalizeDouble(open_price + be_buffer * point * 10, digits);
            if(current_sl == 0 || current_sl < new_sl)
                OrderModify(ticket, open_price, new_sl, OrderTakeProfit(), 0);
        }
        else
        {
            new_sl = NormalizeDouble(open_price - be_buffer * point * 10, digits);
            if(current_sl == 0 || current_sl > new_sl)
                OrderModify(ticket, open_price, new_sl, OrderTakeProfit(), 0);
        }
    }
    
    // Step 2: Trail after exceeding trail_start_pips
    if(profit_pips >= trail_start_pips)
    {
        double trail_distance = profit_pips * (1.0 - trail_factor) * point * 10;
        
        if(OrderType() == OP_BUY)
        {
            new_sl = NormalizeDouble(MarketInfo(OrderSymbol(), MODE_BID) - trail_distance, digits);
            if(new_sl > OrderStopLoss())
                OrderModify(ticket, open_price, new_sl, OrderTakeProfit(), 0);
        }
        else
        {
            new_sl = NormalizeDouble(MarketInfo(OrderSymbol(), MODE_ASK) + trail_distance, digits);
            if(OrderStopLoss() == 0 || new_sl < OrderStopLoss())
                OrderModify(ticket, open_price, new_sl, OrderTakeProfit(), 0);
        }
    }
}
```

---

## SUMMARY OF FINDINGS

| Feature | GitHub Match | Quality | Repo URL |
|---------|-------------|---------|----------|
| Partial Close + Trail Remainder | Joelisking/xauusd-trader | ★★★★★ | https://github.com/Joelisking/xauusd-trader |
| Breakeven-Plus Trailing | peterthomet/MetaTrader-5-and-4-Tools | ★★★★★ | https://github.com/peterthomet/MetaTrader-5-and-4-Tools |
| Time-Decay Position Sizing | No exact match | ★★★ (designed from concept) | N/A |
| Martingale with Trailing | harukihosono/Hosopi-3 | ★★★☆ | https://github.com/harukihosono/Hosopi-3 |

### Key Takeaways:
1. **SwingExitManager.mqh** is the most sophisticated partial-close system found — implements TP1 close 40% + BE + trail, with multiple exit triggers
2. **Trade Manager.mq4** has the best pure-MQL4 breakeven implementation with Hard/Soft BE modes and commission-aware calculations
3. **Time-decay sizing** doesn't exist as a standalone MQL4 implementation — the code patterns above are synthesized from the concept
4. All patterns above are MQL4-compatible and can be directly adapted into DESTROYER QUANTUM's empty partial close section
