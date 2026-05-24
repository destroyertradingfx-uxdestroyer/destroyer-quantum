//+------------------------------------------------------------------+
//| V28.11_STRATEGIES_DEBATE.mq4                                      |
//| All V28.06 strategies converted for debate layer                  |
//| Each returns a signal instead of executing directly                |
//| Include V28_11_DEBATE_LAYER.mq4 in your EA first                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| MEAN REVERSION - RSI+BB+Hurst adaptive                           |
//| Original magic: InpMagic_MeanReversion                           |
//+------------------------------------------------------------------+
void ExecuteMeanReversion_DEBATE()
{
   if(Period() != PERIOD_H4) return;
   if(!InpMeanReversion_Enabled) return;
   if(!IsStrategyHealthy(InpMagic_MeanReversion)) return;
   if(g_hive_state == HIVE_STATE_DEFENSIVE && !InpMR_Allow_Defensive) return;
   if(InpEnable_ReaperConditionFilter && !IsReaperConditionMet()) return;
   if(InpEnableMarketFilters && !CheckMarketConditions()) return;
   if(InpEnableTimeFilter && !CheckTimeFilter()) return;

   int shift = 0;
   g_active_model = MODEL_MEAN_REVERSION;

   // Regime-adaptive bands (V18.2)
   double Hurst = CalculateHurstExponent(Symbol(), Period(), 100);
   double adaptive_dev = 2.0;
   double rsi_upper = 70;
   double rsi_lower = 30;

   if(Hurst < 0.50) {
      adaptive_dev = 1.8; rsi_upper = 65; rsi_lower = 35;
   } else if(Hurst >= 0.40 && Hurst <= 0.60) {
      adaptive_dev = 2.2; rsi_upper = 70; rsi_lower = 30;
   } else {
      adaptive_dev = 3.5; rsi_upper = 80; rsi_lower = 20;
   }

   // Technical indicators
   double bb_upper = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_UPPER, shift);
   double bb_lower = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_LOWER, shift);
   double rsi_val  = iRSI(Symbol(), Period(), 14, PRICE_CLOSE, shift);
   double price    = Close[shift];

   bool buy_signal  = (price < bb_lower) && (rsi_val < rsi_lower);
   bool sell_signal = (price > bb_upper) && (rsi_val > rsi_upper);

   // Elastic scoring (V25 Fix #3)
   if(InpAlphaExpand && InpElasticScoring) {
      int stratIdx = V23_FindStrategyIndex(InpMagic_MeanReversion);
      if(stratIdx >= 0) {
         double prob = V23_GetEmpiricalProb(stratIdx, MathAbs((price - iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)) / iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)));
         double rExpect = v23_stratPerf[stratIdx].rExpectancy;
         double rsiScore_Buy = 0, rsiScore_Sell = 0;
         if(rsi_val < 30) rsiScore_Buy = 1.0 * prob;
         else if(rsi_val < 40) rsiScore_Buy = 0.7 * prob;
         else if(rsi_val < 45) rsiScore_Buy = 0.3 * prob;
         if(rsi_val > 70) rsiScore_Sell = 1.0 * prob;
         else if(rsi_val > 60) rsiScore_Sell = 0.7 * prob;
         else if(rsi_val > 55) rsiScore_Sell = 0.3 * prob;
         double bbRange = bb_upper - bb_lower;
         double bbScore_Buy = (bbRange > 0) ? MathAbs(price - bb_lower) / bbRange : 0;
         double bbScore_Sell = (bbRange > 0) ? MathAbs(price - bb_upper) / bbRange : 0;
         bbScore_Buy = (price < bb_lower) ? (1.0 - bbScore_Buy) * rExpect : 0;
         bbScore_Sell = (price > bb_upper) ? (1.0 - bbScore_Sell) * rExpect : 0;
         double regimeContrib = v23_regime.confidence * 0.2;
         double totalScore_Buy = 0.5 * rsiScore_Buy + 0.3 * bbScore_Buy + regimeContrib;
         double totalScore_Sell = 0.5 * rsiScore_Sell + 0.3 * bbScore_Sell + regimeContrib;
         double scoreThreshold = 0.6 - (prob * 0.1);
         scoreThreshold = MathMax(0.4, MathMin(0.7, scoreThreshold));
         buy_signal = (totalScore_Buy > scoreThreshold);
         sell_signal = (totalScore_Sell > scoreThreshold);
      }
   }

   // Safety checks
   double ADX = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 0);
   if(ADX > 50) return;
   if(IsTrendTooStrong()) return;
   if(!Filter_CounterTrend()) return;

   if(buy_signal && !IsMeanReversionSafe(OP_BUY)) buy_signal = false;
   if(sell_signal && !IsMeanReversionSafe(OP_SELL)) sell_signal = false;

   if(!buy_signal && !sell_signal) return;

   // Conviction: based on RSI extremity + BB distance + Hurst regime
   double rsiDev = MathAbs(rsi_val - 50.0) / 50.0;
   double bbDist = MathAbs((price - bb_lower) / (bb_upper - bb_lower));
   double regimeBonus = 0;
   if(Hurst < 0.50) regimeBonus = 0.3;
   else if(Hurst <= 0.60) regimeBonus = 0.15;
   double conviction = MathMin(1.0, (rsiDev * 0.4 + bbDist * 0.3 + regimeBonus));

   int direction = buy_signal ? OP_BUY : OP_SELL;
   double atr_stop = GetATRStopLossPips() * Point;
   double sl, tp, lots;

   if(direction == OP_BUY) {
      sl = Ask - atr_stop;
      tp = Ask + atr_stop * 2.2;
      lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, GetATRStopLossPips());
   } else {
      sl = Bid + atr_stop;
      tp = Bid - atr_stop * 2.2;
      lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, GetATRStopLossPips());
   }

   if(lots <= 0) return;

   SubmitSignal(InpMagic_MeanReversion, direction, conviction,
                "MR_ADAPTIVE|" + DoubleToStr(Hurst, 2) + "|" + DoubleToStr(rsi_val, 0),
                lots, sl, tp);
}

