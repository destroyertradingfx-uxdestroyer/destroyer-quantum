# Cycle 26 — Adaptive Volatility-Based Lot Sizing & Portfolio Heat Management
## GitHub Code Research for DESTROYER QUANTUM EA

**Date:** 2026-05-30
**Objective:** Find implementations of ATR-based dynamic position sizing, portfolio heat calculations, volatility regime detection for lot scaling, and correlation-aware position sizing in MQL4/5 EAs.

---

## EXECUTIVE SUMMARY

Extracted 4 major code patterns from GitHub repos implementing advanced position sizing:

1. **ATR-Based Dynamic Lot Sizing** — Multiple approaches: simple risk%÷ATR, Kelly Criterion blended, and regime-adaptive
2. **Volatility Regime Detection** — 4-tier classification (CALM/NORMAL/HIGH/EXTREME) with per-regime lot multipliers
3. **Portfolio Heat / Risk Metrics** — Daily drawdown tracking, consecutive loss streaks, adaptive risk multiplier, emergency halt
4. **Correlation-Aware Position Sizing** — Pearson correlation against correlated symbols, directional lot adjustment

**Key Gap in DESTROYER QUANTUM:** The existing `GetVolatilityMultiplier()` only does inverse ATR scaling (0.25x–2.0x). It lacks:
- Portfolio heat (total risk across all open positions)
- Per-strategy risk budgeting
- Volatility regime classification with discrete multipliers
- Correlation-aware lot adjustment
- Adaptive risk multiplier that shrinks after losing streaks

---

## PATTERN 1: ATR-Based Dynamic Position Sizing

### Source 1: EarnForex/Heiken-Ashi-Naive (HAN_Z-Score.mq4)
**Repo:** https://github.com/EarnForex/Heiken-Ashi-Naive

**Core Pattern — ATR as Stop Loss Distance for Position Sizing:**
```mql4
// INPUTS
input double Lots = 0.1;
input bool MM = false;              // Enable ATR-based sizing
input int ATR_Period = 20;
input double ATR_Multiplier = 1;
input double Risk = 2;              // Risk % per trade
input double FixedBalance = 0;      // Use fixed balance if > 0
input bool UseEquityInsteadOfBalance = false;

// ATR-based stop loss estimation
double StopLoss;
if (MM)
{
    StopLoss = iATR(NULL, 0, ATR_Period, 1) * ATR_Multiplier;
}

// POSITION SIZING FUNCTION
double LotsOptimized()
{
    if (!MM) return (Lots);

    double Size, RiskMoney, PositionSize = 0;
    if (AccountCurrency() == "") return(0);

    // Balance selection
    if (FixedBalance > 0)
        Size = FixedBalance;
    else if (UseEquityInsteadOfBalance)
        Size = AccountEquity();
    else
        Size = AccountBalance();

    // Risk money calculation
    if (!UseMoneyInsteadOfPercentage)
        RiskMoney = Size * Risk / 100;
    else
        RiskMoney = MoneyRisk;

    // Position size = RiskMoney / (SL_distance * tickValue / tickSize)
    double UnitCost = MarketInfo(Symbol(), MODE_TICKVALUE);
    double TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
    int LotStep_digits = CountDecimalPlaces(MarketInfo(Symbol(), MODE_LOTSTEP));

    if ((StopLoss != 0) && (UnitCost != 0) && (TickSize != 0))
        PositionSize = NormalizeDouble(RiskMoney / (StopLoss * UnitCost / TickSize), LotStep_digits);

    // Clamp to broker limits
    if (PositionSize < MarketInfo(Symbol(), MODE_MINLOT))
        PositionSize = MarketInfo(Symbol(), MODE_MINLOT);
    else if (PositionSize > MarketInfo(Symbol(), MODE_MAXLOT))
        PositionSize = MarketInfo(Symbol(), MODE_MAXLOT);

    return(PositionSize);
}
```

