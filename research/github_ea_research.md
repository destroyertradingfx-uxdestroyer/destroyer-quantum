# GitHub EA Research — DESTROYER QUANTUM

**Date:** 2026-05-25
**Purpose:** Find high-performing MQL4/5 EA repos and code patterns for multi-strategy EURUSD H4 system improvement.

---

## 1. KEY GITHUB REPOS FOUND

### Tier 1: High-Value Multi-Strategy Frameworks

#### EA31337/EA31337 ★1192
- **URL:** https://github.com/EA31337/EA31337
- **Description:** Forex multi-strategy trading robot for MT4/MT5. Ships with EURUSD-optimized SET files.
- **Key Features:**
  - Multi-strategy framework with Lite, Advanced, and Rider variants
  - Optimized parameter files for EURUSD
  - Multi-timeframe strategy execution (M1, M5, M15, M30)
  - Risk management via MarginMax optimization
  - Signal open filter methods for trade quality
  - Comprehensive CI/CD backtesting pipeline
- **Architecture:** Uses EA31337-classes library (★252) for modular strategy building
- **Relevance to DESTROYER:** **HIGH** — Premier open-source multi-strategy EA. Study its strategy orchestration, risk filtering, and EURUSD parameter optimization approach.

#### longytravel/adaptive-market-ea ★1
- **URL:** https://github.com/longytravel/adaptive-market-ea
- **Description:** Advanced MT4 EA with multi-pair and multi-strategy trading
- **Key Features:**
  - Multi-symbol orchestrator (EURUSD, GBPUSD, USDJPY, XAUUSD) via timer events
  - On-chart adaptive dashboard (equity, drawdown buffer, per-symbol scores/weights)
  - Four blended signal engines: trend, microstructure, mean-reversion, breakout
  - Per-symbol weights from external JSON model
  - ATR-derived stop distances, volatility-aware trailing stops
  - Position flips and configurable daily drawdown kill-switch
  - News blackout via CSV schedule
  - Pluggable offline intelligence (LLMs/ML) rewriting regime_signals.json
- **Relevance to DESTROYER:** **HIGH** — Directly implements equity-curve-based adaptive sizing, multi-strategy blending, and regime-aware position management. Excellent code patterns to study.

#### pedrocarvajal/horizon5-mt ★5
- **URL:** https://github.com/pedrocarvajal/horizon5-mt
- **Description:** Portfolio-oriented algorithmic trading framework for MetaTrader 5
- **Key Features:**
  - Build, backtest, orchestrate multiple strategies from single EA
  - Event-driven orchestration with deterministic identity
  - Crash-safe persistence
  - Risk-adjusted position sizing
  - Real out-of-sample portfolio performance chart available
  - Production-grade infrastructure for multi-asset portfolio
- **Relevance to DESTROYER:** **MEDIUM-HIGH** — Production-quality portfolio framework. Study its crash-safe persistence and event-driven architecture.

### Tier 2: Strategy-Specific Implementations

#### Giacomo-cb/mql4-expert-advisors-portfolio ★0
- **URL:** https://github.com/Giacomo-cb/mql4-expert-advisors-portfolio
- **Description:** Professional MQL4/MQL5 EA portfolio with shared framework
- **Key Strategies:**
  1. **Moving Average Crossover** — Trend following
  2. **Range Breakout** — Dynamic range with cooldown logic
  3. **Asian Session Breakout** — Asian range → London breakout with pending orders
  4. **RSI Mean Reversion** — RSI reversals with trend/ATR filters
  5. **RSI Basket Grid** — Grid/recovery system
- **Architecture:** Shared risk management, strategy-specific modular logic, MT4→MT5 conversion
- **Relevance to DESTROYER:** **HIGH** — Contains Asian Session Breakout implementation directly applicable to session-based EURUSD strategy.

#### Naoghuman/MQL5_Strategy_Session_BreakOut_London ★5
- **URL:** https://github.com/Naoghuman/MQL5_Strategy_Session_BreakOut_London
- **Description:** Session BreakOut London strategy scripts and analysis tools
- **Relevance to DESTROYER:** **MEDIUM** — Study session breakout methodology for London session EURUSD.

#### EarnForex/Vortex-Ultimate ★4
- **URL:** https://github.com/EarnForex/Vortex-Ultimate
- **Description:** Vortex indicator evolution with extra options (MQL5)
- **Relevance to DESTROYER:** **MEDIUM** — Study vortex indicator implementation for potential strategy integration.

