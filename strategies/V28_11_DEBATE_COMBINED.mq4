//+------------------------------------------------------------------+
//| DESTROYER QUANTUM V28.11 - DEBATE LAYER (COMBINED)                |
//| VENI VIDI VICI                                                    |
//|                                                                   |
//| This file contains:                                               |
//|   1. Debate Engine (signals, voting, risk panel, sizing, reflect) |
//|   2. All 12 strategies converted for debate signal submission     |
//|   3. OnNewBar_DebateLayer() drop-in hook                         |
//|                                                                   |
//| INTEGRATION:                                                      |
//|   1. #include this file at top of your EA                        |
//|   2. Call InitDebateLayer() in OnInit()                          |
//|   3. Replace OnNewBar() strategy block with OnNewBar_DebateLayer()|
//|   4. Call ProcessTradeClose() when debate trades close           |
//+------------------------------------------------------------------+

     1|//+------------------------------------------------------------------+
     2|//| V28_11_DEBATE_LAYER.mqh - Signal Debate & Risk Panel             |
     3|//| DESTROYER QUANTUM V28.11 - VENI VIDI VICI                        |
     4|//| Inspired by TradingAgents (TauricResearch)                       |
     5|//| Bolt-on to V28.06 -- does NOT modify existing strategy logic      |
     6|//+------------------------------------------------------------------+
     7|
     8|#ifndef DEBATE_LAYER_MQH
     9|#define DEBATE_LAYER_MQH
    10|
    11|//--- Maximum number of strategies that can submit signals
    12|#define MAX_SIGNALS 16
    13|
    14|//--- Minimum weighted conviction for a trade to pass debate
    15|#define MIN_CONVICTION_THRESHOLD 0.30
    16|
    17|//--- Divergence threshold (both sides above this = conflict)
    18|#define DIVERGENCE_THRESHOLD 0.50
    19|
    20|//--- Size multipliers per tier
    21|#define TIER1_SIZE_MULT 1.5   // STRONG: high conviction + 3/3 approve
    22|#define TIER2_SIZE_MULT 1.0   // NORMAL: good conviction + 2/3 approve
    23|#define TIER3_SIZE_MULT 0.7   // CAUTIOUS: moderate conviction + 2/3 approve
    24|#define TIER4_SIZE_MULT 0.0   // HOLD: low conviction or < 2 approve
    25|
    26|//--- Conservative persona thresholds
    27|#define CONSERVATIVE_MIN_CONVICTION 0.50
    28|#define CONSERVATIVE_MAX_SL_PIPS    200.0
    29|#define CONSERVATIVE_MAX_CONSEC_LOSSES 3
    30|
    31|//--- Neutral persona thresholds
    32|#define NEUTRAL_MAX_EXPOSURE_PCT    80.0
    33|#define NEUTRAL_MAX_SAME_DIRECTION  5
    34|
    35|//--- Risk panel: how many of 3 must approve
    36|#define RISK_PANEL_MIN_APPROVALS 2
    37|
    38|//+------------------------------------------------------------------+
    39|//| STRUCT: StrategySignal                                            |
    40|//| Output from each strategy instead of direct OrderSend()          |
    41|//+------------------------------------------------------------------+
    42|struct StrategySignal {
    43|   int      magic;            // Strategy magic number
    44|   int      direction;        // OP_BUY, OP_SELL, or -1 (no signal)
    45|   double   conviction;       // 0.0 to 1.0 (strength of signal)
    46|   string   reason;           // Human-readable reason
    47|   double   suggestedLots;    // What the strategy would normally trade
    48|   double   suggestedSL;      // Suggested stop loss (price)
    49|   double   suggestedTP;      // Suggested take profit (price)
    50|   double   entryPrice;       // Current price at signal time
    51|   datetime signalTime;       // When the signal was generated
    52|};
    53|
    54|//+------------------------------------------------------------------+
    55|//| STRUCT: DebateResult                                              |
    56|//| Output from the debate engine                                     |
    57|//+------------------------------------------------------------------+
    58|struct DebateResult {
    59|   bool     approved;         // Did the debate approve a trade?
    60|   int      direction;        // OP_BUY or OP_SELL
    61|   double   consensusConviction; // Weighted consensus (0-1)
    62|   double   buyConviction;    // Total weighted BUY conviction
    63|   double   sellConviction;   // Total weighted SELL conviction
    64|   bool     isDivergent;      // Both sides strong = warning
    65|   int      signalsReceived;  // How many strategies submitted
    66|   int      buySignals;       // How many said BUY
    67|   int      sellSignals;      // How many said SELL
    68|   string   agreedStrategies; // Comma-separated list of winning side
    69|   string   disagreedStrategies; // Comma-separated list of losing side
    70|};
    71|
    72|//+------------------------------------------------------------------+
    73|//| STRUCT: RiskPanelResult                                           |
    74|//| Output from the 3-way risk evaluation                             |
    75|//+------------------------------------------------------------------+
    76|struct RiskPanelResult {
    77|   int      approvals;        // 0-3 (how many approved)
    78|   bool     aggressiveApproved;
    79|   bool     conservativeApproved;
    80|   bool     neutralApproved;
    81|   string   aggressiveReason;
    82|   string   conservativeReason;
    83|   string   neutralReason;
    84|};
    85|
    86|//+------------------------------------------------------------------+
    87|//| STRUCT: TradeLog                                                  |
    88|//| For deferred reflection -- log why trades were taken               |
    89|//+------------------------------------------------------------------+
    90|struct TradeLog {
    91|   //--- Entry data (logged on open)
    92|   int      ticket;
    93|   datetime entryTime;
    94|   int      direction;
    95|   double   entryPrice;
    96|   double   lots;
    97|   double   conviction;
    98|   int      riskApprovals;
    99|   string   strategiesAgreed;
   100|   string   strategiesDisagreed;
   101|   double   atrAtEntry;
   102|   double   hurstAtEntry;
   103|   double   adxAtEntry;
   104|   //--- Exit data (logged on close)
   105|   double   exitPrice;
   106|   double   pnl;
   107|   double   holdDuration;
   108|   bool     thesisCorrect;
   109|};
   110|
   111|//+------------------------------------------------------------------+
   112|//| GLOBAL: Signal buffer                                             |
   113|//+------------------------------------------------------------------+
   114|StrategySignal g_signals[MAX_SIGNALS];
   115|int            g_signalCount = 0;
   116|
   117|//+------------------------------------------------------------------+
   118|//| GLOBAL: Trade log buffer                                          |
   119|//+------------------------------------------------------------------+
   120|TradeLog       g_tradeLog[];
   121|int            g_tradeLogCount = 0;
   122|
   123|//+------------------------------------------------------------------+
   124|//| GLOBAL: Strategy weight overrides (from deferred reflection)      |
   125|//+------------------------------------------------------------------+
   126|double         g_strategyWeightAdj[MAX_MAGIC];  // Adjustment multiplier
   127|bool           g_weightAdjInitialized = false;
   128|
   129|//+------------------------------------------------------------------+
   130|//| FUNCTION: InitDebateLayer()                                       |
   131|//| Call once in OnInit()                                             |
   132|//+------------------------------------------------------------------+
   133|void InitDebateLayer() {
   134|   g_signalCount = 0;
   135|   g_tradeLogCount = 0;
   136|   g_weightAdjInitialized = false;
   137|   
   138|   //--- Initialize weight adjustments to 1.0 (no adjustment)
   139|   for (int i = 0; i < MAX_MAGIC; i++) {
   140|      g_strategyWeightAdj[i] = 1.0;
   141|   }
   142|   g_weightAdjInitialized = true;
   143|   
   144|   LogError("DEBATE LAYER: Initialized. " + IntegerToString(MAX_SIGNALS) + " signal slots.");
   145|}
   146|
   147|//+------------------------------------------------------------------+
   148|//| FUNCTION: ResetSignals()                                          |
   149|//| Call at start of each OnNewBar() to clear previous signals       |
   150|//+------------------------------------------------------------------+
   151|void ResetSignals() {
   152|   g_signalCount = 0;
   153|   ArrayResize(g_signals, 0);
   154|}
   155|
   156|//+------------------------------------------------------------------+
   157|//| FUNCTION: SubmitSignal()                                          |
   158|//| Each strategy calls this instead of OrderSend()                   |
   159|//| Returns true if signal was accepted                               |
   160|//+------------------------------------------------------------------+
   161|bool SubmitSignal(int magic, int direction, double conviction,
   162|                  string reason, double lots, double sl, double tp) {
   163|   
   164|   //--- Validate
   165|   if (direction != OP_BUY && direction != OP_SELL) return false;
   166|   if (conviction < 0.0 || conviction > 1.0) return false;
   167|   if (g_signalCount >= MAX_SIGNALS) {
   168|      LogError("DEBATE: Signal buffer full. Dropping signal from magic " + IntegerToString(magic));
   169|      return false;
   170|   }
   171|   
   172|   //--- Add signal to buffer
   173|   int idx = g_signalCount;
   174|   g_signalCount++;
   175|   ArrayResize(g_signals, g_signalCount);
   176|   
   177|   g_signals[idx].magic = magic;
   178|   g_signals[idx].direction = direction;
   179|   g_signals[idx].conviction = conviction;
   180|   g_signals[idx].reason = reason;
   181|   g_signals[idx].suggestedLots = lots;
   182|   g_signals[idx].suggestedSL = sl;
   183|   g_signals[idx].suggestedTP = tp;
   184|   g_signals[idx].entryPrice = (direction == OP_BUY) ? Ask : Bid;
   185|   g_signals[idx].signalTime = TimeCurrent();
   186|   
   187|   return true;
   188|}
   189|
   190|//+------------------------------------------------------------------+
   191|//| FUNCTION: GetStrategyWeight()                                     |
   192|//| Returns credibility weight based on rolling PF + reflection adj   |
   193|//+------------------------------------------------------------------+
   194|double GetStrategyWeight(int magic) {
   195|   int idx = GetStrategyIndexByMagic(magic);
   196|   if (idx < 0) return 1.0;
   197|   
   198|   //--- Base weight from rolling Profit Factor
   199|   double pf = g_stratRollingPF[idx];
   200|   double baseWeight = 1.0;
   201|   
   202|   if (pf < 1.0)       baseWeight = 0.5;   // Losing strategies: half voice
   203|   else if (pf < 1.5)  baseWeight = 1.0;   // Marginal: normal voice
   204|   else if (pf < 2.0)  baseWeight = 1.5;   // Good: 1.5x voice
   205|   else if (pf < 3.0)  baseWeight = 2.0;   // Great: 2x voice
   206|   else                 baseWeight = 3.0;   // Elite (PF 3+): 3x voice
   207|   
   208|   //--- Cap weight for strategies with too few trades
   209|   int totalTrades = g_stratTotalTrades[idx];
   210|   if (totalTrades < 5) baseWeight = MathMin(baseWeight, 1.0);  // Not enough data
   211|   
   212|   //--- Apply deferred reflection adjustment
   213|   if (g_weightAdjInitialized && idx < MAX_MAGIC) {
   214|      baseWeight *= g_strategyWeightAdj[idx];
   215|   }
   216|   
   217|   //--- Clamp to reasonable range
   218|   return MathMax(0.25, MathMin(3.0, baseWeight));
   219|}
   220|
   221|//+------------------------------------------------------------------+
   222|//| FUNCTION: RunDebate()                                             |
   223|//| The core debate engine -- weighs signals, detects divergence       |
   224|//+------------------------------------------------------------------+
   225|DebateResult RunDebate() {
   226|   DebateResult result;
   227|   result.approved = false;
   228|   result.direction = -1;
   229|   result.consensusConviction = 0;
   230|   result.buyConviction = 0;
   231|   result.sellConviction = 0;
   232|   result.isDivergent = false;
   233|   result.signalsReceived = g_signalCount;
   234|   result.buySignals = 0;
   235|   result.sellSignals = 0;
   236|   result.agreedStrategies = "";
   237|   result.disagreedStrategies = "";
   238|   
   239|   //--- No signals = no trade
   240|   if (g_signalCount == 0) return result;
   241|   
   242|   //--- Calculate weighted conviction for each side
   243|   double totalWeight = 0;
   244|   
   245|   for (int i = 0; i < g_signalCount; i++) {
   246|      double weight = GetStrategyWeight(g_signals[i].magic);
   247|      double weightedConviction = g_signals[i].conviction * weight;
   248|      
   249|      if (g_signals[i].direction == OP_BUY) {
   250|         result.buyConviction += weightedConviction;
   251|         result.buySignals++;
   252|      }
   253|      else if (g_signals[i].direction == OP_SELL) {
   254|         result.sellConviction += weightedConviction;
   255|         result.sellSignals++;
   256|      }
   257|      
   258|      totalWeight += weight;
   259|   }
   260|   
   261|   //--- Normalize to 0-1 range
   262|   if (totalWeight > 0) {
   263|      result.buyConviction /= totalWeight;
   264|      result.sellConviction /= totalWeight;
   265|   }
   266|   
   267|   //--- Determine winning direction
   268|   double winningConviction = 0;
   269|   if (result.buyConviction > result.sellConviction) {
   270|      result.direction = OP_BUY;
   271|      winningConviction = result.buyConviction;
   272|   }
   273|   else if (result.sellConviction > result.buyConviction) {
   274|      result.direction = OP_SELL;
   275|      winningConviction = result.sellConviction;
   276|   }
   277|   else {
   278|      //--- Exact tie -- no trade
   279|      LogError("DEBATE: Exact tie between BUY and SELL. No trade.");
   280|      return result;
   281|   }
   282|   
   283|   result.consensusConviction = winningConviction;
   284|   
   285|   //--- Divergence detection
   286|   result.isDivergent = (result.buyConviction > DIVERGENCE_THRESHOLD &&
   287|                         result.sellConviction > DIVERGENCE_THRESHOLD);
   288|   
   289|   if (result.isDivergent) {
   290|      LogError("DEBATE: DIVERGENCE detected. BUY=" + DoubleToStr(result.buyConviction, 2) +
   291|               " SELL=" + DoubleToStr(result.sellConviction, 2));
   292|   }
   293|   
   294|   //--- Build agreed/disagreed lists
   295|   for (int i = 0; i < g_signalCount; i++) {
   296|      string stratName = GetStrategyNameByMagic(g_signals[i].magic);
   297|      if (g_signals[i].direction == result.direction) {
   298|         if (result.agreedStrategies != "") result.agreedStrategies += ",";
   299|         result.agreedStrategies += stratName;
   300|      }
   301|      else {
   302|         if (result.disagreedStrategies != "") result.disagreedStrategies += ",";
   303|         result.disagreedStrategies += stratName;
   304|      }
   305|   }
   306|   
   307|   //--- Check minimum conviction threshold
   308|   if (winningConviction < MIN_CONVICTION_THRESHOLD) {
   309|      LogError("DEBATE: Conviction " + DoubleToStr(winningConviction, 2) +
   310|               " below threshold " + DoubleToStr(MIN_CONVICTION_THRESHOLD, 2) + ". No trade.");
   311|      return result;
   312|   }
   313|   
   314|   result.approved = true;
   315|   
   316|   LogError("DEBATE: APPROVED " + (result.direction == OP_BUY ? "BUY" : "SELL") +
   317|            " | Conviction=" + DoubleToStr(winningConviction, 2) +
   318|            " | BUY=" + IntegerToString(result.buySignals) +
   319|            " SELL=" + IntegerToString(result.sellSignals) +
   320|            " | Agreed: " + result.agreedStrategies);
   321|   
   322|   return result;
   323|}
   324|
   325|//+------------------------------------------------------------------+
   326|//| FUNCTION: AggressiveRiskCheck()                                   |
   327|//| Only blocks EXTREME risk -- lets almost everything through         |
   328|//+------------------------------------------------------------------+
   329|bool AggressiveRiskCheck(StrategySignal &signal, string &reason) {
   330|   //--- Check 1: Extreme volatility (ATR > 3x average)
   331|   double currentATR = iATR(Symbol(), PERIOD_H4, 14, 0);
   332|   double avgATR = 0;
   333|   for (int i = 1; i <= 20; i++) avgATR += iATR(Symbol(), PERIOD_H4, 14, i);
   334|   avgATR /= 20.0;
   335|   
   336|   if (currentATR > 3.0 * avgATR) {
   337|      reason = "Extreme volatility: ATR " + DoubleToStr(currentATR, 1) +
   338|               " > 3x avg " + DoubleToStr(avgATR, 1);
   339|      return false;
   340|   }
   341|   
   342|   //--- Check 2: Already in drawdown protection mode
   343|   if (g_ddProtectionActive) {
   344|      reason = "DD protection active";
   345|      return false;
   346|   }
   347|   
   348|   //--- Check 3: Max open trades reached
   349|   if (CountOpenTrades() >= InpMaxOpenTrades) {
   350|      reason = "Max open trades: " + IntegerToString(InpMaxOpenTrades);
   351|      return false;
   352|   }
   353|   
   354|   reason = "Approved (aggressive)";
   355|   return true;
   356|}
   357|
   358|//+------------------------------------------------------------------+
   359|//| FUNCTION: ConservativeRiskCheck()                                 |
   360|//| Requires multiple confirmations -- high bar for entry              |
   361|//+------------------------------------------------------------------+
   362|bool ConservativeRiskCheck(StrategySignal &signal, string &reason) {
   363|   //--- Check 1: Minimum conviction
   364|   if (signal.conviction < CONSERVATIVE_MIN_CONVICTION) {
   365|      reason = "Conviction " + DoubleToStr(signal.conviction, 2) +
   366|               " < " + DoubleToStr(CONSERVATIVE_MIN_CONVICTION, 2);
   367|      return false;
   368|   }
   369|   
   370|   //--- Check 2: Trend alignment (D1 EMA50)
   371|   double ema50_D1 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   372|   double price = (signal.direction == OP_BUY) ? Ask : Bid;
   373|   
   374|   if (signal.direction == OP_BUY && price < ema50_D1) {
   375|      reason = "BUY against D1 trend (price < EMA50)";
   376|      return false;
   377|   }
   378|   if (signal.direction == OP_SELL && price > ema50_D1) {
   379|      reason = "SELL against D1 trend (price > EMA50)";
   380|      return false;
   381|   }
   382|   
   383|   //--- Check 3: Stop loss too wide
   384|   double slPips = MathAbs(signal.entryPrice - signal.suggestedSL) / g_pipValue;
   385|   if (slPips > CONSERVATIVE_MAX_SL_PIPS) {
   386|      reason = "SL too wide: " + DoubleToStr(slPips, 0) + " pips > " +
   387|               DoubleToStr(CONSERVATIVE_MAX_SL_PIPS, 0);
   388|      return false;
   389|   }
   390|   
   391|   //--- Check 4: Consecutive losses
   392|   if (g_kellyConsecutiveLosses >= CONSERVATIVE_MAX_CONSEC_LOSSES) {
   393|      reason = "Consecutive losses: " + IntegerToString(g_kellyConsecutiveLosses) +
   394|               " >= " + IntegerToString(CONSERVATIVE_MAX_CONSEC_LOSSES);
   395|      return false;
   396|   }
   397|   
   398|   reason = "Approved (conservative)";
   399|   return true;
   400|}
   401|
   402|//+------------------------------------------------------------------+
   403|//| FUNCTION: NeutralRiskCheck()                                      |
   404|//| Portfolio-level risk management -- exposure and correlation         |
   405|//+------------------------------------------------------------------+
   406|bool NeutralRiskCheck(StrategySignal &signal, string &reason) {
   407|   //--- Check 1: Total exposure
   408|   double currentExposure = GetTotalExposurePercent();
   409|   if (currentExposure > NEUTRAL_MAX_EXPOSURE_PCT) {
   410|      reason = "Exposure " + DoubleToStr(currentExposure, 0) +
   411|               "% > " + DoubleToStr(NEUTRAL_MAX_EXPOSURE_PCT, 0) + "%";
   412|      return false;
   413|   }
   414|   
   415|   //--- Check 2: Same direction concentration
   416|   int sameDirCount = CountTradesByDirection(signal.direction);
   417|   if (sameDirCount >= NEUTRAL_MAX_SAME_DIRECTION) {
   418|      reason = IntegerToString(sameDirCount) + " trades already " +
   419|               (signal.direction == OP_BUY ? "BUY" : "SELL") +
   420|               " (max " + IntegerToString(NEUTRAL_MAX_SAME_DIRECTION) + ")";
   421|      return false;
   422|   }
   423|   
   424|   //--- Check 3: Duplicate magic (same strategy already has open trade)
   425|   if (HasOpenPositionByMagic(signal.magic)) {
   426|      reason = "Strategy " + GetStrategyNameByMagic(signal.magic) +
   427|               " already has open position";
   428|      return false;
   429|   }
   430|   
   431|   reason = "Approved (neutral)";
   432|   return true;
   433|}
   434|
   435|//+------------------------------------------------------------------+
   436|//| FUNCTION: RunRiskPanel()                                          |
   437|//| 3-way risk debate: Aggressive, Conservative, Neutral              |
   438|//| Returns how many approved (0-3)                                   |
   439|//+------------------------------------------------------------------+
   440|RiskPanelResult RunRiskPanel(StrategySignal &signal) {
   441|   RiskPanelResult result;
   442|   
   443|   result.aggressiveApproved = AggressiveRiskCheck(signal, result.aggressiveReason);
   444|   result.conservativeApproved = ConservativeRiskCheck(signal, result.conservativeReason);
   445|   result.neutralApproved = NeutralRiskCheck(signal, result.neutralReason);
   446|   
   447|   result.approvals = 0;
   448|   if (result.aggressiveApproved)   result.approvals++;
   449|   if (result.conservativeApproved) result.approvals++;
   450|   if (result.neutralApproved)      result.approvals++;
   451|   
   452|   LogError("RISK PANEL: " + IntegerToString(result.approvals) + "/3 approved" +
   453|            " | Aggr=" + (result.aggressiveApproved ? "YES" : "NO") +
   454|            " | Cons=" + (result.conservativeApproved ? "YES" : "NO") +
   455|            " | Neut=" + (result.neutralApproved ? "YES" : "NO"));
   456|   
   457|   if (result.approvals < RISK_PANEL_MIN_APPROVALS) {
   458|      if (!result.conservativeApproved)
   459|         LogError("RISK PANEL REJECT (conservative): " + result.conservativeReason);
   460|      if (!result.neutralApproved)
   461|         LogError("RISK PANEL REJECT (neutral): " + result.neutralReason);
   462|   }
   463|   
   464|   return result;
   465|}
   466|
   467|//+------------------------------------------------------------------+
   468|//| FUNCTION: GetDebateSizeMultiplier()                               |
   469|//| Maps conviction + approvals to 5-tier position sizing             |
   470|//+------------------------------------------------------------------+
   471|double GetDebateSizeMultiplier(double conviction, int approvals, bool isDivergent) {
   472|   double baseMultiplier = 0.0;
   473|   
   474|   //--- Tier 1: STRONG -- high conviction + all 3 approve
   475|   if (conviction >= 0.80 && approvals == 3)
   476|      baseMultiplier = TIER1_SIZE_MULT;
   477|   
   478|   //--- Tier 2: NORMAL -- good conviction + 2+ approve
   479|   else if (conviction >= 0.50 && approvals >= 2)
   480|      baseMultiplier = TIER2_SIZE_MULT;
   481|   
   482|   //--- Tier 3: CAUTIOUS -- moderate conviction + 2+ approve
   483|   else if (conviction >= 0.30 && approvals >= 2)
   484|      baseMultiplier = TIER3_SIZE_MULT;
   485|   
   486|   //--- Tier 4/5: HOLD -- reject
   487|   else
   488|      baseMultiplier = TIER4_SIZE_MULT;
   489|   
   490|   //--- Divergence penalty: reduce size 50%
   491|   if (isDivergent && baseMultiplier > 0) {
   492|      baseMultiplier *= 0.5;
   493|      LogError("SIZING: Divergence penalty applied. Size reduced 50%.");
   494|   }
   495|   
   496|   return baseMultiplier;
   497|}
   498|
   499|//+------------------------------------------------------------------+
   500|//| FUNCTION: ExecuteDebateTrade()                                    |
   501|

