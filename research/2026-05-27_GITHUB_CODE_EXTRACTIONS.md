# GITHUB CODE EXTRACTIONS — Cycle 10
## Date: 2026-05-27

---

## 1. TAPERED DRAWDOWN PROTECTION (from ApexPullBack RiskOptimizer)
## Source: https://github.com/meococ/ApexPullBack/blob/main/RiskOptimizer.mqh

The ApexPullBack EA uses a sophisticated tapered drawdown protection system that
linearly reduces risk as drawdown increases. This is SUPERIOR to DESTROYER's current
binary approach (either full risk or cut).

### DESTROYER Current State:
- Binary: if DD > threshold → cut lots by fixed amount
- No gradual scaling between thresholds

### ApexPullBack Approach (adapted for MQL4):
```mql4
// TAPERED DRAWDOWN PROTECTION
// Linearly reduces risk from 100% to MinRiskMultiplier as DD increases
// from DrawdownReduceThreshold to MaxAllowedDrawdown

extern bool   InpTaperedDD_Enabled = true;
extern double InpTaperedDD_StartPct = 5.0;     // Start reducing at 5% DD
extern double InpTaperedDD_MaxPct = 20.0;      // Minimum risk at 20% DD
extern double InpTaperedDD_MinMult = 0.25;     // Floor: 25% of normal risk
extern double InpTaperedDD_Smoothing = 0.7;    // 70% old value, 30% new (smooth)

static double g_taperedDDMult = 1.0;

double GetTaperedDrawdownMultiplier()
{
   if(!InpTaperedDD_Enabled) return 1.0;
   
   double equity = AccountEquity();
   double peakEquity = GetPeakEquity(); // Track from existing HWM code
   
   if(peakEquity <= 0) return 1.0;
   
   double ddPct = (peakEquity - equity) / peakEquity * 100.0;
   
   double newMult = 1.0;
   
   if(ddPct <= InpTaperedDD_StartPct)
   {
      newMult = 1.0; // No reduction below threshold
   }
   else if(ddPct >= InpTaperedDD_MaxPct)
   {
      newMult = InpTaperedDD_MinMult; // Floor
   }
   else
   {
      // Linear interpolation between threshold and max DD
      double excessDD = ddPct - InpTaperedDD_StartPct;
      double ddRange = InpTaperedDD_MaxPct - InpTaperedDD_StartPct;
      double reductionPct = excessDD / ddRange; // 0.0 to 1.0
      newMult = 1.0 - (1.0 - InpTaperedDD_MinMult) * reductionPct;
   }
   
   // Smooth to avoid jerky changes
   g_taperedDDMult = g_taperedDDMult * InpTaperedDD_Smoothing + newMult * (1.0 - InpTaperedDD_Smoothing);
   
   return g_taperedDDMult;
}

// Usage in MoneyManagement_Quantum():
// double ddMult = GetTaperedDrawdownMultiplier();
// finalLots *= ddMult;
```

### Why This Is Better Than Binary
- At 5% DD: 100% risk (no change)
- At 8% DD: ~85% risk (gentle reduction)
- At 12% DD: ~65% risk (moderate reduction)
- At 15% DD: ~45% risk (significant reduction)
- At 20% DD: 25% risk (minimum)

This prevents the "cliff effect" where DD hits a threshold and suddenly halves lot size,
which can miss recovery trades.

---

## 2. VOLATILITY SPIKE PROTECTION (from ApexPullBack RiskOptimizer)
## Source: same repo

### Concept
When ATR spikes >50% above its moving average, SKIP the trade entirely. This prevents
entering during flash crashes, NFP spikes, and other extreme events.

```mql4
// VOLATILITY SPIKE PROTECTION

extern bool   InpVolSpike_Enabled = true;
extern int    InpVolSpike_ATR_Period = 14;
extern int    InpVolSpike_ATR_Avg_Period = 50;  // 50-bar ATR average
extern double InpVolSpike_SpikeFactor = 1.5;    // Skip if ATR > 1.5x average

static double g_avgATR = 0;

bool IsVolatilitySpike()
{
   if(!InpVolSpike_Enabled) return false;
   
   // Calculate running average ATR
   double atrSum = 0;
   for(int i = 1; i <= InpVolSpike_ATR_Avg_Period; i++)
      atrSum += iATR(Symbol(), PERIOD_H4, InpVolSpike_ATR_Period, i);
   g_avgATR = atrSum / InpVolSpike_ATR_Avg_Period;
   
   // Current ATR
   double currentATR = iATR(Symbol(), PERIOD_H4, InpVolSpike_ATR_Period, 0);
   
   // Check for spike
   if(currentATR > g_avgATR * InpVolSpike_SpikeFactor)
      return true;
   
   return false;
}

// Usage before OrderSend():
// if(IsVolatilitySpike()) return; // Skip trade during volatility spike
```

