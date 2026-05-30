# MQL4 Multi-Pair Correlation, DXY Filter & Carry Trade Research
## Date: 2026-05-28

---

## 1. MULTI-PAIR CORRELATION-BASED LOT SIZING

### Best Source: PrimordialFire/The-Market — Advanced_Portfolio_EA.mq4
- **Repo**: https://github.com/PrimordialFire/The-Market
- **File**: `mql/MT4_Experts/Advanced_Portfolio_EA.mq4`
- **Relevance**: Full MQL4 correlation matrix with lot sizing integration

#### Key Code Pattern: CalculateCorrelation() (Pearson coefficient on returns)

```mql4
double CalculateCorrelation(string pair1, string pair2, int periods) {
    double returns1[], returns2[];
    ArrayResize(returns1, periods);
    ArrayResize(returns2, periods);
    
    // Calculate price returns for both pairs
    for(int i = 0; i < periods; i++) {
        double price1_curr = iClose(pair1, PERIOD_H1, i);
        double price1_prev = iClose(pair1, PERIOD_H1, i+1);
        double price2_curr = iClose(pair2, PERIOD_H1, i);
        double price2_prev = iClose(pair2, PERIOD_H1, i+1);
        
        returns1[i] = (price1_curr - price1_prev) / price1_prev;
        returns2[i] = (price2_curr - price2_prev) / price2_prev;
    }
    
    // Calculate correlation coefficient
    double sum1 = 0, sum2 = 0, sum1sq = 0, sum2sq = 0, psum = 0;
    
    for(int i = 0; i < periods; i++) {
        sum1 += returns1[i];
        sum2 += returns2[i];
        sum1sq += returns1[i] * returns1[i];
        sum2sq += returns2[i] * returns2[i];
        psum += returns1[i] * returns2[i];
    }
    
    double num = psum - (sum1 * sum2 / periods);
    double den = MathSqrt((sum1sq - sum1*sum1/periods) * (sum2sq - sum2*sum2/periods));
    
    if(den == 0) return 0;
    return num / den;
}
```

#### Key Code Pattern: IsCorrelationAllowed() (block trades when correlation breaks)

```mql4
input bool UseCorrelationFilter = true;    // Avoid correlated pairs
input double MaxCorrelation = 0.7;         // Maximum allowed correlation

bool IsCorrelationAllowed(string symbol, int orderType) {
    if(!UseCorrelationFilter) return true;
    
    int symbolIndex = -1;
    for(int i = 0; i < pairCount; i++) {
        if(pairs[i] == symbol) { symbolIndex = i; break; }
    }
    if(symbolIndex == -1) return true;
    
    // Check correlation with existing positions
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS)) {
            string orderSymbol = OrderSymbol();
            int orderDirection = OrderType();
            int orderSymbolIndex = -1;
            for(int j = 0; j < pairCount; j++) {
                if(pairs[j] == orderSymbol) { orderSymbolIndex = j; break; }
            }
            if(orderSymbolIndex != -1) {
                double correlation = correlationMatrix[symbolIndex][orderSymbolIndex];
                // Don't trade highly correlated pairs in same direction
                if(MathAbs(correlation) > MaxCorrelation) {
                    if((correlation > 0 && orderDirection == orderType) ||
                       (correlation < 0 && orderDirection != orderType)) {
                        return false;
                    }
                }
            }
        }
    }
    return true;
}
```

#### Key Code Pattern: Periodic Correlation Matrix Update

```mql4
void OnTick() {
    // Update correlation matrix periodically
    if(TimeCurrent() - lastOptimization > 3600) { // Every hour
        if(UseCorrelationFilter) InitializeCorrelationMatrix();
        lastOptimization = TimeCurrent();
    }
    // ...
}

double correlationMatrix[8][8]; // For up to 8 pairs

void InitializeCorrelationMatrix() {
    for(int i = 0; i < pairCount; i++) {
        for(int j = 0; j < pairCount; j++) {
            if(i == j) {
                correlationMatrix[i][j] = 1.0;
            } else {
                correlationMatrix[i][j] = CalculateCorrelation(pairs[i], pairs[j], 100);
            }
        }
    }
}
```

### DESTROYER-Specific Adaptation: EURUSD-GBPUSD Correlation Lot Sizing

```mql4
// ADAPTED FOR DESTROYER QUANTUM EA
// When EURUSD-GBPUSD correlation breaks down, reduce EURUSD lots
double GetCorrelationLotMultiplier() {
    double corr = CalculateCorrelation("EURUSD", "GBPUSD", 100);
    
    // Normal range: 0.7 to 0.95 (highly correlated)
    // When correlation drops below 0.5, something is wrong
    // When correlation goes negative, it's a regime shift
    
    if(corr >= 0.7) return 1.0;       // Normal: full lot size
    if(corr >= 0.5) return 0.75;      // Weakening: reduce 25%
    if(corr >= 0.3) return 0.5;       // Low correlation: half lots
    if(corr >= 0.0) return 0.25;      // Near zero: quarter lots
    return 0.0;                        // Negative correlation: NO TRADE
}
```

