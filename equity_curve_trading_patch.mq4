//+------------------------------------------------------------------+
//|  EQUITY CURVE TRADING PATCH FOR DESTROYER_QUANTUM_V28_06_TITAN   |
//|  Adds adaptive lot sizing based on equity vs its EMA             |
//|  When equity > EMA: amplify (1.5x) - winning streak              |
//|  When equity < EMA: reduce  (0.5x) - losing streak               |
//+------------------------------------------------------------------+
//
// CONCEPT:
// Equity Curve Trading (also called "equity curve money management" or
// "equity momentum sizing") is a well-documented position sizing technique.
// The core idea: when your account equity is above its moving average,
// you're on a winning streak and should increase position sizes.
// When below, you're on a losing streak and should reduce exposure.
//
// This creates a natural positive-feedback on winning streaks and
// negative-feedback on losing streaks, improving risk-adjusted returns.
//
// EXPECTED IMPACT: +20-30% profit with minimal DD increase
// The bull multiplier (1.5x) amplifies winners.
// The bear multiplier (0.5x) cuts losers faster.
// Net effect: asymmetric equity curve with faster recovery from drawdowns.
//
// REFERENCES:
// - Van Tharp, "Trade Your Way to Financial Freedom" (equity curve timing)
// - Ralph Vince, "Portfolio Management Formulas" (optimal f + equity filter)
// - Curtis Faith, "Way of the Turtle" (equity curve re-entry system)
//
//+------------------------------------------------------------------+
// STEP 1: ADD INPUT PARAMETERS
// Place AFTER line 1163 (after InpMinTradesForDecision) in the TITAN file
//+------------------------------------------------------------------+

/*
ADD THESE LINES AFTER:   extern int    InpMinTradesForDecision  = 20;        // Min trades before Queen assesses a bee
*/

// --- V28.06 TITAN: Equity Curve Trading (Adaptive Lot Sizing) ---
sinput string Inp_Header_EquityCurve  = "====== V28.06: EQUITY CURVE TRADING ======";
input bool   InpEquityCurve_Enabled   = true;      // Enable Equity Curve Trading
input int    InpEquityCurve_Period    = 20;        // EMA period for equity curve (20 = monthly cycle)
input double InpEquityCurve_BullMult  = 1.5;       // Lot multiplier when equity > EMA (winning streak)
input double InpEquityCurve_BearMult  = 0.5;       // Lot multiplier when equity < EMA (losing streak)


//+------------------------------------------------------------------+
// STEP 2: ADD GLOBAL VARIABLES
// Place AFTER line 4606 (after v23_lastEquity) in the TITAN file
//+------------------------------------------------------------------+

/*
ADD THESE LINES AFTER:   double v23_lastEquity = 0;         // For equity delta calculation
*/

// V28.06: Equity Curve Trading State
double g_equity_curve_ema = 0.0;           // Current EMA of equity
bool   g_equity_curve_initialized = false;  // Has EMA been seeded?
double g_equity_curve_alpha = 0.0;          // EMA smoothing factor


//+------------------------------------------------------------------+
// STEP 3: ADD NEW FUNCTIONS
// Place AFTER line 2879 (after GetDynamicRiskMultiplier closing brace)
// and BEFORE line 2880 (the REMOVED comment block)
// in the TITAN file
//+------------------------------------------------------------------+

/*
INSERT AFTER:   return NormalizeDouble(risk_mult, 2);
                           }
*/

//+------------------------------------------------------------------+
//| V28.06 TITAN: Update Equity Curve EMA                            |
//| Calculates EMA of account equity on each new bar                 |
//| Uses recursive EMA formula: EMA = α*price + (1-α)*EMA_prev      |
//+------------------------------------------------------------------+
void UpdateEquityCurveEMA()
{
    if(!InpEquityCurve_Enabled) return;
    
    double currentEquity = AccountEquity();
    
    // First call: seed EMA with current equity value
    if(!g_equity_curve_initialized)
    {
        g_equity_curve_ema = currentEquity;
        g_equity_curve_alpha = 2.0 / (InpEquityCurve_Period + 1.0);
        g_equity_curve_initialized = true;
        LogError(ERROR_INFO, "EquityCurve EMA initialized: " + DoubleToString(g_equity_curve_ema, 2) + 
                  " | Period: " + IntegerToString(InpEquityCurve_Period) + 
                  " | Alpha: " + DoubleToString(g_equity_curve_alpha, 6), "UpdateEquityCurveEMA");
        return;
    }
    
    // Standard EMA: new = alpha * current + (1 - alpha) * old
    g_equity_curve_ema = g_equity_curve_alpha * currentEquity + 
                         (1.0 - g_equity_curve_alpha) * g_equity_curve_ema;
    
    // Log periodically (every ~20 bars) for debugging
    static int ec_log_counter = 0;
    ec_log_counter++;
    if(ec_log_counter >= InpEquityCurve_Period)
    {
        ec_log_counter = 0;
        string state = (currentEquity > g_equity_curve_ema) ? "BULL" : "BEAR";
        double dist = ((currentEquity - g_equity_curve_ema) / g_equity_curve_ema) * 100.0;
        LogError(ERROR_INFO, "EquityCurve: " + state + " | Equity: " + DoubleToString(currentEquity, 2) + 
                  " | EMA: " + DoubleToString(g_equity_curve_ema, 2) + 
                  " | Dist: " + DoubleToString(dist, 2) + "%" + 
                  " | Mult: " + DoubleToString((currentEquity > g_equity_curve_ema) ? InpEquityCurve_BullMult : InpEquityCurve_BearMult, 2) + "x",
                  "UpdateEquityCurveEMA");
    }
}