**DESTROYER QUANTUM Relevance:** This is the fundamental pattern. The formula `RiskMoney / (ATR * TickValue / TickSize)` is the core of any ATR-based position sizing. DQ already has `GetVolatilityMultiplier()` but it multiplies a fixed lot — it should instead compute lot size FROM the ATR.

---

### Source 2: XAUUSD_ScalperV4.mq5 (Pusparaj99op/mql5)
**Repo:** https://github.com/Pusparaj99op/mql5

**4-Mode Risk System:**
```mql5
enum ENUM_RISK_MODE
{
   RISK_FIXED   = 0, // Fixed Lot
   RISK_PERCENT = 1, // Percent Risk
   RISK_KELLY   = 2, // Kelly Criterion
   RISK_DYNAMIC = 3  // Dynamic (Percent + Kelly blend)
};

double CalculateLotSize(double slPoints)
{
   double lots = InpFixedLot;
   double equity = AccInfo.Equity();
   double pointVal = g_tickValue / (g_tickSize + EPSILON) * g_point;

   switch(InpRiskMode)
   {
      case RISK_FIXED:
         lots = InpFixedLot;
         break;
      case RISK_PERCENT:
         lots = (equity * InpRiskPercent / 100.0) / (slPoints * pointVal + EPSILON);
         break;
      case RISK_KELLY:
         if(g_perfBufCount >= 20 && g_risk.kellyFraction > 0)
            lots = g_risk.kellyFraction * InpKellyFraction * equity / (slPoints * pointVal + EPSILON);
         else
            lots = (equity * InpRiskPercent / 100.0) / (slPoints * pointVal + EPSILON);
         break;
      case RISK_DYNAMIC:
         if(g_perfBufCount < 20)
            lots = (equity * InpRiskPercent / 100.0) / (slPoints * pointVal + EPSILON);
         else
         {
            double lotPct = (equity * InpRiskPercent / 100.0) / (slPoints * pointVal + EPSILON);
            double lotKelly = g_risk.kellyFraction * InpKellyFraction * equity / (slPoints * pointVal + EPSILON);
            lots = lotPct * 0.6 + MathMax(0, lotKelly) * 0.4;  // 60% risk%, 40% Kelly
         }
         break;
   }

   // VOLATILITY ADJUSTMENT (post-sizing)
   if(g_market.atrPips > 20) lots *= 0.75;      // High vol → reduce 25%
   else if(g_market.atrPips < 6) lots *= 1.15;   // Low vol → increase 15%
   lots *= g_risk.adaptiveRiskMult;               // Streak-based multiplier

   // REGIME ADJUSTMENT
   if(g_market.volatilityRegime == VOL_CALM) lots *= 0.75;

   // CORRELATION SIZING
   if(InpUseCorrelationSizing && g_signal.direction != 0)
   {
      double corr = CalcCorrelation();
      if(g_signal.direction > 0) // BUY
      {
         if(corr > 0.5) lots *= 0.8;      // Correlated → reduce
         else if(corr < -0.5) lots *= 1.1; // Counter → increase
      }
      else // SELL
      {
         if(corr < -0.5) lots *= 0.8;
         else if(corr > 0.5) lots *= 1.1;
      }
   }

   // HARD CONSTRAINTS
   lots = MathFloor(lots / g_lotStep) * g_lotStep;
   lots = NormalizeDouble(lots, 2);
   lots = MathMax(InpMinLot, MathMin(InpMaxLot, lots));

   // FREE MARGIN CHECK
   double marginReq = 0;
   ENUM_ORDER_TYPE ot = (g_signal.direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(ot, g_symbol, lots, SymbolInfoDouble(g_symbol, SYMBOL_ASK), marginReq))
   {
      if(marginReq > AccInfo.FreeMargin() * 0.90)
         lots = MathFloor(AccInfo.FreeMargin() * 0.85 / (marginReq / lots + EPSILON) / g_lotStep) * g_lotStep;
   }

   return lots;
}
```

