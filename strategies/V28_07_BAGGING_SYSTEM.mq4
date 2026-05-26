//+------------------------------------------------------------------+
//| BAGGING SYSTEM — Equity Circuit Breaker                           |
//| Close all positions at +5% profit or -3% loss from anchor        |
//| Date: 2026-05-26                                                  |
//+------------------------------------------------------------------+
// Source: KVignesh122/MT5-SMC-trading-bot (51 stars)
// DD reduction: -2-3%. Risk: LOW — only acts at extreme thresholds.

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
// Add near other globals:
/*
double g_bagging_anchor = 0;
*/

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
/*
sinput string Inp_Header_Bagging = "====== BAGGING SYSTEM (EQUITY BREAKER) ======";
input bool   InpBagging_Enabled     = false;    // Enable Bagging System
input double InpBagging_ProfitPct   = 5.0;      // Profit % to close all
input double InpBagging_LossPct     = 3.0;      // Loss % to close all
*/

//+------------------------------------------------------------------+
//| CHECK BAGGING SYSTEM                                              |
//+------------------------------------------------------------------+
void CheckBaggingSystem()
{
   if(!InpBagging_Enabled) return;
   
   // Initialize anchor on first call
   if(g_bagging_anchor <= 0)
   {
      g_bagging_anchor = AccountEquity();
      return;
   }
   
   double equity = AccountEquity();
   double changePct = (equity - g_bagging_anchor) / g_bagging_anchor * 100;
   
   if(changePct >= InpBagging_ProfitPct)
   {
      // +5% profit capture
      CloseAllOurPositions();
      g_bagging_anchor = equity;
      LogError(ERROR_INFO, "BAGGING: +" + DoubleToString(InpBagging_ProfitPct, 1) +
               "% profit captured. Equity=" + DoubleToString(equity, 2) +
               " Anchor reset.", "CheckBaggingSystem");
   }
   else if(changePct <= -InpBagging_LossPct)
   {
      // -3% loss protection
      CloseAllOurPositions();
      g_bagging_anchor = equity;
      LogError(ERROR_WARNING, "BAGGING: -" + DoubleToString(InpBagging_LossPct, 1) +
               "% loss protection triggered. Equity=" + DoubleToString(equity, 2) +
               " Anchor reset.", "CheckBaggingSystem");
   }
}

//+------------------------------------------------------------------+
//| CLOSE ALL OUR POSITIONS                                           |
//+------------------------------------------------------------------+
void CloseAllOurPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(!IsOurMagicNumber(OrderMagicNumber())) continue;
      
      int type = OrderType();
      if(type == OP_BUY)
         RobustOrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
      else if(type == OP_SELL)
         RobustOrderClose(OrderTicket(), OrderLots(), Ask, 3, clrRed);
   }
}

//+------------------------------------------------------------------+
//| ONTICK INTEGRATION                                                |
//+------------------------------------------------------------------+
// Add to OnTick() — call once per tick (or once per bar for efficiency):
/*
   // V28.07: Bagging system — equity circuit breaker
   CheckBaggingSystem();
*/