//+------------------------------------------------------------------+
//| MATH REVERSAL - Z-score pure math                                |
//| Magic: 999002                                                    |
//+------------------------------------------------------------------+
void ExecuteMathReversal_DEBATE()
{
   if(!InpMathFirst || !InpAlphaExpand) return;

   int stratIdx = V23_FindStrategyIndex(999002);
   if(stratIdx < 0) return;

   // Z-score deviation
   double ma20 = iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
   double stdDev20 = iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
   if(stdDev20 <= 0) return;
   double deviation = (Close[1] - ma20) / stdDev20;

   // Math confidence gate
   double prob = V23_GetEmpiricalProb(stratIdx, MathAbs(deviation));
   double entropyNorm = v23_regime.entropyNorm;
   double confidence = v23_regime.confidence;
   int regimeType = v23_regime.type;
   double rExpect = v23_stratPerf[stratIdx].rExpectancy;

   bool mathConfident = (prob > 0.7) && (MathAbs(deviation) > 1.5) &&
                        (entropyNorm < 0.6) && (rExpect > 0) && (confidence > 0.5);
   if(!mathConfident) return;

   // Conviction from math factors
   double convProb = MathMin(1.0, (prob - 0.7) / 0.3);          // 0-1 (0.7->0, 1.0->1)
   double convDev  = MathMin(1.0, (MathAbs(deviation) - 1.5) / 1.5); // 0-1 (1.5->0, 3.0->1)
   double convConf = confidence;
   double conviction = (convProb * 0.4 + convDev * 0.3 + convConf * 0.3);

   int dir = (deviation > 0) ? OP_SELL : OP_BUY;

   double atr = iATR(NULL, 0, 14, 1);
   double slDist = atr * 1.5;
   double tpDist = atr * 2.5;
   double price = (dir == OP_BUY) ? Ask : Bid;
   double sl = (dir == OP_BUY) ? price - slDist : price + slDist;
   double tp = (dir == OP_BUY) ? price + tpDist : price - tpDist;

   double lots = V23_CalculateLotSize(stratIdx, 0.005, 50.0, regimeType);
   if(lots <= 0) return;

   // VAR check
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double marginalVar = lots * 50.0 * Point * tickValue / AccountEquity();
   double currentVar = V23_CalculateEmpiricalVAR();
   double varLimit = 0.05;
   if(regimeType == 0) varLimit *= InpVarRelaxFactor;
   else if(regimeType == 3) varLimit *= 1.2;
   if(currentVar + marginalVar > varLimit) return;

   SubmitSignal(999002, dir, conviction,
                "MATH_REV|prob=" + DoubleToStr(prob, 2) + "|dev=" + DoubleToStr(deviation, 1),
                lots, sl, tp);
}