**Key Insight for DQ:** The RISK_DYNAMIC mode blending 60% fixed-risk + 40% Kelly is a production-grade approach. The post-sizing volatility and regime adjustments are layered on top, creating a multi-factor lot size.

---

### Source 3: XAUBot_Pro_Lite.mq5 (GifariKemal/xaubot-ai)
**Repo:** https://github.com/GifariKemal/xaubot-ai

**Simple but effective adaptive risk:**
```mql5
// Risk state tracking
double currentRisk = RiskPercent;   // Starts at 1.0%
int consecutiveWins = 0;
int consecutiveLosses = 0;

// Lot calculation
double CalculateLotSize(double slDistance)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = accountBalance * (currentRisk / 100.0);
   double tickValue = symbolInfo.TickValue();
   double tickSize = symbolInfo.TickSize();
   double slInTicks = slDistance / tickSize;
   double lotSize = riskMoney / (slInTicks * tickValue);
   return lotSize;
}

// ADAPTIVE RISK AFTER TRADES
// On WIN:
if(consecutiveWins >= 2)
{
   currentRisk = RiskPercent;  // Restore to base after 2 wins
}

// On LOSS:
consecutiveLosses++;
currentRisk = MinRiskPercent;  // Drop to 0.5% immediately
```

**Key Insight:** The simplest adaptive pattern — after any loss, immediately halve risk. After 2 consecutive wins, restore. This is the "circuit breaker" pattern.

---

## PATTERN 2: Volatility Regime Detection

### Source: XAUUSD_ScalperV4.mq5

**4-Tier Regime Classification:**
```mql5
enum ENUM_VOL_REGIME
{
   VOL_CALM    = 0,
   VOL_NORMAL  = 1,
   VOL_HIGH    = 2,
   VOL_EXTREME = 3
};

// INPUTS
input double InpATRCalmThreshPips    = 5.0;   // CALM Threshold (ATR pips)
input double InpATRHighThreshPips    = 25.0;  // HIGH Threshold (ATR pips)
input double InpATRExtremeThreshPips = 50.0;  // EXTREME Threshold (ATR pips)
input bool   InpPauseOnExtreme       = true;  // Pause on EXTREME

// CLASSIFICATION (in UpdateMarketState)
void UpdateMarketState()
{
   g_market.atr       = bufATR[1];
   g_market.atrPips   = g_market.atr / (g_point * 10.0 + EPSILON);
   g_market.atrNorm   = g_market.atr / (close0 + EPSILON) * 10000.0;

   // Volatility Regime Classification
   if(g_market.atrPips < InpATRCalmThreshPips)
      g_market.volatilityRegime = VOL_CALM;
   else if(g_market.atrPips < InpATRHighThreshPips)
      g_market.volatilityRegime = VOL_NORMAL;
   else if(g_market.atrPips < InpATRExtremeThreshPips)
      g_market.volatilityRegime = VOL_HIGH;
   else
      g_market.volatilityRegime = VOL_EXTREME;
}

// SAFETY GUARD — Block trading in extreme volatility
bool CanTrade(int direction)
{
   // ATR range check
   double atrPts = g_market.atr / g_point;
   if(atrPts < InpMinATRPoints) return false;
   if(atrPts > InpMaxATRPoints) return false;

   // Extreme volatility block
   if(g_market.volatilityRegime == VOL_EXTREME && InpPauseOnExtreme)
      return false;
}
```

### Source: sanchil/animated-robot (from previous research)
**Repo:** https://github.com/sanchil/animated-robot