//+------------------------------------------------------------------+
//| STRATEGY CONVERSIONS                                              |
//+------------------------------------------------------------------+

     1|//+------------------------------------------------------------------+
     2|//| V28.11_STRATEGIES_DEBATE.mq4                                      |
     3|//| All V28.06 strategies converted for debate layer                  |
     4|//| Each returns a signal instead of executing directly                |
     5|//| Include V28_11_DEBATE_LAYER.mq4 in your EA first                 |
     6|//+------------------------------------------------------------------+
     7|
     8|//+------------------------------------------------------------------+
     9|//| MEAN REVERSION - RSI+BB+Hurst adaptive                           |
    10|//| Original magic: InpMagic_MeanReversion                           |
    11|//+------------------------------------------------------------------+
    12|void ExecuteMeanReversion_DEBATE()
    13|{
    14|   if(Period() != PERIOD_H4) return;
    15|   if(!InpMeanReversion_Enabled) return;
    16|   if(!IsStrategyHealthy(InpMagic_MeanReversion)) return;
    17|   if(g_hive_state == HIVE_STATE_DEFENSIVE && !InpMR_Allow_Defensive) return;
    18|   if(InpEnable_ReaperConditionFilter && !IsReaperConditionMet()) return;
    19|   if(InpEnableMarketFilters && !CheckMarketConditions()) return;
    20|   if(InpEnableTimeFilter && !CheckTimeFilter()) return;
    21|
    22|   int shift = 0;
    23|   g_active_model = MODEL_MEAN_REVERSION;
    24|
    25|   // Regime-adaptive bands (V18.2)
    26|   double Hurst = CalculateHurstExponent(Symbol(), Period(), 100);
    27|   double adaptive_dev = 2.0;
    28|   double rsi_upper = 70;
    29|   double rsi_lower = 30;
    30|
    31|   if(Hurst < 0.50) {
    32|      adaptive_dev = 1.8; rsi_upper = 65; rsi_lower = 35;
    33|   } else if(Hurst >= 0.40 && Hurst <= 0.60) {
    34|      adaptive_dev = 2.2; rsi_upper = 70; rsi_lower = 30;
    35|   } else {
    36|      adaptive_dev = 3.5; rsi_upper = 80; rsi_lower = 20;
    37|   }
    38|
    39|   // Technical indicators
    40|   double bb_upper = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_UPPER, shift);
    41|   double bb_lower = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_LOWER, shift);
    42|   double rsi_val  = iRSI(Symbol(), Period(), 14, PRICE_CLOSE, shift);
    43|   double price    = Close[shift];
    44|
    45|   bool buy_signal  = (price < bb_lower) && (rsi_val < rsi_lower);
    46|   bool sell_signal = (price > bb_upper) && (rsi_val > rsi_upper);
    47|
    48|   // Elastic scoring (V25 Fix #3)
    49|   if(InpAlphaExpand && InpElasticScoring) {
    50|      int stratIdx = V23_FindStrategyIndex(InpMagic_MeanReversion);
    51|      if(stratIdx >= 0) {
    52|         double prob = V23_GetEmpiricalProb(stratIdx, MathAbs((price - iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)) / iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)));
    53|         double rExpect = v23_stratPerf[stratIdx].rExpectancy;
    54|         double rsiScore_Buy = 0, rsiScore_Sell = 0;
    55|         if(rsi_val < 30) rsiScore_Buy = 1.0 * prob;
    56|         else if(rsi_val < 40) rsiScore_Buy = 0.7 * prob;
    57|         else if(rsi_val < 45) rsiScore_Buy = 0.3 * prob;
    58|         if(rsi_val > 70) rsiScore_Sell = 1.0 * prob;
    59|         else if(rsi_val > 60) rsiScore_Sell = 0.7 * prob;
    60|         else if(rsi_val > 55) rsiScore_Sell = 0.3 * prob;
    61|         double bbRange = bb_upper - bb_lower;
    62|         double bbScore_Buy = (bbRange > 0) ? MathAbs(price - bb_lower) / bbRange : 0;
    63|         double bbScore_Sell = (bbRange > 0) ? MathAbs(price - bb_upper) / bbRange : 0;
    64|         bbScore_Buy = (price < bb_lower) ? (1.0 - bbScore_Buy) * rExpect : 0;
    65|         bbScore_Sell = (price > bb_upper) ? (1.0 - bbScore_Sell) * rExpect : 0;
    66|         double regimeContrib = v23_regime.confidence * 0.2;
    67|         double totalScore_Buy = 0.5 * rsiScore_Buy + 0.3 * bbScore_Buy + regimeContrib;
    68|         double totalScore_Sell = 0.5 * rsiScore_Sell + 0.3 * bbScore_Sell + regimeContrib;
    69|         double scoreThreshold = 0.6 - (prob * 0.1);
    70|         scoreThreshold = MathMax(0.4, MathMin(0.7, scoreThreshold));
    71|         buy_signal = (totalScore_Buy > scoreThreshold);
    72|         sell_signal = (totalScore_Sell > scoreThreshold);
    73|      }
    74|   }
    75|
    76|   // Safety checks
    77|   double ADX = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 0);
    78|   if(ADX > 50) return;
    79|   if(IsTrendTooStrong()) return;
    80|   if(!Filter_CounterTrend()) return;
    81|
    82|   if(buy_signal && !IsMeanReversionSafe(OP_BUY)) buy_signal = false;
    83|   if(sell_signal && !IsMeanReversionSafe(OP_SELL)) sell_signal = false;
    84|
    85|   if(!buy_signal && !sell_signal) return;
    86|
    87|   // Conviction: based on RSI extremity + BB distance + Hurst regime
    88|   double rsiDev = MathAbs(rsi_val - 50.0) / 50.0;
    89|   double bbDist = MathAbs((price - bb_lower) / (bb_upper - bb_lower));
    90|   double regimeBonus = 0;
    91|   if(Hurst < 0.50) regimeBonus = 0.3;
    92|   else if(Hurst <= 0.60) regimeBonus = 0.15;
    93|   double conviction = MathMin(1.0, (rsiDev * 0.4 + bbDist * 0.3 + regimeBonus));
    94|
    95|   int direction = buy_signal ? OP_BUY : OP_SELL;
    96|   double atr_stop = GetATRStopLossPips() * Point;
    97|   double sl, tp, lots;
    98|
    99|   if(direction == OP_BUY) {
   100|      sl = Ask - atr_stop;
   101|      tp = Ask + atr_stop * 2.2;
   102|      lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, GetATRStopLossPips());
   103|   } else {
   104|      sl = Bid + atr_stop;
   105|      tp = Bid - atr_stop * 2.2;
   106|      lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, GetATRStopLossPips());
   107|   }
   108|
   109|   if(lots <= 0) return;
   110|
   111|   SubmitSignal(InpMagic_MeanReversion, direction, conviction,
   112|                "MR_ADAPTIVE|" + DoubleToStr(Hurst, 2) + "|" + DoubleToStr(rsi_val, 0),
   113|                lots, sl, tp);
   114|}
   115|
   116|//+------------------------------------------------------------------+
   117|//| MATH REVERSAL - Z-score pure math                                |
   118|//| Magic: 999002                                                    |
   119|//+------------------------------------------------------------------+
   120|void ExecuteMathReversal_DEBATE()
   121|{
   122|   if(!InpMathFirst || !InpAlphaExpand) return;
   123|
   124|   int stratIdx = V23_FindStrategyIndex(999002);
   125|   if(stratIdx < 0) return;
   126|
   127|   // Z-score deviation
   128|   double ma20 = iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
   129|   double stdDev20 = iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
   130|   if(stdDev20 <= 0) return;
   131|   double deviation = (Close[1] - ma20) / stdDev20;
   132|
   133|   // Math confidence gate
   134|   double prob = V23_GetEmpiricalProb(stratIdx, MathAbs(deviation));
   135|   double entropyNorm = v23_regime.entropyNorm;
   136|   double confidence = v23_regime.confidence;
   137|   int regimeType = v23_regime.type;
   138|   double rExpect = v23_stratPerf[stratIdx].rExpectancy;
   139|
   140|   bool mathConfident = (prob > 0.7) && (MathAbs(deviation) > 1.5) &&
   141|                        (entropyNorm < 0.6) && (rExpect > 0) && (confidence > 0.5);
   142|   if(!mathConfident) return;
   143|
   144|   // Conviction from math factors
   145|   double convProb = MathMin(1.0, (prob - 0.7) / 0.3);          // 0-1 (0.7->0, 1.0->1)
   146|   double convDev  = MathMin(1.0, (MathAbs(deviation) - 1.5) / 1.5); // 0-1 (1.5->0, 3.0->1)
   147|   double convConf = confidence;
   148|   double conviction = (convProb * 0.4 + convDev * 0.3 + convConf * 0.3);
   149|
   150|   int dir = (deviation > 0) ? OP_SELL : OP_BUY;
   151|
   152|   double atr = iATR(NULL, 0, 14, 1);
   153|   double slDist = atr * 1.5;
   154|   double tpDist = atr * 2.5;
   155|   double price = (dir == OP_BUY) ? Ask : Bid;
   156|   double sl = (dir == OP_BUY) ? price - slDist : price + slDist;
   157|   double tp = (dir == OP_BUY) ? price + tpDist : price - tpDist;
   158|
   159|   double lots = V23_CalculateLotSize(stratIdx, 0.005, 50.0, regimeType);
   160|   if(lots <= 0) return;
   161|
   162|   // VAR check
   163|   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   164|   double marginalVar = lots * 50.0 * Point * tickValue / AccountEquity();
   165|   double currentVar = V23_CalculateEmpiricalVAR();
   166|   double varLimit = 0.05;
   167|   if(regimeType == 0) varLimit *= InpVarRelaxFactor;
   168|   else if(regimeType == 3) varLimit *= 1.2;
   169|   if(currentVar + marginalVar > varLimit) return;
   170|
   171|   SubmitSignal(999002, dir, conviction,
   172|                "MATH_REV|prob=" + DoubleToStr(prob, 2) + "|dev=" + DoubleToStr(deviation, 1),
   173|                lots, sl, tp);
   174|}
   175|
   176|//+------------------------------------------------------------------+
   177|//| NOISE BREAKOUT - BB Squeeze breakout                             |
   178|//| Magic: 777012                                                    |
   179|//+------------------------------------------------------------------+
   180|void ExecuteNoiseBreakout_DEBATE()
   181|{
   182|   if(!InpNoiseBreakout_Enabled) return;
   183|   if(Period() != PERIOD_H4) return;
   184|   if(CountOpenTrades(InpNoiseBreakout_Magic) > 0) return;
   185|   if(!IsStrategyHealthy(InpNoiseBreakout_Magic)) return;
   186|   if(!CheckTimeFilter()) return;
   187|
   188|   int bias = CheckDirectionalBias();
   189|
   190|   double bb_upper = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);
   191|   double bb_lower = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);
   192|   double bb_mid   = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_MAIN, 1);
   193|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   194|   if(atr <= 0) return;
   195|
   196|   double squeezeWidth = (bb_upper - bb_lower) / atr;
   197|
   198|   // BUY: Close above upper BB + bullish bias
   199|   if(Close[1] > bb_upper && (bias == 1 || bias == 2)) {
   200|      double conviction = MathMin(1.0, (Close[1] - bb_upper) / atr * 0.5 + 0.3);
   201|      conviction = MathMin(1.0, conviction + (1.0 - squeezeWidth) * 0.2);
   202|      double sl = Ask - (atr * 1.5);
   203|      double tp = Ask + (atr * 3.0);
   204|      double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
   205|      if(lots > 0)
   206|         SubmitSignal(InpNoiseBreakout_Magic, OP_BUY, conviction,
   207|                      "NOISE_BO|BB_squeeze", lots, sl, tp);
   208|   }
   209|   // SELL: Close below lower BB + bearish bias
   210|   else if(Close[1] < bb_lower && (bias == -1 || bias == 2)) {
   211|      double conviction = MathMin(1.0, (bb_lower - Close[1]) / atr * 0.5 + 0.3);
   212|      conviction = MathMin(1.0, conviction + (1.0 - squeezeWidth) * 0.2);
   213|      double sl = Bid + (atr * 1.5);
   214|      double tp = Bid - (atr * 3.0);
   215|      double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
   216|      if(lots > 0)
   217|         SubmitSignal(InpNoiseBreakout_Magic, OP_SELL, conviction,
   218|                      "NOISE_BO|BB_squeeze", lots, sl, tp);
   219|   }
   220|}
   221|
   222|//+------------------------------------------------------------------+
   223|//| APEX - Session rollover fade                                     |
   224|//| Magic: 777011                                                    |
   225|//+------------------------------------------------------------------+
   226|void ExecuteApexStrategy_DEBATE()
   227|{
   228|   if(!InpApex_Enabled) return;
   229|   if(Period() != PERIOD_H4) return;
   230|   if(CountOpenTrades(InpApex_MagicNumber) > 0) return;
   231|   if(!IsStrategyHealthy(InpApex_MagicNumber)) return;
   232|   if(!CheckTimeFilter()) return;
   233|
   234|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   235|   if(atr <= 0) return;
   236|
   237|   // Extended bar detection
   238|   double barRange = High[1] - Low[1];
   239|   double trigger = atr * InpApex_ATR_Multiplier_SL;
   240|   bool extendedBull = (Close[1] > Open[1] && barRange > trigger);
   241|   bool extendedBear = (Close[1] < Open[1] && barRange > trigger);
   242|
   243|   if(!extendedBull && !extendedBear) return;
   244|
   245|   // Conviction from bar extension
   246|   double extensionRatio = barRange / atr;
   247|   double conviction = MathMin(1.0, (extensionRatio - 1.0) / 2.0);
   248|
   249|   int direction;
   250|   double sl, tp, lots;
   251|
   252|   if(extendedBull) {
   253|      direction = OP_SELL;
   254|      sl = High[1] + (atr * InpApex_ATR_Multiplier_SL * Point * 10);
   255|      tp = Bid - (atr * InpApex_ATR_Multiplier_TP * Point * 10);
   256|      lots = MoneyManagement_Quantum(InpApex_MagicNumber, InpBase_Risk_Percent);
   257|   } else {
   258|      direction = OP_BUY;
   259|      sl = Low[1] - (atr * InpApex_ATR_Multiplier_SL * Point * 10);
   260|      tp = Ask + (atr * InpApex_ATR_Multiplier_TP * Point * 10);
   261|      lots = MoneyManagement_Quantum(InpApex_MagicNumber, InpBase_Risk_Percent);
   262|   }
   263|
   264|   if(lots > 0)
   265|      SubmitSignal(InpApex_MagicNumber, direction, conviction,
   266|                   "APEX|ext=" + DoubleToStr(extensionRatio, 1), lots, sl, tp);
   267|}
   268|
   269|//+------------------------------------------------------------------+
   270|//| NEXUS - Volatility compression breakout                          |
   271|//| Magic: 777014                                                    |
   272|//+------------------------------------------------------------------+
   273|void ExecuteNexusStrategy_DEBATE()
   274|{
   275|   if(!InpNexus_Enabled) return;
   276|   if(Period() != PERIOD_H4) return;
   277|   if(CountOpenTrades(InpNexus_MagicNumber) > 0) return;
   278|   if(!IsStrategyHealthy(InpNexus_MagicNumber)) return;
   279|   if(!CheckTimeFilter()) return;
   280|
   281|   int bias = CheckDirectionalBias();
   282|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   283|   if(atr <= 0) return;
   284|
   285|   // Volatility compression: N consecutive bars of ATR below median
   286|   double atrMedian = 0;
   287|   for(int i = 1; i <= 20; i++) atrMedian += iATR(Symbol(), PERIOD_H4, 14, i);
   288|   atrMedian /= 20.0;
   289|
   290|   int compressionBars = 0;
   291|   for(int i = 1; i <= 10; i++) {
   292|      if(iATR(Symbol(), PERIOD_H4, 14, i) < atrMedian * InpNexus_CompressionRatio)
   293|         compressionBars++;
   294|      else break;
   295|   }
   296|
   297|   if(compressionBars < InpNexus_MinCompressionBars) return;
   298|
   299|   // Breakout direction
   300|   bool buyBreak  = (Close[0] > High[1]);
   301|   bool sellBreak = (Close[0] < Low[1]);
   302|   if(!buyBreak && !sellBreak) return;
   303|
   304|   // Conviction from compression depth + breakout strength
   305|   double compressDepth = 1.0 - (atr / atrMedian);
   306|   double breakoutStrength = 0;
   307|   if(buyBreak) breakoutStrength = (Close[0] - High[1]) / atr;
   308|   else breakoutStrength = (Low[1] - Close[0]) / atr;
   309|
   310|   double conviction = MathMin(1.0, compressDepth * 0.5 + breakoutStrength * 0.3 + compressionBars * 0.05);
   311|
   312|   int direction;
   313|   double sl, tp;
   314|
   315|   if(buyBreak && (bias == 1 || bias == 2)) {
   316|      direction = OP_BUY;
   317|      sl = Ask - (atr * InpNexus_SL_ATR_Mult);
   318|      tp = Ask + (atrMedian * InpNexus_TP_Median_Mult);
   319|   } else if(sellBreak && (bias == -1 || bias == 2)) {
   320|      direction = OP_SELL;
   321|      sl = Bid + (atr * InpNexus_SL_ATR_Mult);
   322|      tp = Bid - (atrMedian * InpNexus_TP_Median_Mult);
   323|   } else return;
   324|
   325|   double lots = MoneyManagement_Quantum(InpNexus_MagicNumber, InpBase_Risk_Percent);
   326|   if(lots > 0)
   327|      SubmitSignal(InpNexus_MagicNumber, direction, conviction,
   328|                   "NEXUS|comp=" + IntegerToString(compressionBars) + "bars", lots, sl, tp);
   329|}
   330|
   331|//+------------------------------------------------------------------+
   332|//| MICROSTRUCTURE - H4 Kalman + M15 scalp                           |
   333|//| Magic: InpChronos_MagicNumber                                    |
   334|//+------------------------------------------------------------------+
   335|void ExecuteMicrostructure_DEBATE()
   336|{
   337|   if(!InpChronos_Enabled) return;
   338|   if(Period() != PERIOD_H4) return;
   339|   int magic_micro = InpChronos_MagicNumber;
   340|   if(CountOpenTrades(magic_micro) > 0) return;
   341|   if(!IsStrategyHealthy(magic_micro)) return;
   342|   if(!CheckTimeFilter()) return;
   343|
   344|   // H4 Kalman filter for macro bias
   345|   double kalman_prev = iMA(Symbol(), PERIOD_H4, 10, 0, MODE_EMA, PRICE_CLOSE, 2);
   346|   double kalman_curr = iMA(Symbol(), PERIOD_H4, 10, 0, MODE_EMA, PRICE_CLOSE, 1);
   347|   int bias = 0;
   348|   if(kalman_curr > kalman_prev && Close[1] > kalman_curr) bias = 1;
   349|   else if(kalman_curr < kalman_prev && Close[1] < kalman_curr) bias = -1;
   350|   if(bias == 0) return;
   351|
   352|   // M15 RSI + BB for micro signal
   353|   double m15_rsi = iRSI(Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1);
   354|   double m15_bb_lower = iBands(Symbol(), PERIOD_M15, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);
   355|   double m15_bb_upper = iBands(Symbol(), PERIOD_M15, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);
   356|
   357|   bool buy_scalp  = (bias == 1 && Close[1] < m15_bb_lower && m15_rsi < 30);
   358|   bool sell_scalp = (bias == -1 && Close[1] > m15_bb_upper && m15_rsi > 70);
   359|   if(!buy_scalp && !sell_scalp) return;
   360|
   361|   // Conviction from RSI extremity
   362|   double rsiExtremity = 0;
   363|   if(buy_scalp) rsiExtremity = (30.0 - m15_rsi) / 30.0;
   364|   else rsiExtremity = (m15_rsi - 70.0) / 30.0;
   365|   double conviction = MathMax(0.3, MathMin(1.0, rsiExtremity));
   366|
   367|   int direction = buy_scalp ? OP_BUY : OP_SELL;
   368|   double slPips = InpChronos_ScalpSL_Pips * 10 * Point;
   369|   double tpPips = InpChronos_ScalpTP_Pips * 10 * Point;
   370|   double sl, tp;
   371|
   372|   if(direction == OP_BUY) {
   373|      sl = Ask - slPips;
   374|      tp = Ask + tpPips;
   375|   } else {
   376|      sl = Bid + slPips;
   377|      tp = Bid - tpPips;
   378|   }
   379|
   380|   double lots = MoneyManagement_Quantum(magic_micro, InpBase_Risk_Percent) * InpChronos_LotSizeMultiplier;
   381|   if(lots > 0)
   382|      SubmitSignal(magic_micro, direction, conviction,
   383|                   "MICRO|H4_bias=" + IntegerToString(bias), lots, sl, tp);
   384|}
   385|
   386|//+------------------------------------------------------------------+
   387|//| VORTEX - Vortex indicator crossover                              |
   388|//| Magic: 9001                                                      |
   389|//+------------------------------------------------------------------+
   390|void ExecuteVortexStrategy_DEBATE()
   391|{
   392|   if(!InpVortex_Enabled) return;
   393|   if(Period() != PERIOD_H4) return;
   394|   if(CountOpenTrades(InpVortex_MagicNumber) > 0) return;
   395|   if(!IsStrategyHealthy(InpVortex_MagicNumber)) return;
   396|   if(!CheckTimeFilter()) return;
   397|
   398|   int bias = CheckDirectionalBias();
   399|
   400|   // Vortex indicator
   401|   double vmPlus_1 = 0, vmMinus_1 = 0, atrSum_1 = 0;
   402|   double vmPlus_2 = 0, vmMinus_2 = 0, atrSum_2 = 0;
   403|   for(int v = 1; v <= InpVortex_Period; v++) {
   404|      vmPlus_1  += MathAbs(High[v] - Low[v+1]);
   405|      vmMinus_1 += MathAbs(Low[v] - High[v+1]);
   406|      atrSum_1  += MathAbs(High[v] - Low[v]);
   407|   }
   408|   for(int w = 2; w <= InpVortex_Period + 1; w++) {
   409|      vmPlus_2  += MathAbs(High[w] - Low[w+1]);
   410|      vmMinus_2 += MathAbs(Low[w] - High[w+1]);
   411|      atrSum_2  += MathAbs(High[w] - Low[w]);
   412|   }
   413|   if(atrSum_1 <= 0 || atrSum_2 <= 0) return;
   414|
   415|   double viPlus_1  = vmPlus_1 / atrSum_1;
   416|   double viMinus_1 = vmMinus_1 / atrSum_1;
   417|   double viPlus_2  = vmPlus_2 / atrSum_2;
   418|   double viMinus_2 = vmMinus_2 / atrSum_2;
   419|
   420|   double adx = iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 1);
   421|   if(adx < InpVortex_ADX_Threshold) return;
   422|
   423|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   424|   if(atr <= 0) return;
   425|
   426|   bool buyCross  = (viPlus_1 > viMinus_1 && viPlus_2 <= viMinus_2);
   427|   bool sellCross = (viMinus_1 > viPlus_1 && viMinus_2 <= viPlus_2);
   428|
   429|   if(!buyCross && !sellCross) return;
   430|
   431|   // Conviction from VI spread + ADX
   432|   double viSpread = MathAbs(viPlus_1 - viMinus_1);
   433|   double adxNorm = MathMin(1.0, (adx - InpVortex_ADX_Threshold) / 30.0);
   434|   double conviction = MathMin(1.0, viSpread * 0.6 + adxNorm * 0.4);
   435|
   436|   int direction;
   437|   double sl, tp;
   438|
   439|   if(buyCross && (bias == 1 || bias == 2)) {
   440|      direction = OP_BUY;
   441|      sl = Ask - (atr * 1.5);
   442|      tp = Ask + (atr * 2.5);
   443|   } else if(sellCross && (bias == -1 || bias == 2)) {
   444|      direction = OP_SELL;
   445|      sl = Bid + (atr * 1.5);
   446|      tp = Bid - (atr * 2.5);
   447|   } else return;
   448|
   449|   double lots = MoneyManagement_Quantum(InpVortex_MagicNumber, InpBase_Risk_Percent);
   450|   if(lots > 0)
   451|      SubmitSignal(InpVortex_MagicNumber, direction, conviction,
   452|                   "VORTEX|VI=" + DoubleToStr(viSpread, 2), lots, sl, tp);
   453|}
   454|
   455|//+------------------------------------------------------------------+
   456|//| REGIME SHIFT - ADX+RSI regime change                             |
   457|//| Magic: 9002                                                      |
   458|//+------------------------------------------------------------------+
   459|void ExecuteRegimeShiftStrategy_DEBATE()
   460|{
   461|   if(!InpRegimeShift_Enabled) return;
   462|   if(Period() != PERIOD_H4) return;
   463|   if(CountOpenTrades(InpRegimeShift_MagicNumber) > 0) return;
   464|   if(!IsStrategyHealthy(InpRegimeShift_MagicNumber)) return;
   465|   if(!CheckTimeFilter()) return;
   466|
   467|   int bias = CheckDirectionalBias();
   468|
   469|   double adx_1 = iADX(Symbol(), PERIOD_H4, InpRegimeShift_ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   470|   double adx_2 = iADX(Symbol(), PERIOD_H4, InpRegimeShift_ADX_Period, PRICE_CLOSE, MODE_MAIN, 2);
   471|   double rsi = iRSI(Symbol(), PERIOD_H4, InpRegimeShift_RSI_Period, PRICE_CLOSE, 1);
   472|
   473|   bool adxCrossAbove25 = (adx_1 > 25.0 && adx_2 <= 25.0);
   474|   if(!adxCrossAbove25) return;
   475|
   476|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   477|   if(atr <= 0) return;
   478|
   479|   // Conviction from ADX momentum + RSI distance from 50
   480|   double adxMomentum = MathMin(1.0, (adx_1 - 25.0) / 25.0);
   481|   double rsiBias = MathAbs(rsi - 50.0) / 50.0;
   482|   double conviction = MathMin(1.0, adxMomentum * 0.5 + rsiBias * 0.5);
   483|
   484|   int direction;
   485|   double sl, tp;
   486|
   487|   if(rsi > 50.0 && (bias == 1 || bias == 2)) {
   488|      direction = OP_BUY;
   489|      sl = Ask - (atr * 2.0);
   490|      tp = Ask + (atr * 3.0);
   491|   } else if(rsi < 50.0 && (bias == -1 || bias == 2)) {
   492|      direction = OP_SELL;
   493|      sl = Bid + (atr * 2.0);
   494|      tp = Bid - (atr * 3.0);
   495|   } else return;
   496|
   497|   double lots = MoneyManagement_Quantum(InpRegimeShift_MagicNumber, InpBase_Risk_Percent);
   498|   if(lots > 0)
   499|      SubmitSignal(InpRegimeShift_MagicNumber, direction, conviction,
   500|                   "REGIME_SHIFT|ADX=" + DoubleToStr(adx_1, 0), lots, sl, tp);
   501|

//+------------------------------------------------------------------+
//| ONNEWBAR DEBATE HOOK                                              |
//+------------------------------------------------------------------+

     1|//+------------------------------------------------------------------+
     2|//| V28_11_ONNEWBAR_DEBATE_HOOK.mq4                                  |
     3|//| Drop-in replacement for OnNewBar() strategy section              |
     4|//| Include V28_11_DEBATE_LAYER.mq4 + V28_11_STRATEGIES_DEBATE.mq4  |
     5|//+------------------------------------------------------------------+
     6|
     7|//--- Call this from OnNewBar() INSTEAD of the individual strategy calls
     8|void OnNewBar_DebateLayer()
     9|{
    10|   //--- Step 1: Reset signal buffer for this bar
    11|   ResetSignals();
    12|
    13|   //--- Step 2: All strategies submit signals (no execution)
    14|   ExecuteMeanReversion_DEBATE();
    15|   ExecuteMathReversal_DEBATE();
    16|   ExecuteNoiseBreakout_DEBATE();
    17|   ExecuteApexStrategy_DEBATE();
    18|   ExecuteNexusStrategy_DEBATE();
    19|   ExecuteMicrostructure_DEBATE();
    20|   ExecuteVortexStrategy_DEBATE();
    21|   ExecuteRegimeShiftStrategy_DEBATE();
    22|   ExecuteSessionMomentum_DEBATE();
    23|   ExecuteDivergenceMR_DEBATE();
    24|   ExecuteStructuralRetest_DEBATE();
    25|
    26|   //--- Phantom is Monday-only, fire on Monday
    27|   if(DayOfWeek() == 1) ExecutePhantomStrategy_DEBATE();
    28|
    29|   //--- Step 3: Run debate + risk panel + execute winner
    30|   if(g_signalCount > 0) {
    31|      int ticket = ExecuteDebateTrade();
    32|      if(ticket > 0) {
    33|         LogError("ONNEWBAR_DEBATE: Trade executed #" + IntegerToString(ticket) +
    34|                  " from " + IntegerToString(g_signalCount) + " signals");
    35|      }
    36|   }
    37|
    38|   //--- Step 4: Reaper runs independently (grid first entry through debate)
    39|   //--- Grid levels still use existing ProcessReaperBasket logic
    40|   //--- Comment out ExecuteReaperProtocol() and replace with:
    41|   ExecuteReaperProtocol_Debate();
    42|}
    43|
    44|//+------------------------------------------------------------------+
    45|//| REAPER PROTOCOL - Grid first entry through debate                |
    46|//| Grid levels continue using existing OrderSend logic              |
    47|//+------------------------------------------------------------------+
    48|void ExecuteReaperProtocol_Debate()
    49|{
    50|   //--- Check if Reaper has no active basket in BUY direction
    51|   //--- If so, check for high conviction signal and submit to debate
    52|   int buyMagic = InpReaper_BuyMagicNumber;
    53|   int sellMagic = InpReaper_SellMagicNumber;
    54|
    55|   //--- BUY basket: first entry through debate
    56|   if(CountOpenTrades(buyMagic) == 0) {
    57|      if(IsHighConvictionSignal(OP_BUY)) {
    58|         //--- Calculate conviction from AlphaSentinel confluence layers
    59|         int layers = 0;
    60|         // Layer 1: Pivot proximity (already checked in IsHighConvictionSignal)
    61|         layers++;
    62|         // Layer 2: Stochastic crossover
    63|         double stoch1 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
    64|         double stoch2 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 2);
    65|         if(stoch1 > stoch2) layers++;
    66|         // Layer 3: RSI divergence
    67|         double rsi1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 1);
    68|         double rsi2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 2);
    69|         if(rsi1 > rsi2 && Low[1] < Low[2]) layers++;
    70|
    71|         double conviction = layers / 3.0;
    72|         double lots = GetNextReaperLotSize(0);
    73|         double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
    74|         double sl = Ask - (atr * 2.0);
    75|
    76|         SubmitSignal(buyMagic, OP_BUY, conviction,
    77|                      "REAPER_BUY|layers=" + IntegerToString(layers), lots, sl, 0);
    78|      }
    79|   }
    80|
    81|   //--- SELL basket: first entry through debate
    82|   if(CountOpenTrades(sellMagic) == 0) {
    83|      if(IsHighConvictionSignal(OP_SELL)) {
    84|         int layers = 0;
    85|         layers++;
    86|         double stoch1 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
    87|         double stoch2 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 2);
    88|         if(stoch1 < stoch2) layers++;
    89|         double rsi1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 1);
    90|         double rsi2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 2);
    91|         if(rsi1 < rsi2 && High[1] > High[2]) layers++;
    92|
    93|         double conviction = layers / 3.0;
    94|         double lots = GetNextReaperLotSize(0);
    95|         double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
    96|         double sl = Bid + (atr * 2.0);
    97|
    98|         SubmitSignal(sellMagic, OP_SELL, conviction,
    99|                      "REAPER_SELL|layers=" + IntegerToString(layers), lots, sl, 0);
   100|      }
   101|   }
   102|
   103|   //--- Grid level management continues as before (not through debate)
   104|   ProcessReaperBasket(buyMagic, OP_BUY);
   105|   ProcessReaperBasket(sellMagic, OP_SELL);
   106|}
   107|
   108|//+------------------------------------------------------------------+
   109|//| INTEGRATION GUIDE                                                 |
   110|//|                                                                   |
   111|//| In your EA (V28_11.mq4):                                         |
   112|//|                                                                   |
   113|//| 1. Add at top:                                                    |
   114|//|    #include "V28_11_DEBATE_LAYER.mq4"                            |
   115|//|                                                                   |
   116|//| 2. In OnInit():                                                   |
   117|//|    InitDebateLayer();                                             |
   118|//|                                                                   |
   119|//| 3. In OnNewBar():                                                 |
   120|//|    REPLACE the block of Execute*() calls with:                    |
   121|//|    OnNewBar_DebateLayer();                                        |
   122|//|                                                                   |
   123|//| 4. In OnTradeClose() or equivalent:                               |
   124|//|    ProcessTradeClose(ticket, exitPrice, pnl);                    |
   125|//|                                                                   |
   126|//| That's it. All V28.06 logic preserved. Debate layer is additive. |
   127|//+------------------------------------------------------------------+
   128|