// === DESTROYER QUANTUM — READY-TO-APPLY PATCHES ===
// Date: 2026-05-27
// For: V28.06 TITAN
// Purpose: Push from $138K projected to $170K target
//
// INSTRUCTIONS: Apply these changes to DESTROYER_QUANTUM_V28_06_TITAN.mq4
// Then backtest each change individually to isolate impact.

// ============================================================
// FIX #1: ARRAY SIZE BUG FIX (CRITICAL — DO FIRST)
// ============================================================
// FIND this line (around line 100-200, in global declarations):
//   double g_stratProfits[15][60];
// REPLACE with:
//   double g_stratProfits[17][60];
//
// WHY: Strategies with index 15 (StructuralRetest) and 16 (Silicon-X)
// cause buffer overflow. This is a crash bug.


// ============================================================
// FIX #2: EQUITY CURVE TRADING OVERLAY
// ============================================================
// LOCATION: Inside MoneyManagement_Quantum() function (line ~12829)
// FIND: The line that calculates finalLots (after DD-based reduction)
// INSERT the following code BEFORE the final return/lot calculation:

/*
// === EQUITY CURVE TRADING OVERLAY (V28.06.1) ===
// Tracks equity EMA(20) to determine bull/bear regime
// Bull: amplify lots 1.3x | Bear: reduce 0.6x | DD defense: 0.4x
static double g_ecEMA = 0;
static double g_ecPeak = 0;

// Track peak equity for drawdown defense
if(AccountEquity() > g_ecPeak) g_ecPeak = AccountEquity();

// EMA of equity (alpha = 2/(period+1), period=20)
double ecAlpha = 0.0952; // 2.0 / 21.0
if(g_ecEMA < 1.0) g_ecEMA = AccountEquity(); // Initialize
g_ecEMA = AccountEquity() * ecAlpha + g_ecEMA * (1.0 - ecAlpha);

double ecMult = 1.0;
if(AccountEquity() < g_ecPeak * 0.90) {
    ecMult = 0.40;  // Deep drawdown: cut to 40%
} else if(AccountEquity() < g_ecEMA) {
    ecMult = 0.60;  // Below EMA: reduce to 60%
} else {
    ecMult = 1.30;  // Above EMA: amplify to 130%
}

// Apply equity curve multiplier
finalLots = finalLots * ecMult;

// Ensure minimum lot size
if(finalLots < MarketInfo(Symbol(), MODE_MINLOT))
    finalLots = MarketInfo(Symbol(), MODE_MINLOT);
*/


// ============================================================
// FIX #3: KELLY CONSOLIDATION
// ============================================================
// FIND CalculateKellyFraction() function (line ~3653)
// REPLACE its body with:

/*
double CalculateKellyFraction(int strategyIndex) {
    // Delegate to rolling Kelly (the GOOD implementation)
    return CalculateRollingKelly(strategyIndex);
}
*/

// FIND GetKellyLotSize() function (line ~5055)
// Add this comment at the top:
//   // DEPRECATED: Uses hardcoded stats. Use MoneyManagement_Quantum() instead.
//   // This function is dead code — not called by any V28.00+ strategy.


// ============================================================
// FIX #4: SESSION MOMENTUM ATR-ORB ENHANCEMENT
// ============================================================
// LOCATION: Inside ExecuteSessionMomentum() function (line ~9267)
// FIND: The session range calculation:
//   double sessionHigh = High[iHighest(Symbol(), PERIOD_H4, MODE_HIGH, 4, 1)];
//   double sessionLow = Low[iLowest(Symbol(), PERIOD_H4, MODE_LOW, 4, 1)];
// REPLACE with:

