//+------------------------------------------------------------------+
//| V28_11_DEBATE_LAYER.mqh - Signal Debate & Risk Panel             |
//| DESTROYER QUANTUM V28.11 - VENI VIDI VICI                        |
//| Inspired by TradingAgents (TauricResearch)                       |
//| Bolt-on to V28.06 -- does NOT modify existing strategy logic      |
//+------------------------------------------------------------------+

#ifndef DEBATE_LAYER_MQH
#define DEBATE_LAYER_MQH

//--- Maximum number of strategies that can submit signals
#define MAX_SIGNALS 16

//--- Minimum weighted conviction for a trade to pass debate
#define MIN_CONVICTION_THRESHOLD 0.30

//--- Divergence threshold (both sides above this = conflict)
#define DIVERGENCE_THRESHOLD 0.50

//--- Size multipliers per tier
#define TIER1_SIZE_MULT 1.5   // STRONG: high conviction + 3/3 approve
#define TIER2_SIZE_MULT 1.0   // NORMAL: good conviction + 2/3 approve
#define TIER3_SIZE_MULT 0.7   // CAUTIOUS: moderate conviction + 2/3 approve
#define TIER4_SIZE_MULT 0.0   // HOLD: low conviction or < 2 approve

//--- Conservative persona thresholds
#define CONSERVATIVE_MIN_CONVICTION 0.50
#define CONSERVATIVE_MAX_SL_PIPS    200.0
#define CONSERVATIVE_MAX_CONSEC_LOSSES 3

//--- Neutral persona thresholds
#define NEUTRAL_MAX_EXPOSURE_PCT    80.0
#define NEUTRAL_MAX_SAME_DIRECTION  5

//--- Risk panel: how many of 3 must approve
#define RISK_PANEL_MIN_APPROVALS 2

//+------------------------------------------------------------------+
//| STRUCT: StrategySignal                                            |
//| Output from each strategy instead of direct OrderSend()          |
//+------------------------------------------------------------------+
struct StrategySignal {
   int      magic;            // Strategy magic number
   int      direction;        // OP_BUY, OP_SELL, or -1 (no signal)
   double   conviction;       // 0.0 to 1.0 (strength of signal)
   string   reason;           // Human-readable reason
   double   suggestedLots;    // What the strategy would normally trade
   double   suggestedSL;      // Suggested stop loss (price)
   double   suggestedTP;      // Suggested take profit (price)
   double   entryPrice;       // Current price at signal time
   datetime signalTime;       // When the signal was generated
};

//+------------------------------------------------------------------+
//| STRUCT: DebateResult                                              |
//| Output from the debate engine                                     |
//+------------------------------------------------------------------+
struct DebateResult {
   bool     approved;         // Did the debate approve a trade?
   int      direction;        // OP_BUY or OP_SELL
   double   consensusConviction; // Weighted consensus (0-1)
   double   buyConviction;    // Total weighted BUY conviction
   double   sellConviction;   // Total weighted SELL conviction
   bool     isDivergent;      // Both sides strong = warning
   int      signalsReceived;  // How many strategies submitted
   int      buySignals;       // How many said BUY
   int      sellSignals;      // How many said SELL
   string   agreedStrategies; // Comma-separated list of winning side
   string   disagreedStrategies; // Comma-separated list of losing side
};

//+------------------------------------------------------------------+
//| STRUCT: RiskPanelResult                                           |
//| Output from the 3-way risk evaluation                             |
//+------------------------------------------------------------------+
struct RiskPanelResult {
   int      approvals;        // 0-3 (how many approved)
   bool     aggressiveApproved;
   bool     conservativeApproved;
   bool     neutralApproved;
   string   aggressiveReason;
   string   conservativeReason;
   string   neutralReason;
};

//+------------------------------------------------------------------+
//| STRUCT: TradeLog                                                  |
//| For deferred reflection -- log why trades were taken               |
//+------------------------------------------------------------------+
struct TradeLog {
   //--- Entry data (logged on open)
   int      ticket;
   datetime entryTime;
   int      direction;
   double   entryPrice;
   double   lots;
   double   conviction;
   int      riskApprovals;
   string   strategiesAgreed;
   string   strategiesDisagreed;
   double   atrAtEntry;
   double   hurstAtEntry;
   double   adxAtEntry;
   //--- Exit data (logged on close)
   double   exitPrice;
   double   pnl;
   double   holdDuration;
   bool     thesisCorrect;
};