//+------------------------------------------------------------------+
//| NOISE BREAKOUT - BB Squeeze breakout                             |
//| Magic: 777012                                                    |
//+------------------------------------------------------------------+
void ExecuteNoiseBreakout_DEBATE()
{
   if(!InpNoiseBreakout_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpNoiseBreakout_Magic) > 0) return;
   if(!IsStrategyHealthy(InpNoiseBreakout_Magic)) return;
   if(!CheckTimeFilter()) return;

   int bias = CheckDirectionalBias();

   double bb_upper = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double bb_lower = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double bb_mid   = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_MAIN, 1);
   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   double squeezeWidth = (bb_upper - bb_lower) / atr;

   // BUY: Close above upper BB + bullish bias
   if(Close[1] > bb_upper && (bias == 1 || bias == 2)) {
      double conviction = MathMin(1.0, (Close[1] - bb_upper) / atr * 0.5 + 0.3);
      conviction = MathMin(1.0, conviction + (1.0 - squeezeWidth) * 0.2);
      double sl = Ask - (atr * 1.5);
      double tp = Ask + (atr * 3.0);
      double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
      if(lots > 0)
         SubmitSignal(InpNoiseBreakout_Magic, OP_BUY, conviction,
                      "NOISE_BO|BB_squeeze", lots, sl, tp);
   }
   // SELL: Close below lower BB + bearish bias
   else if(Close[1] < bb_lower && (bias == -1 || bias == 2)) {
      double conviction = MathMin(1.0, (bb_lower - Close[1]) / atr * 0.5 + 0.3);
      conviction = MathMin(1.0, conviction + (1.0 - squeezeWidth) * 0.2);
      double sl = Bid + (atr * 1.5);
      double tp = Bid - (atr * 3.0);
      double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
      if(lots > 0)
         SubmitSignal(InpNoiseBreakout_Magic, OP_SELL, conviction,
                      "NOISE_BO|BB_squeeze", lots, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| APEX - Session rollover fade                                     |
//| Magic: 777011                                                    |
//+------------------------------------------------------------------+
void ExecuteApexStrategy_DEBATE()
{
   if(!InpApex_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpApex_MagicNumber) > 0) return;
   if(!IsStrategyHealthy(InpApex_MagicNumber)) return;
   if(!CheckTimeFilter()) return;

   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   // Extended bar detection
   double barRange = High[1] - Low[1];
   double trigger = atr * InpApex_ATR_Multiplier_SL;
   bool extendedBull = (Close[1] > Open[1] && barRange > trigger);
   bool extendedBear = (Close[1] < Open[1] && barRange > trigger);

   if(!extendedBull && !extendedBear) return;

   // Conviction from bar extension
   double extensionRatio = barRange / atr;
   double conviction = MathMin(1.0, (extensionRatio - 1.0) / 2.0);

   int direction;
   double sl, tp, lots;

   if(extendedBull) {
      direction = OP_SELL;
      sl = High[1] + (atr * InpApex_ATR_Multiplier_SL * Point * 10);
      tp = Bid - (atr * InpApex_ATR_Multiplier_TP * Point * 10);
      lots = MoneyManagement_Quantum(InpApex_MagicNumber, InpBase_Risk_Percent);
   } else {
      direction = OP_BUY;
      sl = Low[1] - (atr * InpApex_ATR_Multiplier_SL * Point * 10);
      tp = Ask + (atr * InpApex_ATR_Multiplier_TP * Point * 10);
      lots = MoneyManagement_Quantum(InpApex_MagicNumber, InpBase_Risk_Percent);
   }

   if(lots > 0)
      SubmitSignal(InpApex_MagicNumber, direction, conviction,
                   "APEX|ext=" + DoubleToStr(extensionRatio, 1), lots, sl, tp);
}

//+------------------------------------------------------------------+
//| NEXUS - Volatility compression breakout                          |
//| Magic: 777014                                                    |
//+------------------------------------------------------------------+
void ExecuteNexusStrategy_DEBATE()
{
   if(!InpNexus_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpNexus_MagicNumber) > 0) return;
   if(!IsStrategyHealthy(InpNexus_MagicNumber)) return;
   if(!CheckTimeFilter()) return;

   int bias = CheckDirectionalBias();
   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   // Volatility compression: N consecutive bars of ATR below median
   double atrMedian = 0;
   for(int i = 1; i <= 20; i++) atrMedian += iATR(Symbol(), PERIOD_H4, 14, i);
   atrMedian /= 20.0;

   int compressionBars = 0;
   for(int i = 1; i <= 10; i++) {
      if(iATR(Symbol(), PERIOD_H4, 14, i) < atrMedian * InpNexus_CompressionRatio)
         compressionBars++;
      else break;
   }

   if(compressionBars < InpNexus_MinCompressionBars) return;

   // Breakout direction
   bool buyBreak  = (Close[0] > High[1]);
   bool sellBreak = (Close[0] < Low[1]);
   if(!buyBreak && !sellBreak) return;

   // Conviction from compression depth + breakout strength
   double compressDepth = 1.0 - (atr / atrMedian);
   double breakoutStrength = 0;
   if(buyBreak) breakoutStrength = (Close[0] - High[1]) / atr;
   else breakoutStrength = (Low[1] - Close[0]) / atr;

   double conviction = MathMin(1.0, compressDepth * 0.5 + breakoutStrength * 0.3 + compressionBars * 0.05);

   int direction;
   double sl, tp;

   if(buyBreak && (bias == 1 || bias == 2)) {
      direction = OP_BUY;
      sl = Ask - (atr * InpNexus_SL_ATR_Mult);
      tp = Ask + (atrMedian * InpNexus_TP_Median_Mult);
   } else if(sellBreak && (bias == -1 || bias == 2)) {
      direction = OP_SELL;
      sl = Bid + (atr * InpNexus_SL_ATR_Mult);
      tp = Bid - (atrMedian * InpNexus_TP_Median_Mult);
   } else return;

   double lots = MoneyManagement_Quantum(InpNexus_MagicNumber, InpBase_Risk_Percent);
   if(lots > 0)
      SubmitSignal(InpNexus_MagicNumber, direction, conviction,
                   "NEXUS|comp=" + IntegerToString(compressionBars) + "bars", lots, sl, tp);
}

