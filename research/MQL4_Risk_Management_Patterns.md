# MQL4 Risk Management Implementation Patterns
## Research Results for DESTROYER QUANTUM EA Enhancements

---

## 1. VOLATILITY REGIME DETECTION (ATR-Based)

### Source: `sanchil/animated-robot` - MarketMetrics-v2.mqh
**Repo:** https://github.com/sanchil/animated-robot
**File:** Include/Sandeep/v2/MarketMetrics-v2.mqh (UTF-16LE encoded, MQL5 but fully adaptable to MQL4)

### Key Function: `atrKinetic()` - Universal Normalized ATR Score [0.0, 1.0]
```mql4
double MarketMetrics::atrKinetic(const double atr) {
   double pipValue = util.getPipValue(_Symbol);
   if(pipValue <= 0) return 0.0;
   
   double atrPips = atr / pipValue;
   
   // BASELINE: 30 pips on M15 = "Max Energy" (1.0)
   double baseRef = 30.0;
   
   // PHYSICS SCALING: Square Root of Time Rule
   // M15=1.0, H1=2.0, H4=4.0
   double timeRatio = (double)_Period / 15.0;
   if(timeRatio <= 0) timeRatio = 1.0;
   
   double physicsCeiling = baseRef * MathSqrt(timeRatio);
   
   // Normalize & Squash (Kinetic Energy = v²)
   double atrNorm = MathMin(MathMax(atrPips / physicsCeiling, 0.0), 1.0);
   return (atrNorm * atrNorm);
}
```

### Key Function: `atrScale()` - Parameter Scaling by Regime
```mql4
double MarketMetrics::atrScale(double atrRaw, double minVal, double maxVal, double curvature = 1.0) {
   if(atrRaw <= 0 || minVal >= maxVal) return minVal;
   double k = atrKinetic(atrRaw);
   if(curvature != 1.0) k = MathPow(k, curvature);  // curvature>1 = punish weak moves
   k = MathMax(0.0, MathMin(1.0, k));
   return minVal + (maxVal - minVal) * k;
}
```

### Key Function: `regimeInterpolate()` - Regime-Adaptive Value
```mql4
double MarketMetrics::regimeInterpolate(double atrRaw, double quietState, double energeticState) {
   return quietState + ((energeticState - quietState) * atrKinetic(atrRaw));
}
```

### Key Function: `atrSIG()` - Regime Classification (TRADE/NOTRADE)
**Source:** Include/Sandeep/v2/SanSignals-v2.mqh (line 2569)
```mql4
SAN_SIGNAL SanSignals::atrSIG(const double &atr[], const int period = 10) {
   SAN_SIGNAL atrSIG = SAN_SIGNAL::NOSIG;
   double atrPips = NormalizeDouble((atr[1] / util.getPipValue(_Symbol)), 3);
   DTYPE atrSlope = slopeSIGData(atr, 5, 21, 1);
   
   double MULTIP = (_Period > 1) ? log(_Period) : _Period;
   double MULTIPADJUSTER = 5;
   double ATR_LOWERBOUND = ceil(MULTIP);           // e.g., 3 pips on H4
   double ATR_UPPERBOUND = ceil(MULTIPADJUSTER * MULTIP); // e.g., 15 pips on H4
   double ATR_SLOPE = -0.3;
   
   if(atrSlope.val1 < ATR_SLOPE) atrSIG = NOTRADE;  // ATR declining = no trade
   if(atrSlope.val1 > ATR_SLOPE) atrSIG = TRADE;
   if(atrPips < ATR_LOWERBOUND)  atrSIG = NOTRADE;  // Too quiet
   if(atrPips > ATR_UPPERBOUND && atrSlope.val1 < ATR_SLOPE) atrSIG = NOTRADE;
   if(atrPips > ATR_LOWERBOUND && atrSlope.val1 > ATR_SLOPE) atrSIG = TRADE;
   if(atrPips > ATR_UPPERBOUND && atrSlope.val1 > ATR_SLOPE) atrSIG = TRADE;
   return atrSIG;
}
```

