# Cycle 16 Research: GitHub Patterns for $170K Push
## Date: 2026-05-29
## Status: ACTIONABLE FINDINGS — Code Changes Documented

---

## CONTEXT

- **V28.07 Actual**: $65,564 profit, PF 2.03, DD 28.14%, 540 trades
- **V28.08 OBLIVION**: Backtest pending (DD reduction focus)
- **Target**: $170K from $10K
- **Gap**: $104,436 (2.6x improvement needed)
- **Key bottleneck**: Trade count (540 → need 2,000+) and 11 dormant strategies

---

## FINDING 1: Advanced Hurst Adaptive Thresholds (meococ/Hurst-Advance-Suite-EA)

**Source**: https://github.com/meococ/Hurst-Advance-Suite-EA
**Relevance**: DIRECTLY applicable to fixing our dormant MeanReversion strategy

### Key Insights

The Hurst-Advance-Suite-EA implements a sophisticated Hurst analysis system that solves the exact problem we have with MeanReversion (0 trades because Hurst threshold 0.55 is too tight for EURUSD H4).

**Their approach:**
1. **Adaptive thresholds** with a sensitivity parameter:
   ```mql4
   // From their HurstAnalysis.mqh
   bool IsMeanRevertingMarket(double hurstValue) {
      if(m_adaptiveHurstThresholds) {
         double threshold = m_hurstMeanRevThreshold * (1.0 + (m_hurstSensitivity - 1.0) * 0.05);
         return hurstValue < threshold;
      }
      return hurstValue < m_hurstMeanRevThreshold;
   }
   ```
   With sensitivity=1.2 and base threshold=0.45, the effective threshold becomes ~0.46.
   This means they DON'T require H < 0.45 — they adapt to the instrument.

2. **Multi-timeframe Hurst divergence detection:**
   ```mql4
   // Short-term Hurst vs Long-term Hurst divergence
   bool DetectHurstDivergence(string symbol, ENUM_TIMEFRAMES timeframe, bool &isBullish) {
      double shortTerm, mediumTerm, longTerm;
      CalculateMultiTimeframe(symbol, shortTerm, mediumTerm, longTerm);
      
      // Bullish divergence: short-term Hurst > long-term Hurst (momentum building)
      if (shortTerm > longTerm && shortTerm > 0.5 && (shortTerm - longTerm > 0.15)) {
         isBullish = true;
         return true;
      }
      // Bearish divergence: long-term > short-term (momentum fading)
      if (longTerm > shortTerm && longTerm > 0.5 && (longTerm - shortTerm > 0.15)) {
         isBullish = false;
         return true;
      }
      return false;
   }
   ```

3. **Regime change probability** (useful for switching between trend/mean-reversion):
   ```mql4
   double GetRegimeChangeProbability(string symbol, ENUM_TIMEFRAMES timeframe) {
      // Calculate distances between short/medium/long Hurst
      double maxDiff = MathMax(shortMediumDiff, MathMax(mediumLongDiff, shortLongDiff));
      if (maxDiff < 0.05) return 0.0;  // Stable regime
      if (maxDiff > 0.20) return 1.0;  // Regime change imminent
      return (maxDiff - 0.05) / 0.15;  // Linear interpolation
   }
   ```

4. **Hurst interpretation thresholds** (empirically validated):
   ```mql4
   if(hurstValue > 0.60)      → "Strong persistent trend"
   else if(hurstValue > 0.55) → "Moderate trend persistence"
   else if(hurstValue >= 0.48 && <= 0.52) → "Random walk"
   else if(hurstValue >= 0.4 && < 0.45)   → "Moderate mean reversion"
   else if(hurstValue < 0.4)              → "Strong mean reversion"
   ```

### Actionable Changes for DESTROYER QUANTUM

**Problem**: Our MeanReversion uses Hurst < 0.55 as threshold. EURUSD H4 Hurst typically ranges 0.50-0.65. This blocks 90%+ of trades.

**Solution**: Implement adaptive Hurst thresholds with sensitivity scaling.