//+------------------------------------------------------------------+
//| GLOBAL: Signal buffer                                             |
//+------------------------------------------------------------------+
StrategySignal g_signals[MAX_SIGNALS];
int            g_signalCount = 0;

//+------------------------------------------------------------------+
//| GLOBAL: Trade log buffer                                          |
//+------------------------------------------------------------------+
TradeLog       g_tradeLog[];
int            g_tradeLogCount = 0;

//+------------------------------------------------------------------+
//| GLOBAL: Strategy weight overrides (from deferred reflection)      |
//+------------------------------------------------------------------+
double         g_strategyWeightAdj[MAX_MAGIC];  // Adjustment multiplier
bool           g_weightAdjInitialized = false;

//+------------------------------------------------------------------+
//| FUNCTION: InitDebateLayer()                                       |
//| Call once in OnInit()                                             |
//+------------------------------------------------------------------+
void InitDebateLayer() {
   g_signalCount = 0;
   g_tradeLogCount = 0;
   g_weightAdjInitialized = false;
   
   //--- Initialize weight adjustments to 1.0 (no adjustment)
   for (int i = 0; i < MAX_MAGIC; i++) {
      g_strategyWeightAdj[i] = 1.0;
   }
   g_weightAdjInitialized = true;
   
   LogError("DEBATE LAYER: Initialized. " + IntegerToString(MAX_SIGNALS) + " signal slots.");
}

//+------------------------------------------------------------------+
//| FUNCTION: ResetSignals()                                          |
//| Call at start of each OnNewBar() to clear previous signals       |
//+------------------------------------------------------------------+
void ResetSignals() {
   g_signalCount = 0;
   ArrayResize(g_signals, 0);
}

//+------------------------------------------------------------------+
//| FUNCTION: SubmitSignal()                                          |
//| Each strategy calls this instead of OrderSend()                   |
//| Returns true if signal was accepted                               |
//+------------------------------------------------------------------+
bool SubmitSignal(int magic, int direction, double conviction,
                  string reason, double lots, double sl, double tp) {
   
   //--- Validate
   if (direction != OP_BUY && direction != OP_SELL) return false;
   if (conviction < 0.0 || conviction > 1.0) return false;
   if (g_signalCount >= MAX_SIGNALS) {
      LogError("DEBATE: Signal buffer full. Dropping signal from magic " + IntegerToString(magic));
      return false;
   }
   
   //--- Add signal to buffer
   int idx = g_signalCount;
   g_signalCount++;
   ArrayResize(g_signals, g_signalCount);
   
   g_signals[idx].magic = magic;
   g_signals[idx].direction = direction;
   g_signals[idx].conviction = conviction;
   g_signals[idx].reason = reason;
   g_signals[idx].suggestedLots = lots;
   g_signals[idx].suggestedSL = sl;
   g_signals[idx].suggestedTP = tp;
   g_signals[idx].entryPrice = (direction == OP_BUY) ? Ask : Bid;
   g_signals[idx].signalTime = TimeCurrent();
   
   return true;
}

//+------------------------------------------------------------------+
//| FUNCTION: GetStrategyWeight()                                     |
//| Returns credibility weight based on rolling PF + reflection adj   |
//+------------------------------------------------------------------+
double GetStrategyWeight(int magic) {
   int idx = GetStrategyIndexByMagic(magic);
   if (idx < 0) return 1.0;
   
   //--- Base weight from rolling Profit Factor
   double pf = g_stratRollingPF[idx];
   double baseWeight = 1.0;
   
   if (pf < 1.0)       baseWeight = 0.5;   // Losing strategies: half voice
   else if (pf < 1.5)  baseWeight = 1.0;   // Marginal: normal voice
   else if (pf < 2.0)  baseWeight = 1.5;   // Good: 1.5x voice
   else if (pf < 3.0)  baseWeight = 2.0;   // Great: 2x voice
   else                 baseWeight = 3.0;   // Elite (PF 3+): 3x voice
   
   //--- Cap weight for strategies with too few trades
   int totalTrades = g_stratTotalTrades[idx];
   if (totalTrades < 5) baseWeight = MathMin(baseWeight, 1.0);  // Not enough data
   
   //--- Apply deferred reflection adjustment
   if (g_weightAdjInitialized && idx < MAX_MAGIC) {
      baseWeight *= g_strategyWeightAdj[idx];
   }
   
   //--- Clamp to reasonable range
   return MathMax(0.25, MathMin(3.0, baseWeight));
}