### Key Function: `marketRegime()` - 3D Regime Classification
```mql4
double MarketMetrics::marketRegime(const FEATURE_VECTOR& fV) {
   double posX = (fV.slopeIma5 + fV.slopeIma30 + fV.adxPlusMinusDiff + fV.rsi + fV.fractalAlignment);
   double posY = (fV.atr + fV.stdDevCP + fV.adx + fV.tVol);
   double posZ = (fV.priceElasticity + fV.mfi + fV.vWCM + fV.expansionCompression);
   
   double projection3D[3] = {posX, posY, posZ};
   double regimeMagnitude = stats.norm(projection3D);
   return regimeMagnitude;
}
```

### PARAMETER VALUES FOR EURUSD H4:
- **baseRef = 30.0** (30 pips M15 baseline)
- **H4 physicsCeiling = 30 * sqrt(16) = 120 pips** (max expected ATR)
- **ATR_LOWERBOUND = ceil(ln(240)) = 6** (minimum viable ATR in pips for H4)
- **ATR_UPPERBOUND = ceil(5 * ln(240)) = 28** (extreme volatility threshold)
- **ATR_SLOPE = -0.3** (minimum ATR slope for trade permission)
- **Regime thresholds:** Dormant < 0.3, Developing 0.3-0.6, Awake 0.6-0.85, Climax > 0.85

---

## 2. PARTIAL PROFIT TAKING (Close Half at 1:1, Trail Remainder)

### Source A: `dennislwm/FX-Git` - Gday mark 2.mq4
**Repo:** https://github.com/dennislwm/FX-Git
**File:** experts/Gday mark 2.mq4 (2571 lines)

### Part-Close at BreakEven (Thirds Strategy)
```mql4
extern bool EnablePartClosure = true;
extern int  BreakEvenTargetPips = 50;
extern int  BreakEvenTargetProfit = 2;  // Lock in 2 pips at BE
extern int  JumpingStopTargetPips = 50;

// In CountOpenTrades():
if(OrderLots() > PartLot && EnablePartClosure) {
   TradeManagementModule();  // Move stop to BE
   double pp = CalculateTradeProfitInPips(OrderType());
   
   // First third: close at BreakEvenPips profit
   if(pp >= BreakEvenPips && pp < (JumpingStopPips * 2) && OrderLots() == Lot)
      PartCloseThisTrade();
   
   // Second third: close at 2x JumpingStopPips
   if(pp >= (JumpingStopPips * 2) && OrderLots() > PartLot)
      PartCloseThisTrade();
   
   // Catch-up: if BE was set but part-close failed
   if(OrderType() == OP_BUY && OrderStopLoss() >= OrderOpenPrice() && OrderLots() == Lot)
      PartCloseThisTrade();
}

void PartCloseThisTrade() {
   double PartLot = Lot / 3;
   bool result = OrderClose(OrderTicket(), PartLot, OrderClosePrice(), 1000, Blue);
   if(!result) ReportError("PartCloseThisTrade()", pcm);
}

bool HalfCloseTrade() {
   bool Success = OrderClose(OrderTicket(), OrderLots() / 2, OrderClosePrice(), 1000, Blue);
   if(!Success) { ReportError("HalfCloseTrade()", pcm); return false; }
   return true;
}
```

### Full Trade Management Module (BE -> Jumping Stop -> Trailing -> Candle Trail)
```mql4
void TradeManagementModule() {
   if(BreakEven) BreakEvenStopLoss();
   
   // Candlestick trailing (once per bar)
   static datetime OldCstBarTime;
   if(UseCandlestickTrailingStop && OldCstBarTime != iTime(NULL, CstTimeFrame, 0)) {
      OldCstBarTime = iTime(NULL, CstTimeFrame, 0);
      CandlestickTrailingStop();
   }
   
   if(JumpingStop) JumpingStopLoss();
   if(TrailingStop) TrailingStopLoss();
}
```

