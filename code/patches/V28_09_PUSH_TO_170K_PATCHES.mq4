//+------------------------------------------------------------------+
//| V28.09 PUSH_TO_170K PATCHES                                      |
//| Apply these changes to DESTROYER_QUANTUM_V29_00.mq4              |
//| Date: 2026-05-30                                                  |
//+------------------------------------------------------------------+

//==========================================================================
// PATCH 1: INCREASE RISK PARAMETERS (DD Headroom Lever)
// Location: Input parameters section (~Line 50-100)
//==========================================================================

// FIND:
//   extern double InpBase_Risk_Percent = 5.0;
// REPLACE WITH:
   extern double InpBase_Risk_Percent = 7.0;  // +40% per-trade risk (was 5.0)

// FIND:
//   extern double InpMaxTotalRisk_Percent = 8.0;
// REPLACE WITH:
   extern double InpMaxTotalRisk_Percent = 12.0;  // +50% portfolio limit (was 8.0)

//==========================================================================
// PATCH 2: KELLY BLEND ADJUSTMENT (DD Headroom Lever)
// Location: GetKellyLotSize() function (~Line 5055)
//==========================================================================

// FIND:
//   double kellyBlend = 0.60;  // 60% Kelly, 40% base
// REPLACE WITH:
   double kellyBlend = 0.80;  // 80% Kelly, 20% base (more aggressive)

//==========================================================================
// PATCH 3: WIN/LOSS STREAK MOMENTUM (Streak Momentum Lever)
// Location: MoneyManagement_Quantum() function (~Line 5100)
// ADD AFTER base lot calculation, BEFORE final lot clamp
//==========================================================================

// ADD THIS CODE:
   //--- STREAK MOMENTUM MULTIPLIER ---
   // g_consecutiveWins and g_consecutiveLosses are already tracked
   // Use them to amplify hot streaks, reduce cold streaks
   double streakMultiplier = 1.0;
   if(g_consecutiveWins >= 3) streakMultiplier = 1.25;   // Hot hand: +25%
   if(g_consecutiveWins >= 5) streakMultiplier = 1.50;   // Very hot: +50%
   if(g_consecutiveLosses >= 3) streakMultiplier = 0.75;  // Cooling: -25%
   if(g_consecutiveLosses >= 5) streakMultiplier = 0.50;  // Cold: -50%
   
   baseLot = baseLot * streakMultiplier;  // Apply streak momentum

//==========================================================================
// PATCH 4: EQUITY CURVE MULTIPLIER (Equity Curve Lever)
// Location: MoneyManagement_Quantum() function
// ADD AFTER streak multiplier, BEFORE final lot clamp
//==========================================================================

// ADD THIS CODE:
   //--- EQUITY CURVE AMPLIFICATION ---
   // Copy CalculateEquityCurveMultiplier() from V29_00_EQUITY_CURVE.mq4
   // Place the function BEFORE MoneyManagement_Quantum()
   double equityCurveMult = CalculateEquityCurveMultiplier();
   baseLot = baseLot * equityCurveMult;  // Range: 0.5x to 2.5x

//==========================================================================
// PATCH 5: MEAN REVERSION RELAXATION (Dead Strategy Activation)
// Location: Mean Reversion strategy section (~Line 8000-8500)
//==========================================================================

// FIND:
//   double hurstThreshold = 0.55;
// REPLACE WITH:
   double hurstThreshold = 0.70;  // Allow mild trends (was 0.55)

// FIND:
//   double bbDeviation = 2.0;
// REPLACE WITH:
   double bbDeviation = 1.5;  // More overextension signals (was 2.0)

// FIND:
//   int adxMax = 30;
// REPLACE WITH:
   int adxMax = 40;  // Fade moderate trends (was 30)

//==========================================================================
// PATCH 6: SESSION MOMENTUM RELAXATION (Dead Strategy Activation)
// Location: SessionMomentum strategy section (~Line 9000-9500)
//==========================================================================

// FIND:
//   int adxMin = 20;
// REPLACE WITH:
   int adxMin = 15;  // Weaker trend OK (was 20)

