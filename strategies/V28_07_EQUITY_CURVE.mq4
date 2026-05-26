//+------------------------------------------------------------------+
//| EQUITY CURVE ANTI-MARTINGALE — Portfolio-Level Sizing Multiplier  |
//| Ready for integration into DESTROYER QUANTUM V28.06 TITAN         |
//| Date: 2026-05-26                                                  |
//+------------------------------------------------------------------+
// INTEGRATION POINT: Add to MoneyManagement_Quantum() before final lot calc
// ORTHOGONAL to Kelly: Kelly is per-strategy, this is portfolio-level

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
// Add near other globals (~line 1529):
/*
#define EQUITY_HISTORY_SIZE 60
double   g_equityHistory[EQUITY_HISTORY_SIZE];
int      g_equityHistoryIdx = 0;
int      g_equityHistoryCount = 0;
double   g_peakEquity = 0;
datetime g_lastEquitySnapshot = 0;
*/

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
// Add to input section:
/*
sinput string Inp_Header_EquityCurve = "====== EQUITY CURVE ANTI-MARTINGALE ======";
input bool   InpEquityCurve_Enabled     = true;    // Enable Equity Curve Trading
input int    InpEquityCurve_Period      = 20;      // Rolling period for slope calc
input double InpEquityCurve_WinMult     = 1.3;     // Multiplier when equity rising
input double InpEquityCurve_LossMult    = 0.7;     // Multiplier when equity falling
input double InpEquityCurve_DDThreshold = 0.10;    // DD% to trigger 50% cut
input double InpEquityCurve_DDReduction = 0.50;    // Lot reduction in DD
*/

//+------------------------------------------------------------------+
//| RECORD EQUITY SNAPSHOT                                            |
//+------------------------------------------------------------------+
void RecordEquitySnapshot()
{
   if(!InpEquityCurve_Enabled) return;
   
   // Only snapshot once per H4 bar
   datetime currentBarTime = iTime(Symbol(), PERIOD_H4, 0);
   if(g_lastEquitySnapshot == currentBarTime) return;
   g_lastEquitySnapshot = currentBarTime;
   
   double equity = AccountEquity();
   
   // Store in circular buffer
   g_equityHistory[g_equityHistoryIdx] = equity;
   g_equityHistoryIdx = (g_equityHistoryIdx + 1) % EQUITY_HISTORY_SIZE;
   if(g_equityHistoryCount < EQUITY_HISTORY_SIZE) g_equityHistoryCount++;
   
   // Update peak equity
   if(equity > g_peakEquity) g_peakEquity = equity;
}

//+------------------------------------------------------------------+
//| CALCULATE EQUITY CURVE SLOPE                                      |
//+------------------------------------------------------------------+
double GetEquityCurveSlope(int period)
{
   if(g_equityHistoryCount < period) return 0;
   
   // Extract last 'period' values from circular buffer
   double values[];
   ArrayResize(values, period);
   
   int startIdx = (g_equityHistoryIdx - period + EQUITY_HISTORY_SIZE) % EQUITY_HISTORY_SIZE;
   for(int i = 0; i < period; i++)
      values[i] = g_equityHistory[(startIdx + i) % EQUITY_HISTORY_SIZE];
   
   // Linear regression: slope = (n*sum(xy) - sum(x)*sum(y)) / (n*sum(x^2) - (sum(x))^2)
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = period;
   
   for(int i = 0; i < n; i++)
   {
      double x = (double)i;
      double y = values[i];
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
   }
   
   double denom = (n * sumX2) - (sumX * sumX);
   if(denom == 0) return 0;
   
   return ((n * sumXY) - (sumX * sumY)) / denom;
}

//+------------------------------------------------------------------+
//| GET EQUITY CURVE MULTIPLIER                                       |
//+------------------------------------------------------------------+
double GetEquityCurveMultiplier()
{
   if(!InpEquityCurve_Enabled) return 1.0;
   
   double equity = AccountEquity();
   
   // Drawdown defense
   if(g_peakEquity > 0 && equity < g_peakEquity * (1.0 - InpEquityCurve_DDThreshold))
   {
      return InpEquityCurve_DDReduction;  // 0.5x in drawdown
   }
   
   // Need minimum data
   if(g_equityHistoryCount < InpEquityCurve_Period) return 1.0;
   
   // Calculate slope
   double slope = GetEquityCurveSlope(InpEquityCurve_Period);
   
   // Normalize slope to account equity scale
   double avgEquity = 0;
   int count = MathMin(g_equityHistoryCount, InpEquityCurve_Period);
   int startIdx = (g_equityHistoryIdx - count + EQUITY_HISTORY_SIZE) % EQUITY_HISTORY_SIZE;
   for(int i = 0; i < count; i++)
      avgEquity += g_equityHistory[(startIdx + i) % EQUITY_HISTORY_SIZE];
   avgEquity /= count;
   
   if(avgEquity <= 0) return 1.0;
   
   double normalizedSlope = slope / avgEquity * 10000;  // Scale to meaningful range
   
   // Anti-martingale: amplify when winning, reduce when losing
   if(normalizedSlope > 0.5)      return InpEquityCurve_WinMult;   // 1.3x hot streak
   else if(normalizedSlope > 0.1)  return 1.0 + (InpEquityCurve_WinMult - 1.0) * 0.5; // 1.15x warm
   else if(normalizedSlope > -0.1) return 1.0;                      // Neutral
   else if(normalizedSlope > -0.5) return 1.0 + (InpEquityCurve_LossMult - 1.0) * 0.5; // 0.85x cooling
   else                             return InpEquityCurve_LossMult;  // 0.7x cold
   
   return 1.0;
}

//+------------------------------------------------------------------+
//| INTEGRATION INTO MoneyManagement_Quantum()                        |
//+------------------------------------------------------------------+
// Add at the END of MoneyManagement_Quantum(), before return:
/*
   // V28.07: Equity Curve Anti-Martingale
   RecordEquitySnapshot();  // Record once per H4 bar
   double equityMult = GetEquityCurveMultiplier();
   lots *= equityMult;
   
   if(equityMult != 1.0)
      LogError(ERROR_INFO, "Equity Curve: mult=" + DoubleToString(equityMult, 2) +
               " slope=" + DoubleToString(GetEquityCurveSlope(InpEquityCurve_Period), 2),
               "MoneyManagement_Quantum");
*/