### Jumping Stop Loss (Ratcheting)
```mql4
void JumpingStopLoss() {
   if(OrderType() == OP_BUY) {
      if(sl == 0) sl = MathMax(OrderStopLoss(), OrderOpenPrice());
      if(Bid >= sl + ((JumpingStopPips * 2) / factor)) {
         NewStop = NormalizeDouble(sl + (JumpingStopPips / factor), Digits);
         if(AddBEP) NewStop += (BreakEvenProfit / factor);
         if(NewStop - OrderStopLoss() >= Point) modify = true;
      }
   }
}
```

### Source B: `dryousufmesalm/Experts` - SolidEA.mq4
**Repo:** https://github.com/dryousufmesalm/Experts

### Configurable Partial Close + Trailing + BE
```mql4
// Partial Close
input bool UsePartialClose = true;
input ENUM_UNIT PartialCloseUnit = InPips;
input double PartialCloseTrigger = 40;    // Close partial after 40 pips
input double PartialClosePercent = 0.5;   // Close 50% of position
input int MaxNoPartialClose = 1;

// Trailing Stop
input bool UseTrailingStop = true;
input ENUM_UNIT TrailingUnit = InPips;
input double TrailingStart = 35;   // Start trailing after 35 pips
input double TrailingStep = 10;    // Trail by 10 pips
input double TrailingStop = 2;     // 2 pip buffer

// Break Even
input bool UseBreakEven = true;
input ENUM_UNIT BreakEvenUnit = InPips;
input double BreakEvenTrigger = 30;
input double BreakEvenProfit = 1;
```

### IMPLEMENTATION PATTERN FOR DESTROYER:
```
1. Open trade with SL = ATR-based
2. When price reaches 1:1 R:R (profit = SL distance):
   - Close 50% of position
   - Move SL to breakeven + 1 pip
3. Trail remainder using:
   - Jumping stop (ratchet by ATR/2 increments)
   - OR Candlestick trailing (previous candle high/low)
4. Maximum 1 partial close per trade
```

---

## 3. PORTFOLIO HEAT BUDGET / RISK AGGREGATION

### Source: `sanchil/animated-robot` - MarketMetrics-v2.mqh
**Functions:** marketSlopesHeat(), marketProbHeat()

### marketSlopesHeat() - Slope-Based Heat Measurement
```mql4
double MarketMetrics::marketSlopesHeat(
   double fast, double slow, double baselineScale, double sensitivity = 2.0
) {
   // 1. Conflict Protection (Directional Harmony)
   if(fast * slow < 0) return 0.0;
   
   // 2. Structural Floor (5% of baseline, e.g., ATR)
   double noiseFloor = baselineScale * 0.05;
   double absFast = MathAbs(fast);
   double absSlow = MathAbs(slow);
   
   // 3. Absolute Dormancy Check
   if(absFast < noiseFloor && absSlow < noiseFloor) return 0.0;
   
   // 4. Safe Denominator (prevent infinity when slow = 0)
   double safeSlow = MathMax(absSlow, noiseFloor);
   
   // 5. Dimensionless Shifted Ratio
   double ratio = absFast / safeSlow;
   double shiftedRatio = ratio - 1.0;
   
   // 6. Tanh Squash (-1.0 to 1.0)
   double intensity = MathTanh(shiftedRatio * sensitivity);
   return intensity;
}
```

### marketProbHeat() - Probability-Based Heat (Exhaustion Detector)
```mql4
double MarketMetrics::marketProbHeat(double fast, double slow, double sensitivity = 2.0) {
   double fv = fast - 0.5;
   double sv = slow - 0.5;
   
   if(fv * sv < 0) return 0.0;  // Conflict protection
   
   double noiseFloor = 0.5 * 0.05;
   double absFast = MathAbs(fv);
   double absSlow = MathAbs(sv);
   
   if(absFast < noiseFloor && absSlow < noiseFloor) return 0.0;
   
   double safeSlow = MathMax(absSlow, noiseFloor);
   double ratio = absFast / safeSlow;
   double shiftedRatio = ratio - 1.0;
   
   // Heat > 0.95 = "Redline" (mean-reversion imminent)
   return MathTanh(shiftedRatio * sensitivity);
}
```