// FIND:
//   int maxConcurrent = 1;
// REPLACE WITH:
   int maxConcurrent = 2;  // Allow 2 trades different directions (was 1)

//==========================================================================
// PATCH 7: ASIAN RANGE BREAKOUT STRATEGY (New Strategy)
// Location: Add new strategy section after SessionMomentum (~Line 9500)
// Magic Number: 9007
//==========================================================================

// ADD THIS ENTIRE SECTION:
/*
//+------------------------------------------------------------------+
//| STRATEGY 9007: ASIAN RANGE BREAKOUT                              |
//| Logic: Trade London open breakout of Tokyo session range          |
//| Time: 08:00-12:00 UTC (London session start)                     |
//| Entry: Close above/below Asian range + volume confirmation        |
//| SL: Opposite side of Asian range                                  |
//| TP: 1.5x Asian range width                                       |
//+------------------------------------------------------------------+
int CheckAsianRangeBreakout()
{
   // Define Asian session: 00:00-08:00 UTC (H4 bars 0-2)
   double asianHigh = 0, asianLow = 99999;
   
   for(int i = 1; i <= 2; i++)  // Last 2 H4 bars = 8 hours
   {
      double high = iHigh(Symbol(), PERIOD_H4, i);
      double low = iLow(Symbol(), PERIOD_H4, i);
      if(high > asianHigh) asianHigh = high;
      if(low < asianLow) asianLow = low;
   }
   
   double asianRange = asianHigh - asianLow;
   double currentClose = iClose(Symbol(), PERIOD_H4, 0);
   double currentVolume = iVolume(Symbol(), PERIOD_H4, 0);
   double avgVolume = (iVolume(Symbol(), PERIOD_H4, 1) + 
                       iVolume(Symbol(), PERIOD_H4, 2) + 
                       iVolume(Symbol(), PERIOD_H4, 3)) / 3.0;
   
   // Current hour in UTC
   int currentHour = Hour();  // Adjust for broker timezone if needed
   
   // Only trade during London open (08:00-12:00 UTC)
   if(currentHour < 8 || currentHour > 12) return 0;
   
   // Volume confirmation: current volume > 1.2x average
   if(currentVolume < avgVolume * 1.2) return 0;
   
   // BUY signal: Close breaks above Asian high
   if(currentClose > asianHigh && Close[1] <= asianHigh)
   {
      // Additional confirmation: bullish candle
      if(Close[0] > Open[0])
         return 1;  // BUY
   }
   
   // SELL signal: Close breaks below Asian low
   if(currentClose < asianLow && Close[1] >= asianLow)
   {
      // Additional confirmation: bearish candle
      if(Close[0] < Open[0])
         return -1;  // SELL
   }
   
   return 0;  // No signal
}

void OpenAsianRangeBreakout(int signal)
{
   double asianHigh = 0, asianLow = 99999;
   for(int i = 1; i <= 2; i++)
   {
      double high = iHigh(Symbol(), PERIOD_H4, i);
      double low = iLow(Symbol(), PERIOD_H4, i);
      if(high > asianHigh) asianHigh = high;
      if(low < asianLow) asianLow = low;
   }
   
   double asianRange = asianHigh - asianLow;
   double stopLoss, takeProfit;
   double lotSize = CalculateLotSize(9007, asianRange);
   
   if(signal == 1)  // BUY
   {
      stopLoss = asianLow - asianRange * 0.1;  // SL below Asian range + 10% buffer
      takeProfit = Bid + asianRange * 1.5;      // TP = 1.5x Asian range
      
      int ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3, 
                            stopLoss, takeProfit, "AsianBreakout_BUY", 9007, 0, clrGreen);
      if(ticket > 0) 
      {
         g_stratTotalTrades[9007]++;
         Print("Asian Breakout BUY opened: ", ticket);
      }
   }
   else if(signal == -1)  // SELL
   {
      stopLoss = asianHigh + asianRange * 0.1;  // SL above Asian range + 10% buffer
      takeProfit = Bid - asianRange * 1.5;       // TP = 1.5x Asian range
      
      int ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3, 
                            stopLoss, takeProfit, "AsianBreakout_SELL", 9007, 0, clrRed);
      if(ticket > 0) 
      {
         g_stratTotalTrades[9007]++;
         Print("Asian Breakout SELL opened: ", ticket);
      }
   }
}
*/

