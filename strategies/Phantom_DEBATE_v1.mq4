//+------------------------------------------------------------------+
//| V28.11: ExecutePhantomStrategy_DEBATE()                           |
//| Converted from V28.06 ExecutePhantomStrategy()                    |
//| Instead of calling OpenTrade(), submits signal to debate layer    |
//|                                                                   |
//| CONVICTION SCORING:                                               |
//|   - Gap size quality (40%): bigger gap = stronger signal          |
//|   - Spread quality (30%): tighter spread = cleaner entry          |
//|   - Gap ratio (30%): gap vs max allowed (bigger = better)         |
//|                                                                   |
//| ALL original V28.06 logic preserved. Only OrderSend replaced.     |
//+------------------------------------------------------------------+
void ExecutePhantomStrategy_DEBATE()
{
   //--- [V28.06 UNCHANGED] Master switch + health checks
   if(!InpPhantom_Enabled) return;
   if(!IsStrategyHealthy(InpPhantom_MagicNumber)) return;
   if(CountOpenTrades(InpPhantom_MagicNumber) > 0) return;
   if(Period() != PERIOD_H4) return;

   //--- [V28.06 UNCHANGED] Monday only, first H4 bar
   if(DayOfWeek() != 1) return;
   if(TimeHour(TimeCurrent()) > 4) return;

   //--- [V28.06 UNCHANGED] Gap detection
   double mondayOpen  = Open[0];
   double fridayClose = Close[1];
   for(int fb = 1; fb <= 5; fb++)
   {
      if(DayOfWeek() - (fb - 1) <= 0) break;
      int dayOfWeek_fb = TimeDayOfWeek(Time[fb]);
      if(dayOfWeek_fb == 5 || dayOfWeek_fb == 4)
      {
         fridayClose = Close[fb];
         break;
      }
   }

   double gapPips = MathAbs(mondayOpen - fridayClose) / (Point * 10);

   //--- [V28.06 UNCHANGED] Gap size filter
   if(gapPips < InpPhantom_MinGap_Pips) return;
   if(gapPips > InpPhantom_MaxGap_Pips) return;

   //--- [V28.06 UNCHANGED] Spread check
   double spread = (Ask - Bid) / Point;
   if(spread > InpMax_Spread_Pips * 10) return;

   //--- [V28.06 UNCHANGED] Calculate SL/TP from gap
   double gapPoints = gapPips * Point * 10;
   double sl        = gapPoints * InpPhantom_SL_GapMult;
   double tp        = gapPoints * InpPhantom_TP_GapMult;

   //--- [V28.06 UNCHANGED] Position sizing
   double lots = MoneyManagement_Quantum(InpPhantom_MagicNumber, InpBase_Risk_Percent);

   //--- [V28.11 NEW] Calculate conviction score
   //--- Component 1: Gap size quality (0-1, where min gap = 0, sweet spot = 1)
   double gapMidpoint = (InpPhantom_MinGap_Pips + InpPhantom_MaxGap_Pips) / 2.0;
   double gapQuality = 0;
   if(gapPips <= gapMidpoint)
      gapQuality = (gapPips - InpPhantom_MinGap_Pips) / (gapMidpoint - InpPhantom_MinGap_Pips);
   else
      gapQuality = 1.0 - ((gapPips - gapMidpoint) / (InpPhantom_MaxGap_Pips - gapMidpoint));
   gapQuality = MathMax(0.25, MathMin(1.0, gapQuality));

   //--- Component 2: Spread quality (tighter spread = higher conviction)
   double maxSpread = InpMax_Spread_Pips * 10;
   double spreadQuality = 1.0 - (spread / maxSpread);
   spreadQuality = MathMax(0.1, MathMin(1.0, spreadQuality));

   //--- Component 3: Gap ratio (how big relative to max allowed)
   double gapRatio = gapPips / InpPhantom_MaxGap_Pips;
   gapRatio = MathMax(0.2, MathMin(1.0, gapRatio));

   //--- Combined conviction: weighted average
   double conviction = (gapQuality * 0.40) + (spreadQuality * 0.30) + (gapRatio * 0.30);
   conviction = MathMax(0.15, MathMin(1.0, conviction));

   //--- Build reason string
   string reason = "PHANTOM_GAP|" + DoubleToStr(gapPips, 1) + "pips";

   //--- [V28.11 NEW] Determine direction and submit signal
   int direction = -1;
   double slPrice = 0;
   double tpPrice = 0;

   //--- Gap up: price opened above Friday close -> fade DOWN
   if(mondayOpen > fridayClose)
   {
      direction = OP_SELL;
      slPrice = Ask + sl;
      tpPrice = Bid - tp;
      reason += "|SELL(fade_gap_up)";
   }
   //--- Gap down: price opened below Friday close -> fade UP
   else
   {
      direction = OP_BUY;
      slPrice = Bid - sl;
      tpPrice = Ask + tp;
      reason += "|BUY(fade_gap_down)";
   }

   //--- Submit signal to debate layer instead of trading directly
   bool submitted = SubmitSignal(
      InpPhantom_MagicNumber,  // magic
      direction,               // OP_BUY or OP_SELL
      conviction,              // 0.0 to 1.0
      reason,                  // human-readable reason
      lots,                    // suggested lot size
      slPrice,                 // suggested stop loss
      tpPrice                  // suggested take profit
   );

   if(submitted)
   {
      LogError(ERROR_INFO, "PHANTOM: Signal submitted " +
               (direction == OP_BUY ? "BUY" : "SELL") +
               " | Gap=" + DoubleToStr(gapPips, 1) + "pips" +
               " | Conviction=" + DoubleToStr(conviction, 2) +
               " | Lots=" + DoubleToStr(lots, 2), "Phantom");
   }
   else
   {
      LogError(ERROR_WARNING, "PHANTOM: Signal submission FAILED", "Phantom");
   }
}
//+------------------------------------------------------------------+