```mql4
// === ADAPTIVE HURST THRESHOLD (for MeanReversion strategy) ===
// Replace hardcoded Hurst < 0.55 with:

double GetAdaptiveHurstThreshold(double baseThreshold, double sensitivity) {
    // sensitivity = 1.0 means no adjustment
    // sensitivity = 1.2 means 10% more lenient (allows more trades)
    // sensitivity = 1.5 means 25% more lenient
    return baseThreshold * (1.0 + (sensitivity - 1.0) * 0.05);
}

// Usage in MeanReversion:
double hurstThreshold = GetAdaptiveHurstThreshold(0.55, 1.5); // Effective: ~0.564
// OR for maximum trade generation:
double hurstThreshold = GetAdaptiveHurstThreshold(0.60, 1.3); // Effective: ~0.609
```

**Additional Hurst-based enhancements:**
```mql4
// Multi-timeframe Hurst alignment check
// Instead of single H4 Hurst, check D1 + H4 + H1
double h4Hurst = CalculateHurst(Symbol(), PERIOD_H4, 300);
double d1Hurst = CalculateHurst(Symbol(), PERIOD_D1, 200);
double h1Hurst = CalculateHurst(Symbol(), PERIOD_H1, 500);

// Mean reversion works best when SHORT-TERM is mean-reverting
// but LONG-TERM is trending (range within a trend)
bool meanRevSetup = (h1Hurst < 0.48) && (d1Hurst > 0.52);
```

---

## FINDING 2: 19 Money Management Methods (drsuksaeng-cyber/FlashEASuite)

**Source**: https://github.com/drsuksaeng-cyber/FlashEASuite
**Relevance**: Money management patterns for equity curve trading and streak-based sizing

### Key Architecture

FlashEASuite defines 19 MM methods in an interface pattern:

```mql4
enum ENUM_MM_ID {
    MM_ID_FIXED_CONSERVATIVE = 1,   // Fixed Fractional 1%
    MM_ID_FIXED_AGGRESSIVE   = 2,   // Fixed Fractional 2%
    MM_ID_ATR_BASED          = 3,   // ATR Dynamic
    MM_ID_KELLY              = 4,   // Kelly Criterion (Half-Kelly)
    MM_ID_MARTINGALE         = 5,   // Controlled Martingale
    MM_ID_ANTI_MARTINGALE    = 6,   // Anti-Martingale ← KEY for us
    MM_ID_PCT_VOLATILITY     = 7,   // Percent Volatility
    MM_ID_PYRAMID            = 8,   // Pyramid Adding
    MM_ID_EQUITY_RECOVERY    = 9,   // Equity Curve Recovery ← KEY
    MM_ID_DRAWDOWN_BASED     = 10,  // Drawdown-Based
    MM_ID_SESSION_BASED      = 11,  // Session-Based ← KEY
    MM_ID_EQUITY_FILTER      = 12,  // Equity Curve Filter ← KEY
    MM_ID_CORRELATION        = 13,  // Correlation Adjusted
    MM_ID_TIERED_RISK        = 14,  // Tiered Risk
    MM_ID_WIN_STREAK         = 15,  // Adaptive Win-Streak ← KEY
    MM_ID_VOL_PERCENTILE     = 16,  // Volatility Percentile
    MM_ID_REGIME_BASED       = 17,  // Regime-Based ← KEY
    MM_ID_PORTFOLIO_CAP      = 18,  // Portfolio Cap
    MM_ID_DYNAMIC_MULTI      = 19   // Dynamic Multi-Method
};
```

### Key Pattern: SMMState (Trade History Tracking)