//+------------------------------------------------------------------+
//| FUNCTION: RunDebate()                                             |
//| The core debate engine -- weighs signals, detects divergence       |
//+------------------------------------------------------------------+
DebateResult RunDebate() {
   DebateResult result;
   result.approved = false;
   result.direction = -1;
   result.consensusConviction = 0;
   result.buyConviction = 0;
   result.sellConviction = 0;
   result.isDivergent = false;
   result.signalsReceived = g_signalCount;
   result.buySignals = 0;
   result.sellSignals = 0;
   result.agreedStrategies = "";
   result.disagreedStrategies = "";
   
   //--- No signals = no trade
   if (g_signalCount == 0) return result;
   
   //--- Calculate weighted conviction for each side
   double totalWeight = 0;
   
   for (int i = 0; i < g_signalCount; i++) {
      double weight = GetStrategyWeight(g_signals[i].magic);
      double weightedConviction = g_signals[i].conviction * weight;
      
      if (g_signals[i].direction == OP_BUY) {
         result.buyConviction += weightedConviction;
         result.buySignals++;
      }
      else if (g_signals[i].direction == OP_SELL) {
         result.sellConviction += weightedConviction;
         result.sellSignals++;
      }
      
      totalWeight += weight;
   }
   
   //--- Normalize to 0-1 range
   if (totalWeight > 0) {
      result.buyConviction /= totalWeight;
      result.sellConviction /= totalWeight;
   }
   
   //--- Determine winning direction
   double winningConviction = 0;
   if (result.buyConviction > result.sellConviction) {
      result.direction = OP_BUY;
      winningConviction = result.buyConviction;
   }
   else if (result.sellConviction > result.buyConviction) {
      result.direction = OP_SELL;
      winningConviction = result.sellConviction;
   }
   else {
      //--- Exact tie -- no trade
      LogError("DEBATE: Exact tie between BUY and SELL. No trade.");
      return result;
   }
   
   result.consensusConviction = winningConviction;
   
   //--- Divergence detection
   result.isDivergent = (result.buyConviction > DIVERGENCE_THRESHOLD &&
                         result.sellConviction > DIVERGENCE_THRESHOLD);
   
   if (result.isDivergent) {
      LogError("DEBATE: DIVERGENCE detected. BUY=" + DoubleToStr(result.buyConviction, 2) +
               " SELL=" + DoubleToStr(result.sellConviction, 2));
   }
   
   //--- Build agreed/disagreed lists
   for (int i = 0; i < g_signalCount; i++) {
      string stratName = GetStrategyNameByMagic(g_signals[i].magic);
      if (g_signals[i].direction == result.direction) {
         if (result.agreedStrategies != "") result.agreedStrategies += ",";
         result.agreedStrategies += stratName;
      }
      else {
         if (result.disagreedStrategies != "") result.disagreedStrategies += ",";
         result.disagreedStrategies += stratName;
      }
   }
   
   //--- Check minimum conviction threshold
   if (winningConviction < MIN_CONVICTION_THRESHOLD) {
      LogError("DEBATE: Conviction " + DoubleToStr(winningConviction, 2) +
               " below threshold " + DoubleToStr(MIN_CONVICTION_THRESHOLD, 2) + ". No trade.");
      return result;
   }
   
   result.approved = true;
   
   LogError("DEBATE: APPROVED " + (result.direction == OP_BUY ? "BUY" : "SELL") +
            " | Conviction=" + DoubleToStr(winningConviction, 2) +
            " | BUY=" + IntegerToString(result.buySignals) +
            " SELL=" + IntegerToString(result.sellSignals) +
            " | Agreed: " + result.agreedStrategies);
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNCTION: AggressiveRiskCheck()                                   |
//| Only blocks EXTREME risk -- lets almost everything through         |
//+------------------------------------------------------------------+
bool AggressiveRiskCheck(StrategySignal &signal, string &reason) {
   //--- Check 1: Extreme volatility (ATR > 3x average)
   double currentATR = iATR(Symbol(), PERIOD_H4, 14, 0);
   double avgATR = 0;
   for (int i = 1; i <= 20; i++) avgATR += iATR(Symbol(), PERIOD_H4, 14, i);
   avgATR /= 20.0;
   
   if (currentATR > 3.0 * avgATR) {
      reason = "Extreme volatility: ATR " + DoubleToStr(currentATR, 1) +
               " > 3x avg " + DoubleToStr(avgATR, 1);
      return false;
   }
   
   //--- Check 2: Already in drawdown protection mode
   if (g_ddProtectionActive) {
      reason = "DD protection active";
      return false;
   }
   
   //--- Check 3: Max open trades reached
   if (CountOpenTrades() >= InpMaxOpenTrades) {
      reason = "Max open trades: " + IntegerToString(InpMaxOpenTrades);
      return false;
   }
   
   reason = "Approved (aggressive)";
   return true;
}

//+------------------------------------------------------------------+
//| FUNCTION: ConservativeRiskCheck()                                 |
//| Requires multiple confirmations -- high bar for entry              |
//+------------------------------------------------------------------+
bool ConservativeRiskCheck(StrategySignal &signal, string &reason) {
   //--- Check 1: Minimum conviction
   if (signal.conviction < CONSERVATIVE_MIN_CONVICTION) {
      reason = "Conviction " + DoubleToStr(signal.conviction, 2) +
               " < " + DoubleToStr(CONSERVATIVE_MIN_CONVICTION, 2);
      return false;
   }
   
   //--- Check 2: Trend alignment (D1 EMA50)
   double ema50_D1 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double price = (signal.direction == OP_BUY) ? Ask : Bid;
   
   if (signal.direction == OP_BUY && price < ema50_D1) {
      reason = "BUY against D1 trend (price < EMA50)";
      return false;
   }
   if (signal.direction == OP_SELL && price > ema50_D1) {
      reason = "SELL against D1 trend (price > EMA50)";
      return false;
   }
   
   //--- Check 3: Stop loss too wide
   double slPips = MathAbs(signal.entryPrice - signal.suggestedSL) / g_pipValue;
   if (slPips > CONSERVATIVE_MAX_SL_PIPS) {
      reason = "SL too wide: " + DoubleToStr(slPips, 0) + " pips > " +
               DoubleToStr(CONSERVATIVE_MAX_SL_PIPS, 0);
      return false;
   }
   
   //--- Check 4: Consecutive losses
   if (g_kellyConsecutiveLosses >= CONSERVATIVE_MAX_CONSEC_LOSSES) {
      reason = "Consecutive losses: " + IntegerToString(g_kellyConsecutiveLosses) +
               " >= " + IntegerToString(CONSERVATIVE_MAX_CONSEC_LOSSES);
      return false;
   }
   
   reason = "Approved (conservative)";
   return true;
}

//+------------------------------------------------------------------+
//| FUNCTION: NeutralRiskCheck()                                      |
//| Portfolio-level risk management -- exposure and correlation         |
//+------------------------------------------------------------------+
bool NeutralRiskCheck(StrategySignal &signal, string &reason) {
   //--- Check 1: Total exposure
   double currentExposure = GetTotalExposurePercent();
   if (currentExposure > NEUTRAL_MAX_EXPOSURE_PCT) {
      reason = "Exposure " + DoubleToStr(currentExposure, 0) +
               "% > " + DoubleToStr(NEUTRAL_MAX_EXPOSURE_PCT, 0) + "%";
      return false;
   }
   
   //--- Check 2: Same direction concentration
   int sameDirCount = CountTradesByDirection(signal.direction);
   if (sameDirCount >= NEUTRAL_MAX_SAME_DIRECTION) {
      reason = IntegerToString(sameDirCount) + " trades already " +
               (signal.direction == OP_BUY ? "BUY" : "SELL") +
               " (max " + IntegerToString(NEUTRAL_MAX_SAME_DIRECTION) + ")";
      return false;
   }
   
   //--- Check 3: Duplicate magic (same strategy already has open trade)
   if (HasOpenPositionByMagic(signal.magic)) {
      reason = "Strategy " + GetStrategyNameByMagic(signal.magic) +
               " already has open position";
      return false;
   }
   
   reason = "Approved (neutral)";
   return true;
}

//+------------------------------------------------------------------+
//| FUNCTION: RunRiskPanel()                                          |
//| 3-way risk debate: Aggressive, Conservative, Neutral              |
//| Returns how many approved (0-3)                                   |
//+------------------------------------------------------------------+
RiskPanelResult RunRiskPanel(StrategySignal &signal) {
   RiskPanelResult result;
   
   result.aggressiveApproved = AggressiveRiskCheck(signal, result.aggressiveReason);
   result.conservativeApproved = ConservativeRiskCheck(signal, result.conservativeReason);
   result.neutralApproved = NeutralRiskCheck(signal, result.neutralReason);
   
   result.approvals = 0;
   if (result.aggressiveApproved)   result.approvals++;
   if (result.conservativeApproved) result.approvals++;
   if (result.neutralApproved)      result.approvals++;
   
   LogError("RISK PANEL: " + IntegerToString(result.approvals) + "/3 approved" +
            " | Aggr=" + (result.aggressiveApproved ? "YES" : "NO") +
            " | Cons=" + (result.conservativeApproved ? "YES" : "NO") +
            " | Neut=" + (result.neutralApproved ? "YES" : "NO"));
   
   if (result.approvals < RISK_PANEL_MIN_APPROVALS) {
      if (!result.conservativeApproved)
         LogError("RISK PANEL REJECT (conservative): " + result.conservativeReason);
      if (!result.neutralApproved)
         LogError("RISK PANEL REJECT (neutral): " + result.neutralReason);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNCTION: GetDebateSizeMultiplier()                               |
//| Maps conviction + approvals to 5-tier position sizing             |
//+------------------------------------------------------------------+
double GetDebateSizeMultiplier(double conviction, int approvals, bool isDivergent) {
   double baseMultiplier = 0.0;
   
   //--- Tier 1: STRONG -- high conviction + all 3 approve
   if (conviction >= 0.80 && approvals == 3)
      baseMultiplier = TIER1_SIZE_MULT;
   
   //--- Tier 2: NORMAL -- good conviction + 2+ approve
   else if (conviction >= 0.50 && approvals >= 2)
      baseMultiplier = TIER2_SIZE_MULT;
   
   //--- Tier 3: CAUTIOUS -- moderate conviction + 2+ approve
   else if (conviction >= 0.30 && approvals >= 2)
      baseMultiplier = TIER3_SIZE_MULT;
   
   //--- Tier 4/5: HOLD -- reject
   else
      baseMultiplier = TIER4_SIZE_MULT;
   
   //--- Divergence penalty: reduce size 50%
   if (isDivergent && baseMultiplier > 0) {
      baseMultiplier *= 0.5;
      LogError("SIZING: Divergence penalty applied. Size reduced 50%.");
   }
   
   return baseMultiplier;
}

//+------------------------------------------------------------------+
//| FUNCTION: ExecuteDebateTrade()                                    |
//| The main entry point -- runs debate + risk panel + executes        |
//| Returns ticket number or -1 if rejected                           |
//+------------------------------------------------------------------+
int ExecuteDebateTrade() {
   //--- Phase 1: Run debate on collected signals
   DebateResult debate = RunDebate();
   
   if (!debate.approved) {
      LogError("EXECUTE: Debate rejected. No trade.");
      return -1;
   }
   
   //--- Phase 2: Find the winning signal (highest conviction in winning direction)
   StrategySignal bestSignal;
   double bestConv = 0;
   bool foundSignal = false;
   
   for (int i = 0; i < g_signalCount; i++) {
      if (g_signals[i].direction == debate.direction &&
          g_signals[i].conviction > bestConv) {
         bestSignal = g_signals[i];
         bestConv = g_signals[i].conviction;
         foundSignal = true;
      }
   }
   
   if (!foundSignal) {
      LogError("EXECUTE: No signal found in winning direction.");
      return -1;
   }
   
   //--- Phase 3: Run risk panel on the best signal
   RiskPanelResult risk = RunRiskPanel(bestSignal);
   
   if (risk.approvals < RISK_PANEL_MIN_APPROVALS) {
      LogError("EXECUTE: Risk panel rejected (" +
               IntegerToString(risk.approvals) + "/3). No trade.");
      return -1;
   }
   
   //--- Phase 4: Calculate debate-adjusted position size
   double sizeMult = GetDebateSizeMultiplier(debate.consensusConviction,
                                              risk.approvals,
                                              debate.isDivergent);
   
   if (sizeMult <= 0) {
      LogError("EXECUTE: Size multiplier is 0. No trade.");
      return -1;
   }
   
   //--- Apply debate multiplier to the strategy's suggested lots
   double debateLots = bestSignal.suggestedLots * sizeMult;
   
   //--- Clamp to broker limits
   debateLots = MathMax(MarketInfo(Symbol(), MODE_MINLOT),
                MathMin(MarketInfo(Symbol(), MODE_MAXLOT),
                NormalizeDouble(debateLots, 2)));
   
   //--- Phase 5: Execute the trade
   int ticket = -1;
   double price = (debate.direction == OP_BUY) ? Ask : Bid;
   
   int slippage = 3;
   string comment = "D:" + IntegerToString(debate.signalsReceived) + "sig" +
                    "|" + DoubleToStr(debate.consensusConviction, 2) +
                    "|R" + IntegerToString(risk.approvals);
   
   ticket = OrderSend(Symbol(), debate.direction, debateLots,
                      NormalizeDouble(price, (int)MarketInfo(Symbol(), MODE_DIGITS)),
                      slippage,
                      NormalizeDouble(bestSignal.suggestedSL, (int)MarketInfo(Symbol(), MODE_DIGITS)),
                      NormalizeDouble(bestSignal.suggestedTP, (int)MarketInfo(Symbol(), MODE_DIGITS)),
                      comment, bestSignal.magic, 0,
                      (debate.direction == OP_BUY) ? clrLime : clrRed);
   
   if (ticket > 0) {
      LogError("EXECUTE: TRADE OPENED #" + IntegerToString(ticket) +
               " " + (debate.direction == OP_BUY ? "BUY" : "SELL") +
               " " + DoubleToStr(debateLots, 2) + " lots" +
               " | Size mult=" + DoubleToStr(sizeMult, 2) +
               " | " + debate.agreedStrategies);
      
      //--- Log for deferred reflection
      LogTradeEntry(ticket, debate, risk, bestSignal, debateLots);
   }
   else {
      int err = GetLastError();
      LogError("EXECUTE: OrderSend FAILED. Error=" + IntegerToString(err));
   }
   
   return ticket;
}

//+------------------------------------------------------------------+
//| FUNCTION: LogTradeEntry()                                         |
//| Records trade details for deferred reflection                     |
//+------------------------------------------------------------------+
void LogTradeEntry(int ticket, DebateResult &debate, RiskPanelResult &risk,
                   StrategySignal &signal, double lots) {
   
   int idx = g_tradeLogCount;
   g_tradeLogCount++;
   ArrayResize(g_tradeLog, g_tradeLogCount);
   
   g_tradeLog[idx].ticket = ticket;
   g_tradeLog[idx].entryTime = TimeCurrent();
   g_tradeLog[idx].direction = debate.direction;
   g_tradeLog[idx].entryPrice = signal.entryPrice;
   g_tradeLog[idx].lots = lots;
   g_tradeLog[idx].conviction = debate.consensusConviction;
   g_tradeLog[idx].riskApprovals = risk.approvals;
   g_tradeLog[idx].strategiesAgreed = debate.agreedStrategies;
   g_tradeLog[idx].strategiesDisagreed = debate.disagreedStrategies;
   g_tradeLog[idx].atrAtEntry = iATR(Symbol(), PERIOD_H4, 14, 0);
   g_tradeLog[idx].hurstAtEntry = g_hurstValue;
   g_tradeLog[idx].adxAtEntry = g_adxValue;
   
   //--- Exit data filled later
   g_tradeLog[idx].exitPrice = 0;
   g_tradeLog[idx].pnl = 0;
   g_tradeLog[idx].holdDuration = 0;
   g_tradeLog[idx].thesisCorrect = false;
}

//+------------------------------------------------------------------+
//| FUNCTION: ProcessTradeClose()                                     |
//| Call when a debate trade closes -- fills exit data + adjusts weights|
//+------------------------------------------------------------------+
void ProcessTradeClose(int ticket, double exitPrice, double pnl) {
   for (int i = 0; i < g_tradeLogCount; i++) {
      if (g_tradeLog[i].ticket == ticket) {
         g_tradeLog[i].exitPrice = exitPrice;
         g_tradeLog[i].pnl = pnl;
         g_tradeLog[i].holdDuration = (TimeCurrent() - g_tradeLog[i].entryTime) / 3600.0;
         
         //--- Was the thesis correct?
         if (g_tradeLog[i].direction == OP_BUY)
            g_tradeLog[i].thesisCorrect = (exitPrice > g_tradeLog[i].entryPrice);
         else
            g_tradeLog[i].thesisCorrect = (exitPrice < g_tradeLog[i].entryPrice);
         
         //--- Deferred reflection: adjust strategy weights
         AdjustWeightsFromReflection(g_tradeLog[i]);
         
         LogError("REFLECTION: Ticket #" + IntegerToString(ticket) +
                  " | PnL=" + DoubleToStr(pnl, 2) +
                  " | Thesis=" + (g_tradeLog[i].thesisCorrect ? "CORRECT" : "WRONG") +
                  " | Conviction=" + DoubleToStr(g_tradeLog[i].conviction, 2));
         
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| FUNCTION: AdjustWeightsFromReflection()                           |
//| Boost strategies that were right, penalize those that were wrong  |
//+------------------------------------------------------------------+
void AdjustWeightsFromReflection(TradeLog &log) {
   //--- Only adjust if conviction was meaningful
   if (log.conviction < 0.3) return;
   
   double adjustment = 0.05;  // 5% boost or penalty per trade
   
   if (log.thesisCorrect) {
      //--- Correct thesis: boost agreed strategies
      //--- Parse agreed strategies by magic
      for (int i = 0; i < g_signalCount; i++) {
         string name = GetStrategyNameByMagic(g_signals[i].magic);
         if (StringFind(log.strategiesAgreed, name) >= 0) {
            int idx = GetStrategyIndexByMagic(g_signals[i].magic);
            if (idx >= 0 && idx < MAX_MAGIC) {
               g_strategyWeightAdj[idx] += adjustment;
               g_strategyWeightAdj[idx] = MathMin(2.0, g_strategyWeightAdj[idx]);
            }
         }
      }
   }
   else {
      //--- Wrong thesis: penalize agreed strategies
      for (int i = 0; i < g_signalCount; i++) {
         string name = GetStrategyNameByMagic(g_signals[i].magic);
         if (StringFind(log.strategiesAgreed, name) >= 0) {
            int idx = GetStrategyIndexByMagic(g_signals[i].magic);
            if (idx >= 0 && idx < MAX_MAGIC) {
               g_strategyWeightAdj[idx] -= adjustment;
               g_strategyWeightAdj[idx] = MathMax(0.25, g_strategyWeightAdj[idx]);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FUNCTION: GetTotalExposurePercent()                               |
//| Returns current exposure as % of max allowed                      |
//+------------------------------------------------------------------+
double GetTotalExposurePercent() {
   int openTrades = CountOpenTrades();
   if (InpMaxOpenTrades <= 0) return 0;
   return (openTrades / (double)InpMaxOpenTrades) * 100.0;
}

//+------------------------------------------------------------------+
//| FUNCTION: CountTradesByDirection()                                |
//| Counts open trades in a given direction                           |
//+------------------------------------------------------------------+
int CountTradesByDirection(int direction) {
   int count = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol() == Symbol() && OrderType() == direction)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| FUNCTION: HasOpenPositionByMagic()                                |
//| Checks if a strategy already has an open trade                    |
//+------------------------------------------------------------------+
bool HasOpenPositionByMagic(int magic) {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic)
            return true;
      }
   }
   return false;
}

#endif // DEBATE_LAYER_MQH
//+------------------------------------------------------------------+