#### EarnForex/PersistentAnti ★12
- **URL:** https://github.com/EarnForex/PersistentAnti
- **Description:** EA that detects trend persistence and trades against it (anti-momentum)
- **Relevance to DESTROYER:** **MEDIUM** — Anti-momentum/mean-reversion patterns applicable to multi-strategy diversification.

### Tier 3: Risk Management & Infrastructure

#### Hatef-Rostamkhani/mt5-risk-managed-trend-ea ★1
- **URL:** https://github.com/Hatef-Rostamkhani/mt5-risk-managed-trend-ea
- **Description:** MT5 EA targeting EURUSD H1 with comprehensive risk controls
- **Key Features:**
  - EMA trend filter + RSI momentum confirmation
  - ATR-based SL/TP, break-even, trailing stop
  - Risk-per-trade position sizing using account equity and tick value
  - Spread filter, session filter, daily loss guard, max-position limits
  - Backtest documentation and presets included
- **Relevance to DESTROYER:** **MEDIUM-HIGH** — Clean risk-per-trade sizing implementation using equity. Good reference for EURUSD risk framework.

#### smartedgetrading/SmartEdge-EA ★1
- **URL:** https://github.com/smartedgetrading/SmartEdge-EA
- **Description:** Multi-currency MT4 EA with controlled drawdown architecture
- **Key Features:**
  - Multi-currency simultaneous trading
  - Controlled drawdown architecture
  - RSI, EMA, MACD, VW-MACD signal filters
  - Risk-first philosophy (not grid/martingale)
- **Relevance to DESTROYER:** **MEDIUM** — Study multi-currency risk distribution approach.

#### Zrakt/MT5-Risk-Management-EA ★5
- **URL:** https://github.com/Zrakt/MT5-Risk-Management-EA
- **Description:** Risk management EA for MT5 with advanced money management
- **Relevance to DESTROYER:** **LOW-MEDIUM** — Reference for risk management patterns.

#### toomyem/EquityTracker ★1
- **URL:** https://github.com/toomyem/EquityTracker
- **Description:** MQL4 script for tracking equity, auto-closes positions on threshold
- **Relevance to DESTROYER:** **LOW-MEDIUM** — Simple equity-tracking patterns.

---

## 2. MQL5 CODEBASE REFERENCES

### Referenced Code IDs
The MQL5 codebase IDs from initial research did NOT match expected content:

| ID | Expected | Actual |
|----|----------|--------|
| #12296 | Equity curve EA | "Automatic Posting with WebRequest()" (MetaQuotes) |
| #10649 | Asian range breakout | "e-PSI@SAR v.20.09.2012" (Parabolic SAR EA, Russian) |
| #10007 | Anti-martingale | "ProfitLine" (breakeven indicator, Russian) |
| #11897 | Vortex indicator EA | "BJ EA DISCIPLINE" (black.jack EA for MT5) |

**Note:** The original code IDs may have been incorrect or the codebase has been reorganized. The actual implementations should be found via keyword search on MQL5.com/code/.

### Relevant MQL5.com Searches (blocked by anti-scraping)
MQL5.com blocks automated access. Manual searches recommended for:
- `equity curve` in Code Base (Experts section)
- `Asian session breakout` in Code Base
- `anti martingale` in Code Base
- `vortex indicator` in Code Base (indicators)

---

## 3. CODE PATTERNS FOR DESTROYER QUANTUM

### Pattern 1: Equity Curve Based Position Sizing (from adaptive-market-ea)
```mql4
// Concept: Use equity curve slope to scale position size
// When equity is above its moving average → increase size
// When equity is below → decrease size or pause trading

// Track equity history
double equityMA = iMAOnArray(equityHistory, equityPeriod, 0, MODE_SMA, 0);
double equityRatio = AccountEquity() / equityMA;

// Scale lot size
double baseLot = NormalizeDouble(baseLotSize * equityRatio, 2);
baseLot = MathMax(baseLot, minLot);
baseLot = MathMin(baseLot, maxLot);
```

