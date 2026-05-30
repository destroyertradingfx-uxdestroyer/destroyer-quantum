# GitHub Research: Session Strategies & Adaptive Lot Sizing (MQL4)

**Date:** 2026-05-29
**Search queries:** MQL4 session breakout EA, London fix EA, Asian session breakout, ATR lot size, opening range breakout

---

## Summary

Found 5 high-quality repos with actual .mq4 source code covering session breakout strategies, London breakout patterns, ATR-based position sizing, and multi-session filtering. Key patterns extracted below for integration into DESTROYER QUANTUM.

---

## 1. CCTS_Breakout.mq4 — Multi-Session EA Framework ⭐⭐⭐⭐⭐

**Repo:** [Maidenfan78/CCTS_EA_Framework](https://github.com/Maidenfan78/CCTS_EA_Framework)
**File:** `MQL4/Experts/CCTS_Breakout.mq4`
**Why it's best:** Full EA framework with session filtering (Asian/London/NY), ATR-based SL/TP, risk-based lot sizing, and modular signal architecture.

### Session Filtering Pattern (Copy-paste ready)
```mql4
// Session definitions in GMT
#define ASIA_START_HOUR   0
#define ASIA_END_HOUR     9
#define LONDON_START_HOUR  8
#define LONDON_END_HOUR    17
#define NY_START_HOUR      13
#define NY_END_HOUR        22

// Timezone offsets
#define ASIA_OFFSET     ( 9 * 3600)   // GMT+9 (Tokyo)
#define LONDON_OFFSET   ( 1 * 3600)   // GMT+1 for BST
#define NEWYORK_OFFSET  (-4 * 3600)   // GMT-4 for EDT

string GetCurrentSession() {
   int h = TimeHour(TimeGMT());
   if(h >= ASIA_START_HOUR   && h < ASIA_END_HOUR)   return "Asian";
   if(h >= LONDON_START_HOUR && h < LONDON_END_HOUR)  return "London";
   if(h >= NY_START_HOUR     && h < NY_END_HOUR)      return "New York";
   return "";
}
```

### Session Filter in OnTick
```mql4
int  h        = TimeHour(TimeGMT());
bool inAsia   = (h >= ASIA_START_HOUR   && h < ASIA_END_HOUR);
bool inLondon = (h >= LONDON_START_HOUR && h < LONDON_END_HOUR);
bool inNY     = (h >= NY_START_HOUR     && h < NY_END_HOUR);

// Skip if outside enabled sessions
if(!((EnableAsianSession     && inAsia)
     ||(EnableLondonSession  && inLondon)
     ||(EnableNewYorkSession && inNY)))
  { return; }
```

### ATR-Based SL/TP & Lot Sizing
```mql4
ATRValue = iATR(currentSymbol, Period(), ATR_Period, 1);
CalculateStandardSLTP(Sl, Tp, Tp_2, SlPoints, TpPoints, Tp_2Points);
LotsVolume = CalcLotsVolume(Sl, SlPoints);
double point_Value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE) 
                   / SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
double dollarsRisk = LotsVolume * Sl * point_Value;
```

### Day-of-Week Filter
```mql4
bool IsDayAllowed() {
   int dow = TimeDayOfWeek(TimeCurrent());
   switch(dow) {
      case 0: return AllowSunday;
      case 1: return AllowMonday;
      // ... etc
   }
   return false;
}
```

### Implementation Notes
- Uses modular architecture: separate setup/signal/exit phases
- Multiple indicator signals (BL2, C1, C2, V1) with trend/volume filters
- CanReadPythonSignals() — supports ML model integration
- ATR trailing stop on runner position (2nd order)
- Break-even management on first TP hit

---

## 2. 3 Tier London Breakout V.3.3b — London Session Box ⭐⭐⭐⭐⭐

**Repo:** [H4RTBrothers/Advisory-Source-Code](https://github.com/H4RTBrothers/Advisory-Source-Code)
**File:** `Tier London Breakout V.3.3b.mq4`
**Origin:** ForexFactory thread by Squalou & mer071898

### Core Box Calculation
```mql4
extern string StartTime     = "06:00";    // Box start
extern string EndTime       = "09:14";    // Box end
extern string SessionEndTime= "04:30";    // Session end
extern int    MinBoxSizeInPips = 15;
extern int    MaxBoxSizeInPips = 80;

// Determine box high/low
boxStartShift = iBarShift(NULL,0,tBoxStart);
boxEndShift   = iBarShift(NULL,0,tBoxEnd);
boxHigh = High[iHighest(NULL,0,MODE_HIGH,(boxStartShift-boxEndShift+1),boxEndShift)];
boxLow  = Low[iLowest(NULL,0,MODE_LOW,(boxStartShift-boxEndShift+1),boxEndShift)];
boxMedianPrice = (boxHigh+boxLow)/2;
boxExtent = boxHigh - boxLow;
```

### Breakout Levels with Fibonacci Targets
```mql4
// Entry levels
BuyEntry  = boxHigh;
SellEntry = boxLow;

// TP levels based on box extent multipliers
TP1Factor = 1.000;   // 1x box size
TP3Factor = 2.618;   // Fibonacci 2.618x
TP5Factor = 4.236;   // Fibonacci 4.236x
TP2Factor = (TP1Factor+TP3Factor)/2;  // midpoint
TP4Factor = (TP3Factor+TP5Factor)/2;  // midpoint

// Compute TPs
BuyTP1 = NormalizeDouble(BuyEntry + boxExtent*TP1Factor, Digits);
SellTP1 = NormalizeDouble(SellEntry - boxExtent*TP1Factor, Digits);
```

### Box Size Filtering
```mql4
if (boxExtent >= MaxBoxSizeInPips * pip && LimitBoxToMaxSize==true) {
   // Box too large - limit to max and recenter on EMA
   boxExtent = MaxBoxSizeInPips * pip;
   boxMedianPrice = iMA(NULL,0,boxStartShift-boxEndShift,0,MODE_EMA,PRICE_MEDIAN,boxEndShift);
}
```

### Stick-to-Extreme Logic
```mql4
// When box too large, stick to latest extreme
if (StickBoxToLatestExtreme==true) {
   int boxHighShift = iHighest(NULL,PERIOD_M1,MODE_HIGH,...);
   int boxLowShift  = iLowest(NULL,PERIOD_M1,MODE_LOW,...);
   if (boxHighShift <= boxLowShift) {
      // High is more recent: stick to highest
      boxMedianPrice = boxHigh - boxExtent/2;
   } else {
      // Low is more recent: stick to lowest
      boxMedianPrice = boxLow + boxExtent/2;
   }
}
```

### Implementation Notes
- Indicator (not EA) — draws boxes and TP levels visually
- MondayFix option handles IBFX weekend candle issues
- StickBoxOutsideSRlevels: uses reversal points as S/R
- LevelsResizeFactor: allows scaling all levels proportionally
- Can be used as signal generator for a separate EA

---

## 3. JamesORB.mq4 — Opening Range Breakout with ATR ⭐⭐⭐⭐

**Repo:** [omnisis/mt4-ea-obr](https://github.com/omnisis/mt4-ea-obr)
**File:** `JamesORB.mq4`

### ATR-Based ORB Calculation
```mql4
extern double OBR_PIP_OFFSET = 0.0002;
extern int    EET_START = 10;       // 10:00 EET (Eastern European Time)
extern double OBR_RATIO = 1.9;
extern double ATR_PERIOD = 72;

double CalcCurrORB() {
   double currATR = iATR(NULL, 0, ATR_PERIOD, 1);
   return (currATR + OBR_PIP_OFFSET);
}
```

### Pending Order Generation
```mql4
void generateDailyPendingOrders(double orbval) {
   double tenEETHi = High[1];  // Previous bar high
   double tenEETLo = Low[1];   // Previous bar low
   
   // Buy side
   double buyEntry = tenEETHi + orbval;
   double SL = buyEntry - (1.65 * orbval);
   double TP = buyEntry + orbval;
   
   PlacePendingStopOrder(OP_BUYSTOP, Symbol(), buyEntry, lotSize, SL_Dist, TP_Dist);
   
   // Sell side
   double sellEntry = tenEETLo - orbval;
   SL = sellEntry + (1.65 * orbval);
   TP = sellEntry - orbval;
   
   PlacePendingStopOrder(OP_SELLSTOP, Symbol(), sellEntry, lotSize, SL_Dist, TP_Dist);
}
```

### Risk-Based Lot Sizing
```mql4
double calcTradeVolume(double risk, double stopLossPoints) {
   double minLotAllowed = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLotAllowed = MarketInfo(Symbol(), MODE_MAXLOT);
   
   double vol = (AccountFreeMargin() * (risk/100)) 
              / (stopLossPoints * MarketInfo(Symbol(), MODE_TICKVALUE));
   
   if(vol < minLotAllowed) vol = -1.0;  // Can't trade
   if(vol > maxLotAllowed) vol = maxLotAllowed;
   return(vol);
}
```

### Implementation Notes
- Triggers at 11:00 (hour after EET start)
- Closes all orders at 17:30 (close of day)
- SL = 1.65x ORB value (asymmetric risk)
- TP = 1x ORB value
- Uses pending stop orders (not market)

---

## 4. OrbBreakoutEA.mq4 — Advanced ORB with SMC/SMC ⭐⭐⭐⭐

**Repo:** [javierdiaz13/mt4-telegram-alert-bridge](https://github.com/javierdiaz13/mt4-telegram-alert-bridge)
**File:** `EA-Files/OrbBreakoutEA.mq4` (101KB — very comprehensive)

### Key Features
- Opening Range Breakout on attached chart
- Enters on ORB, AMD, SMC/SMT, and order-block BOS signals
- Supports one opposite-side reversal per symbol/magic
- **Trails the stop with ATR on closed bars**
- Emits MT4 JSONL events for backend integration

### ATR Trailing Stop Pattern
```mql4
// Trails stop using ATR on closed bars (not every tick)
// Uses previous bar's ATR to avoid whipsaws
```

### Implementation Notes
- Very large file (101KB) — production-grade
- JSONL event output for analytics/ML pipeline
- Sharded event files by instrument type (FOREX, GOLD, US500, etc.)
- Multi-strategy signals: ORB + AMD + SMC/SMT + Order Block BOS
- One reversal trade per symbol to prevent overtrading

---

## 5. EarnForex PositionSizer — Professional Position Sizing ⭐⭐⭐⭐⭐

**Repo:** [EarnForex/PositionSizer](https://github.com/EarnForex/PositionSizer)
**File:** `MQL4/Experts/Position Sizer/Position Sizer.mq4`
**Stars:** Very popular (EarnForex is well-known)

### ATR-Based SL/TP Settings
```mql4
input bool    ShowATROptions = true;           // Enable ATR mode
input int     DefaultATRPeriod = 14;           // ATR period
input double  DefaultATRMultiplierSL = 0;      // ATR multiplier for SL
input double  DefaultATRMultiplierTP = 0;      // ATR multiplier for TP
input ENUM_TIMEFRAMES DefaultATRTimeframe = PERIOD_CURRENT;
input bool    DefaultSpreadAdjustmentSL = false; // Adjust SL by spread
input bool    DefaultSpreadAdjustmentTP = false;
```

### Risk-Based Position Sizing
```mql4
input double DefaultRisk = 1;              // Risk percentage
input double DefaultMoneyRisk = 0;         // Money risk (overrides %)
input double DefaultPositionSize = 0;      // Fixed lot size (if > 0)
input ACCOUNT_BUTTON DefaultAccountButton = Balance; // Balance/Equity
input double AdditionalFunds = 0;          // Added to balance
input double CustomBalance = 0;            // Override balance
```

### Key Features for Our EA
- Supports multiple take-profit levels with volume splitting
- Portfolio risk calculation across all open positions
- Margin-based position sizing
- Commission-aware risk calculation
- Break-even and trailing stop built in
- Max position size limits per symbol and total

### Implementation Notes
- This is a position sizing TOOL, not a strategy EA
- Can be used as reference for our CalcLotsVolume() function
- Commission-aware calculation is critical for accurate sizing
- Supports both Balance and Equity based risk

---

## Key Patterns for DESTROYER QUANTUM Integration

### Pattern 1: Asian Range Breakout
```
1. Define Asian session: 00:00-09:00 GMT
2. Record High/Low during Asian session
3. At London open (08:00-09:00 GMT), set pending orders:
   - Buy Stop at Asian High + buffer
   - Sell Stop at Asian Low - buffer
4. SL = opposite side of Asian range (or ATR-based)
5. TP = 1x-2x range width
6. Close all at NY close or end of day
```

### Pattern 2: London Fix Reversal (16:00 GMT)
```
1. Monitor price action around 16:00 GMT (London fix)
2. Look for exhaustion patterns: long wicks, RSI divergence
3. Enter counter-trend at 16:00-16:30 GMT
4. SL = recent swing high/low
5. TP = 50% retracement of daily range
6. Time-based exit at 17:00-17:30 GMT
```

### Pattern 3: ATR-Based Adaptive Lot Sizing
```mql4
// From CCTS framework - adapt this
double CalcLotsVolume(double slPrice, int slPoints) {
   double atr = iATR(Symbol(), Period(), 14, 1);
   double riskAmount = AccountBalance() * (RiskPercent / 100.0);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   
   if (tickValue == 0) return 0.01;
   
   double lots = riskAmount / (slPoints * tickValue);
   
   // Normalize to broker constraints
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   
   return lots;
}
```

### Pattern 4: Multi-Session Momentum
```
1. Track momentum across sessions using RSI/MACD
2. Asian session: accumulate range data
3. London open: check for breakout direction + momentum
4. NY session: look for continuation or reversal
5. Use session transitions as signal triggers
```

---

## Recommended Implementation Order

1. **Phase 1:** Add session filtering to existing EA (from CCTS pattern)
2. **Phase 2:** Implement Asian Range Breakout strategy
3. **Phase 3:** Add ATR-based adaptive lot sizing (from JamesORB + PositionSizer)
4. **Phase 4:** Implement London Fix reversal strategy
5. **Phase 5:** Add multi-session momentum confirmation

---

## Raw File URLs (for direct download)

- CCTS_Breakout.mq4: https://raw.githubusercontent.com/Maidenfan78/CCTS_EA_Framework/main/MQL4/Experts/CCTS_Breakout.mq4
- Tier London Breakout V.3.3b.mq4: https://raw.githubusercontent.com/H4RTBrothers/Advisory-Source-Code/main/Tier%20London%20Breakout%20V.3.3b.mq4
- JamesORB.mq4: https://raw.githubusercontent.com/omnisis/mt4-ea-obr/master/JamesORB.mq4
- OrbBreakoutEA.mq4: https://raw.githubusercontent.com/javierdiaz13/mt4-telegram-alert-bridge/main/EA-Files/OrbBreakoutEA.mq4
- Position Sizer.mq4: https://raw.githubusercontent.com/EarnForex/PositionSizer/master/MQL4/Experts/Position%20Sizer/Position%20Sizer.mq4
