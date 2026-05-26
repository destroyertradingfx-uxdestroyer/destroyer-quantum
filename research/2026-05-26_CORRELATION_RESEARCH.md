# Correlation / Pairs Trading EA Research — 2026-05-26

## Purpose
Search for open-source MQL4/MQL5 Expert Advisors implementing EURUSD/GBPUSD correlation trading, pairs trading, or spread trading strategies. Goal: find new edge sources for DESTROYER QUANTUM EA to push from $138K projected to $170K target.

---

## Repositories Found

### 1. jblanked/MQL4-Currency-Pair-Correlation-Expert-Advisor ⭐ 13
- **URL:** https://github.com/jblanked/MQL4-Currency-Pair-Correlation-Expert-Advisor
- **Language:** MQL4
- **Description:** "CARA v6.3" — trades correlations across multiple predefined pairs
- **Backtest Results:** None documented
- **Key Code Patterns:**
  - Uses `DetectOrders4()` and `DetectOrdersSameTrend5()` functions for correlation-based order detection
  - Monitors multiple pairs (US30, NAS100, XAUUSD, USDCAD, ETHUSD, BTCUSD, AUDJPY, NZDJPY, EURJPY, GBPJPY, CADJPY)
  - When a manual trade is detected on one pair, it auto-opens correlated trades on related pairs
  - Example: When US30 is traded, it also trades correlated USD pairs (USDJPY, USDCAD, USDCHF, etc.)
  - When EURJPY is traded, it trades correlated EUR pairs (EURAUD, EURCAD, EURCHF, EURGBP, EURNZD)
  - Risk splitting: `OrderLots()/N` distributes lot size across correlated pairs
  - Uses magic numbers for multi-pair order management (21 magic numbers total)
  - **Critical limitation:** This is a "follower" EA — it detects an existing trade on one pair and mirrors it to correlated pairs. Not a standalone signal generator.
- **Dependencies:** CustomFunctionsFix.mqh, CARAComponents.mqh (not included in repo)
- **Relevance to DESTROYER:** LOW — This is a copy-trade-to-correlated-pairs EA, not a statistical arbitrage system. No mean-reversion or spread trading logic.

### 2. vidoh89/EA-correlation_mql4 ⭐ 0
- **URL:** https://github.com/vidoh89/EA-correlation_mql4
- **Language:** MQL4
- **Description:** "EA RSI based trading" — minimal repo
- **Backtest Results:** None documented
- **Relevance to DESTROYER:** VERY LOW — appears to be basic RSI EA with "correlation" in name only.

### 3. 5ymph0en1x/Heptet ⭐ 64
- **URL:** https://github.com/5ymph0en1x/Heptet
- **Language:** Python (TensorFlow)
- **Description:** Pair Trading with Reinforcement Learning using Oanda API
- **Pairs:** EURJPY / GBPJPY (1-minute data)
- **Backtest Results:** PnL chart documented for EURJPY/GBPJPY 2019 (visual only, no PF number)
- **Key Code Patterns:**
  - N-armed bandit RL approach for cointegration pair trading
  - Uses `Analysis.py` to compute correlation matrices and cointegration values
  - `Training_Model.py` for backtesting with configurable strategies
  - YAML config for trading parameters
  - HistData.com for historical tick data
- **Relevance to DESTROYER:** MEDIUM — good reference for cointegration-based pair selection methodology, but Python/Oanda, not MQL4. The RL approach is novel but complex.

### 4. MichaelSoegaard/Cointegration_in_trading ⭐ 7
- **URL:** https://github.com/MichaelSoegaard/Cointegration_in_trading
- **Language:** Python
- **Description:** Cointegration test of forex pairs for spread trading
- **Backtest Results:** 
  - **Profit: 3.6% over 1 year** (2021 test set)
  - **Sharpe Ratio: 0.472**
  - Conclusion by author: "hasn't been possible to get much edge in this strategy"
  - Window size optimized: 150 (on hourly data 2010-2019)
  - Entry/exit threshold overfitting was a major challenge
- **Key Code Patterns:**
  - Mean-reversion on cointegrated spread
  - Buy one asset, sell the other (market-neutral)
  - Z-score based entry/exit thresholds
  - QuantConnect backtesting integration
- **Relevance to DESTROYER:** MEDIUM — honest assessment that cointegration spread trading has limited edge. Sharpe 0.472 is mediocre. Useful as validation that pure cointegration may not be enough.