**Normalized ATR Score [0.0, 1.0] with Physics Scaling:**
```mql4
double atrKinetic(const double atr) {
   double pipValue = util.getPipValue(_Symbol);
   if(pipValue <= 0) return 0.0;
   
   double atrPips = atr / pipValue;
   
   // BASELINE: 30 pips on M15 = "Max Energy" (1.0)
   double baseRef = 30.0;
   
   // PHYSICS SCALING: Square Root of Time Rule
   // M15=1.0, H1=2.0, H4=4.0
   double timeRatio = (double)_Period / 15.0;
   if(timeRatio <= 0) timeRatio = 1.0;
   
   double physicsCeiling = baseRef * MathSqrt(timeRatio);
   
   // Normalize & Squash (Kinetic Energy = v²)
   double atrNorm = MathMin(MathMax(atrPips / physicsCeiling, 0.0), 1.0);
   return (atrNorm * atrNorm);
}

// Parameter scaling by regime
double atrScale(double atrRaw, double minVal, double maxVal, double curvature = 1.0) {
   if(atrRaw <= 0 || minVal >= maxVal) return minVal;
   double k = atrKinetic(atrRaw);
   if(curvature != 1.0) k = MathPow(k, curvature);
   k = MathMax(0.0, MathMin(1.0, k));
   return minVal + (maxVal - minVal) * k;
}
```

**Key Insight for DQ (EURUSD H4):**
- For H4 timeframe, the physics ceiling would be `30 * sqrt(240/15) = 30 * 4 = 120 pips`
- EURUSD H4 ATR(14) typically ranges 20-80 pips
- Proposed regime thresholds for EURUSD H4:
  - CALM: ATR < 25 pips (atrNorm < 0.04)
  - NORMAL: ATR 25-50 pips (atrNorm 0.04-0.17)
  - HIGH: ATR 50-80 pips (atrNorm 0.17-0.44)
  - EXTREME: ATR > 80 pips (atrNorm > 0.44)

---

## PATTERN 3: Portfolio Heat & Risk Metrics

### Source: XAUUSD_ScalperV4.mq5 — SRiskMetrics

**Complete Risk Metrics Structure:**
```mql5
struct SRiskMetrics
{
   double   balance;
   double   equity;
   double   dailyStartBalance;
   double   dailyPnL;
   double   dailyDrawdownPct;
   double   totalDrawdownPct;
   double   peakEquity;
   int      consecutiveLosses;
   int      consecutiveWins;
   double   winRate20;          // Rolling 20-trade win rate
   double   avgWin;
   double   avgLoss;
   double   expectancy;
   double   kellyFraction;     // Kelly Criterion [0, 0.25]
   double   adaptiveRiskMult;  // Shrinks on losses, grows on wins
   double   adaptiveEntryThresh; // Signal score threshold adjustment
   bool     tradingHalted;
   string   haltReason;
   datetime haltUntil;
};
```

