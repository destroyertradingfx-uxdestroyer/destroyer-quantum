# Advanced Research Findings — DESTROYER QUANTUM
**Date:** 2026-05-25
**Focus:** Equity curve implementations, adaptive position sizing, session strategies, volatility targeting

---

## 1. FULL CODE ACQUIRED: adaptive-market-ea (longytravel/adaptive-market-ea)

**URL:** https://github.com/longytravel/adaptive-market-ea
**File saved:** /tmp/adaptive_market_ea.mq4 (1815 lines)
**Status:** COMPLETE MQL4 EA — production quality

### Key Implementation Patterns

#### A. Adaptive Position Sizing with Risk Multiplier
```mql4
double CalculatePositionSize(const string symbol, const double stopPoints, const SymbolState &state)
{
   double riskPerTrade = InpRiskPerTrade / 100.0;
   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
   double riskAmount = AccountEquity() * riskPerTrade;
   double multiplier = ClampDouble(gGlobalRiskMultiplier * state.riskMultiplier, 0.1, InpMaxRiskMultiplier);
   riskAmount *= multiplier;
   double stopValuePerLot = stopPoints * tickValue;
   double lots = riskAmount / stopValuePerLot;
   // ... normalize to lot step
}
```
- Uses `AccountEquity() * riskPercent * globalMultiplier * symbolMultiplier`
- Global risk multiplier from JSON model (can be updated by ML/LLM pipeline)
- Per-symbol risk multiplier from regime detection

#### B. Regime-Based Signal Weighting (4 engines)
```mql4
double blended = (weightTrend * trendScore
                + weightMicro * microScore
                + weightReversion * reversionScore
                + weightBreakout * breakoutScore) / weightSum;
double aggregated = blended + state.bias + state.llmBias + gGlobalSentiment;
```
- Each engine produces a score [-1.0, 1.0]
- Weights are per-symbol, configurable via JSON
- Bias and LLM bias allow external model overlay

#### C. ATR-Based Trailing Stop
```mql4
double trailGapPoints = atrPoints * InpAtrTrailMultiplier;
if(trailGapPoints < InpMinStopPoints * 0.5)
   trailGapPoints = InpMinStopPoints * 0.5;
// Trail by modifying SL to bid/ask - trailGapPoints
```

#### D. Daily Loss Kill-Switch
```mql4
double threshold = gDailyAnchorEquity * (1.0 - InpDailyLossLimit / 100.0);
if(AccountEquity() < threshold) gTradingHaltedByLoss = true;
```

#### E. Per-Symbol Regime Configuration (regime_signals.json)
```json
{
  "EURUSD": {
    "bias": 0.12,
    "risk_multiplier": 1.10,
    "regime": "trending",
    "weights": {"trend": 0.45, "micro": 0.20, "reversion": 0.15, "breakout": 0.20}
  }
}
```

### Signal Engines (Full Code Extracted)

1. **Trend Score** — EMA21/55 on H1 + EMA34/89 on H4 + ADX14
2. **Microstructure Score** — M1 volume surge + momentum + body/range imbalance
3. **Reversion Score** — EMA55 distance on M5 + session anchor (M15 96-period SMA)
4. **Breakout Score** — M15 range breakout + M5 impulse + EMA34 bands

---

## 2. NEW MQL5 ARTICLES FOUND (Not in Previous Research)

### Article 21720: RiskGate — Centralized Risk Management for Multiple EAs
**URL:** https://www.mql5.com/en/articles/21720
**Relevance:** ★★★★★ HIGHEST — Directly implements centralized lot sizing for multi-EA accounts
- EAs become signal generators; central "risk brain" approves/rejects trades
- Account-wide rules: daily loss, exposure caps, correlations, strategy limits
- Returns: approved (bool), lot (position size), reason (string)
- CalcExpectedLot() function with equity-based risk calculation
- Per-symbol limits, total risk cap, correlation checks
- **Key insight for DESTROYER:** Separate signal generation from risk management — use a centralized risk gate for all 12 strategies

### Article 22558: Fenwick Tree Money Management with 1D CNN
**URL:** https://www.mql5.com/en/articles/22558
**Relevance:** ★★★★ — Non-linear position sizing using volume topology
- Uses Fenwick tree + CNN to determine lot size from OBV (On Balance Volume)
- If volume lacks conviction → halves lot size
- If volume supports → increases lot size
- Reports show non-linear sizing is "fundamentally protective"
- Profit factor improvements demonstrated in backtests

