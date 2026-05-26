//+------------------------------------------------------------------+
//| ASIAN RANGE BREAKOUT — Magic 9007                                 |
//| Ready for integration into DESTROYER QUANTUM V28.06 TITAN         |
//| Date: 2026-05-26                                                  |
//+------------------------------------------------------------------+
// REGISTRATION CHECKLIST (V28.09 lesson):
// [x] Magic number input (9007)
// [x] Strategy function (ExecuteAsianBreakout)
// [ ] Register in GetStrategyIndexFromMagic (return new index)
// [ ] Register in GetStrategyIndexByMagic (return new index)
// [ ] Register in GetStrategyIndexByMoney (return new index)
// [ ] Register in GetStrategySpecificRisk (set risk multiplier 0.8x)
// [ ] Expand ALL arrays: g_perfData, g_strategyMultiplier, g_stratKellyFraction,
//     g_stratHeatScore, g_stratDynamicMaxMult, g_stratTotalTrades, g_stratProfits,
//     g_stratProfitIdx, g_consecLossTracker, g_strategyCooldown, g_strategyLockoutUntil,
//     g_stratRollingWinRate, g_stratRollingAvgWin, g_stratRollingAvgLoss,
//     g_stratRollingPF, g_stratSharpeProxy, g_stratLastCalcTime
// [ ] Add to IsOurMagicNumber()
// [ ] Add to QueenBee exposure tracking
// [ ] Add to OnNewBar dispatch chain

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
// Add near other strategy inputs (~line 4584):
/*
sinput string Inp_Header_AsianBreakout = "====== ASIAN RANGE BREAKOUT (9007) ======";
extern int    InpAsianBreakout_Magic     = 9007;       // Magic number
extern bool   InpAsianBreakout_Enabled   = true;        // Enable Asian Breakout
extern int    InpAsianBreakout_Lookback  = 3;           // H4 bars for Asian range (3=12hrs)
extern double InpAsianBreakout_ATR_SL    = 1.5;        // ATR multiplier for SL
extern double InpAsianBreakout_ATR_TP    = 2.5;        // ATR multiplier for TP
extern double InpAsianBreakout_MinRange  = 0.3;        // Min range as ATR fraction
extern double InpAsianBreakout_MaxRange  = 1.5;        // Max range as ATR fraction
extern int    InpAsianBreakout_ADX       = 15;         // ADX threshold
extern int    InpAsianBreakout_MaxTrades = 1;          // Max concurrent trades
*/

//+------------------------------------------------------------------+
//| STRATEGY FUNCTION                                                 |
//+------------------------------------------------------------------+
void ExecuteAsianBreakout()
{
   // Guard clauses
   if(!InpAsianBreakout_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpAsianBreakout_Magic) >= InpAsianBreakout_MaxTrades) return;
   if(!IsStrategyHealthy(InpAsianBreakout_Magic)) return;
   
   // Time filter: Only trade at London open (07:00-09:00 UTC)
   int serverHour = TimeHour(TimeCurrent());
   int utcHour = serverHour - InpServerUTCOffset;
   if(utcHour < 0) utcHour += 24;
   if(utcHour < 7 || utcHour > 9) return;
   
   // Calculate Asian session range
   // Look back N H4 bars covering 20:00-08:00 UTC
   double asianHigh = High[1];
   double asianLow = Low[1];
   for(int lb = 2; lb <= InpAsianBreakout_Lookback; lb++)
   {
      if(High[lb] > asianHigh) asianHigh = High[lb];
      if(Low[lb] < asianLow) asianLow = Low[lb];
   }
   double asianRange = asianHigh - asianLow;
   if(asianRange <= 0) return;
   
   // ATR for filters and SL/TP
   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;
   
   // Goldilocks range filter
   if(asianRange > atr * InpAsianBreakout_MaxRange) return;  // Too wide (already moved)
   if(asianRange < atr * InpAsianBreakout_MinRange) return;  // Too narrow (no vol)
   
   // ADX filter
   double adx = iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx < InpAsianBreakout_ADX) return;
   
   // Efficiency Ratio filter (Improvement #4)
   double er = EfficiencyRatio(20);
   if(er < 0.25) return;  // Too choppy for breakout
   
   // Directional bias from D1 EMA
   double d1_ema20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double d1_ema50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   // BUY: Close breaks above Asian high + D1 bullish
   if(Close[0] > asianHigh && d1_ema20 > d1_ema50)
   {
      double sl = Ask - (atr * InpAsianBreakout_ATR_SL);
      double tp = Ask + (atr * InpAsianBreakout_ATR_TP);
      double lots = MoneyManagement_Quantum(InpAsianBreakout_Magic, InpBase_Risk_Percent);
      
      if(lots > 0)
      {
         int ticket = OpenTrade(OP_BUY, lots, Ask, sl, tp, "ASIAN_BO_BUY", InpAsianBreakout_Magic);
         if(ticket > 0)
         {
            int stratIdx = GetStrategyIndex(InpAsianBreakout_Magic);
            if(stratIdx >= 0) g_perfData[stratIdx].trades++;
            LogError(ERROR_INFO, "Asian Breakout BUY: Range=" + DoubleToString(asianRange/_Point, 0) +
                     " pips, ATR=" + DoubleToString(atr/_Point, 0), "ExecuteAsianBreakout");
         }
      }
   }
   // SELL: Close breaks below Asian low + D1 bearish
   else if(Close[0] < asianLow && d1_ema20 < d1_ema50)
   {
      double sl = Bid + (atr * InpAsianBreakout_ATR_SL);
      double tp = Bid - (atr * InpAsianBreakout_ATR_TP);
      double lots = MoneyManagement_Quantum(InpAsianBreakout_Magic, InpBase_Risk_Percent);
      
      if(lots > 0)
      {
         int ticket = OpenTrade(OP_SELL, lots, Bid, sl, tp, "ASIAN_BO_SELL", InpAsianBreakout_Magic);
         if(ticket > 0)
         {
            int stratIdx = GetStrategyIndex(InpAsianBreakout_Magic);
            if(stratIdx >= 0) g_perfData[stratIdx].trades++;
            LogError(ERROR_INFO, "Asian Breakout SELL: Range=" + DoubleToString(asianRange/_Point, 0) +
                     " pips, ATR=" + DoubleToString(atr/_Point, 0), "ExecuteAsianBreakout");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EFFICIENCY RATIO (shared with other strategies)                   |
//+------------------------------------------------------------------+
double EfficiencyRatio(int periods)
{
   if(periods <= 0 || Bars < periods + 1) return 0.0;
   
   double netMove = MathAbs(Close[0] - Close[periods]);
   double totalMove = 0;
   for(int i = 0; i < periods; i++)
      totalMove += MathAbs(Close[i] - Close[i+1]);
   
   return (totalMove > 0) ? netMove / totalMove : 0.0;
}

//+------------------------------------------------------------------+
//| ONNEWBAR DISPATCH ADDITION                                        |
//+------------------------------------------------------------------+
// Add after ExecuteSessionMomentum() block (~line 5553):
/*
   // V28.07 BEEHIVE — Asian Range Breakout Worker (Tokyo-London handoff)
   if(InpAsianBreakout_Enabled)
   {
      ExecuteAsianBreakout();
      if(CountOpenTrades() >= InpMaxOpenTrades) { if(!IsOptimization()) UpdateDashboard_StaticV8_6(); return; }
   }
*/