### Impact
- Prevents entries during NFP, ECB, FOMC flash moves
- Reduces "gap through stop" scenarios
- Expected: -10% to -15% of losing trades eliminated

---

## 3. FOREXFACTORY NEWS FILTER (from ForexNewsKillerEA)
## Source: https://github.com/Ahmed-GoCode/forex-news-killer

### Concept
Pulls ForexFactory calendar via XML API and blocks trading N minutes before/after
high-impact news events.

### Key Implementation Details
- Data source: https://nfs.faireconomy.media/ff_calendar_thisweek.xml
- Updates every 2 hours (configurable)
- Filters by: currency, impact level (high/medium/low), title keywords
- Title keywords: "Non-Farm, Unemployment, ISM, PMI, CPI, FOMC, Retail Sales, GDP, PCE, JOLTS"

### Adapted for DESTROYER (simplified — no DLL, no chart closing):
```mql4
// NEWS FILTER — Simplified for DESTROYER
// Does NOT close existing trades, just blocks NEW entries

extern bool   InpNewsFilter_Enabled = true;
extern int    InpNewsFilter_MinutesBefore = 30;  // Block entries 30 min before news
extern int    InpNewsFilter_MinutesAfter = 30;   // Block entries 30 min after news
extern bool   InpNewsFilter_HighImpact = true;
extern bool   InpNewsFilter_MediumImpact = false;

// Hardcoded high-impact EURUSD news times (updated weekly by Ryan or cron)
// Format: "YYYY.MM.DD HH:MM" — one per line
// These would need to be updated weekly. Alternative: use WebRequest to ForexFactory.
string g_newsEvents[] = {
   // Ryan fills this in weekly or we use a file
};

bool IsNearNewsEvent()
{
   if(!InpNewsFilter_Enabled) return false;
   
   datetime now = TimeCurrent();
   
   for(int i = 0; i < ArraySize(g_newsEvents); i++)
   {
      datetime newsTime = StringToTime(g_newsEvents[i]);
      if(newsTime == 0) continue;
      
      int minutesDiff = (int)((now - newsTime) / 60);
      
      // Before news: block if within N minutes
      if(minutesDiff < 0 && MathAbs(minutesDiff) <= InpNewsFilter_MinutesBefore)
         return true;
      
      // After news: block if within N minutes
      if(minutesDiff > 0 && minutesDiff <= InpNewsFilter_MinutesAfter)
         return true;
   }
   
   return false;
}

// Usage before OrderSend():
// if(IsNearNewsEvent()) return; // Skip trade near news
```

### Simpler Alternative (No External Data)
Instead of WebRequest (which requires URL whitelisting), use TIME-BASED news avoidance:
```mql4
// SIMPLE TIME-BASED NEWS AVOIDANCE
// NFP: First Friday of month, 13:30 UTC
// FOMC: ~8 times/year, 19:00 UTC (hard to predict)
// ECB: ~8 times/year, 12:45 UTC (hard to predict)

bool IsNearScheduledNewsTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // NFP: First Friday, 13:00-14:00 UTC
   if(dt.day_of_week == 5 && dt.day <= 7 && dt.hour >= 13 && dt.hour <= 14)
      return true;
   
   // FOMC: Wednesday 18:30-19:30 UTC (approximate — 8 times/year)
   // This is a rough filter — catches most FOMC windows
   if(dt.day_of_week == 3 && dt.hour >= 18 && dt.hour <= 19)
      return true;
   
   return false;
}
```

---

## 4. MULTI-FACTOR RISK COMPOSITION (from ApexPullBack)
## The key insight: combine multiple risk factors with weighted averaging