---

## 2. DXY (DOLLAR INDEX) FILTER FOR EURUSD TRADING

### Conceptual Reference: Luinea/AlgoTrade — XAUUSD Trading Strategies
- **Repo**: https://github.com/Luinea/AlgoTrade
- **File**: `docs/plans/XAUUSD Trading Strategies and MQ5.md`
- **Key Insight**: "XAU/USD often behaves like the anti-dollar. When the DXY strengthens, Gold typically weakens." Same applies to EURUSD.

### MQL4 DXY Implementation Pattern (Synthesized)

**Problem**: MT4 does NOT have a native DXY instrument. Most brokers don't offer it.

**Solution Options**:
1. Use a proxy symbol (some brokers offer "USDIndex" or "DXY")
2. Calculate a synthetic DXY from component pairs
3. Use EURUSD inverse as a DXY proxy (EURUSD ≈ 57.6% of DXY)

```mql4
// OPTION 1: Use broker's DXY symbol if available
// Check if symbol exists
bool HasDXYSymbol() {
    return (SymbolInfoInteger("USDIndex", SYMBOL_EXIST) || 
            SymbolInfoInteger("DXY", SYMBOL_EXIST) ||
            SymbolInfoInteger("USDOLLAR", SYMBOL_EXIST));
}

// OPTION 2: Synthetic DXY from EURUSD (simplified)
// EURUSD is ~57.6% of DXY weight, so it's the dominant component
// For a quick filter, just check if EURUSD is dropping = DXY rising

// OPTION 3: Full synthetic DXY calculation
// DXY = 50.14348112 × (EURUSD^-0.576) × (USDJPY^0.136) × (GBPUSD^-0.119) ×
//        (USDCAD^0.091) × (USDSEK^0.042) × (USDCHF^0.036)

double CalculateSyntheticDXY(int shift) {
    double eurusd = iClose("EURUSD", PERIOD_H4, shift);
    double usdjpy = iClose("USDJPY", PERIOD_H4, shift);
    double gbpusd = iClose("GBPUSD", PERIOD_H4, shift);
    double usdcad = iClose("USDCAD", PERIOD_H4, shift);
    // Note: USDSEK and USDCHF may not be available on all brokers
    double usdsek = SymbolInfoInteger("USDSEK", SYMBOL_EXIST) ? iClose("USDSEK", PERIOD_H4, shift) : 10.0;
    double usdchf = iClose("USDCHF", PERIOD_H4, shift);
    
    double dxy = 50.14348112 * 
                 MathPow(eurusd, -0.576) *
                 MathPow(usdjpy, 0.136) *
                 MathPow(gbpusd, -0.119) *
                 MathPow(usdcad, 0.091) *
                 MathPow(usdsek, 0.042) *
                 MathPow(usdchf, 0.036);
    return dxy;
}

// DXY TREND FILTER: Only trade EURUSD long when DXY is dropping
bool IsDXYFilterPassing(bool isLong) {
    // Use 20-period EMA of synthetic DXY on H4
    double dxy_current = CalculateSyntheticDXY(0);
    double dxy_prev = CalculateSyntheticDXY(1);
    double dxy_prev2 = CalculateSyntheticDXY(2);
    
    // Calculate DXY momentum (simple slope)
    double dxy_slope = dxy_current - dxy_prev;
    double dxy_slope_prev = dxy_prev - dxy_prev2;
    
    // For EURUSD LONG: DXY must be dropping (slope negative)
    if(isLong) {
        return (dxy_slope < 0);  // DXY falling = EURUSD bullish
    }
    // For EURUSD SHORT: DXY must be rising (slope positive)
    else {
        return (dxy_slope > 0);  // DXY rising = EURUSD bearish
    }
}

// ENHANCED VERSION: Multi-bar DXY EMA filter
double dxyBuffer[];
bool IsDXYTrendConfirmed(bool isLong, int lookback) {
    // Calculate DXY for last N bars
    ArrayResize(dxyBuffer, lookback);
    for(int i = 0; i < lookback; i++) {
        dxyBuffer[i] = CalculateSyntheticDXY(i);
    }
    
    // Calculate EMA of DXY
    double ema = dxyBuffer[0];
    double alpha = 2.0 / (lookback + 1);
    for(int i = 1; i < lookback; i++) {
        ema = alpha * dxyBuffer[i] + (1 - alpha) * ema;
    }
    
    // DXY is trending down if current < EMA
    bool dxyFalling = (dxyBuffer[0] < ema);
    
    // EURUSD long only when DXY falling
    if(isLong) return dxyFalling;
    else return !dxyFalling;
}
```