//+------------------------------------------------------------------+
//| MICROSTRUCTURE - H4 Kalman + M15 scalp                           |
//| Magic: InpChronos_MagicNumber                                    |
//+------------------------------------------------------------------+
void ExecuteMicrostructure_DEBATE()
{
   if(!InpChronos_Enabled) return;
   if(Period() != PERIOD_H4) return;
   int magic_micro = InpChronos_MagicNumber;
   if(CountOpenTrades(magic_micro) > 0) return;
   if(!IsStrategyHealthy(magic_micro)) return;
   if(!CheckTimeFilter()) return;

   // H4 Kalman filter for macro bias
   double kalman_prev = iMA(Symbol(), PERIOD_H4, 10, 0, MODE_EMA, PRICE_CLOSE, 2);
   double kalman_curr = iMA(Symbol(), PERIOD_H4, 10, 0, MODE_EMA, PRICE_CLOSE, 1);
   int bias = 0;
   if(kalman_curr > kalman_prev && Close[1] > kalman_curr) bias = 1;
   else if(kalman_curr < kalman_prev && Close[1] < kalman_curr) bias = -1;
   if(bias == 0) return;

   // M15 RSI + BB for micro signal
   double m15_rsi = iRSI(Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1);
   double m15_bb_lower = iBands(Symbol(), PERIOD_M15, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double m15_bb_upper = iBands(Symbol(), PERIOD_M15, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);

   bool buy_scalp  = (bias == 1 && Close[1] < m15_bb_lower && m15_rsi < 30);
   bool sell_scalp = (bias == -1 && Close[1] > m15_bb_upper && m15_rsi > 70);
   if(!buy_scalp && !sell_scalp) return;

   // Conviction from RSI extremity
   double rsiExtremity = 0;
   if(buy_scalp) rsiExtremity = (30.0 - m15_rsi) / 30.0;
   else rsiExtremity = (m15_rsi - 70.0) / 30.0;
   double conviction = MathMax(0.3, MathMin(1.0, rsiExtremity));

   int direction = buy_scalp ? OP_BUY : OP_SELL;
   double slPips = InpChronos_ScalpSL_Pips * 10 * Point;
   double tpPips = InpChronos_ScalpTP_Pips * 10 * Point;
   double sl, tp;

   if(direction == OP_BUY) {
      sl = Ask - slPips;
      tp = Ask + tpPips;
   } else {
      sl = Bid + slPips;
      tp = Bid - tpPips;
   }

   double lots = MoneyManagement_Quantum(magic_micro, InpBase_Risk_Percent) * InpChronos_LotSizeMultiplier;
   if(lots > 0)
      SubmitSignal(magic_micro, direction, conviction,
                   "MICRO|H4_bias=" + IntegerToString(bias), lots, sl, tp);
}

//+------------------------------------------------------------------+
//| VORTEX - Vortex indicator crossover                              |
//| Magic: 9001                                                      |
//+------------------------------------------------------------------+
void ExecuteVortexStrategy_DEBATE()
{
   if(!InpVortex_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpVortex_MagicNumber) > 0) return;
   if(!IsStrategyHealthy(InpVortex_MagicNumber)) return;
   if(!CheckTimeFilter()) return;

   int bias = CheckDirectionalBias();

   // Vortex indicator
   double vmPlus_1 = 0, vmMinus_1 = 0, atrSum_1 = 0;
   double vmPlus_2 = 0, vmMinus_2 = 0, atrSum_2 = 0;
   for(int v = 1; v <= InpVortex_Period; v++) {
      vmPlus_1  += MathAbs(High[v] - Low[v+1]);
      vmMinus_1 += MathAbs(Low[v] - High[v+1]);
      atrSum_1  += MathAbs(High[v] - Low[v]);
   }
   for(int w = 2; w <= InpVortex_Period + 1; w++) {
      vmPlus_2  += MathAbs(High[w] - Low[w+1]);
      vmMinus_2 += MathAbs(Low[w] - High[w+1]);
      atrSum_2  += MathAbs(High[w] - Low[w]);
   }
   if(atrSum_1 <= 0 || atrSum_2 <= 0) return;

   double viPlus_1  = vmPlus_1 / atrSum_1;
   double viMinus_1 = vmMinus_1 / atrSum_1;
   double viPlus_2  = vmPlus_2 / atrSum_2;
   double viMinus_2 = vmMinus_2 / atrSum_2;

   double adx = iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx < InpVortex_ADX_Threshold) return;

   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   bool buyCross  = (viPlus_1 > viMinus_1 && viPlus_2 <= viMinus_2);
   bool sellCross = (viMinus_1 > viPlus_1 && viMinus_2 <= viPlus_2);

   if(!buyCross && !sellCross) return;

   // Conviction from VI spread + ADX
   double viSpread = MathAbs(viPlus_1 - viMinus_1);
   double adxNorm = MathMin(1.0, (adx - InpVortex_ADX_Threshold) / 30.0);
   double conviction = MathMin(1.0, viSpread * 0.6 + adxNorm * 0.4);

   int direction;
   double sl, tp;

   if(buyCross && (bias == 1 || bias == 2)) {
      direction = OP_BUY;
      sl = Ask - (atr * 1.5);
      tp = Ask + (atr * 2.5);
   } else if(sellCross && (bias == -1 || bias == 2)) {
      direction = OP_SELL;
      sl = Bid + (atr * 1.5);
      tp = Bid - (atr * 2.5);
   } else return;

   double lots = MoneyManagement_Quantum(InpVortex_MagicNumber, InpBase_Risk_Percent);
   if(lots > 0)
      SubmitSignal(InpVortex_MagicNumber, direction, conviction,
                   "VORTEX|VI=" + DoubleToStr(viSpread, 2), lots, sl, tp);
}

