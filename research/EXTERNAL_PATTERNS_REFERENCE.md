# EXTERNAL RESEARCH: Key Patterns from GitHub
## Date: 2026-05-28
## Purpose: Reference patterns for DESTROYER QUANTUM improvements

---

## 1. MULTI-TIMEFRAME HURST (meococ/Hurst-Advance-Suite-EA)

### Pattern: 3-Timeframe Hurst Alignment

```mql4
// Calculate Hurst at three timeframes
double shortTermHurst  = CalculateHurstExponent(Symbol(), Period(), 30);
double mediumTermHurst = CalculateHurstExponent(Symbol(), Period(), 60);
double longTermHurst   = CalculateHurstExponent(Symbol(), Period(), 100);

// Alignment detection
bool hurstAlignedTrend    = (longTermHurst > 0.55 && mediumTermHurst > 0.55);
bool hurstAlignedReversal = (longTermHurst < 0.45);

// Regime-based strategy selection
if(hurstAlignedTrend) {
    // TRENDING: Boost trend strategies, reduce MR
    // Signal threshold: 0.4 (need stronger signals)
    // Min confirmation signals: 2 (Hurst is confident)
} else if(hurstAlignedReversal) {
    // MEAN-REVERTING: Boost MR strategies
    // Signal threshold: 0.15 (accept weaker signals)
    // Min confirmation signals: 4 (need more confirmation)
} else {
    // NOISE/RANGE: Balanced allocation
    // Signal threshold: 0.2 (standard)
    // Min confirmation signals: 3 (standard)
}
```

### Pattern: Hurst-Based Weight Adjustment

```mql4
// Adjust indicator weights based on market regime
switch(marketMode) {
    case MARKET_MODE_TRENDING:
        hurstWeight = 1.5;      // Trust Hurst more in trends
        trendlineWeight = 1.3;
        rsiWeight = 0.7;        // RSI less reliable in trends
        if(hurstExponent > 0.6) {
            hurstWeight = 1.8;   // Strong trend = high Hurst confidence
            rsiWeight = 0.5;     // RSI very unreliable
        }
        break;
        
    case MARKET_MODE_RANGING:
        patternWeight = 1.3;    // Patterns more reliable in ranges
        wyckoffWeight = 1.4;
        hurstWeight = 0.8;      // Hurst less useful in ranges
        if(hurstExponent > 0.45 && hurstExponent < 0.55) {
            rsiWeight = 1.3;    // RSI great in ranges
        }
        break;
        
    case MARKET_MODE_REVERSAL:
        rsiWeight = 1.5;        // RSI critical for reversals
        patternWeight = 1.4;
        if(hurstExponent < 0.42) {
            hurstWeight = 1.4;  // Low Hurst = strong reversal signal
            rsiWeight = 1.7;
        }
        break;
}
```

### Pattern: Hurst Multiplier on Signal Score

```mql4
double hurstMultiplier = 1.0;
if(hurstExponent > 0.6) {
    // Strong trend: amplify WITH-trend signals, dampen counter-trend
    if((normalizedScore > 0 && hurstScore > 0) || 
       (normalizedScore < 0 && hurstScore < 0)) {
        hurstMultiplier = 1.0 + (hurstExponent - 0.6) * 2.0; // Up to 1.8x
    } else {
        hurstMultiplier = 1.0 - (hurstExponent - 0.6) * 1.5; // Down to 0.4x
    }
} else if(hurstExponent < 0.4) {
    // Strong reversal: amplify counter-trend signals
    if((normalizedScore > 0 && hurstScore < 0) || 
       (normalizedScore < 0 && hurstScore > 0)) {
        hurstMultiplier = 1.0 + (0.4 - hurstExponent) * 2.0; // Up to 1.8x
    }
}
```

---

## 2. 6-FACTOR GENIUS SIZING (francomascareloai/EA_SCALPER_XAUUSD)

### Pattern: Session-Aware Position Scaling

```mql4
double GetSessionMultiplier() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int gmt_hour = (dt.hour - gmt_offset + 24) % 24;
    
    // London/NY Overlap: BEST liquidity
    if(gmt_hour >= 12 && gmt_hour < 16) return 1.20;
    // London Session: Good institutional flow
    if(gmt_hour >= 7 && gmt_hour < 12)  return 1.10;
    // NY Session: Good volume
    if(gmt_hour >= 16 && gmt_hour < 21) return 1.00;
    // Late NY: Liquidity thinning
    if(gmt_hour >= 21 || gmt_hour < 1)  return 0.70;
    // Asian: Wide spreads, choppy
    if(gmt_hour >= 1 && gmt_hour < 7)   return 0.50;
    
    return 1.0;
}
```

### Pattern: Win/Loss Streak Momentum

```mql4
double GetMomentumMultiplier() {
    // WINNING STREAK
    if(consecutive_wins >= 4)  return 1.15;  // +15%
    if(consecutive_wins >= 2)  return 1.08;  // +8%
    
    // LOSING STREAK (aggressive protection)
    if(consecutive_losses >= 4) return 0.40;  // -60%
    if(consecutive_losses >= 3) return 0.55;  // -45%
    if(consecutive_losses >= 2) return 0.70;  // -30%
    if(consecutive_losses >= 1) return 0.85;  // -15%
    
    return 1.0;
}
```

### Pattern: Profit Protection Ratchet

```mql4
double GetProfitRatchetMultiplier() {
    if(daily_profit_percent <= 0.0) return 1.0;
    
    // The more you're up, the more you protect
    if(daily_profit_percent >= 3.0) return 0.50;  // Coast mode
    if(daily_profit_percent >= 2.0) return 0.65;  // Conservative
    if(daily_profit_percent >= 1.0) return 0.80;  // Slightly cautious
    if(daily_profit_percent >= 0.5) return 0.90;  // Small buffer
    
    return 1.0;
}
```

### Pattern: 6-Factor Combined Formula

```mql4
double CalculateGeniusRisk() {
    double base_risk = GetDrawdownAdjustedRisk();  // Kelly + DD
    double session   = GetSessionMultiplier();
    double momentum  = GetMomentumMultiplier();
    double ratchet   = GetProfitRatchetMultiplier();
    
    double genius_risk = base_risk * session * momentum * ratchet;
    
    // Safety clamps
    genius_risk = MathMax(0.1, MathMin(1.5, genius_risk));
    
    return genius_risk;
}
```

---

## 3. KEY TAKEAWAYS FOR DESTROYER QUANTUM

1. **Multi-TF Hurst > Single Hurst:** Using 30/60/100-bar Hurst together gives better regime detection than single 100-bar Hurst.

2. **Session timing matters A LOT for EURUSD:** London/NY overlap trades are 20% better than Asian session trades. Scale lots accordingly.

3. **Streak-based sizing is powerful:** Cut losers aggressively (40% after 4 losses), amplify winners slightly (115% after 4 wins). Asymmetric = positive EV.

4. **Profit ratchet prevents giveback:** When up 3%+ for the day, cut to 50% size. Protects the psychological win.

5. **Equity curve overlay is the single biggest lever:** The V29 implementation (0.5x-2.5x range) combined with session + momentum could add $30-50K.