### Article 22391: Build a Market to Suit Your Strategy
**URL:** https://www.mql5.com/en/articles/22391
**Relevance:** ★★★ — Equity curve stress testing methodology
- Custom symbol construction (Renko, Range, Volume bars)
- Stress testing: gradually worsen conditions, watch equity curve
- If equity curve degrades gracefully → strategy has margin of safety
- Compare Profit Factor, Max DD, Recovery Factor across stress parameters

### Article 22578: From "Best Pass" to Robust Solutions
**URL:** https://www.mql5.com/en/articles/22578
**Relevance:** ★★★ — Optimization robustness for profit factor
- Moving beyond overfit optimization
- Robust parameter selection methodology

### Article 22553: Market Microstructure in MQL5
**URL:** https://www.mql5.com/en/articles/22553
**Relevance:** ★★★ — Hurst exponent for regime detection
- Long memory detection in price series
- Applicable to adaptive strategy selection

---

## 3. HORIZON5-MT FRAMEWORK (pedrocarvajal/horizon5-mt)

**URL:** https://github.com/pedrocarvajal/horizon5-mt (★5)
**Type:** MT5 framework — event-driven portfolio orchestration
- Real out-of-sample portfolio performance report (PDF) available
- Risk-adjusted position sizing built-in
- Crash-safe persistence
- Production-grade multi-asset framework
- **Note:** Strategies are proprietary, but infrastructure is open source

---

## 4. IMPLEMENTATION RECOMMENDATIONS FOR DESTROYER QUANTUM

### 4a. Equity Curve Multiplier (NEW — not in previous research)

Based on adaptive-market-ea pattern, adapted for DESTROYER:

```mql4
// === EQUITY CURVE MULTIPLIER ===
// Track 100-bar SMA of equity snapshots
// If equity > SMA → scale up (max 1.5x)
// If equity < SMA → scale down (min 0.5x)

#define EQUITY_HISTORY_SIZE 100
double gEquityHistory[EQUITY_HISTORY_SIZE];
int gEquityIndex = 0;
bool gEquityFilled = false;

void UpdateEquityHistory()
{
   gEquityHistory[gEquityIndex] = AccountEquity();
   gEquityIndex = (gEquityIndex + 1) % EQUITY_HISTORY_SIZE;
   if(gEquityIndex == 0) gEquityFilled = true;
}

double GetEquityCurveMultiplier()
{
   if(!gEquityFilled) return 1.0;
   double sum = 0;
   int count = gEquityFilled ? EQUITY_HISTORY_SIZE : gEquityIndex;
   for(int i = 0; i < count; i++) sum += gEquityHistory[i];
   double equityMA = sum / count;
   double ratio = AccountEquity() / equityMA;
   // Clamp between 0.5 and 1.5
   return MathMax(0.5, MathMin(1.5, ratio));
}
```

### 4b. Volatility-Targeted Lot Sizing (NEW)

```mql4
// Target 1% equity risk per trade, scaled by volatility regime
double GetVolatilityTargetLots(double stopPoints, double atrCurrent, double atrAvg)
{
   double volRatio = atrCurrent / atrAvg; // >1 = high vol, <1 = low vol
   double volMultiplier = 1.0 / volRatio; // Inverse: less lots in high vol
   volMultiplier = MathMax(0.5, MathMin(2.0, volMultiplier));
   
   double riskAmount = AccountEquity() * 0.01 * volMultiplier;
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double lots = riskAmount / (stopPoints * tickValue);
   return NormalizeDouble(lots, 2);
}
```

### 4c. Session-Based Strategy (from Giacomo-cb Asian Session Breakout)

Pattern already documented in previous research. Key addition:
- Use MQL5 article 22553's Hurst exponent to confirm session breakout validity
- Add volume confirmation from microstructure score pattern

---

## 5. STATUS OF PROFIT FACTOR >2.0 SEARCH

**Finding:** No open-source MQL4/5 EA was found with VERIFIED profit factor >2.0 in published backtests. This is expected because:
1. Most profitable EAs are proprietary
2. Published EAs are typically demonstration/educational
3. EA31337 has CI/CD backtesting but results vary by pair/timeframe
4. The adaptive-market-ea has no published backtest results (code only)

**Best available evidence:**
- EA31337 CI pipeline produces per-optimization backtest reports (check their Actions tab)
- Horizon5-mt has a PDF portfolio report (real out-of-sample)
- MQL5 article 22558 shows profit factor improvements from non-linear sizing

**Recommendation:** Focus on implementing the patterns from adaptive-market-ea and RiskGate, then backtest in MT4 to verify profit factor for DESTROYER's specific strategies.