//+------------------------------------------------------------------+
//| REGIME SHIFT - ADX+RSI regime change                             |
//| Magic: 9002                                                      |
//+------------------------------------------------------------------+
void ExecuteRegimeShiftStrategy_DEBATE()
{
   if(!InpRegimeShift_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpRegimeShift_MagicNumber) > 0) return;
   if(!IsStrategyHealthy(InpRegimeShift_MagicNumber)) return;
   if(!CheckTimeFilter()) return;

   int bias = CheckDirectionalBias();

   double adx_1 = iADX(Symbol(), PERIOD_H4, InpRegimeShift_ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   double adx_2 = iADX(Symbol(), PERIOD_H4, InpRegimeShift_ADX_Period, PRICE_CLOSE, MODE_MAIN, 2);
   double rsi = iRSI(Symbol(), PERIOD_H4, InpRegimeShift_RSI_Period, PRICE_CLOSE, 1);

   bool adxCrossAbove25 = (adx_1 > 25.0 && adx_2 <= 25.0);
   if(!adxCrossAbove25) return;

   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   // Conviction from ADX momentum + RSI distance from 50
   double adxMomentum = MathMin(1.0, (adx_1 - 25.0) / 25.0);
   double rsiBias = MathAbs(rsi - 50.0) / 50.0;
   double conviction = MathMin(1.0, adxMomentum * 0.5 + rsiBias * 0.5);

   int direction;
   double sl, tp;

   if(rsi > 50.0 && (bias == 1 || bias == 2)) {
      direction = OP_BUY;
      sl = Ask - (atr * 2.0);
      tp = Ask + (atr * 3.0);
   } else if(rsi < 50.0 && (bias == -1 || bias == 2)) {
      direction = OP_SELL;
      sl = Bid + (atr * 2.0);
      tp = Bid - (atr * 3.0);
   } else return;

   double lots = MoneyManagement_Quantum(InpRegimeShift_MagicNumber, InpBase_Risk_Percent);
   if(lots > 0)
      SubmitSignal(InpRegimeShift_MagicNumber, direction, conviction,
                   "REGIME_SHIFT|ADX=" + DoubleToStr(adx_1, 0), lots, sl, tp);
}