### IMPLEMENTATION PATTERN FOR PORTFOLIO HEAT BUDGET:
```mql4
// MQL4 Portfolio Heat Budget (adapted from sanchil patterns)
double CalculatePortfolioHeat() {
   double totalHeat = 0;
   for(int i = OrdersTotal()-1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      
      // Risk per position = lots * SL_distance * tick_value
      double slDist = MathAbs(OrderOpenPrice() - OrderStopLoss());
      double posRisk = OrderLots() * slDist * MarketInfo(OrderSymbol(), MODE_TICKVALUE);
      totalHeat += posRisk;
   }
   return totalHeat / AccountBalance();  // As percentage of equity
}

// Gate new entries when heat > threshold
double MaxPortfolioHeat = 0.06;  // 6% max portfolio risk
if(CalculatePortfolioHeat() >= MaxPortfolioHeat) return;  // Block new trade
```

### Bayesian Regime Multiplier (from bayesianHoldScore):
```mql4
double regimeMultiplier = 1.0;
if(useOverallForce) {
   double omf = overallMarketForce(_Symbol, _Period, 14);
   regimeMultiplier = (omf > 0.35) ? 1.2 : (omf < -0.35 ? 0.8 : 1.0);
}
```

---

## 4. TIME-DECAY EXITS (Close Stale Trades After N Bars)

### Source A: `dryousufmesalm/Experts` - SolidEA.mq4

### closeWithCandleExpiration() - Close After N Bars
```mql4
input int Bars_TO_CLOSE = 10;  // Close after 10 bars
input caraclose closetype = bar;  // enum: opposite=0, sltp=1, bar=2

void closeWithCandleExpiration(CPosition &pos) {
   int size = pos.GroupTotal();
   for(int i = 0; i < size; i++) {
      datetime timeOpen = pos[i].GetTimeOpen();
      string symb = pos[i].GetSymbol();
      datetime timetoDelete = iTime(symb, 0, Bars_TO_CLOSE);
      
      if(timeOpen <= timetoDelete) {
         // Trade is older than Bars_TO_CLOSE candles
         pos[i].Close(30);
         return;
      }
   }
}
```

### Source B: `sanchil/animated-robot` - MarketMetrics-v2.mqh

### Linear Time Retention (Decay Over Bars)
```mql4
double MarketMetrics::getLinearTimeRetention(int barsHeld, double decayRate = 0.05, double floor = 0.60) {
   double retention = 1.0 - (barsHeld * decayRate);
   return MathMax(retention, floor);  // Never drop below floor
}
```

### Hybrid Time + Volatility Retention
```mql4
double MarketMetrics::getHybridRetention(int barsHeld, double atr) {
   double timeRet = getLinearTimeRetention(barsHeld, 0.02, 0.80);
   double volRet  = getVolAdaptiveRetention(atr);
   return (timeRet * volRet);
}

// v2: Adds trend quality bonus (strong trends decay slower)
double MarketMetrics::getHybridRetention_v2(int barsHeld, double atr, double trendQualityScore = 0.0) {
   double timeRet = 1.0 - (barsHeld * 0.015);     // 1.5% per bar
   timeRet = MathMax(timeRet, 0.75);               // Floor at 75%
   
   double volScore = atrKinetic(atr);
   double volRet = 0.98 - (0.12 * MathSqrt(volScore));
   volRet = MathMax(volRet, 0.72);
   
   double trendBonus = 1.0 + (trendQualityScore * 0.35);  // 0.0 -> 1.35x slower decay
   
   return timeRet * volRet * trendBonus;
}
```