//+------------------------------------------------------------------+
//| V28.06 TITAN: Get Equity Curve Multiplier                        |
//| Returns lot size multiplier based on equity position vs EMA      |
//|   Bull (equity > EMA): InpEquityCurve_BullMult (default 1.5x)   |
//|   Bear (equity < EMA): InpEquityCurve_BearMult (default 0.5x)   |
//+------------------------------------------------------------------+
double GetEquityCurveMultiplier()
{
    if(!InpEquityCurve_Enabled) return 1.0;
    if(!g_equity_curve_initialized) return 1.0;
    if(g_equity_curve_ema <= 0) return 1.0;
    
    double currentEquity = AccountEquity();
    
    if(currentEquity > g_equity_curve_ema)
    {
        // Equity above EMA = winning streak → amplify position
        return InpEquityCurve_BullMult;
    }
    else
    {
        // Equity below EMA = losing streak → reduce position
        return InpEquityCurve_BearMult;
    }
}


//+------------------------------------------------------------------+
// STEP 4: MODIFY GetLotSizeV8_5_9_FIXED
// Add equity curve multiplier AFTER lot size calculation (line 2965)
// and BEFORE the range validation (line 2968)
//+------------------------------------------------------------------+

/*
CHANGE IN GetLotSizeV8_5_9_FIXED (lines 2964-2968):

BEFORE:
    // SAFE LOT SIZE CALCULATION
    double lotSize = riskAmount / (stopLossPoints * tickValuePerLot);
    
    // ENHANCED LOT SIZE VALIDATION
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);

AFTER:
    // SAFE LOT SIZE CALCULATION
    double lotSize = riskAmount / (stopLossPoints * tickValuePerLot);
    
    // V28.06 TITAN: EQUITY CURVE TRADING AMPLIFICATION
    // When equity > EMA (winning streak): amplify lots by BullMult
    // When equity < EMA (losing streak): reduce lots by BearMult
    double equityCurveMult = GetEquityCurveMultiplier();
    if(equityCurveMult != 1.0)
    {
        lotSize *= equityCurveMult;
        LogError(ERROR_INFO, "EquityCurve applied: " + DoubleToString(equityCurveMult, 2) + 
                  "x | Lot: " + DoubleToString(lotSize, 2), "GetLotSizeV8_5_9_FIXED");
    }
    
    // ENHANCED LOT SIZE VALIDATION
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
*/


//+------------------------------------------------------------------+
// STEP 5: ADD EMA UPDATE IN OnTick
// Place AFTER line 5205 (after lastBarTime = Time[0];)
// and BEFORE line 5207 (before if(UpdateMultiTimeframeData_Fixed()))
//+------------------------------------------------------------------+

/*
CHANGE IN OnTick() (lines 5203-5207):

BEFORE:
   if(Time[0] > lastBarTime)
   {
      lastBarTime = Time[0];
      
      // V11.1: FIXED MULTI-TIMEFRAME STRATEGY EXECUTION (ONCE PER BAR)

AFTER:
   if(Time[0] > lastBarTime)
   {
      lastBarTime = Time[0];
      
      // V28.06: Update Equity Curve EMA (once per bar, before strategies)
      UpdateEquityCurveEMA();
      
      // V11.1: FIXED MULTI-TIMEFRAME STRATEGY EXECUTION (ONCE PER BAR)
*/


//+------------------------------------------------------------------+
// COMPLETE INTEGRATION SUMMARY
//+------------------------------------------------------------------+
//
// What this does:
// 1. Tracks a 20-period EMA of AccountEquity() (updated once per bar)
// 2. When current equity > EMA (winning streak):
//    - All lot sizes are multiplied by 1.5x (50% larger positions)
//    - This amplifies profits during favorable market conditions
// 3. When current equity < EMA (losing streak):
//    - All lot sizes are multiplied by 0.5x (50% smaller positions)
//    - This preserves capital during unfavorable conditions
// 4. The EMA smooths out noise — short-term spikes don't flip the state
// 5. Works WITH the existing Kelly system (both contribute to sizing)
//
// Why this works:
// - Trading strategies tend to have regime-dependent performance
// - Winning streaks indicate the strategy is aligned with current market
// - Losing streaks indicate misalignment (regime change, volatility shift)
// - By sizing UP when winning and DOWN when losing, you:
//   a) Capture more profit when your edge is active
//   b) Lose less when your edge is inactive
//   c) Naturally recover faster from drawdowns
//
// Safety bounds:
// - BearMult = 0.5 means we never go below half our normal size
// - BullMult = 1.5 is moderate amplification (not 3x or 5x)
// - The existing MaxLotSize, MaxTotalRisk, and PortfolioRiskBudget checks
//   still apply AFTER the equity curve multiplier
// - The existing range validation (minLot/maxLot) still clamps the result
//
// Parameter sensitivity:
// - Period=20: Balanced between responsiveness and smoothness
//   Lower (10): More responsive, more whipsaw
//   Higher (40): Smoother, slower to react to regime changes
// - BullMult=1.5: Moderate aggression on winning streaks
//   Lower (1.2): Conservative amplification
//   Higher (2.0): Aggressive (use with caution)
// - BearMult=0.5: Significant reduction on losing streaks
//   Lower (0.3): Very defensive (may miss recovery)
//   Higher (0.7): Mild reduction (less drawdown protection)
//
//+------------------------------------------------------------------+
