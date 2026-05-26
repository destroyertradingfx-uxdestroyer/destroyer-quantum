//+------------------------------------------------------------------+
//| DONCHIAN CHANNEL TRAILING STOP                                    |
//| For trend-following strategies (Vortex, RegimeShift, SessionMom)  |
//| Date: 2026-05-26                                                  |
//+------------------------------------------------------------------+
// INTEGRATION: Call from OnTick() for selected strategies
// Keep Chandelier Exit for grid strategies (Reaper, SX)

//+------------------------------------------------------------------+
//| APPLY DONCHIAN TRAIL                                              |
//+------------------------------------------------------------------+
void ApplyDonchianTrail(int magic, int donchianPeriod = 20)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != magic) continue;
      if(OrderSymbol() != Symbol()) continue;
      
      int type = OrderType();
      double currentSL = OrderStopLoss();
      double openPrice = OrderOpenPrice();
      
      if(type == OP_BUY)
      {
         // Trail at N-bar low (structural support)
         double donchianSL = Low[iLowest(NULL, PERIOD_H4, MODE_LOW, donchianPeriod, 1)];
         donchianSL = NormalizeDouble(donchianSL - 5 * _Point, Digits); // 5-point buffer
         
         // Only tighten, never loosen. Only activate after 10 pips profit.
         if(donchianSL > currentSL && Bid > openPrice + 10 * _Point)
         {
            if(RobustOrderModify(OrderTicket(), openPrice, donchianSL, OrderTakeProfit(), 0, clrGreen))
            {
               LogError(ERROR_INFO, "Donchian Trail BUY: SL=" + DoubleToString(donchianSL, Digits) +
                        " (was " + DoubleToString(currentSL, Digits) + ")", "ApplyDonchianTrail");
            }
         }
      }
      else if(type == OP_SELL)
      {
         // Trail at N-bar high (structural resistance)
         double donchianSL = High[iHighest(NULL, PERIOD_H4, MODE_HIGH, donchianPeriod, 1)];
         donchianSL = NormalizeDouble(donchianSL + 5 * _Point, Digits); // 5-point buffer
         
         // Only tighten, never loosen. Only activate after 10 pips profit.
         if((donchianSL < currentSL || currentSL == 0) && Ask < openPrice - 10 * _Point)
         {
            if(RobustOrderModify(OrderTicket(), openPrice, donchianSL, OrderTakeProfit(), 0, clrRed))
            {
               LogError(ERROR_INFO, "Donchian Trail SELL: SL=" + DoubleToString(donchianSL, Digits) +
                        " (was " + DoubleToString(currentSL, Digits) + ")", "ApplyDonchianTrail");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ONTICK INTEGRATION                                                |
//+------------------------------------------------------------------+
// Add to OnTick() (~line 5174):
/*
   // V28.07: Donchian trail for trend-following strategies
   ApplyDonchianTrail(InpVortex_MagicNumber, 20);
   ApplyDonchianTrail(InpRegimeShift_MagicNumber, 20);
   ApplyDonchianTrail(InpSessionMomentum_Magic, 20);
   ApplyDonchianTrail(InpAsianBreakout_Magic, 20);
*/