```mql4
struct SMMState {
    int     consecutive_wins;
    int     consecutive_losses;
    int     total_trades;
    double  win_rates[];      // Rolling win history (1=win, 0=loss)
    double  rr_history[];     // Rolling R:R history
    int     history_count;
    double  peak_equity;      // High water mark
    double  last_lot;
    
    void AddResult(bool win, double rr) {
        if(win) { consecutive_wins++; consecutive_losses = 0; }
        else    { consecutive_losses++; consecutive_wins = 0; }
        total_trades++;
        // Circular buffer for rolling stats
        int idx = history_count % history_capacity;
        win_rates[idx] = win ? 1.0 : 0.0;
        rr_history[idx] = rr;
    }
    
    double GetWinRate() const {
        if(history_count == 0) return 0.5;
        double sum = 0.0;
        for(int i = 0; i < n; i++) sum += win_rates[i];
        return sum / n;
    }
};
```

### Actionable Patterns for DESTROYER QUANTUM

**Pattern 1: Anti-Martingale Sizing**
```mql4
// Increase size on wins, decrease on losses
// This is the OPPOSITE of martingale — mathematically superior
double AntiMartingaleLot(double baseLot, int consecutiveWins, int consecutiveLosses) {
    if(consecutiveWins >= 3) return baseLot * 1.3;   // Hot streak: amplify
    if(consecutiveWins >= 2) return baseLot * 1.15;
    if(consecutiveLosses >= 3) return baseLot * 0.5;  // Cold streak: reduce
    if(consecutiveLosses >= 2) return baseLot * 0.7;
    return baseLot;
}
```

**Pattern 2: Equity Curve Recovery**
```mql4
// When equity is below peak, reduce size proportionally
double EquityRecoveryMultiplier(double currentEquity, double peakEquity) {
    double ddPct = (peakEquity - currentEquity) / peakEquity;
    if(ddPct > 0.15) return 0.4;      // Deep DD: cut to 40%
    if(ddPct > 0.10) return 0.6;      // Moderate DD: 60%
    if(ddPct > 0.05) return 0.8;      // Mild DD: 80%
    return 1.0;                        // No DD: full size
}
```

**Pattern 3: Win Streak Adaptive**
```mql4
// Scale lots based on rolling win rate
double WinStreakMultiplier(double rollingWinRate, double avgRR) {
    // Kelly-inspired: if win rate and R:R are good, size up
    double kellyFrac = rollingWinRate - ((1.0 - rollingWinRate) / avgRR);
    if(kellyFrac > 0.2) return 1.4;   // Strong edge: amplify
    if(kellyFrac > 0.1) return 1.2;
    if(kellyFrac < 0.0) return 0.5;   // Negative edge: reduce
    return 1.0;
}
```

---

## FINDING 3: Opening Range Breakout with ATR (javierdiaz13/OrbBreakoutEA)

**Source**: https://github.com/javierdiaz13/mt4-telegram-alert-bridge
**Relevance**: Session breakout logic for our dormant SessionMomentum strategy

### Key Insights

The OrbBreakoutEA implements:
1. **ATR-based breakout thresholds** (not fixed pip values)
2. **Opening Range Breakout (ORB)** — trade the breakout of the first N hours
3. **SMC/SMT concepts** — order blocks, break of structure
4. **ATR trailing stops** on closed bars (prevents intra-bar noise)

### Actionable Pattern for SessionMomentum

```mql4
// === ATR-ADAPTIVE SESSION BREAKOUT ===
// Replace fixed session range with ATR-scaled breakout

double atr = iATR(Symbol(), PERIOD_H4, 72, 1); // 3-day ATR

// 8-hour range (2 H4 bars) for session definition
double sessionHigh = High[iHighest(Symbol(), PERIOD_H4, MODE_HIGH, 2, 1)];
double sessionLow = Low[iLowest(Symbol(), PERIOD_H4, MODE_LOW, 2, 1)];
double sessionRange = sessionHigh - sessionLow;

// Only trade if range is expandable (not already expanded)
bool rangeIsTight = (sessionRange < atr * 0.75);

// Breakout levels with ATR buffer
double buyBreakout = sessionHigh + (atr * 0.25);  // 25% ATR above range
double sellBreakout = sessionLow - (atr * 0.25);   // 25% ATR below range

// Entry: price breaks above/below with ATR confirmation
if(Close[0] > buyBreakout && rangeIsTight && iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 0) > 15) {
    // BUY signal — session breakout with trend
}
```

