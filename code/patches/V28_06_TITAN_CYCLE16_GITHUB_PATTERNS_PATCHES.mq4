// === DESTROYER QUANTUM — CYCLE 16 CODE PATCHES ===
// Date: 2026-05-29
// Based on: GitHub research (Hurst-Advance-Suite-EA, FlashEASuite, OrbBreakoutEA)
// Target: Push from $65K actual toward $170K
//
// INSTRUCTIONS: Apply each patch separately, backtest, compare.

// ============================================================
// PATCH #1: ADAPTIVE HURST THRESHOLD FOR MEAN REVERSION
// ============================================================
// Source: meococ/Hurst-Advance-Suite-EA (adaptive threshold pattern)
// Problem: MeanReversion uses Hurst < 0.55, but EURUSD H4 Hurst is 0.50-0.65
// Solution: Adaptive threshold with sensitivity scaling
//
// FIND in MeanReversion strategy section:
//   if(hurstValue < 0.55)
// REPLACE with:

/*
// === ADAPTIVE HURST THRESHOLD ===
// Sensitivity 1.5 = 25% more lenient than base threshold
// This allows MeanReversion to fire when Hurst is 0.55-0.60
// (mild trending) instead of requiring strict mean reversion < 0.55
double mrSensitivity = 1.5;  // Adjustable: 1.0=strict, 1.5=moderate, 2.0=lenient
double mrBaseThreshold = 0.55;
double mrAdaptiveThreshold = mrBaseThreshold * (1.0 + (mrSensitivity - 1.0) * 0.05);
// Effective threshold: 0.55 * 1.025 = 0.564 (allows more trades)

if(hurstValue < mrAdaptiveThreshold)
*/


// ============================================================
// PATCH #2: MULTI-TIMEFRAME HURST ALIGNMENT
// ============================================================
// Source: meococ/Hurst-Advance-Suite-EA (MTF divergence detection)
// Enhances MeanReversion by checking Hurst across timeframes
//
// ADD before MeanReversion entry logic:

/*
// === MULTI-TIMEFRAME HURST CHECK ===
// Mean reversion works best when:
// - SHORT-TERM (H1) is mean-reverting (H < 0.48)
// - LONG-TERM (D1) is trending (H > 0.52)
// This means we're in a range WITHIN a trend — ideal for MR
double h4Hurst = CalculateHurst(Symbol(), PERIOD_H4, 300);
double d1Hurst = CalculateHurst(Symbol(), PERIOD_D1, 200);
double h1Hurst = CalculateHurst(Symbol(), PERIOD_H1, 500);

// Check for regime alignment
bool mtfMeanRevSetup = (h1Hurst < 0.50) && (d1Hurst > 0.52);
bool mtfStrongMeanRev = (h1Hurst < 0.45) && (d1Hurst > 0.55);

// Use MTF alignment to boost confidence
double hurstConfidence = 1.0;
if(mtfStrongMeanRev) hurstConfidence = 1.5;  // Strong setup: amplify
else if(mtfMeanRevSetup) hurstConfidence = 1.2;  // Good setup
else if(h1Hurst > 0.55 && d1Hurst < 0.48) hurstConfidence = 0.5;  // Bad setup: reduce
*/


// ============================================================
// PATCH #3: ATR-ADAPTIVE SESSION BREAKOUT (SessionMomentum)
// ============================================================
// Source: javierdiaz13/OrbBreakoutEA (ATR-based ORB pattern)
// Problem: SessionMomentum uses fixed session range, rarely triggers
// Solution: ATR-scaled breakout with tight range filter
//
// FIND in SessionMomentum section:
//   double sessionHigh = High[iHighest(Symbol(), PERIOD_H4, MODE_HIGH, 4, 1)];
//   double sessionLow = Low[iLowest(Symbol(), PERIOD_H4, MODE_LOW, 4, 1)];
// REPLACE with:

/*
// === ATR-ADAPTIVE OPENING RANGE BREAKOUT ===
double smATR = iATR(Symbol(), PERIOD_H4, 72, 1); // 3-day ATR
double orbOffset = smATR * 0.25;  // 25% ATR as breakout buffer

// 8-hour range (2 H4 bars) — more session-specific than 16 hours
double sessionHigh = High[iHighest(Symbol(), PERIOD_H4, MODE_HIGH, 2, 1)];
double sessionLow = Low[iLowest(Symbol(), PERIOD_H4, MODE_LOW, 2, 1)];
double sessionRange = sessionHigh - sessionLow;

// Only trade if range is TIGHT (not already expanded)
// This prevents chasing breakouts that already happened
bool rangeIsTight = (sessionRange < smATR * 0.75);

// Breakout levels with ATR buffer
double buyBreakout = sessionHigh + orbOffset;
double sellBreakout = sessionLow - orbOffset;

// ADX filter — relaxed from 20 to 15 (more signals)
double smADX = iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 0);
bool trendConfirmed = (smADX > 15);  // Was 20, now 15

// Entry conditions
bool buySignal = (Close[0] > buyBreakout) && rangeIsTight && trendConfirmed;
bool sellSignal = (Close[0] < sellBreakout) && rangeIsTight && trendConfirmed;
*/