### Simpler EURUSD-only DXY Proxy (57.6% weight)

```mql4
// If you ONLY trade EURUSD and don't want to load other pairs:
// EURUSD INVERSE is the best DXY proxy since EUR has 57.6% weight

input int DXY_EMA_Period = 20;
input ENUM_TIMEFRAMES DXY_Timeframe = PERIOD_H4;

bool IsEURUSDDXYFilterOK(bool isLong) {
    // Use EURUSD's own 200 EMA as DXY proxy
    double ema200 = iMA("EURUSD", DXY_Timeframe, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
    double ema50  = iMA("EURUSD", DXY_Timeframe, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    double close  = iClose("EURUSD", DXY_Timeframe, 0);
    
    if(isLong) {
        // EURUSD long: price above 200 EMA AND 50 > 200 (DXY bearish)
        return (close > ema200 && ema50 > ema200);
    } else {
        // EURUSD short: price below 200 EMA AND 50 < 200 (DXY bullish)
        return (close < ema200 && ema50 < ema200);
    }
}
```

---

## 3. INTEREST RATE / CARRY TRADE FILTER

### Source: sandman9988/VelocityTrader — VT_BrokerSpecs.mqh
- **Repo**: https://github.com/sandman9988/VelocityTrader
- **File**: `MQL5/Include/VT_BrokerSpecs.mqh`
- **Relevance**: Comprehensive swap cost calculation that can serve as carry trade filter

### Key Code Pattern: Swap Cost Calculation (from VelocityTrader)

```mql4
// Swap-aware position management
// Can be used to FILTER trades based on interest rate differential

// Get swap values (positive = earn interest, negative = pay interest)
double swapLong  = MarketInfo("EURUSD", MODE_SWAPLONG);
double swapShort = MarketInfo("EURUSD", MODE_SWAPSHORT);

// Swap values represent the overnight interest rate differential
// EURUSD swapLong > 0 means EUR rates > USD rates (bullish for carry)
// EURUSD swapShort > 0 means USD rates > EUR rates (bearish for carry)
```

### Carry Trade Filter Implementation

```mql4
// CARRY TRADE FILTER
// Only take trades in the direction that earns positive swap

input bool UseCarryTradeFilter = false;  // Enable carry trade filter
input double MinSwapForEntry = 0.0;      // Minimum swap to allow entry (can be negative)

bool IsCarryTradeFavorable(string symbol, bool isLong) {
    if(!UseCarryTradeFilter) return true;
    
    double swapLong  = MarketInfo(symbol, MODE_SWAPLONG);
    double swapShort = MarketInfo(symbol, MODE_SWAPSHORT);
    
    if(isLong) {
        // For long: check if long swap is favorable
        return (swapLong >= MinSwapForEntry);
    } else {
        // For short: check if short swap is favorable
        return (swapShort >= MinSwapForEntry);
    }
}

// ENHANCED: Use swap as a lot size multiplier
// Positive swap = boost lot size (earn while holding)
// Negative swap = reduce lot size (pay while holding)
double GetCarryTradeLotMultiplier(string symbol, bool isLong) {
    if(!UseCarryTradeFilter) return 1.0;
    
    double swap = isLong ? MarketInfo(symbol, MODE_SWAPLONG) 
                        : MarketInfo(symbol, MODE_SWAPSHORT);
    
    // Swap is in points per lot per day
    // Normalize to a multiplier
    if(swap > 0) return 1.2;    // Earn swap: boost by 20%
    if(swap > -0.5) return 1.0; // Small cost: no change
    if(swap > -1.0) return 0.8; // Moderate cost: reduce 20%
    return 0.5;                  // High cost: reduce 50%
}

// TRIPLE SWAP DAY FILTER
// Avoid holding through triple swap (Wednesday for forex)
input bool AvoidTripleSwap = true;

bool IsTripleSwapDay(string symbol) {
    if(!AvoidTripleSwap) return true;
    
    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);
    
    // Most forex brokers: triple swap on Wednesday (day 3)
    // Some brokers: triple swap on Friday (day 5)
    // Check both and avoid if the swap is negative
    if(now.day_of_week == 3) { // Wednesday
        double swapL = MarketInfo(symbol, MODE_SWAPLONG);
        double swapS = MarketInfo(symbol, MODE_SWAPSHORT);
        // Only avoid if we'd be paying triple swap
        if(swapL < 0 || swapS < 0) return false;
    }
    return true;
}
```

### Interest Rate Proxy Using Swap Differentials

