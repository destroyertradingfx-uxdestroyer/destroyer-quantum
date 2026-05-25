# Implementation Guide: Asian Range Breakout + Equity Curve Multiplier
## For V28.06 TITAN / OMEGA
## Date: 2026-05-25

---

## ADDITION 1: ASIAN RANGE BREAKOUT (Magic 9007)

### Registration Checklist (10 steps)

**Step 1: Add inputs (near line 4597, after StructuralRetest inputs)**
```mql4
//--- V28.07: ASIAN RANGE BREAKOUT STRATEGY (Magic: 9007) ---
extern bool    InpAsianBreakout_Enabled         = true;       // Enable Asian Range Breakout
extern int     InpAsianBreakout_MagicNumber     = 9007;       // Magic number for Asian Breakout
extern int     InpAsianBreakout_ADX_Threshold   = 15;         // ADX threshold for trend confirmation
extern double  InpAsianBreakout_ATR_SL_Mult     = 1.5;        // ATR multiplier for SL
extern double  InpAsianBreakout_ATR_TP_Mult     = 2.5;        // ATR multiplier for TP
extern double  InpAsianBreakout_MaxRange_ATR    = 1.5;        // Max range as ATR multiple
extern double  InpAsianBreakout_MinRange_ATR    = 0.3;        // Min range as ATR multiple
extern int     InpAsianBreakout_AsianBars       = 3;          // H4 bars to measure Asian range
```

**Step 2: Expand arrays (line 1690)**
```mql4
// Change from [17] to [18]
PerfData g_perfData[18];
```
Also expand ALL other arrays — grep for `[17]` and change to `[18]`:
- g_strategyMultiplier
- g_stratKellyFraction
- g_stratHeatScore
- g_stratDynamicMaxMult
- g_stratTotalTrades
- g_stratProfits
- g_stratProfitIdx
- g_consecLossTracker
- g_strategyCooldown
- g_strategyLockoutUntil
- g_stratRollingWinRate
- g_stratRollingAvgWin
- g_stratRollingAvgLoss
- g_stratRollingPF
- g_stratSharpeProxy
- g_stratLastCalcTime

**Step 3: Register in IsOurMagicNumber() (line 5856)**
```mql4
       magic == InpStructuralRetest_MagicNumber ||
       magic == InpAsianBreakout_MagicNumber)      // V28.07: Asian Breakout
```

**Step 4: Register in GetStrategyIndexFromMagic() (line 5886)**
```mql4
    if(magicNumber == InpStructuralRetest_MagicNumber) return 16;
    if(magicNumber == InpAsianBreakout_MagicNumber) return 17; // V28.07: Asian Breakout
    return -1;
```

**Step 5: Register in GetStrategyIndexByMagic() (line 14288 area)**
```mql4
    // Add after StructuralRetest mapping
    if(magicNumber == InpAsianBreakout_MagicNumber) return 17;
```

**Step 6: Register in GetStrategySpecificRisk() (line 4465 area)**
```mql4
    if(magicNumber == InpAsianBreakout_MagicNumber) return 1.0; // Standard risk
```

**Step 7: Add to Init loop (line 4663 area)**
```mql4
    // After StructuralRetest init
    g_perfData[17].name = "AsianBreakout";
    g_perfData[17].trades = 0;
    g_perfData[17].grossProfit = 0.0;
    g_perfData[17].grossLoss = 0.0;
```

