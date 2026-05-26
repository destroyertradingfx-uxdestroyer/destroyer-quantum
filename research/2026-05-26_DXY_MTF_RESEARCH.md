# DXY CORRELATION + MULTI-TIMEFRAME RESEARCH
## Date: 2026-05-26
## Purpose: Patterns for DESTROYER QUANTUM $170K path

---

## 1. DXY (DOLLAR INDEX) CORRELATION FILTER

### Concept
EURUSD and DXY have -0.90 to -0.95 correlation (strong inverse). When DXY is trending up,
EURUSD trends down. Using DXY as a directional filter can improve entry quality.

### MQL4 Implementation
```mql4
// Access DXY via USD index proxy (not directly available on all brokers)
// Option 1: Use EURUSD inverse as proxy
double GetDXYBias() {
   // Use D1 EMA crossover on EURUSD as DXY proxy
   double ema20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   if(ema20 > ema50) return 1.0;   // EURUSD bullish = DXY bearish
   if(ema20 < ema50) return -1.0;  // EURUSD bearish = DXY bullish
   return 0.0;                      // Neutral
}

// Option 2: If broker has USDIndex symbol
double GetDXYValue() {
   return iClose("USDIndex", PERIOD_H4, 0);  // Check symbol name on broker
}

// Filter: Only trade in direction of D1 trend
bool IsD1TrendAligned(int tradeDirection) {
   double bias = GetDXYBias();
   if(bias == 0) return true;  // Neutral = allow
   return (tradeDirection == OP_BUY && bias > 0) || 
          (tradeDirection == OP_SELL && bias < 0);
}
```

### Integration
Add to ExecutePhantomStrategy(), ExecuteNoiseBreakout(), ExecuteSessionMomentum():
```mql4
// Before entry:
if(!IsD1TrendAligned(OP_BUY)) return;  // Block counter-trend entries
```

### Expected Impact
- Filters ~30-40% of counter-trend entries
- Improves PF by 0.1-0.3 on trend-following strategies
- May reduce trade count by 20-30%

### Risk
MEDIUM. Mean-reversion strategies (MeanReversion, DivergenceMR) should NOT use this filter
—they specifically trade against the trend.

---

## 2. MULTI-TIMEFRAME (MTF) D1 TREND FILTER

### Concept
Use Daily (D1) trend as a higher-timeframe filter for H4 entries. If D1 is bullish, only
take BUY signals on H4. If D1 is bearish, only take SELL signals.

### Why It Works
H4 strategies often get caught in counter-trend moves that look like setups but are actually
pullbacks in a larger trend. D1 filter keeps trades aligned with the dominant direction.

### Implementation (Bias Variable Pattern — V29.00 Lesson)
```mql4
// Global bias variable (NOT early return — preserves trailing stops)
int g_d1TrendBias = 0;  // 1 = BUY, -1 = SELL, 0 = NEUTRAL

void UpdateD1TrendBias() {
   double ema20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double adx = iADX(Symbol(), PERIOD_D1, 14, PRICE_CLOSE, MODE_MAIN, 0);
   
   if(adx < 20) {
      g_d1TrendBias = 0;  // No clear trend = allow all trades
   } else if(ema20 > ema50) {
      g_d1TrendBias = 1;  // Bullish
   } else {
      g_d1TrendBias = -1; // Bearish
   }
}

// In OnNewBar():
UpdateD1TrendBias();

// In strategy functions (example for SessionMomentum):
void ExecuteSessionMomentum() {
   // ... existing logic ...
   
   // MTF filter: only trade with D1 trend
   if(g_d1TrendBias != 0 && tradeDirection != g_d1TrendBias) return;
   
   // ... rest of logic ...
}
```

### Critical: Use Bias Variable, NOT Early Return
Early `return` from OnNewBar() kills trailing stops and management for ALL strategies.
The bias variable pattern lets strategies check the bias before entering while trails
and management still run for existing positions. (V29.00 lesson)