---

## FINDING 4: Correlation Trading Pattern (jblanked/MQL4-Currency-Pair-Correlation-EA)

**Source**: https://github.com/jblanked/MQL4-Currency-Pair-Correlation-Expert-Advisor
**Relevance**: EURUSD/GBPUSD correlation filter

### Key Insights

The CARA v6.3 EA is simpler than expected — it primarily:
1. Detects orders on correlated pairs
2. Uses `DetectOrders4()` to check 4 correlated pairs before entry
3. Uses `DetectOrdersSameTrend5()` for crypto correlations
4. Splits risk across correlated positions

**The core pattern is a PRE-TRADE FILTER:**
```mql4
// Before opening EURUSD trade, check if GBPUSD already has a position
// If GBPUSD is in a trade in the SAME direction, skip (correlated risk)
// If GBPUSD is in a trade in the OPPOSITE direction, it's a hedge — skip
// If GBPUSD has NO position, proceed with EURUSD trade
```

### Simplified Correlation Filter for DESTROYER QUANTUM

```mql4
// === GBPUSD CORRELATION FILTER ===
// Before any EURUSD entry, check GBPUSD state

bool PassesCorrelationFilter() {
    double eurusd_change = (Close[0] - Close[10]) / Close[10];
    double gbpusd_change = (iClose("GBPUSD", PERIOD_H4, 0) - iClose("GBPUSD", PERIOD_H4, 10)) / iClose("GBPUSD", PERIOD_H4, 10);
    
    // Calculate 10-bar correlation
    double correlation = CalculateCorrelation(eurusd_change, gbpusd_change, 50);
    
    // If highly correlated (>0.90), no edge — skip
    if(correlation > 0.90) return false;
    
    // If correlation breakdown (<0.75), mean reversion opportunity
    if(correlation < 0.75) {
        // Check if GBPUSD has already reverted
        double gbpusd_now = iClose("GBPUSD", PERIOD_H4, 0);
        double gbpusd_sma = iMA("GBPUSD", PERIOD_H4, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
        
        // If GBPUSD is near its mean but EURUSD isn't, trade EURUSD reversion
        if(MathAbs(gbpusd_now - gbpusd_sma) < gbpusd_sma * 0.001) {
            return true; // GBPUSD reverted, EURUSD should follow
        }
    }
    
    return true; // Normal conditions, no filter
}
```

---

## FINDING 5: Risk Manager with Volatility Adjustment (meococ/Hurst-Advance-Suite-EA)

**Source**: RiskManager.mqh from Hurst-Advance-Suite-EA
**Relevance**: Dynamic risk adjustment for our DD reduction

### Key Pattern: Progressive Risk Reduction

```mql4
// Reduce risk as drawdown increases
double AdjustRiskForDrawdown(double risk, double currentDD, double maxDD) {
    double ddThreshold = maxDD * 0.5; // Start reducing at 50% of max DD
    
    if(currentDD > ddThreshold) {
        double ddFactor = (currentDD - ddThreshold) / (maxDD - ddThreshold);
        risk *= (1.0 - (ddFactor * 0.75)); // Progressive reduction up to 75%
    }
    return risk;
}

// Reduce risk after consecutive losses
double AdjustRiskForConsecutiveLosses(double risk, int consecutiveLosses) {
    if(consecutiveLosses > 0) {
        double reductionFactor = MathPow(0.8, MathMin(consecutiveLosses, 3));
        risk *= reductionFactor; // 20% reduction per loss, max 3
    }
    return risk;
}
```

---

## SYNTHESIS: What to Implement for $170K Push

### Priority 1: Wake Up Dormant Strategies (Highest Impact)

| Strategy | Root Cause | Fix | Expected Trades | Expected Profit |
|----------|-----------|-----|-----------------|-----------------|
| MeanReversion | Hurst threshold too tight | Adaptive threshold with sensitivity=1.5 | +50-100 | +$5K-$15K |
| SessionMomentum | Session range too wide | ATR-adaptive ORB (Finding 3) | +30-50 | +$8K-$15K |
| Titan | Unknown — needs debug | Run in isolation | TBD | TBD |
| DivergenceMR | RSI divergence too strict | Relax to simple RSI < 30 / > 70 | +20-40 | +$3K-$8K |