**Step 8: Add strategy function (before OnNewBar)**
```mql4
//+------------------------------------------------------------------+
//| Asian Range Breakout Strategy (Magic: 9007)                     |
//| Measures Asian session range, trades London open breakout       |
//+------------------------------------------------------------------+
void ExecuteAsianBreakout()
{
    if(!InpAsianBreakout_Enabled) return;
    if(Period() != PERIOD_H4) return;
    if(CountOpenTrades(InpAsianBreakout_MagicNumber) >= 1) return;
    if(!IsStrategyHealthy(InpAsianBreakout_MagicNumber)) return;
    
    // Time filter: London open (07:00-09:00 UTC)
    int serverHour = TimeHour(TimeCurrent());
    int utcHour = serverHour - InpServerUTCOffset;
    if(utcHour < 0) utcHour += 24;
    if(utcHour < 7 || utcHour > 9) return;
    
    // Calculate Asian session range
    double asianHigh = High[1];
    double asianLow = Low[1];
    for(int lb = 2; lb <= InpAsianBreakout_AsianBars; lb++)
    {
        if(High[lb] > asianHigh) asianHigh = High[lb];
        if(Low[lb] < asianLow) asianLow = Low[lb];
    }
    double asianRange = asianHigh - asianLow;
    if(asianRange <= 0) return;
    
    // Range filter
    double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
    if(asianRange > atr * InpAsianBreakout_MaxRange_ATR) return;  // Too wide
    if(asianRange < atr * InpAsianBreakout_MinRange_ATR) return;  // Too narrow
    
    // ADX filter
    double adx = iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 1);
    if(adx < InpAsianBreakout_ADX_Threshold) return;
    
    // D1 trend bias
    double d1EMA20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
    double d1EMA50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
    int d1Bias = 0;
    if(d1EMA20 > d1EMA50) d1Bias = 1;   // Bullish
    if(d1EMA20 < d1EMA50) d1Bias = -1;  // Bearish
    
    // BUY: Close breaks above Asian high + D1 bullish
    if(Close[0] > asianHigh && d1Bias >= 0)
    {
        double sl = Ask - (atr * InpAsianBreakout_ATR_SL_Mult);
        double tp = Ask + (atr * InpAsianBreakout_ATR_TP_Mult);
        double lots = MoneyManagement_Quantum(InpAsianBreakout_MagicNumber, InpBase_Risk_Percent);
        if(lots > 0)
        {
            int ticket = OpenTrade(OP_BUY, lots, Ask, sl, tp, "ASIAN_BO_BUY", InpAsianBreakout_MagicNumber);
            if(ticket > 0)
            {
                int stratIdx = GetStrategyIndexFromMagic(InpAsianBreakout_MagicNumber);
                if(stratIdx >= 0) g_perfData[stratIdx].trades++;
            }
        }
    }
    // SELL: Close breaks below Asian low + D1 bearish
    else if(Close[0] < asianLow && d1Bias <= 0)
    {
        double sl = Bid + (atr * InpAsianBreakout_ATR_SL_Mult);
        double tp = Bid - (atr * InpAsianBreakout_ATR_TP_Mult);
        double lots = MoneyManagement_Quantum(InpAsianBreakout_MagicNumber, InpBase_Risk_Percent);
        if(lots > 0)
        {
            int ticket = OpenTrade(OP_SELL, lots, Bid, sl, tp, "ASIAN_BO_SELL", InpAsianBreakout_MagicNumber);
            if(ticket > 0)
            {
                int stratIdx = GetStrategyIndexFromMagic(InpAsianBreakout_MagicNumber);
                if(stratIdx >= 0) g_perfData[stratIdx].trades++;
            }
        }
    }
}
```

**Step 9: Add to OnNewBar() dispatch (after line 5537)**
```mql4
      ExecuteAsianBreakout();  // V28.07: Asian Range Breakout
```

**Step 10: Verify compilation**
- No duplicate input names
- No duplicate magic numbers
- All arrays expanded to [18]
- Brace balance = 0

---

## ADDITION 2: EQUITY CURVE ANTI-MARTINGALE

### Implementation (4 steps, no strategy registration needed)

