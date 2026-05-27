//+------------------------------------------------------------------+
//| V29.00: EQUITY CURVE AMPLIFICATION ENGINE                        |
//| Copy this function into DESTROYER_QUANTUM_V29_00.mq4             |
//| Place after GetKellyLotSize() (~Line 5055)                       |
//+------------------------------------------------------------------+
//| Returns: 0.5 (weak curve) to 2.5 (strong curve)                  |
//| Logic: Measures equity curve health via HWM proximity,            |
//|        rolling returns, drawdown state, and win streak momentum   |
//+------------------------------------------------------------------+
double CalculateEquityCurveMultiplier()
{
   double equity = AccountEquity();
   
   // FACTOR 1: HWM Proximity (30% weight)
   // How close to all-time high equity
   double hwmProximity = 1.0;
   if(g_high_watermark_equity > 0)
   {
      hwmProximity = equity / g_high_watermark_equity;  // 1.0 = at HWM, 0.9 = 10% below
   }
   
   // FACTOR 2: Rolling Equity Growth Rate (30% weight)
   // Compare current equity to equity N days ago
   static double equitySamples[20] = {0};
   static int equitySampleIdx = 0;
   static datetime lastSampleTime = 0;
   
   // Sample equity once per day
   datetime today = iTime(Symbol(), PERIOD_D1, 0);
   if(today > lastSampleTime)
   {
      equitySamples[equitySampleIdx % 20] = equity;
      equitySampleIdx++;
      lastSampleTime = today;
   }
   
   double growthRate = 1.0;
   if(equitySampleIdx >= 5)
   {
      int oldestIdx = (equitySampleIdx - 10) % 20;
      if(oldestIdx < 0) oldestIdx += 20;
      double oldestEquity = equitySamples[oldestIdx];
      if(oldestEquity > 0)
      {
         growthRate = equity / oldestEquity;  // >1.0 = growing, <1.0 = shrinking
      }
   }
   
   // FACTOR 3: Drawdown State (25% weight)
   // Lower DD = higher multiplier (inverse relationship)
   double ddFactor = 1.0;
   double ddPercent = 0;
   if(g_high_watermark_equity > 0)
      ddPercent = (g_high_watermark_equity - equity) / g_high_watermark_equity * 100;
   
   if(ddPercent > 10.0) ddFactor = 0.5;
   else if(ddPercent > 5.0) ddFactor = 0.7;
   else if(ddPercent > 2.0) ddFactor = 0.85;
   else if(ddPercent < 1.0) ddFactor = 1.2;  // Near HWM = boost
   
   // FACTOR 4: Win Streak Momentum (15% weight)
   // Track which strategies are currently winning
   double streakFactor = 1.0;
   int winningStrats = 0;
   int totalStrats = 0;
   for(int i = 0; i < 17; i++)
   {
      if(g_stratTotalTrades[i] >= 5)
      {
         totalStrats++;
         if(g_strategyMultiplier[i] > 1.0) winningStrats++;
      }
   }
   if(totalStrats > 0)
   {
      double winRatio = (double)winningStrats / (double)totalStrats;
      if(winRatio > 0.7) streakFactor = 1.3;       // Most strategies winning
      else if(winRatio > 0.5) streakFactor = 1.15;  // Half winning
      else if(winRatio < 0.3) streakFactor = 0.6;   // Most losing
      else if(winRatio < 0.5) streakFactor = 0.8;   // Fewer winning
   }
   
   // COMPOSITE: Weighted combination
   double composite = (hwmProximity * 0.30) + (growthRate * 0.30) + (ddFactor * 0.25) + (streakFactor * 0.15);
   
   // Map to multiplier range [0.5, 2.5]
   double multiplier = MathMax(0.5, MathMin(2.5, composite));
   
   return multiplier;
}

//+------------------------------------------------------------------+
//| V29.00: GBPUSD CORRELATION FILTER                                |
//| Returns: -1 (divergence = skip), 0 (neutral), +1 (confirmation)  |
//| Used by SessionMomentum to validate breakout signals              |
//+------------------------------------------------------------------+
int GetGBPUSDCorrelationSignal()
{
   // Get 20-bar correlation between EURUSD and GBPUSD H4
   double eurusd_close[20], gbpusd_close[20];
   
   for(int i = 0; i < 20; i++)
   {
      eurusd_close[i] = iClose("EURUSD", PERIOD_H4, i);
      gbpusd_close[i] = iClose("GBPUSD", PERIOD_H4, i);
   }
   
   // Calculate Pearson correlation
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;
   for(int i = 0; i < 20; i++)
   {
      sum_x += eurusd_close[i];
      sum_y += gbpusd_close[i];
      sum_xy += eurusd_close[i] * gbpusd_close[i];
      sum_x2 += eurusd_close[i] * eurusd_close[i];
      sum_y2 += gbpusd_close[i] * gbpusd_close[i];
   }
   
   double n = 20;
   double denom = (MathSqrt(n * sum_x2 - sum_x * sum_x) * MathSqrt(n * sum_y2 - sum_y * sum_y));
   if(denom == 0) return 0;  // Can't calculate, stay neutral
   double corr = (n * sum_xy - sum_x * sum_y) / denom;
   
   // Check GBPUSD momentum direction
   double gbpusd_momentum = iClose("GBPUSD", PERIOD_H4, 0) - iClose("GBPUSD", PERIOD_H4, 5);
   double eurusd_momentum = iClose("EURUSD", PERIOD_H4, 0) - iClose("EURUSD", PERIOD_H4, 5);
   
   // High correlation + same direction = confirmation
   if(corr > 0.80)
   {
      if((gbpusd_momentum > 0 && eurusd_momentum > 0) ||
         (gbpusd_momentum < 0 && eurusd_momentum < 0))
         return 1;  // Confirmation
   }
   
   // Low correlation or divergence = caution
   if(corr < 0.70) return -1;  // Divergence, skip
   
   return 0;  // Neutral
}