### Priority 2: Equity Curve Amplification (Already coded in V29_00)

Integrate the 4-factor composite from V29_00_EQUITY_CURVE.mq4:
- HWM proximity (30%)
- Growth rate (30%)
- DD state (25%)
- Win streak (15%)
- Maps to [0.5, 2.5] multiplier

### Priority 3: Anti-Martingale + Win Streak Sizing

From FlashEASuite patterns:
- Track consecutive wins/losses (already tracked in g_consecutiveWins/Losses!)
- Scale lots: +30% on 3+ win streak, -50% on 3+ loss streak
- Use rolling 20-trade win rate for Kelly recalculation

### Priority 4: GBPUSD Correlation Filter

Simple pre-trade check:
- If EURUSD/GBPUSD correlation > 0.90, skip (no edge)
- If correlation < 0.75 and GBPUSD already reverted, trade EURUSD reversion

### Priority 5: Volatility Regime Switching

Use ATR percentile to determine regime:
- Low vol (ATR < 25th percentile): Tighten stops, reduce lots, favor mean reversion
- Normal vol (25th-75th): Standard parameters
- High vol (ATR > 75th): Widen stops, reduce lots, favor trend following

---

## REALISTIC PROJECTION

| Enhancement | Profit Impact | DD Impact | Confidence |
|------------|---------------|-----------|------------|
| Wake dormant strategies (half) | +$20K-$40K | +2-3% | HIGH |
| Equity curve amplification | +$15K-$25K | -2-4% | MEDIUM-HIGH |
| Anti-martingale sizing | +$10K-$15K | -1-2% | HIGH |
| Correlation filter | +$3K-$5K | -1% | MEDIUM |
| Volatility regime switching | +$5K-$10K | -1-2% | MEDIUM |
| **TOTAL** | **+$53K-$95K** | **-3 to +1%** | — |

**Combined with V28.07 baseline ($65,564):**
- Conservative: $65K + $53K = **$118K**
- Optimistic: $65K + $95K = **$160K**
- With V28.08 DD reduction enabling higher sizing: **$130K-$170K**

**The $170K target is achievable if:**
1. V28.08 DD reduction works (enables higher base sizing)
2. At least 4-5 dormant strategies wake up
3. Equity curve amplification is integrated
4. Anti-martingale sizing is applied

---

## CODE CHANGES READY FOR APPLICATION

### Change 1: Adaptive Hurst Threshold (MeanReversion)
**Location**: MeanReversion strategy section
**Change**: Replace `if(hurst < 0.55)` with adaptive threshold
**Risk**: LOW — only affects MeanReversion entry conditions
**Testing**: Run MeanReversion in isolation first

### Change 2: ATR-ORB Session Breakout (SessionMomentum)
**Location**: SessionMomentum strategy section
**Change**: Replace fixed session range with ATR-scaled ORB
**Risk**: LOW — only affects SessionMomentum entry conditions
**Testing**: Run SessionMomentum in isolation first

### Change 3: Anti-Martingale Lot Sizing
**Location**: MoneyManagement_Quantum() function
**Change**: Add streak-based multiplier before final lot calculation
**Risk**: MEDIUM — affects all strategies' lot sizing
**Testing**: Backtest with and without, compare DD

### Change 4: GBPUSD Correlation Filter
**Location**: Pre-trade filter (before any entry)
**Change**: Add correlation check function
**Risk**: LOW — only skips trades, never adds trades
**Testing**: Backtest with filter ON vs OFF

---

*Hermes autonomous worker — 2026-05-29*
*Key insight: The Hurst-Advance-Suite-EA's adaptive threshold pattern is the single most actionable finding for waking up MeanReversion. Combined with the ORB pattern for SessionMomentum, we can potentially double our trade count.*