### Volatility-Adaptive Retention
```mql4
double MarketMetrics::getVolAdaptiveRetention(double atr) {
   double volScore = atrKinetic(atr);
   // Sqrt makes it loosen quickly as soon as volatility starts
   double retention = 0.98 - (0.16 * MathSqrt(volScore));
   return MathMax(retention, 0.70);
}
```

### Bayesian Hold Score with Time Decay (2% per bar)
```mql4
// In bayesianHoldScore():
double timeDecay = MathMax(0.2, 1.0 - (barsHeld * 0.02));
lr *= timeDecay;
```

### IMPLEMENTATION PATTERN FOR DESTROYER:
```mql4
// Time-decay exit with regime awareness
input int MaxBarsHeld = 20;        // Hard exit after 20 bars (H4 = ~3.3 days)
input int SoftExitBars = 12;       // Start reducing after 12 bars
input double DecayFloor = 0.75;    // Never decay below 75% confidence

void CheckTimeDecayExit() {
   for(int i = OrdersTotal()-1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      
      int barsHeld = iBarShift(NULL, 0, OrderOpenTime());
      
      // Hard exit
      if(barsHeld >= MaxBarsHeld) {
         OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 30);
         continue;
      }
      
      // Soft exit: scale position confidence down
      if(barsHeld >= SoftExitBars) {
         double retention = 1.0 - ((barsHeld - SoftExitBars) * 0.05);
         retention = MathMax(retention, DecayFloor);
         // Use retention to tighten trailing stop or close partial
      }
   }
}
```

---

## PARAMETER SUMMARY FOR DESTROYER QUANTUM EA (EURUSD H4)

| Feature | Parameter | Value | Rationale |
|---------|-----------|-------|-----------|
| ATR Regime | baseRef | 30 pips (M15) | sanchil calibration |
| ATR Regime | H4 ceiling | 120 pips | 30 * sqrt(16) |
| ATR Regime | Lower bound | 6 pips | ceil(ln(240)) |
| ATR Regime | Upper bound | 28 pips | ceil(5*ln(240)) |
| ATR Regime | Slope threshold | -0.3 | Minimum ATR slope |
| Partial Close | Trigger | 1:1 R:R | Close half at breakeven distance |
| Partial Close | Percent | 50% | Standard half-close |
| Partial Close | Max count | 1 | Single partial per trade |
| Trailing | Start | 1R profit | Activate after partial close |
| Trailing | Type | Jumping stop | Ratchet by ATR/2 |
| Portfolio Heat | Max | 6% of equity | Industry standard |
| Portfolio Heat | Per-trade | 1.5% | 4 concurrent positions max |
| Time Decay | Hard exit | 20 bars (80h) | ~3.3 days on H4 |
| Time Decay | Soft exit | 12 bars (48h) | Start tightening |
| Time Decay | Floor | 0.75 | Never decay below 75% |

---

## REPOS FOUND WITH CODE

1. **sanchil/animated-robot** - Advanced regime detection, time decay, heat measurement
   - MarketMetrics-v2.mqh: ATR regime, time retention, heat scores
   - SanSignals-v2.mqh: ATR signal classification, volatility momentum signals
   - ~5000+ lines of MQL5 (adaptable to MQL4)

2. **dennislwm/FX-Git** - Gday mark 2.mq4 (2571 lines)
   - Complete trade management: BE -> Part-close (thirds) -> Jumping stop -> Trailing -> Candle trail
   - Production-tested patterns with parameter values

3. **dryousufmesalm/Experts** - SolidEA.mq4
   - Time-bar expiration exit (closeWithCandleExpiration)
   - Configurable partial close with unit selection (pips/dollars)
   - Trailing stop with start/step/stop parameters
   - Multi-symbol portfolio management

4. **smartedgetrading/SmartEdge-EA** (1 star)
   - Multi-currency MT4 EA focused on controlled drawdown and portfolio stability