```mql4
// MULTI-FACTOR RISK COMPOSITION
// Weights: Performance 25%, DD 30%, Volatility 15%, Market 10%, Broker 10%, Stability 10%
// For DESTROYER: simplified to 3 factors

double GetCompositeRiskMultiplier()
{
   double perfMult = GetPerformanceBasedMultiplier();  // From Recovery Mode
   double ddMult = GetTaperedDrawdownMultiplier();      // From Tapered DD
   double volMult = GetVolatilityTargetMultiplier();    // From Vol-Targeting
   double ecMult = CalculateEquityCurveMultiplier();    // From V29 code
   
   // Weighted combination
   double composite = (perfMult * 0.20) + (ddMult * 0.30) + (volMult * 0.20) + (ecMult * 0.30);
   
   // Smooth to avoid jerky changes
   static double lastComposite = 1.0;
   double smoothed = lastComposite * 0.7 + composite * 0.3;
   lastComposite = smoothed;
   
   // Clamp
   smoothed = MathMax(0.25, MathMin(2.0, smoothed));
   
   return smoothed;
}
```

---

## 5. R-MULTIPLE TRAILING STOP (from ApexPullBack)
## Most sophisticated trailing approach found on GitHub

### The 4-Phase Trailing System:
```
Phase 0: No trailing (just entered)
Phase 1: Break-even (at 1.0R) — move SL to entry + buffer
Phase 2: First lock (at 1.5R) — lock in 50% of unrealized profit
Phase 3: Second lock (at 2.5R) — lock in 70% of unrealized profit
Phase 4: Third lock (at 4.0R) — lock in 85% of unrealized profit
```

### Adapted for DESTROYER:
```mql4
// R-MULTIPLE TRAILING STOP
// R = initial risk (entry - SL distance)

extern bool   InpRMultTrail_Enabled = true;
extern double InpRMultTrail_BE_Mult = 1.0;       // Move to BE at 1R profit
extern double InpRMultTrail_Lock1_Mult = 1.5;    // First lock at 1.5R
extern double InpRMultTrail_Lock2_Mult = 2.5;    // Second lock at 2.5R
extern double InpRMultTrail_Lock1_Pct = 50.0;    // Lock 50% at first lock
extern double InpRMultTrail_Lock2_Pct = 70.0;    // Lock 70% at second lock
extern double InpRMultTrail_BE_Buffer = 5.0;     // 5 points buffer at BE

void UpdateRMultipleTrailing()
{
   if(!InpRMultTrail_Enabled) return;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsOurMagicNumber(OrderMagicNumber())) continue;
      if(OrderSymbol() != Symbol()) continue;
      
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double initialRisk = MathAbs(openPrice - currentSL);
      
      if(initialRisk <= 0) continue;
      
      double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
      double currentProfit = (OrderType() == OP_BUY) ? (currentPrice - openPrice) : (openPrice - currentPrice);
      double rMultiple = currentProfit / initialRisk;
      
      double newSL = currentSL;
      
      if(rMultiple >= InpRMultTrail_Lock2_Mult)
      {
         // Lock 70% of profit
         double lockPrice = openPrice + (OrderType() == OP_BUY ? 1 : -1) * currentProfit * (InpRMultTrail_Lock2_Pct / 100.0);
         newSL = lockPrice;
      }
      else if(rMultiple >= InpRMultTrail_Lock1_Mult)
      {
         // Lock 50% of profit
         double lockPrice = openPrice + (OrderType() == OP_BUY ? 1 : -1) * currentProfit * (InpRMultTrail_Lock1_Pct / 100.0);
         newSL = lockPrice;
      }
      else if(rMultiple >= InpRMultTrail_BE_Mult)
      {
         // Move to breakeven + buffer
         double buffer = InpRMultTrail_BE_Buffer * Point;
         newSL = openPrice + (OrderType() == OP_BUY ? buffer : -buffer);
      }
      
      // Only move SL in favorable direction
      bool isImprovement = (OrderType() == OP_BUY && newSL > currentSL) ||
                           (OrderType() == OP_SELL && newSL < currentSL);
      
      if(isImprovement && newSL != currentSL)
      {
         OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrGreen);
      }
   }
}

// Call in OnTick() after strategy logic
// UpdateRMultipleTrailing();
```

---

## SUMMARY: Top Techniques Extracted from GitHub

| # | Technique | Source | DESTROYER Impact |
|---|-----------|--------|-----------------|
| 1 | Tapered DD Protection | ApexPullBack | Smooths lot reduction during DD |
| 2 | Volatility Spike Skip | ApexPullBack | Blocks entries during flash events |
| 3 | News Filter | ForexNewsKiller | Blocks entries near NFP/FOMC/ECB |
| 4 | Multi-Factor Risk | ApexPullBack | Combines all risk factors optimally |
| 5 | R-Multiple Trailing | ApexPullBack | 4-phase progressive profit lock |

---

*Extraction completed: 2026-05-27*