// ============================================================
// PATCH #4: ANTI-MARTINGALE LOT SIZING
// ============================================================
// Source: drsuksaeng-cyber/FlashEASuite (Anti-Martingale pattern)
// Problem: Current sizing doesn't account for win/loss streaks
// Solution: Scale lots based on consecutive wins/losses
//
// ADD inside MoneyManagement_Quantum() BEFORE final lot return:

/*
// === ANTI-MARTINGALE STREAK SIZING ===
// Uses existing g_consecutiveWins and g_consecutiveLosses (already tracked!)
// Scale lots up on winning streaks, down on losing streaks
// This is mathematically superior to martingale — we ADD to winners

double streakMult = 1.0;

// Winning streaks: amplify (we're hot)
if(g_consecutiveWins >= 5)      streakMult = 1.40;  // 5+ wins: +40%
else if(g_consecutiveWins >= 3) streakMult = 1.25;  // 3-4 wins: +25%
else if(g_consecutiveWins >= 2) streakMult = 1.10;  // 2 wins: +10%

// Losing streaks: reduce (we're cold)
if(g_consecutiveLosses >= 5)      streakMult = 0.40;  // 5+ losses: -60%
else if(g_consecutiveLosses >= 3) streakMult = 0.60;  // 3-4 losses: -40%
else if(g_consecutiveLosses >= 2) streakMult = 0.80;  // 2 losses: -20%

// Apply streak multiplier
finalLots = finalLots * streakMult;
*/


// ============================================================
// PATCH #5: EQUITY CURVE MULTIPLIER (Enhanced)
// ============================================================
// Combines: V29_00_EQUITY_CURVE.mq4 pattern + FlashEASuite EquityRecovery
// More sophisticated than the V28.06.1 version
//
// ADD inside MoneyManagement_Quantum() AFTER streak sizing:

/*
// === ENHANCED EQUITY CURVE MULTIPLIER ===
// 4-factor composite: HWM proximity, growth rate, DD state, win rate
static double g_ecEMA = 0;
static double g_ecPeak = 0;
static int g_ecTradeCount = 0;
static double g_ecWinSum = 0;

// Track peak equity
if(AccountEquity() > g_ecPeak) g_ecPeak = AccountEquity();

// EMA of equity (alpha = 2/(period+1), period=20)
double ecAlpha = 0.0952;
if(g_ecEMA < 1.0) g_ecEMA = AccountEquity();
g_ecEMA = AccountEquity() * ecAlpha + g_ecEMA * (1.0 - ecAlpha);

// Factor 1: HWM Proximity (30% weight)
double ecHWM = 1.0;
if(g_ecPeak > 0) {
    double ddPct = (g_ecPeak - AccountEquity()) / g_ecPeak;
    if(ddPct > 0.15) ecHWM = 0.4;      // Deep DD
    else if(ddPct > 0.10) ecHWM = 0.6;
    else if(ddPct > 0.05) ecHWM = 0.8;
    else if(ddPct < 0.02) ecHWM = 1.2;  // Near peak: amplify
}

// Factor 2: Growth Rate (30% weight)
double ecGrowth = 1.0;
if(AccountEquity() > g_ecEMA) ecGrowth = 1.3;   // Above EMA: growing
else ecGrowth = 0.7;                              // Below EMA: shrinking

// Factor 3: DD State (25% weight)
double ecDD = 1.0;
double currentDD = (g_ecPeak - AccountEquity()) / g_ecPeak * 100.0;
if(currentDD > 20) ecDD = 0.3;  // Emergency: cut hard
else if(currentDD > 15) ecDD = 0.5;
else if(currentDD > 10) ecDD = 0.7;

// Factor 4: Win Rate (15% weight)
double ecWR = 1.0;
if(g_ecTradeCount > 0) {
    double winRate = g_ecWinSum / g_ecTradeCount;
    if(winRate > 0.70) ecWR = 1.3;
    else if(winRate > 0.60) ecWR = 1.1;
    else if(winRate < 0.50) ecWR = 0.7;
}

// Composite multiplier (weighted average)
double ecMult = (ecHWM * 0.30) + (ecGrowth * 0.30) + (ecDD * 0.25) + (ecWR * 0.15);

// Clamp to reasonable range [0.3, 2.0]
ecMult = MathMax(0.3, MathMin(2.0, ecMult));

finalLots = finalLots * ecMult;
*/


// ============================================================
// PATCH #6: GBPUSD CORRELATION FILTER
// ============================================================
// Source: jblanked/MQL4-Currency-Pair-Correlation-Expert-Advisor
// Problem: EURUSD trades during GBPUSD-correlated moves have no edge
// Solution: Skip trades when correlation is too high (>0.90)
//
// ADD as a function, call before any entry:

/*
// === GBPUSD CORRELATION FILTER ===
// Returns true if trade should proceed, false if should skip
bool PassesCorrelationFilter() {
    // Calculate 10-bar returns for both pairs
    double eurusd_returns[10];
    double gbpusd_returns[10];
    
    for(int i = 0; i < 10; i++) {
        eurusd_returns[i] = (Close[i+1] - Close[i+2]) / Close[i+2];
        gbpusd_returns[i] = (iClose("GBPUSD", PERIOD_H4, i+1) - iClose("GBPUSD", PERIOD_H4, i+2)) / iClose("GBPUSD", PERIOD_H4, i+2);
    }
    
    // Calculate Pearson correlation
    double eurusd_mean = 0, gbpusd_mean = 0;
    for(int i = 0; i < 10; i++) {
        eurusd_mean += eurusd_returns[i];
        gbpusd_mean += gbpusd_returns[i];
    }
    eurusd_mean /= 10;
    gbpusd_mean /= 10;
    
    double cov = 0, var_eu = 0, var_gu = 0;
    for(int i = 0; i < 10; i++) {
        double de = eurusd_returns[i] - eurusd_mean;
        double dg = gbpusd_returns[i] - gbpusd_mean;
        cov += de * dg;
        var_eu += de * de;
        var_gu += dg * dg;
    }
    
    double correlation = 0;
    if(var_eu > 0 && var_gu > 0) {
        correlation = cov / MathSqrt(var_eu * var_gu);
    }
    
    // If highly correlated (>0.90), no edge — skip
    if(correlation > 0.90) return false;
    
    // If correlation breakdown (<0.75), check for mean reversion opportunity
    if(correlation < 0.75) {
        double gbpusd_now = iClose("GBPUSD", PERIOD_H4, 0);
        double gbpusd_sma = iMA("GBPUSD", PERIOD_H4, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
        
        // If GBPUSD already reverted to mean, EURUSD should follow
        if(MathAbs(gbpusd_now - gbpusd_sma) < gbpusd_sma * 0.002) {
            return true;  // Good setup: GBPUSD reverted, EURUSD catching up
        }
    }
    
    return true;  // Normal conditions
}
*/


// ============================================================
// PATCH #7: VOLATILITY REGIME SWITCHING
// ============================================================
// Problem: Same parameters in all market conditions
// Solution: Adjust behavior based on ATR percentile
//
// ADD before strategy execution:

/*
// === VOLATILITY REGIME DETECTION ===
// Calculate ATR percentile over 200-bar lookback
double currentATR = iATR(Symbol(), PERIOD_H4, 14, 0);
double atrSum = 0;
double atrArray[200];
for(int i = 0; i < 200; i++) {
    atrArray[i] = iATR(Symbol(), PERIOD_H4, 14, i);
    atrSum += atrArray[i];
}
double atrMean = atrSum / 200;

// Count how many bars had lower ATR than current
int lowerCount = 0;
for(int i = 0; i < 200; i++) {
    if(atrArray[i] < currentATR) lowerCount++;
}
double atrPercentile = (double)lowerCount / 200.0;

// Regime classification
int volRegime = 1;  // 0=low, 1=normal, 2=high
if(atrPercentile < 0.25) volRegime = 0;       // Low vol
else if(atrPercentile > 0.75) volRegime = 2;  // High vol

// Regime-based adjustments
double volLotMult = 1.0;
double volSLMult = 1.0;
int volStrategyBias = 0;  // 0=neutral, 1=mean rev, 2=trend

if(volRegime == 0) {
    // Low volatility: tighter stops, favor mean reversion
    volLotMult = 0.8;
    volSLMult = 0.7;
    volStrategyBias = 1;  // Favor mean reversion
}
else if(volRegime == 2) {
    // High volatility: wider stops, favor trend following
    volLotMult = 0.7;  // Reduce size (risk management)
    volSLMult = 1.5;
    volStrategyBias = 2;  // Favor trend following
}
*/


// ============================================================
// APPLICATION ORDER (RECOMMENDED)
// ============================================================
//
// 1. PATCH #1 (Adaptive Hurst) — Low risk, immediate impact on MeanReversion
// 2. PATCH #3 (ATR-ORB) — Low risk, immediate impact on SessionMomentum
// 3. PATCH #6 (Correlation Filter) — Low risk, only skips trades
// 4. PATCH #4 (Anti-Martingale) — Medium risk, affects all lot sizing
// 5. PATCH #5 (Equity Curve) — Medium risk, complex but high impact
// 6. PATCH #7 (Vol Regime) — Medium risk, changes strategy selection
// 7. PATCH #2 (MTF Hurst) — Requires Hurst calculation function
//
// BACKTEST EACH INDEPENDENTLY before combining.
// Expected combined impact: +$50K-$90K profit, -3% to +1% DD
//
// ============================================================