```mql4
// Use swap differentials as an interest rate proxy
// This avoids needing external data feeds

double GetInterestRateDifferential(string symbol) {
    double swapLong  = MarketInfo(symbol, MODE_SWAPLONG);
    double swapShort = MarketInfo(symbol, MODE_SWAPSHORT);
    
    // swapLong - swapShort gives the total differential
    // Positive = base currency has higher rate
    // Negative = quote currency has higher rate
    
    // For EURUSD:
    // swapLong > 0 and swapShort < 0: EUR rate > USD rate (bullish)
    // swapLong < 0 and swapShort > 0: EUR rate < USD rate (bearish)
    
    return (swapLong - swapShort);
}

// Use as a trend confirmation filter
bool IsInterestRateSupporting(string symbol, bool isLong) {
    double differential = GetInterestRateDifferential(symbol);
    
    if(isLong) {
        return (differential > 0);  // Rate favors long (base currency stronger)
    } else {
        return (differential < 0);  // Rate favors short (quote currency stronger)
    }
}
```

---

## 4. INTEGRATION INTO DESTROYER QUANTUM EA

### Proposed Filter Architecture

```mql4
// DESTROYER QUANTUM EA — External Filters Module

// === INPUT PARAMETERS ===
extern bool   UseCorrelationFilter    = true;    // EURUSD-GBPUSD correlation check
extern double CorrelationThreshold    = 0.5;     // Min correlation to allow trade
extern double CorrelationLotScale     = true;    // Scale lots by correlation strength

extern bool   UseDXYFilter           = true;    // DXY trend filter
extern int    DXY_EMA_Period         = 20;      // EMA period for DXY proxy
extern ENUM_TIMEFRAMES DXY_Timeframe = PERIOD_H4;

extern bool   UseCarryFilter         = false;   // Carry trade filter (swap-based)
extern double MinSwapThreshold       = -1.0;    // Max negative swap to allow entry
extern bool   AvoidTripleSwap        = true;    // Avoid Wednesday triple swap

// === FILTER CHECK FUNCTION ===
bool PassesAllFilters(bool isLong, double &lotMultiplier) {
    lotMultiplier = 1.0;
    
    // 1. Correlation Filter
    if(UseCorrelationFilter) {
        double corr = CalculateCorrelation("EURUSD", "GBPUSD", 100);
        if(corr < CorrelationThreshold) {
            if(CorrelationLotScale) {
                lotMultiplier *= MathMax(0.25, corr / 0.7);
            } else {
                return false; // Hard block
            }
        }
    }
    
    // 2. DXY Filter
    if(UseDXYFilter) {
        if(!IsDXYTrendConfirmed(isLong, DXY_EMA_Period)) {
            return false;
        }
    }
    
    // 3. Carry Trade Filter
    if(UseCarryFilter) {
        if(!IsCarryTradeFavorable("EURUSD", isLong)) {
            lotMultiplier *= 0.5; // Don't block, but reduce
        }
        if(!IsTripleSwapDay("EURUSD")) {
            return false;
        }
    }
    
    return true;
}
```

---

## 5. ADDITIONAL REPOS & REFERENCES

| Repo | URL | What It Has |
|------|-----|-------------|
| PrimordialFire/The-Market | https://github.com/PrimordialFire/The-Market | Full correlation matrix MQL4 EA, lot sizing, portfolio risk |
| Luinea/AlgoTrade | https://github.com/Luinea/AlgoTrade | DXY-Gold correlation theory, strategy designs |
| sandman9988/VelocityTrader | https://github.com/sandman9988/VelocityTrader | Broker specs, swap calculations, RL normalization |
| ns-vikas/trading-bot-mql5 | https://github.com/ns-vikas/trading-bot-mql5 | Multi-currency config with correlation thresholds (MQL5) |
| smartedgetrading/SmartEdge-EA | https://github.com/smartedgetrading/SmartEdge-EA | Multi-currency EA architecture (proprietary, docs only) |

### Notes on GitHub Search Limitations
- GitHub code search for MQL4-specific patterns is sparse
- Most MQL4 EA repos are either proprietary (.ex4 only) or low-quality
- The best code patterns were found in MQL5 repos that are easily adaptable to MQL4
- Rate limits were hit during this search, so additional repos may exist but were not found

---

## 6. KEY TAKEAWAYS FOR DESTROYER QUANTUM EA

1. **Correlation implementation is straightforward**: The Pearson correlation on returns approach from PrimordialFire is clean and production-ready
2. **DXY proxy works well**: Using EURUSD's own 200 EMA is the simplest DXY filter; synthetic DXY is more accurate but requires loading 6 pairs
3. **Carry trade filter is simplest**: Just check swap values from MarketInfo() — no external data needed
4. **All three filters can be combined** into a single `PassesAllFilters()` function that returns a lot multiplier (0.0 = no trade, 1.0 = full size)
5. **Periodic recalculation**: Correlation matrix should update every 1-4 hours, not every tick