### 5. XBT3K/MeanReversionAlgo ⭐ 9
- **URL:** https://github.com/XBT3K/MeanReversionAlgo
- **Language:** Python
- **Description:** Mean reversion on EUR/USD using z-score, Oanda API
- **Backtest Results:** Has `backtesting.py` but no documented results in README
- **Key Code Patterns:**
  - Z-score of closing prices for overbought/oversold detection
  - Configurable thresholds for entry/exit
  - Oanda API for live data and execution
- **Relevance to DESTROYER:** LOW — Python/Oanda, no MQL4, no documented profit results.

### 6. iammrmikeman/MT5EA-ForexTrading ⭐ 56
- **URL:** https://github.com/iammrmikeman/MT5EA-ForexTrading
- **Language:** C# (.NET app, not MQL5)
- **Description:** Multi-strategy forex EA with spread/hedging features
- **Structure:** Windows C# application with MT5 bridge
- **Backtest Results:** None documented
- **Relevance to DESTROYER:** LOW — not MQL4/MQL5, C# desktop app.

---

## GitHub Code Search Results

Searched for MQL4 source code containing correlation patterns:
- `iClose + correlation + EURUSD + GBPUSD + language:mql4` — **0 results**
- `Correlation + period + symbol + mql4 + expert` — **0 results**

**Conclusion:** Very few open-source MQL4 correlation EAs exist on GitHub. The space is dominated by Python implementations.

---

## Analysis: Why So Few MQL4 Correlation EAs?

1. **MT4 limitation:** MT4's `iClose()` can fetch other symbol data, but cross-symbol backtesting is notoriously unreliable in MT4 strategy tester (only tests one symbol at a time)
2. **Data quality:** Correlation strategies need synchronized multi-pair tick data, which MT4's built-in tester doesn't provide
3. **Edge decay:** Multiple sources confirm cointegration/spread strategies have lost their edge as more participants use them
4. **MT5 migration:** Serious quant traders have moved to MT5 or Python for multi-asset strategies

---

## Key Takeaways for DESTROYER QUANTUM

### What the Research Shows
1. **No open-source MQL4 EA has documented PF > 2.0 on correlation/pairs trading**
2. **Cointegration spread trading yields ~3.6% annual with Sharpe 0.47** (per MichaelSoegaard) — this is below our threshold
3. **The best correlation EA (CARA v6.3) is a trade-follower, not a signal generator** — it mirrors existing trades to correlated pairs
4. **Python implementations exist but none document strong backtest results**

### Implications for DESTROYER
- **Correlation as a standalone edge source: NOT VIABLE** based on open-source evidence
- **Correlation as a FILTER/CONFIRMATION:** More promising — use EURUSD/GBPUSD correlation state to:
  - Reduce position size when correlation breaks down (risk management)
  - Increase confidence when multiple correlated pairs confirm a signal
  - Detect regime changes (correlation breakdown = volatility incoming)
- **Mean reversion on EURUSD H4:** No documented profitable EA found (consistent with prior research)

### Recommended Next Steps
1. **Do NOT add correlation as a separate strategy** — evidence shows insufficient edge
2. **Consider correlation as a risk filter** — when EURUSD/GBPUSD correlation drops below threshold, reduce lot sizes on both
3. **Focus remaining effort on optimizing existing strategies** rather than adding correlation as a new edge source
4. **Alternative edge sources to investigate instead:**
   - Session-based volatility patterns (London/NY overlap)
   - Multi-timeframe momentum alignment
   - News sentiment integration
   - Adaptive position sizing based on recent volatility regime

---

## Search Queries Executed
- `MQL4 correlation EURUSD GBPUSD` → 13★ CARA repo found
- `MQL5 pairs trading forex` → position calculator only
- `forex spread trading EA` → 56★ iammrmikeman (C#, not MQL)
- `currency correlation expert advisor mql4` → same CARA repo
- `mean reversion EURUSD H4` → 0 results
- `pairs trading forex` → Python repos (Heptet 64★, Cointegration 7★, MeanReversion 9★)
- `correlation trading mql` → same CARA repo
- Multiple code searches → 0 MQL4 results

## Files Created
- `/home/ubuntu/destroyer-quantum/research/2026-05-26_CORRELATION_RESEARCH.md` (this file)