//+------------------------------------------------------------------+
//| SESSION MOMENTUM - London/NY breakout                            |
//| Magic: 9003                                                      |
//+------------------------------------------------------------------+
void ExecuteSessionMomentum_DEBATE()
{
   if(!InpSessionMomentum_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpSessionMomentum_MagicNumber) > 0) return;
   if(!IsStrategyHealthy(InpSessionMomentum_MagicNumber)) return;
   if(!CheckTimeFilter()) return;

   int utcHour = TimeHour(TimeCurrent()) - InpServerUTCOffset;
   if(utcHour < 0) utcHour += 24;
   if(utcHour < 8 || utcHour > 18) return;

   int bias = CheckDirectionalBias();

   double londonHigh = High[1], londonLow = Low[1];
   for(int lb = 2; lb <= 6; lb++) {
      if(High[lb] > londonHigh) londonHigh = High[lb];
      if(Low[lb] < londonLow) londonLow = Low[lb];
   }
   double londonRange = londonHigh - londonLow;
   if(londonRange <= 0) return;

   double adx = iADX(Symbol(), PERIOD_H4, InpSessionMomentum_ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx < InpSessionMomentum_ADX_Threshold) return;

   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   bool buySignal  = (Close[0] > londonHigh);
   bool sellSignal = (Close[0] < londonLow);
   if(!buySignal && !sellSignal) return;

   // Conviction from breakout strength + ADX
   double breakoutDist = 0;
   if(buySignal) breakoutDist = (Close[0] - londonHigh) / atr;
   else breakoutDist = (londonLow - Close[0]) / atr;
   double adxNorm = MathMin(1.0, (adx - InpSessionMomentum_ADX_Threshold) / 30.0);
   double conviction = MathMin(1.0, breakoutDist * 0.5 + adxNorm * 0.5);

   int direction;
   double sl, tp;

   if(buySignal && (bias == 1 || bias == 2)) {
      direction = OP_BUY;
      sl = Ask - (atr * InpSessionMomentum_ATR_SL_Mult);
      tp = Ask + (atr * InpSessionMomentum_ATR_TP_Mult);
   } else if(sellSignal && (bias == -1 || bias == 2)) {
      direction = OP_SELL;
      sl = Bid + (atr * InpSessionMomentum_ATR_SL_Mult);
      tp = Bid - (atr * InpSessionMomentum_ATR_TP_Mult);
   } else return;

   double lots = MoneyManagement_Quantum(InpSessionMomentum_MagicNumber, InpBase_Risk_Percent);
   if(lots > 0)
      SubmitSignal(InpSessionMomentum_MagicNumber, direction, conviction,
                   "SESS_MOM|break=" + DoubleToStr(breakoutDist, 1), lots, sl, tp);
}