### Expected Impact
- Blocks ~30-40% of counter-trend entries
- Improves PF by 0.1-0.3
- Reduces trade count by 20-30%
- **WARNING:** V29.00 used early return and killed 75% of trades. Must use bias variable.

---

## 3. SESSION TIME-OF-DAY SEASONALITY

### EURUSD H4 Session Analysis (From Data)
| Hour (UTC) | Avg Return | Bullish % | Volatility | Assessment |
|------------|-----------|-----------|------------|------------|
| 00:00 | -0.2 pip | 48.1% | Low | Asian dead zone |
| 04:00 | -0.4 pip | 47.7% | Low | WORST hour |
| 08:00 | +0.3 pip | 50.2% | Rising | London open |
| 12:00 | +0.7 pip | 50.7% | High | NY overlap |
| 16:00 | +0.4 pip | 50.1% | Falling | London fix |
| 20:00 | +1.0 pip | 52.4% | Low | BEST hour (Sydney) |

### Application
- **Best hours for trend strategies:** 08:00-16:00 UTC (London + NY)
- **Best hour for mean reversion:** 20:00 UTC (Sydney — low vol, mean-reverting)
- **Avoid:** 00:00-06:00 UTC (Asian dead zone — low vol, random)
- **Current TITAN filter:** 6-20 UTC — already good, but could be more granular

### Time-Based Strategy Routing
```mql4
int GetOptimalSessionStrategy() {
   int utcHour = GetUTCHour();
   
   if(utcHour >= 7 && utcHour <= 11) return STRATEGY_SESSION_MOMENTUM;  // London
   if(utcHour >= 12 && utcHour <= 16) return STRATEGY_NOISE_BREAKOUT;   // NY overlap
   if(utcHour >= 20 || utcHour <= 2)  return STRATEGY_MEAN_REVERSION;   // Sydney
   return STRATEGY_ANY;  // Default
}
```

---

## 4. CORRELATION STRATEGY (EURUSD/GBPUSD)

### Concept
EURUSD and GBPUSD are 85-95% correlated. When correlation breaks temporarily, it creates
mean-reversion opportunities.

### Implementation (Single-Pair Simplification)
Rather than trading both pairs (complex), use GBPUSD as a LEADING indicator for EURUSD:
```mql4
double GetGBPUSDBias() {
   // If GBPUSD already reverted to mean, EURUSD likely to follow
   double gbpusd_rsi = iRSI("GBPUSD", PERIOD_H4, 14, PRICE_CLOSE, 0);
   
   if(gbpusd_rsi > 70) return -1.0;  // GBPUSD overbought = EURUSD may fall
   if(gbpusd_rsi < 30) return 1.0;   // GBPUSD oversold = EURUSD may rise
   return 0.0;
}
```

### Risk
MEDIUM-HIGH. Correlation can break for fundamental reasons (Brexit, ECB divergence).
Best used as a CONFIRMATION filter, not a primary signal.

---

## 5. KAUFMAN EFFICIENCY RATIO (Detailed)

### Already documented in comprehensive research. Key addition:

### Adaptive Thresholds
```mql4
// Instead of fixed ER thresholds, use dynamic ones based on recent volatility
double GetAdaptiveERThreshold(int period = 20) {
   double atr = iATR(Symbol(), PERIOD_H4, 14, 0);
   double atrAvg = iATR(Symbol(), PERIOD_H4, 100, 0);
   double volRatio = atr / atrAvg;
   
   // In high vol: require higher ER for breakouts (more noise)
   // In low vol: lower ER threshold (less noise = cleaner signals)
   if(volRatio > 1.5) return 0.35;  // High vol: stricter
   if(volRatio < 0.7) return 0.20;  // Low vol: looser
   return 0.25;                      // Normal: default
}
```

---

## FILES

- `research/2026-05-26_COMPREHENSIVE_170K_RESEARCH.md` — Main synthesis
- `research/2026-05-26_ADVANCED_TRAILING_RESEARCH.md` — Trailing stop patterns
- This file — DXY/MTF/session patterns

---

*VENI VIDI VICI* 🔷