**Risk Metrics Update Loop:**
```mql5
void UpdateRiskMetrics()
{
   g_risk.balance = AccInfo.Balance();
   g_risk.equity  = AccInfo.Equity();

   // DAILY RESET
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(dt.day != g_lastDay)
   {
      g_risk.dailyStartBalance = g_risk.balance;
      g_lastDay = dt.day;
      if(g_risk.tradingHalted && g_risk.haltReason == "Daily drawdown exceeded")
      {
         g_risk.tradingHalted = false;
         g_risk.haltReason = "";
      }
   }

   // DRAWDOWN CALCULATIONS
   g_risk.dailyPnL = g_risk.equity - g_risk.dailyStartBalance;
   g_risk.dailyDrawdownPct = (-g_risk.dailyPnL) / (g_risk.dailyStartBalance + EPSILON) * 100.0;
   if(g_risk.dailyDrawdownPct < 0) g_risk.dailyDrawdownPct = 0;

   if(g_risk.equity > g_risk.peakEquity)
      g_risk.peakEquity = g_risk.equity;
   g_risk.totalDrawdownPct = (g_risk.peakEquity - g_risk.equity) / (g_risk.peakEquity + EPSILON) * 100.0;

   // DAILY DD HALT
   if(g_risk.dailyDrawdownPct >= InpMaxDailyDrawdown && !g_risk.tradingHalted)
   {
      g_risk.tradingHalted = true;
      g_risk.haltReason = "Daily drawdown exceeded";
   }

   // PERFORMANCE METRICS FROM RING BUFFER
   if(g_perfBufCount > 0)
   {
      int wins = 0;
      double sumWin = 0, sumLoss = 0;
      int wCount = 0, lCount = 0;
      for(int i = 0; i < g_perfBufCount; i++)
      {
         if(g_perfBuf[i] > 0) { wins++; sumWin += g_perfBuf[i]; wCount++; }
         else { sumLoss += MathAbs(g_perfBuf[i]); lCount++; }
      }
      g_risk.winRate20 = (double)wins / g_perfBufCount;
      g_risk.avgWin  = (wCount > 0) ? sumWin / wCount : 0;
      g_risk.avgLoss = (lCount > 0) ? sumLoss / lCount : 0;

      // KELLY CRITERION
      double lossRate = 1.0 - g_risk.winRate20;
      double B = g_risk.avgWin / (g_risk.avgLoss + EPSILON);
      g_risk.kellyFraction = (g_risk.winRate20 * B - lossRate) / (B + EPSILON);
      g_risk.kellyFraction = MathMax(0, MathMin(0.25, g_risk.kellyFraction));
   }
}
```

**Adaptive Risk Multiplier (Streak-Based):**
```mql5
void OnTradeClose(double profitPips, double componentScores[])
{
   // Store in perf ring buffer
   g_perfBuf[g_perfBufIdx] = profitPips;
   g_perfBufIdx = (g_perfBufIdx + 1) % PERF_BUFFER;
   if(g_perfBufCount < PERF_BUFFER) g_perfBufCount++;

   // Consecutive tracking
   if(profitPips > 0) { g_risk.consecutiveWins++; g_risk.consecutiveLosses = 0; }
   else               { g_risk.consecutiveLosses++; g_risk.consecutiveWins = 0; }

   // ADAPTIVE RISK MULTIPLIER
   if(profitPips <= 0)
      g_risk.adaptiveRiskMult = MathMax(0.1, g_risk.adaptiveRiskMult * 0.92);  // -8% per loss
   else
      g_risk.adaptiveRiskMult = MathMin(2.0, g_risk.adaptiveRiskMult * 1.05);  // +5% per win

   // ADAPTIVE ENTRY THRESHOLD
   if(g_perfBufCount >= 5)
   {
      int recentWins = 0;
      for(int i = 0; i < MathMin(5, g_perfBufCount); i++)
      {
         int idx = (g_perfBufIdx - 1 - i + PERF_BUFFER) % PERF_BUFFER;
         if(g_perfBuf[idx] > 0) recentWins++;
      }
      double wr5 = (double)recentWins / MathMin(5, g_perfBufCount);
      if(wr5 < 0.30)
         g_risk.adaptiveEntryThresh = MathMin(InpMinSignalScore + 25, g_risk.adaptiveEntryThresh + 5);
      else if(wr5 > 0.65)
         g_risk.adaptiveEntryThresh = MathMax(InpMinSignalScore - 10, g_risk.adaptiveEntryThresh - 3);
   }
}
```

**Key Insight for DQ:** The `adaptiveRiskMult` pattern (0.92x per loss, 1.05x per win, clamped [0.1, 2.0]) is the most elegant approach. It creates a "momentum of confidence" — after 3 losses, you're at `0.92³ = 0.779x` risk. After 3 wins, you're at `1.05³ = 1.158x`.

---

## PATTERN 4: Correlation-Aware Position Sizing

### Source: XAUUSD_ScalperV4.mq5