### Pattern 2: Multi-Strategy Signal Blending (from adaptive-market-ea)
```mql4
// Four engines with per-symbol weights
// trend_score * w_trend + micro_score * w_micro + meanrev_score * w_meanrev + breakout_score * w_breakout
// Signal confidence = weighted sum → threshold for entry

double combinedSignal = 0;
for (int i = 0; i < numStrategies; i++) {
    combinedSignal += strategySignal[i] * strategyWeight[i];
}
if (MathAbs(combinedSignal) > signalThreshold) {
    // Execute trade in direction of combinedSignal
}
```

### Pattern 3: Session-Based Trading (from Giacomo-cb Asian Session Breakout)
```mql4
// Define session times (server time)
int asianStart = 0;   // 00:00
int asianEnd = 8;     // 08:00
int londonStart = 8;  // 08:00

// Track Asian session range
double asianHigh = High[iHighest(NULL, 0, MODE_HIGH, asianBars, 1)];
double asianLow = Low[iLowest(NULL, 0, MODE_LOW, asianBars, 1)];
double asianRange = asianHigh - asianLow;

// Trade London breakout if range is within acceptable bounds
if (asianRange > minRange && asianRange < maxRange) {
    // Place buy stop at asianHigh + buffer
    // Place sell stop at asianLow - buffer
}
```

### Pattern 4: ATR-Based Adaptive Risk (from multiple repos)
```mql4
// Dynamic stop loss based on ATR
double atr = iATR(NULL, 0, 14, 0);
double stopLoss = atr * atrMultiplier;

// Position sizing based on risk percentage
double riskAmount = AccountEquity() * riskPercent / 100.0;
double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
double lotSize = NormalizeDouble(riskAmount / (stopLoss / Point * tickValue), 2);
```

### Pattern 5: Daily Drawdown Kill-Switch
```mql4
// Track daily P&L
static double dayStartEquity;
if (Hour() == 0 && Minute() == 0) dayStartEquity = AccountEquity();

double dailyPnL = AccountEquity() - dayStartEquity;
double dailyDrawdown = -dailyPnL / dayStartEquity * 100;

if (dailyDrawdown > maxDailyDrawdown) {
    // Close all positions and stop trading for the day
    CloseAllPositions();
    tradingEnabled = false;
}
```

### Pattern 6: Regime-Aware Strategy Weights (from adaptive-market-ea)
```json
// models/regime_signals.json
{
  "EURUSD": {
    "regime": "trending",
    "weights": {
      "trend": 0.5,
      "microstructure": 0.2,
      "mean_reversion": 0.1,
      "breakout": 0.2
    },
    "bias": 0.0
  }
}
```

---

## 4. RECOMMENDATIONS FOR DESTROYER QUANTUM

### High Priority Code to Study
1. **EA31337** — Multi-strategy orchestration architecture, EURUSD optimization methodology
2. **adaptive-market-ea** — Equity-curve sizing, signal blending, regime-aware weights, daily kill-switch
3. **Giacomo-cb portfolio** — Asian session breakout implementation, shared risk framework

### Key Architectural Insights
1. **Strategy Isolation:** Each strategy should have independent signal logic but share risk infrastructure
2. **Equity Curve Sizing:** Scale position size inversely with drawdown from equity curve MA
3. **Session Awareness:** Filter trades by session (Asian range for London breakout on EURUSD)
4. **Regime Detection:** Use volatility/trend metrics to adjust strategy weights dynamically
5. **Kill Switches:** Daily drawdown limit, consecutive loss limit, volatility spike pause

### Trade Frequency >1000/Year Strategies
- EA31337 achieves high frequency by combining many strategies across multiple timeframes
- For H4 EURUSD, achieving >1000 trades/year requires ~4+ trades/day → need multiple concurrent strategies
- Consider: session breakout (1-2/day) + trend following (1-2/day) + mean reversion (1-2/day) + breakout (1/day)

### Repos NOT Found (404)
- AcademyAlgo/Trading-Strategies — Does not exist on GitHub
- CMC-AG/mql4 — Does not exist on GitHub

---

## 5. NEXT STEPS
- [ ] Clone adaptive-market-ea and study equity curve sizing implementation in detail
- [ ] Clone Giacomo-cb portfolio and extract Asian Session Breakout logic
- [ ] Study EA31337 strategy orchestration and signal filtering
- [ ] Implement equity curve MA-based position sizing in DESTROYER
- [ ] Implement session-aware trade filtering for EURUSD
- [ ] Search MQL5.com manually for vortex indicator and anti-martingale implementations
