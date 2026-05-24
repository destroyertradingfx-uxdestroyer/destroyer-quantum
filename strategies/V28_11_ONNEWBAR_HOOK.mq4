//+------------------------------------------------------------------+
//| V28_11_ONNEWBAR_DEBATE_HOOK.mq4                                  |
//| Drop-in replacement for OnNewBar() strategy section              |
//| Include V28_11_DEBATE_LAYER.mq4 + V28_11_STRATEGIES_DEBATE.mq4  |
//+------------------------------------------------------------------+

//--- Call this from OnNewBar() INSTEAD of the individual strategy calls
void OnNewBar_DebateLayer()
{
   //--- Step 1: Reset signal buffer for this bar
   ResetSignals();

   //--- Step 2: All strategies submit signals (no execution)
   ExecuteMeanReversion_DEBATE();
   ExecuteMathReversal_DEBATE();
   ExecuteNoiseBreakout_DEBATE();
   ExecuteApexStrategy_DEBATE();
   ExecuteNexusStrategy_DEBATE();
   ExecuteMicrostructure_DEBATE();
   ExecuteVortexStrategy_DEBATE();
   ExecuteRegimeShiftStrategy_DEBATE();
   ExecuteSessionMomentum_DEBATE();
   ExecuteDivergenceMR_DEBATE();
   ExecuteStructuralRetest_DEBATE();

   //--- Phantom is Monday-only, fire on Monday
   if(DayOfWeek() == 1) ExecutePhantomStrategy_DEBATE();

   //--- Step 3: Run debate + risk panel + execute winner
   if(g_signalCount > 0) {
      int ticket = ExecuteDebateTrade();
      if(ticket > 0) {
         LogError("ONNEWBAR_DEBATE: Trade executed #" + IntegerToString(ticket) +
                  " from " + IntegerToString(g_signalCount) + " signals");
      }
   }

   //--- Step 4: Reaper runs independently (grid first entry through debate)
   //--- Grid levels still use existing ProcessReaperBasket logic
   //--- Comment out ExecuteReaperProtocol() and replace with:
   ExecuteReaperProtocol_Debate();
}

//+------------------------------------------------------------------+
//| REAPER PROTOCOL - Grid first entry through debate                |
//| Grid levels continue using existing OrderSend logic              |
//+------------------------------------------------------------------+
void ExecuteReaperProtocol_Debate()
{
   //--- Check if Reaper has no active basket in BUY direction
   //--- If so, check for high conviction signal and submit to debate
   int buyMagic = InpReaper_BuyMagicNumber;
   int sellMagic = InpReaper_SellMagicNumber;

   //--- BUY basket: first entry through debate
   if(CountOpenTrades(buyMagic) == 0) {
      if(IsHighConvictionSignal(OP_BUY)) {
         //--- Calculate conviction from AlphaSentinel confluence layers
         int layers = 0;
         // Layer 1: Pivot proximity (already checked in IsHighConvictionSignal)
         layers++;
         // Layer 2: Stochastic crossover
         double stoch1 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
         double stoch2 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 2);
         if(stoch1 > stoch2) layers++;
         // Layer 3: RSI divergence
         double rsi1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 1);
         double rsi2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 2);
         if(rsi1 > rsi2 && Low[1] < Low[2]) layers++;

         double conviction = layers / 3.0;
         double lots = GetNextReaperLotSize(0);
         double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
         double sl = Ask - (atr * 2.0);

         SubmitSignal(buyMagic, OP_BUY, conviction,
                      "REAPER_BUY|layers=" + IntegerToString(layers), lots, sl, 0);
      }
   }

   //--- SELL basket: first entry through debate
   if(CountOpenTrades(sellMagic) == 0) {
      if(IsHighConvictionSignal(OP_SELL)) {
         int layers = 0;
         layers++;
         double stoch1 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
         double stoch2 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 2);
         if(stoch1 < stoch2) layers++;
         double rsi1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 1);
         double rsi2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 2);
         if(rsi1 < rsi2 && High[1] > High[2]) layers++;

         double conviction = layers / 3.0;
         double lots = GetNextReaperLotSize(0);
         double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
         double sl = Bid + (atr * 2.0);

         SubmitSignal(sellMagic, OP_SELL, conviction,
                      "REAPER_SELL|layers=" + IntegerToString(layers), lots, sl, 0);
      }
   }

   //--- Grid level management continues as before (not through debate)
   ProcessReaperBasket(buyMagic, OP_BUY);
   ProcessReaperBasket(sellMagic, OP_SELL);
}

//+------------------------------------------------------------------+
//| INTEGRATION GUIDE                                                 |
//|                                                                   |
//| In your EA (V28_11.mq4):                                         |
//|                                                                   |
//| 1. Add at top:                                                    |
//|    #include "V28_11_DEBATE_LAYER.mq4"                            |
//|                                                                   |
//| 2. In OnInit():                                                   |
//|    InitDebateLayer();                                             |
//|                                                                   |
//| 3. In OnNewBar():                                                 |
//|    REPLACE the block of Execute*() calls with:                    |
//|    OnNewBar_DebateLayer();                                        |
//|                                                                   |
//| 4. In OnTradeClose() or equivalent:                               |
//|    ProcessTradeClose(ticket, exitPrice, pnl);                    |
//|                                                                   |
//| That's it. All V28.06 logic preserved. Debate layer is additive. |
//+------------------------------------------------------------------+