**Pearson Correlation Calculation:**
```mql5
double CalcCorrelation()
{
   if(!InpUseCorrelationSizing) return 0;
   string corrSym = InpCorrelationSymbol;
   if(!SymbolSelect(corrSym, true)) return 0;
   if(SymbolInfoDouble(corrSym, SYMBOL_BID) == 0) return 0;

   double x[], y[];
   int n = 20;
   if(CopyClose(g_symbol, InpTF, 0, n, x) < n) return 0;
   if(CopyClose(corrSym, InpTF, 0, n, y) < n) return 0;

   double sumX=0,sumY=0,sumXY=0,sumX2=0,sumY2=0;
   for(int i=0;i<n;i++)
   {
      sumX+=x[i]; sumY+=y[i]; sumXY+=x[i]*y[i];
      sumX2+=x[i]*x[i]; sumY2+=y[i]*y[i];
   }
   double denom=MathSqrt((n*sumX2-sumX*sumX)*(n*sumY2-sumY*sumY));
   if(denom<EPSILON) return 0;
   return (n*sumXY-sumX*sumY)/denom;
}

// APPLICATION IN LOT SIZING
if(InpUseCorrelationSizing && g_signal.direction != 0)
{
   double corr = CalcCorrelation();
   if(g_signal.direction > 0) // BUY
   {
      if(corr > 0.5) lots *= 0.8;      // Highly correlated → reduce exposure
      else if(corr < -0.5) lots *= 1.1; // Counter-correlated → can add more
   }
   else // SELL (mirror)
   {
      if(corr < -0.5) lots *= 0.8;
      else if(corr > 0.5) lots *= 1.1;
   }
}
```

**Key Insight for DQ:** For EURUSD H4, the correlation symbol would be GBPUSD or DXY. If EURUSD and GBPUSD are highly correlated (ρ > 0.5) and both have open positions, reduce lot size by 20% to avoid doubling exposure to the same USD move.

---

## PATTERN 5: Safety Guards (CanTrade Checks)

### Source: XAUUSD_ScalperV4.mq5 — 13 Safety Guards

```mql5
bool CanTrade(int direction)
{
   // 13.1 Spread check
   double spreadPts = (ask - bid) / g_point;
   if(spreadPts > InpMaxSpreadPoints) return false;

   // 13.2 ATR range (not too quiet, not too wild)
   double atrPts = g_market.atr / g_point;
   if(atrPts < InpMinATRPoints) return false;
   if(atrPts > InpMaxATRPoints) return false;

   // 13.3 Session hours
   if(dt.hour < InpStartHour || dt.hour >= InpEndHour) return false;

   // 13.4 Daily drawdown
   if(g_risk.dailyDrawdownPct >= InpMaxDailyDrawdown) return false;

   // 13.5 Total drawdown (EMERGENCY)
   if(g_risk.totalDrawdownPct >= InpMaxTotalDrawdown)
   {
      CloseAllPositions();
      g_risk.tradingHalted = true;
      g_risk.haltReason = "Max total drawdown exceeded";
      return false;
   }

   // 13.6 Consecutive losses
   if(g_risk.consecutiveLosses >= InpEmergencyLosses) return false;

   // 13.7 Max simultaneous positions
   // 13.8 Max daily trades
   // 13.9 Weekend filter
   // 13.10 Day-of-week filter
   // 13.11 Extreme volatility block
   // 13.12 News filter (optional)
   // 13.13 Cooldown after loss

   return true;
}
```

---

## PORTFOLIO HEAT CONCEPT (Not Found in MQL4 Repos — Design Pattern)

No MQL4 repo was found implementing true "portfolio heat" (sum of risk across all open positions). This is the key gap. Here's the design pattern synthesized from the research:

```mql4
// PORTFOLIO HEAT CALCULATION
// Heat = sum of (lot_size * stop_loss_distance * tick_value) for all open positions
// Expressed as % of account equity

double CalculatePortfolioHeat()
{
   double totalHeatMoney = 0;
   double equity = AccountEquity();
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() > OP_SELL) continue;  // Skip pending orders
      
      double lots = OrderLots();
      double openPrice = OrderOpenPrice();
      double sl = OrderStopLoss();
      
      double slDistance = 0;
      if(sl > 0)
         slDistance = MathAbs(openPrice - sl);
      else
         slDistance = iATR(NULL, 0, 14, 1) * 1.5;  // Estimate if no SL
      
      double tickValue = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
      double tickSize = MarketInfo(OrderSymbol(), MODE_TICKSIZE);
      
      totalHeatMoney += lots * (slDistance / tickSize) * tickValue;
   }
   
   return (totalHeatMoney / equity) * 100.0;  // Heat as % of equity
}

// HEAT-BASED LOT SCALING
double HeatAdjustedLots(double baseLots, double maxHeatPct = 6.0)
{
   double currentHeat = CalculatePortfolioHeat();
   
   if(currentHeat >= maxHeatPct)
      return 0;  // BLOCK new trades — max heat reached
   
   double remainingHeat = maxHeatPct - currentHeat;
   double heatRatio = remainingHeat / maxHeatPct;
   
   // Scale down lots as heat approaches max
   // At 0% heat → 1.0x lots
   // At 50% heat → 0.5x lots  
   // At 90% heat → 0.1x lots
   return baseLots * heatRatio;
}

// PER-STRATEGY RISK BUDGET
double StrategyRiskBudget(string strategyName, double totalBudgetPct = 6.0)
{
   // Each strategy gets a fraction of total heat budget
   // If 4 strategies, each gets 1.5% max heat
   int numStrategies = 4;  // Count of active strategies
   double strategyBudget = totalBudgetPct / numStrategies;
   
   // Calculate this strategy's current heat
   double strategyHeat = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderComment() != strategyName) continue;  // Tag by strategy
      
      double lots = OrderLots();
      double sl = OrderStopLoss();
      double slDist = MathAbs(OrderOpenPrice() - sl);
      double tv = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
      double ts = MarketInfo(OrderSymbol(), MODE_TICKSIZE);
      
      strategyHeat += lots * (slDist / ts) * tv;
   }
   
   double equity = AccountEquity();
   double strategyHeatPct = (strategyHeat / equity) * 100.0;
   double remainingBudget = strategyBudget - strategyHeatPct;
   
   return MathMax(0, remainingBudget);
}
```

---

## RECOMMENDED IMPLEMENTATION FOR DESTROYER QUANTUM

### Step 1: Replace GetVolatilityMultiplier() with Multi-Factor Lot Sizing

```mql4
// NEW: AdaptiveLotSize() — replaces simple GetVolatilityMultiplier()
double AdaptiveLotSize(double baseLots, double atrValue, int strategyId)
{
   double lots = baseLots;
   
   // FACTOR 1: ATR-based scaling (inverse volatility)
   double atrNorm = atrValue / (iATR(NULL, PERIOD_D1, 100, 1) + 0.0001);
   double volMult = 1.0 / MathMax(0.5, MathMin(2.0, atrNorm));
   volMult = MathMax(0.25, MathMin(2.0, volMult));
   lots *= volMult;
   
   // FACTOR 2: Volatility regime
   int regime = GetVolRegime(atrValue);
   if(regime == VOL_CALM)    lots *= 0.75;
   if(regime == VOL_HIGH)    lots *= 0.85;
   if(regime == VOL_EXTREME) return 0;  // Block
   
   // FACTOR 3: Adaptive risk multiplier (streak-based)
   lots *= g_adaptiveRiskMult;  // Updated after each trade
   
   // FACTOR 4: Portfolio heat
   lots = HeatAdjustedLots(lots, 6.0);
   
   // FACTOR 5: Strategy budget
   double budget = StrategyRiskBudget(GetStrategyName(strategyId));
   double maxLotsForStrategy = budget / (atrValue / MarketInfo(Symbol(), MODE_TICKSIZE) * MarketInfo(Symbol(), MODE_TICKVALUE));
   lots = MathMin(lots, maxLotsForStrategy);
   
   // Clamp
   lots = MathFloor(lots / MarketInfo(Symbol(), MODE_LOTSTEP)) * MarketInfo(Symbol(), MODE_LOTSTEP);
   lots = MathMax(MarketInfo(Symbol(), MODE_MINLOT), MathMin(MarketInfo(Symbol(), MODE_MAXLOT), lots));
   
   return lots;
}

// Volatility regime for EURUSD H4
int GetVolRegime(double atrValue)
{
   double atrPips = atrValue / (Point * 10);
   if(atrPips < 25) return 0;  // CALM
   if(atrPips < 50) return 1;  // NORMAL
   if(atrPips < 80) return 2;  // HIGH
   return 3;                    // EXTREME
}
```