//+------------------------------------------------------------------+
//| DIVERGENCE MEAN REVERSION - RSI divergence + BB                  |
//| Magic: 9004                                                      |
//+------------------------------------------------------------------+
void ExecuteDivergenceMR_DEBATE()
{
   if(!InpDivergenceMR_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpDivergenceMR_MagicNumber) > 0) return;
   if(!IsStrategyHealthy(InpDivergenceMR_MagicNumber)) return;
   if(!CheckTimeFilter()) return;

   int bias = CheckDirectionalBias();

   double rsi_1 = iRSI(Symbol(), PERIOD_H4, InpDivergenceMR_RSI_Period, PRICE_CLOSE, 1);
   double rsi_2 = iRSI(Symbol(), PERIOD_H4, InpDivergenceMR_RSI_Period, PRICE_CLOSE, 2);
   double adx = iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx > InpDivergenceMR_ADX_Max) return;

   double hurst = CalculateHurstExponent(Symbol(), Period(), 100);
   if(hurst >= InpDivergenceMR_Hurst_Threshold) return;

   double bbUpper = iBands(Symbol(), PERIOD_H4, InpDivergenceMR_BB_Period, InpDivergenceMR_BB_Dev, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double bbLower = iBands(Symbol(), PERIOD_H4, InpDivergenceMR_BB_Period, InpDivergenceMR_BB_Dev, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   bool bullishDiv = (Low[1] < Low[2] && rsi_1 > rsi_2);
   bool bearishDiv = (High[1] > High[2] && rsi_1 < rsi_2);
   bool atBBLower = (Close[1] <= bbLower);
   bool atBBUpper = (Close[1] >= bbUpper);

   // Conviction from divergence strength + BB position + Hurst
   double divStrength = 0;
   if(bullishDiv) divStrength = MathAbs(rsi_1 - rsi_2) / 20.0;
   else if(bearishDiv) divStrength = MathAbs(rsi_2 - rsi_1) / 20.0;
   double hurstConfidence = 1.0 - hurst;
   double conviction = MathMin(1.0, divStrength * 0.4 + hurstConfidence * 0.3 + 0.3);

   int direction;
   double sl, tp;

   if(bullishDiv && atBBLower && (bias == 1 || bias == 2)) {
      direction = OP_BUY;
      sl = Ask - (atr * InpDivergenceMR_ATR_SL_Mult);
      tp = Ask + (atr * InpDivergenceMR_ATR_TP_Mult);
   } else if(bearishDiv && atBBUpper && (bias == -1 || bias == 2)) {
      direction = OP_SELL;
      sl = Bid + (atr * InpDivergenceMR_ATR_SL_Mult);
      tp = Bid - (atr * InpDivergenceMR_ATR_TP_Mult);
   } else return;

   double lots = MoneyManagement_Quantum(InpDivergenceMR_MagicNumber, InpBase_Risk_Percent);
   if(lots > 0)
      SubmitSignal(InpDivergenceMR_MagicNumber, direction, conviction,
                   "DIV_MR|H=" + DoubleToStr(hurst, 2), lots, sl, tp);
}

//+------------------------------------------------------------------+
//| STRUCTURAL RETEST - Breakout then retest                         |
//| Magic: InpStructuralRetest_MagicNumber                           |
//+------------------------------------------------------------------+
void ExecuteStructuralRetest_DEBATE()
{
   if(!InpStructuralRetest_Enabled) return;
   if(Period() != PERIOD_H4) return;
   if(CountOpenTrades(InpStructuralRetest_MagicNumber) > 0) return;
   if(!IsStrategyHealthy(InpStructuralRetest_MagicNumber)) return;
   if(!CheckTimeFilter()) return;

   int bias = CheckDirectionalBias();
   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   if(atr <= 0) return;

   double swingHigh = High[iHighest(Symbol(), PERIOD_H4, MODE_HIGH, InpStructuralRetest_SwingPeriod, 1)];
   double swingLow = Low[iLowest(Symbol(), PERIOD_H4, MODE_LOW, InpStructuralRetest_SwingPeriod, 1)];

   // Detect breakout
   bool brokeAbove = false, brokeBelow = false;
   int breakBar = -1;
   for(int i = 2; i <= InpStructuralRetest_RetraceBars; i++) {
      if(Close[i] > swingHigh && Close[i-1] <= swingHigh) { brokeAbove = true; breakBar = i; break; }
      if(Close[i] < swingLow && Close[i-1] >= swingLow) { brokeBelow = true; breakBar = i; break; }
   }

   int direction = -1;
   double sl, tp, conviction = 0;
   double rr = 0;

   // BUY retest
   if(brokeAbove && breakBar > 1) {
      double retestLevel = swingHigh;
      bool retesting = (Low[1] <= retestLevel * 1.001 && Close[1] > retestLevel);
      if(retesting && (bias == 1 || bias == 2)) {
         sl = Low[1] - (atr * InpStructuralRetest_ATR_SL_Mult);
         tp = Ask + (atr * InpStructuralRetest_ATR_TP_Mult);
         double risk = Ask - sl;
         double reward = tp - Ask;
         rr = (risk > 0) ? reward / risk : 0;
         if(rr >= InpStructuralRetest_MinRR) {
            direction = OP_BUY;
            // Conviction from RR ratio + retest quality
            double retestProximity = MathAbs(Low[1] - retestLevel) / retestLevel;
            conviction = MathMin(1.0, rr * 0.3 + (1.0 - retestProximity * 100) * 0.4 + breakBar * 0.03);
         }
      }
   }
   // SELL retest
   if(brokeBelow && breakBar > 1 && direction == -1) {
      double retestLevel = swingLow;
      bool retesting = (High[1] >= retestLevel * 0.999 && Close[1] < retestLevel);
      if(retesting && (bias == -1 || bias == 2)) {
         sl = High[1] + (atr * InpStructuralRetest_ATR_SL_Mult);
         tp = Bid - (atr * InpStructuralRetest_ATR_TP_Mult);
         double risk = sl - Bid;
         double reward = Bid - tp;
         rr = (risk > 0) ? reward / risk : 0;
         if(rr >= InpStructuralRetest_MinRR) {
            direction = OP_SELL;
            double retestProximity = MathAbs(High[1] - retestLevel) / retestLevel;
            conviction = MathMin(1.0, rr * 0.3 + (1.0 - retestProximity * 100) * 0.4 + breakBar * 0.03);
         }
      }
   }

   if(direction == -1) return;

   double lots = MoneyManagement_Quantum(InpStructuralRetest_MagicNumber, InpBase_Risk_Percent);
   if(lots > 0)
      SubmitSignal(InpStructuralRetest_MagicNumber, direction, conviction,
                   "RETEST|RR=" + DoubleToStr(rr, 1), lots, sl, tp);
}
//+------------------------------------------------------------------+