**Step 1: Add global variables (near other globals, after g_perfData)**
```mql4
//+------------------------------------------------------------------+
//| Equity Curve Anti-Martingale Multiplier                          |
//+------------------------------------------------------------------+
#define EQUITY_HISTORY_SIZE 100
double gEquityHistory[EQUITY_HISTORY_SIZE];
int    gEquityIndex = 0;
bool   gEquityFilled = false;
double gPeakEquity = 0.0;
extern bool   InpEquityCurve_Enabled = true;    // Enable Equity Curve Multiplier
extern double InpEquityCurve_MaxMult = 1.5;     // Max multiplier (amplify winners)
extern double InpEquityCurve_MinMult = 0.5;     // Min multiplier (reduce losers)
extern double InpEquityCurve_DDThreshold = 0.90; // DD threshold (90% = cut at 10% DD)
```

**Step 2: Add UpdateEquityHistory() function**
```mql4
void UpdateEquityHistory()
{
    if(!InpEquityCurve_Enabled) return;
    
    double equity = AccountEquity();
    gEquityHistory[gEquityIndex] = equity;
    gEquityIndex = (gEquityIndex + 1) % EQUITY_HISTORY_SIZE;
    if(gEquityIndex == 0) gEquityFilled = true;
    
    // Track peak equity
    if(equity > gPeakEquity) gPeakEquity = equity;
}
```

**Step 3: Add GetEquityCurveMultiplier() function**
```mql4
double GetEquityCurveMultiplier()
{
    if(!InpEquityCurve_Enabled) return 1.0;
    
    double equity = AccountEquity();
    
    // Drawdown defense: if equity < 90% of peak, cut sizing
    if(gPeakEquity > 0 && equity < gPeakEquity * InpEquityCurve_DDThreshold)
    {
        return InpEquityCurve_MinMult;
    }
    
    // Need minimum data before activating
    if(!gEquityFilled && gEquityIndex < 20) return 1.0;
    
    // Calculate equity SMA
    int count = gEquityFilled ? EQUITY_HISTORY_SIZE : gEquityIndex;
    double sum = 0;
    for(int i = 0; i < count; i++) sum += gEquityHistory[i];
    double equityMA = sum / count;
    
    if(equityMA <= 0) return 1.0;
    
    // Ratio: equity / SMA
    double ratio = equity / equityMA;
    
    // Clamp to bounds
    return MathMax(InpEquityCurve_MinMult, MathMin(InpEquityCurve_MaxMult, ratio));
}
```

**Step 4: Apply in MoneyManagement_Quantum()**
Find the return statement in MoneyManagement_Quantum() and add:
```mql4
    // Apply equity curve multiplier (V28.07)
    lots *= GetEquityCurveMultiplier();
    
    // Normalize and return
    lots = NormalizeDouble(lots, 2);
    // ... existing normalization code
```

**Step 5: Call UpdateEquityHistory() in OnTick()**
```mql4
    // In OnTick(), before strategy execution
    UpdateEquityHistory();
```

---

## COMBINED SIZING FORMULA

After both additions, the lot sizing chain is:
```
baseLots = AccountEquity() * riskPercent / (stopPoints * tickValue)
kellyMult = GetKellyLotSize(strategy)  // Per-strategy Kelly
equityCurveMult = GetEquityCurveMultiplier()  // Portfolio-level
finalLots = baseLots * kellyMult * equityCurveMult
```

This creates two orthogonal amplification layers:
- **Kelly** amplifies per-strategy based on individual win rate/payoff
- **Equity Curve** amplifies at portfolio level based on aggregate performance

During winning streaks: Kelly amplifies winning strategies AND equity curve amplifies everything = double amplification.
During losing streaks: Kelly reduces losing strategies AND equity curve reduces everything = double protection.

---

## TESTING PROTOCOL

1. **Backtest TITAN first** (Ryan) — establish baseline
2. **Add Asian Breakout ONLY** → backtest → compare
3. **Add Equity Curve Multiplier ONLY** → backtest → compare
4. **Add both** → backtest → compare
5. **If below $170K:** Add volatility targeting → backtest

**Each step is ONE change per Ryan's rule #2.**