/*
// ATR-based Opening Range Breakout (JamesORB pattern)
double smATR = iATR(Symbol(), PERIOD_H4, 72, 1);
double orbOffset = smATR * 0.5; // 50% of ATR as breakout threshold

// 8-hour range (2 H4 bars) — more session-specific than 16 hours
double sessionHigh = High[iHighest(Symbol(), PERIOD_H4, MODE_HIGH, 2, 1)];
double sessionLow = Low[iLowest(Symbol(), PERIOD_H4, MODE_LOW, 2, 1)];

// Breakout levels include ATR offset
double buyBreakout = sessionHigh + orbOffset;
double sellBreakout = sessionLow - orbOffset;

// ATR-based SL/TP (from JamesORB research)
double atrSL = smATR * 1.65;  // 1.65x ATR stop
double atrTP = smATR * 2.50;  // 2.50x ATR target (1.5:1 R:R)
*/


// ============================================================
// FIX #5: DIVERGENCEMR ACTUAL DIVERGENCE DETECTION
// ============================================================
// LOCATION: Inside ExecuteDivergenceMR() function (line ~9345)
// FIND: The oversold/overbought check:
//   bool isOversold = (rsi_1 < 35);
//   bool isOverbought = (rsi_1 > 65);
// REPLACE with actual divergence detection:

/*
// === ACTUAL RSI DIVERGENCE DETECTION ===
// Look back 20 bars for swing lows/highs
int lookbackBars = 20;
int recentBars = 3;  // Recent swing must be within last 3 bars

// Find lowest low and its bar index in last 20 bars
int lowBar1 = iLowest(Symbol(), PERIOD_H4, MODE_LOW, lookbackBars, recentBars);
int lowBar2 = iLowest(Symbol(), PERIOD_H4, MODE_LOW, lookbackBars, recentBars + 5);

double priceLow1 = iLow(Symbol(), PERIOD_H4, lowBar1);
double priceLow2 = iLow(Symbol(), PERIOD_H4, lowBar2);
double rsiLow1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, lowBar1);
double rsiLow2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, lowBar2);

// Find highest high and its bar index
int highBar1 = iHighest(Symbol(), PERIOD_H4, MODE_HIGH, lookbackBars, recentBars);
int highBar2 = iHighest(Symbol(), PERIOD_H4, MODE_HIGH, lookbackBars, recentBars + 5);

double priceHigh1 = iHigh(Symbol(), PERIOD_H4, highBar1);
double priceHigh2 = iHigh(Symbol(), PERIOD_H4, highBar2);
double rsiHigh1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, highBar1);
double rsiHigh2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, highBar2);

// Bullish divergence: price lower low + RSI higher low
bool bullishDivergence = (priceLow1 < priceLow2) && (rsiLow1 > rsiLow2) && (rsiLow1 < 40);

// Bearish divergence: price higher high + RSI lower high
bool bearishDivergence = (priceHigh1 > priceHigh2) && (rsiHigh1 < rsiHigh2) && (rsiHigh1 > 60);

// Combined with BB overextension
double bbUpper = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);
double bbLower = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);

bool isOversold = bullishDivergence && (Close[1] < bbLower);
bool isOverbought = bearishDivergence && (Close[1] > bbUpper);
*/


// ============================================================
// VERIFICATION CHECKLIST
// ============================================================
// After applying each fix:
// [ ] Compile in MetaEditor (zero errors/warnings)
// [ ] Backtest 2020-01-01 to 2024-12-31 on EURUSD H4
// [ ] Compare: Net Profit, PF, DD, Trade Count vs baseline
// [ ] If DD > 35%, reduce ecMult in Fix #2 (0.40 → 0.50, 0.60 → 0.70)
// [ ] If PF < 1.5, revert that specific fix
//
// ORDER OF APPLICATION:
// 1. Fix #5 (array size) — 5 min, zero risk
// 2. Fix #3 (Kelly cleanup) — 1 hr, low risk
// 3. Fix #2 (equity curve) — 2 hr, low risk
// 4. Backtest #1-3 combined
// 5. Fix #4 (Session ATR-ORB) — 2 hr, medium risk
// 6. Fix #5 (DivergenceMR) — 3 hr, medium risk
// 7. Backtest #4-5 combined
// 8. Final backtest with ALL fixes