### Step 2: Add Risk Metrics Tracking

```mql4
// Global risk state
double g_dailyStartBalance = 0;
double g_peakEquity = 0;
int g_consecutiveLosses = 0;
int g_consecutiveWins = 0;
double g_adaptiveRiskMult = 1.0;
int g_perfBuffer[20];  // Ring buffer of recent trade results
int g_perfIdx = 0;
int g_perfCount = 0;

void UpdateRiskState()
{
   double equity = AccountEquity();
   if(equity > g_peakEquity) g_peakEquity = equity;
   
   // Daily reset
   // ... (check day change)
}

void OnTradeResult(double profitPips)
{
   g_perfBuffer[g_perfIdx] = (profitPips > 0) ? 1 : 0;
   g_perfIdx = (g_perfIdx + 1) % 20;
   if(g_perfCount < 20) g_perfCount++;
   
   if(profitPips > 0)
   {
      g_consecutiveWins++;
      g_consecutiveLosses = 0;
      g_adaptiveRiskMult = MathMin(2.0, g_adaptiveRiskMult * 1.05);
   }
   else
   {
      g_consecutiveLosses++;
      g_consecutiveWins = 0;
      g_adaptiveRiskMult = MathMax(0.1, g_adaptiveRiskMult * 0.92);
   }
}
```

---

## SOURCE REPOS

| Repo | Stars | Key Pattern | File |
|------|-------|------------|------|
| EarnForex/Heiken-Ashi-Naive | - | ATR-based position sizing | HAN_Z-Score.mq4 |
| Pusparaj99op/mql5 | - | Full risk system: Kelly, regimes, correlation, adaptive | XAUUSD_ScalperV4.mq5 |
| GifariKemal/xaubot-ai | - | Adaptive risk after losses, ATR spike detection | XAUBot_Pro_Lite.mq5 |
| torOxO/Advanced_SMC_EA | - | ATR for FVG sizing, max daily loss, consecutive loss guard | Advanced_SMC_EA.mq5 |
| sanchil/animated-robot | - | Normalized ATR score, physics scaling, regime interpolation | MarketMetrics-v2.mqh |

---

## KEY TAKEAWAYS FOR DQ EA

1. **Stop using GetVolatilityMultiplier() as a simple multiplier on fixed lots.** Instead, compute lot size FROM risk budget ÷ ATR distance, like the EarnForex pattern.

2. **Add a 4-tier volatility regime** with EURUSD H4-specific thresholds (25/50/80 pips ATR).

3. **Implement adaptiveRiskMult** (0.92x per loss, 1.05x per win, clamped [0.1, 2.0]) — this is the single most impactful risk management feature.

4. **Add portfolio heat tracking** — sum of all open position risk as % of equity, with a 6% max heat cap.

5. **Add per-strategy risk budgeting** — divide total heat budget equally among active strategies.

6. **Add correlation-aware sizing** — reduce lots by 20% when correlated pairs (GBPUSD) have concurrent positions in the same direction.

7. **Add safety guards**: max daily DD halt, max total DD emergency close, consecutive loss trading pause, ATR range filter (don't trade when too quiet or too wild).