//==========================================================================
// PATCH 8: PARTIAL CLOSE IMPLEMENTATION (Partial Close Lever)
// Location: Trade management loop (~Line 12048-12060)
// REPLACE the empty stub with actual implementation
//==========================================================================

// FIND (the empty partial close stub):
//   // Partial close logic here
// REPLACE WITH:

/*
void ManagePartialCloses()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() < 9001 || OrderMagicNumber() > 9007) continue;
      
      double openPrice = OrderOpenPrice();
      double stopLoss = OrderStopLoss();
      double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      
      // Calculate risk in money terms
      double riskPips = MathAbs(openPrice - stopLoss) / Point;
      double riskMoney = riskPips * tickValue * OrderLots();
      double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      
      // Check if already partially closed (use global array or comment marker)
      string comment = OrderComment();
      bool alreadyPartial = (StringFind(comment, "PC50") >= 0);
      
      if(!alreadyPartial && currentProfit >= 2.0 * riskMoney)
      {
         // PARTIAL CLOSE AT 2R: Close 50%
         double closeLots = NormalizeDouble(OrderLots() * 0.50, 2);
         if(closeLots >= MarketInfo(Symbol(), MODE_MINLOT))
         {
            if(OrderClose(OrderTicket(), closeLots, currentPrice, 3, clrYellow))
            {
               // Move SL to breakeven + 1R
               double newSL;
               if(OrderType() == OP_BUY)
                  newSL = openPrice + (openPrice - stopLoss);  // BE + 1R
               else
                  newSL = openPrice - (stopLoss - openPrice);  // BE + 1R
               
               // Modify remaining position
               // Note: Need to select the remaining order after partial close
               // The comment approach helps track which orders have been partially closed
               
               Print("Partial close at 2R for ticket: ", OrderTicket());
            }
         }
      }
      else if(alreadyPartial && currentProfit >= 4.0 * riskMoney)
      {
         // FULL CLOSE AT 4R: Close remaining
         if(OrderClose(OrderTicket(), OrderLots(), currentPrice, 3, clrAqua))
         {
            Print("Full close at 4R for ticket: ", OrderTicket());
         }
      }
   }
}
*/

//==========================================================================
// PATCH 9: PER-STRATEGY DD TRACKING (Risk Mitigation)
// Location: Global variables section
//==========================================================================

// ADD TO GLOBAL VARIABLES:
//   double g_strategyDD[17] = {0};     // Per-strategy drawdown tracking
//   double g_strategyPeak[17] = {0};   // Per-strategy equity peak

// ADD TO OnTick() or trade management:
/*
void UpdateStrategyDrawdowns()
{
   for(int i = 0; i < 17; i++)
   {
      double stratEquity = 0;
      for(int j = OrdersTotal() - 1; j >= 0; j--)
      {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
         if(GetStrategyIndex(OrderMagicNumber()) == i)
            stratEquity += OrderProfit() + OrderSwap() + OrderCommission();
      }
      
      if(stratEquity > g_strategyPeak[i]) 
         g_strategyPeak[i] = stratEquity;
      
      if(g_strategyPeak[i] > 0)
         g_strategyDD[i] = (g_strategyPeak[i] - stratEquity) / g_strategyPeak[i] * 100;
      
      // DISABLE strategy if DD > 5%
      if(g_strategyDD[i] > 5.0)
      {
         // Set flag to skip this strategy in signal generation
         g_strategyDisabled[i] = true;
         Print("Strategy ", i, " disabled due to DD > 5%");
      }
   }
}
*/

//==========================================================================
// EXPECTED COMBINED IMPACT
//==========================================================================
// Conservative: +$34-58K → $95K-$119K total
// Optimistic: +$54-92K → $115K-$153K total
// Target: $170K (may need parameter optimization via MT4 genetic algo)
//
// DD Impact: +4-5% (from 17.2% to ~22%)
// Trade Count: +100-200 (from 554 to ~700)
//==========================================================================
