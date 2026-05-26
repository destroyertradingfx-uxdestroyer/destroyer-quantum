# Advanced Trailing Stop Research — 2026-05-26

## Executive Summary

Searched GitHub for MQL4/MQL5 repos implementing advanced trailing stop mechanisms (Donchian, Keltner, Chandelier, PSAR, Supertrend, Fractals). Found **5 repos with >5 stars** from EarnForex's MQLTA library, plus analyzed how the existing DESTROYER QUANTUM V29.00 EA already integrates several of these patterns. Below are findings with code patterns and integration recommendations.

---

## 1. Repositories Found (Sorted by Stars)

### 1.1 EarnForex/Trailing-Stop-on-Profit ⭐ 64
- **URL**: https://github.com/EarnForex/Trailing-Stop-on-Profit
- **Language**: MQL4 + MQL5
- **Description**: Classic trailing stop that activates only after a given profit threshold is reached
- **Key Pattern**: Profit-activation gating — the trailing stop only engages once position profit exceeds a configurable threshold. This prevents premature stop tightening on noise.
- **Integration Value**: DESTROYER already has profit-based activation (R-multiples at 1.0R and 2.0R thresholds). The EarnForex approach uses absolute USD/points, which is simpler but less adaptive.

### 1.2 EarnForex/ATR-Trailing-Stop ⭐ 19
- **URL**: https://github.com/EarnForex/ATR-Trailing-Stop
- **Language**: MQL4 + MQL5
- **Description**: ATR-based trailing stop — SL distance adapts to current volatility
- **Key Code Pattern**:
  ```mql4
  // BUY trailing stop
  double SLValue = SymbolInfoDouble(Instrument, SYMBOL_BID) - iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift) * ATRMultiplier;
  
  // SELL trailing stop  
  double SLValue = SymbolInfoDouble(Instrument, SYMBOL_ASK) + iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift) * ATRMultiplier;
  
  // Activation gate: only trail after N×ATR profit
  if (ActivationATRMult > 0) {
      double atr = iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift);
      activated = (currentBid - openPrice >= ActivationATRMult * atr);
  }
  ```
- **Inputs**: `ATRPeriod=14`, `ATRMultiplier=1.0`, `ActivationATRMult` (ATR-based profit gate), `ActivationMinProfit` (points-based profit gate)
- **Timeframe Support**: Configurable via `ENUM_CUSTOMTIMEFRAMES` (M1→MN1, including H4/D1)
- **Integration Value**: **HIGH** — DESTROYER uses ATR for stop calculation already (InpChandelier_Period=22, InpChandelier_Multiplier=3.0), but the EarnForex dual-activation-gate pattern (ATR-based OR points-based) is cleaner than DESTROYER's current R-multiple approach for some strategies.

### 1.3 EarnForex/PSAR-Trailing-Stop ⭐ 15
- **URL**: https://github.com/EarnForex/PSAR-Trailing-Stop
- **Language**: MQL4 + MQL5
- **Description**: Parabolic SAR-based trailing stop
- **Key Code Pattern**:
  ```mql4
  // BUY: PSAR value becomes the stop loss
  double SLValue = iSAR(symbol, PERIOD_CURRENT, PSARStep, PSARMax, Shift);
  
  // SELL: same indicator, different validation
  if ((Shift > 0) && (SLValue < iHigh(symbol, Period(), Shift))) return 0; // Wrong side
  
  // Modification: only tighten, never loosen
  if (PSAR_SL > SLPrice) // BUY: new SL must be higher
  if (PSAR_SL < SLPrice || SLPrice == 0) // SELL: new SL must be lower
  ```
- **Inputs**: `PSARStep=0.02`, `PSARMax=0.2`, `Shift`, `ProfitPoints` (activation gate)
- **Integration Value**: **ALREADY INTEGRATED** — DESTROYER V29.00 has `ApplyPSARTrailV8()` at line 9370 using `iSAR(Symbol(), Period(), InpPSAR_Step, InpPSAR_Max, 0)`. Current implementation is functionally identical.

### 1.4 EarnForex/Fractals-Trailing-Stop ⭐ 15
- **URL**: https://github.com/EarnForex/Fractals-Trailing-Stop
- **Language**: MQL4 + MQL5
- **Description**: Bill Williams Fractals-based trailing — uses recent swing highs/lows as stop levels
- **Key Code Pattern**:
  ```mql4
  // BUY: Find the Nth fractal low (Donchian-like support)
  double FractalDown = 0;
  int counter = 0;
  for (int i = 0; i < BarsToScan; i++) {
      FractalDown = iFractals(symbol, PERIOD_CURRENT, MODE_LOWER, i);
      if (FractalDown > 0) {
          counter++;
          if (counter >= FractalToUse) break; // Use Nth fractal
      }
  }
  ```
- **Integration Value**: **MEDIUM** — Fractals are structurally similar to Donchian channels (both use recent swing extremes). The "Nth fractal" approach allows deeper pullback tolerance. Could replace or supplement DESTROYER's Chandelier Exit for strategies that need structural support/resistance levels rather than pure ATR distance.

### 1.5 EarnForex/Supertrend-Trailing-Stop ⭐ 10
- **URL**: https://github.com/EarnForex/Supertrend-Trailing-Stop
- **Language**: MQL4 + MQL5
- **Description**: Supertrend indicator-based trailing (ATR envelope that flips direction)
- **Key Code Pattern**:
  ```mql4
  // Get Supertrend value from custom indicator
  double tu = iCustom(Instrument, Timeframe, SupertrendFileName, "", ATRMultiplier, ATRPeriod, 0, CandleToCheck);
  double td = iCustom(Instrument, Timeframe, SupertrendFileName, "", ATRMultiplier, ATRPeriod, 1, CandleToCheck);
  if (tu != EMPTY_VALUE) Supertrend = tu;      // Uptrend line
  else if (td != EMPTY_VALUE) Supertrend = td;  // Downtrend line
  
  // Trail to Supertrend value (only tighten)
  if (NewSL > SLPrice + StopLevel) ModifyOrder(...);
  ```
- **Inputs**: `ATRMultiplier=2.0`, `ATRPeriod=100`, `StopATRTimeframe` (configurable!), `CandleToCheck` (current vs closed)
- **Integration Value**: **HIGH** — Supertrend is a self-directional trailing stop (automatically flips between long/short levels). The `StopATRTimeframe` parameter allows computing Supertrend on H4/D1 while trading on lower TFs. DESTROYER does NOT currently have Supertrend trailing.

---

## 2. Repositories NOT Found (Gaps in GitHub)

| Indicator | GitHub Results | Notes |
|-----------|---------------|-------|
| **Donchian Channel Trailing** | 0 repos >5★ | No standalone MQL4/5 EA exists. Donchian is typically coded inline (Highest High - N periods). The Fractals repo is the closest analog. |
| **Keltner Channel Trailing** | 0 repos >5★ | No standalone EA. Keltner is used in DESTROYER's Warden strategy for entry filtering (line 9762-9787) but not as a trailing mechanism. |
| **Chandelier Exit EA** | 0 repos >5★ | No standalone EA. Chandelier is already integrated in DESTROYER V29.00. |

---

## 3. DESTROYER QUANTUM V29.00 — Current Trailing Infrastructure

The EA already has a **sophisticated multi-layer trailing system**:

### 3.1 Multi-Stage Hyperion Protocol (Lines 9300-9365)
```
Stage 1 (≥1.0R profit): Move SL to Break-Even + 2pt buffer
Stage 2 (≥2.0R profit): Apply Chandelier Exit trailing
```
- Uses `g_trail_stage` global (lines 7132, 7213, 9055-9058) for PSAR → Chandelier → EMA progression
- V27.20 special: Short positions held >24hrs get 0.5×ATR tight trailing

### 3.2 Active Trailing Methods

| Method | Function | Line | Status |
|--------|----------|------|--------|
| **Chandelier Exit** | `ApplyChandelierTrail()` | 5505 | ✅ Active (Period=22, Mult=3.0) |
| **Chandelier V8** | `ApplyChandelierTrailV8()` | 9411 | ✅ Active (used by Hyperion Stage 2) |
| **PSAR Trail** | `ApplyPSARTrailV8()` | 9370 | ✅ Active (Step=0.02, Max=0.2) |
| **EMA Trail** | `ApplyEMATrailV8()` | 9462 | ✅ Active (Period=10) |
| **Jaguar ATR Trail** | Silicon-X system | 1283-1288 | ✅ Active (Mult=3.0, MA=100) |
| **Aegis Basket Trail** | Silicon-X basket | 1294-1298 | ✅ Active ($50 start, 100 pips) |
| **Reaper Chimera** | Defensive trail | 1236-1239 | ✅ Active ($150 start, 300 pips) |
| **Hubble Pending Trail** | Pending order trail | 1301-1302 | ✅ Active (50 pips) |
| **Keltner Channel** | Warden filter | 9762-9787 | ⚠️ Entry filter only, NOT trailing |

### 3.3 Current Parameters (Line 1148-1154)
```mql4
InpATR_Multiplier = 2.5;          // Volatility forecast
InpChandelier_Period = 22;        // Chandelier lookback
InpChandelier_Multiplier = 3.0;   // Chandelier ATR multiplier
InpEMA_Trail_Period = 10;         // EMA trail period
```

---

## 4. Integration Recommendations

### 4.1 Donchian Channel Trailing Stop (NEW — High Priority)

**What**: Trail using the N-period Donchian channel (Highest High / Lowest Low minus buffer).

**Why**: Donchian is structurally superior to Chandelier for trending markets because it uses actual price extremes rather than ATR distance. Chandelier can get stopped out on a volatility spike that doesn't breach structure; Donchian won't.

**Implementation**:
```mql4
// DONCHIAN TRAILING STOP — New function for DESTROYER
// Add after ApplyChandelierTrailV8 (line ~9457)

extern int InpDonchian_Period = 20;          // Donchian lookback period
extern double InpDonchian_Buffer = 0.5;      // Buffer in ATR multiples below channel

void ApplyDonchianTrail(int ticket, int order_type)
{
    if(ticket <= 0) return;
    
    double atr = iATR(Symbol(), Period(), 14, 0);
    double buffer = atr * InpDonchian_Buffer;
    
    if(order_type == OP_BUY)
    {
        double highestHigh = High[iHighest(Symbol(), Period(), MODE_HIGH, InpDonchian_Period, 1)];
        double new_sl = highestHigh - buffer;
        if(new_sl > OrderStopLoss() && new_sl < Bid)
            ModifyTradeV8(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), "Donchian_Trail");
    }
    else if(order_type == OP_SELL)
    {
        double lowestLow = Low[iLowest(Symbol(), Period(), MODE_LOW, InpDonchian_Period, 1)];
        double new_sl = lowestLow + buffer;
        if((new_sl < OrderStopLoss() || OrderStopLoss() == 0) && new_sl > Ask)
            ModifyTradeV8(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), "Donchian_Trail");
    }
}
```

**Integration point**: Replace `ApplyChandelierTrailV8` call at line 9362 with `ApplyDonchianTrail` for trend-following strategies (Valkyrie, Warden). Keep Chandelier for mean-reversion strategies.

### 4.2 Keltner Channel Trailing Stop (NEW — Medium Priority)

**What**: Trail using Keltner Channel edge (EMA ± ATR×Mult) instead of Chandelier.

**Why**: Keltner provides a smoother trailing reference than Chandelier because the center line (EMA) adapts to trend direction. DESTROYER already computes Keltner for Warden entries (line 9762-9787) — just needs a trailing function.

**Implementation**:
```mql4
// KELTNER CHANNEL TRAILING STOP
extern int InpKC_Trail_Period = 20;
extern double InpKC_Trail_ATR_Mult = 1.5;

void ApplyKeltnerTrail(int ticket, int order_type)
{
    if(ticket <= 0) return;
    
    double kc_ma = iMA(Symbol(), Period(), InpKC_Trail_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
    double kc_atr = iATR(Symbol(), Period(), InpKC_Trail_Period, 0);
    
    if(order_type == OP_BUY)
    {
        double kc_lower = kc_ma - (kc_atr * InpKC_Trail_ATR_Mult);
        if(kc_lower > OrderStopLoss() && kc_lower < Bid)
            ModifyTradeV8(ticket, OrderOpenPrice(), kc_lower, OrderTakeProfit(), "Keltner_Trail");
    }
    else if(order_type == OP_SELL)
    {
        double kc_upper = kc_ma + (kc_atr * InpKC_Trail_ATR_Mult);
        if((kc_upper < OrderStopLoss() || OrderStopLoss() == 0) && kc_upper > Ask)
            ModifyTradeV8(ticket, OrderOpenPrice(), kc_upper, OrderTakeProfit(), "Keltner_Trail");
    }
}
```

**Integration point**: Use for Warden strategy trades (already has KC parameters). Replace generic Chandelier trail with KC-specific trail when `OrderMagicNumber() == InpMagic_Warden`.

### 4.3 Supertrend Trailing Stop (NEW — Medium Priority)

**What**: Self-flipping trailing stop that automatically adjusts direction.

**Why**: Supertrend's key advantage is it only moves in the direction of the trend — once it flips, it stays on the new side. This prevents the whipsaw problem where Chandelier/PSAR trail gets repeatedly triggered.

**Implementation** (self-contained, no external indicator needed):
```mql4
// SUPERTREND TRAILING STOP — Pure function, no iCustom dependency
extern int InpSupertrend_Period = 10;
extern double InpSupertrend_Multiplier = 3.0;

void ApplySupertrendTrail(int ticket, int order_type)
{
    if(ticket <= 0) return;
    
    double atr = iATR(Symbol(), Period(), InpSupertrend_Period, 0);
    double hl2 = (High[0] + Low[0]) / 2.0;
    double upperBand = hl2 + (InpSupertrend_Multiplier * atr);
    double lowerBand = hl2 - (InpSupertrend_Multiplier * atr);
    
    // Simple Supertrend logic: use band on correct side of price
    if(order_type == OP_BUY)
    {
        if(lowerBand > OrderStopLoss() && lowerBand < Bid)
            ModifyTradeV8(ticket, OrderOpenPrice(), lowerBand, OrderTakeProfit(), "Supertrend_Trail");
    }
    else if(order_type == OP_SELL)
    {
        if((upperBand < OrderStopLoss() || OrderStopLoss() == 0) && upperBand > Ask)
            ModifyTradeV8(ticket, OrderOpenPrice(), upperBand, OrderTakeProfit(), "Supertrend_Trail");
    }
}
```

### 4.4 Enhanced Multi-Stage Progression (Upgrade Existing)

Current DESTROYER progression: `PSAR → Chandelier → EMA`

**Recommended progression**:
```
Stage 1 (≥0.5R): Move to Break-Even (tighter than current 1.0R)
Stage 2 (≥1.0R): PSAR trail (tight, reactive)
Stage 3 (≥1.5R): Donchian trail (structural, medium)
Stage 4 (≥2.5R): Keltner trail (smooth, trend-following)
Stage 5 (≥3.5R): 0.5×ATR tight trail (lock in maximum profit)
```

---

## 5. Key Patterns from EarnForex Library

| Pattern | Description | DESTROYER Already Has? |
|---------|-------------|----------------------|
| Dual activation gate (ATR OR points) | Trail only after profit exceeds threshold | ✅ R-multiple gates |
| Tick-size normalization | `MathRound(SL / TickSize) * TickSize` | ❌ Missing — could cause rejected modifications |
| Spread adjustment for SELL SL | `NewSL = SLSell + Spread` | ❌ Missing |
| StopLevel check before modify | `SL < Bid - StopLevel` for BUY | ✅ Present |
| Retry loop with error handling | `for(i=1; i<=5; i++)` OrderModify retry | ✅ RobustOrderModify exists |
| Multi-timeframe ATR calculation | `iATR(Instrument, PERIOD_H4, ...)` | ✅ Used in VolSizing |

**Critical missing pattern**: Tick-size normalization. The EarnForex EAs all do:
```mql4
double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
if (TickSize > 0)
    NewSL = NormalizeDouble(MathRound(NewSL / TickSize) * TickSize, eDigits);
```
DESTROYER uses `NormalizeDouble(newSL, Digits)` but NOT tick-size rounding. This can cause `OrderModify` rejections on instruments where tick size ≠ point size (e.g., some CFDs, crypto).

---

## 6. Summary of Recommendations

| Priority | Action | Expected Impact |
|----------|--------|-----------------|
| 🔴 HIGH | Add Donchian trailing for trend strategies | Better trend capture, fewer false stops |
| 🔴 HIGH | Add tick-size normalization to all ModifyTrade calls | Prevent rejected OrderModify on non-standard instruments |
| 🟡 MEDIUM | Add Keltner Channel trailing for Warden strategy | Leverage existing KC parameters for strategy-specific trailing |
| 🟡 MEDIUM | Add Supertrend trailing option | Self-flipping reduces whipsaw |
| 🟢 LOW | Tighten BE trigger from 1.0R to 0.5R | Earlier risk-free positioning |
| 🟢 LOW | Add spread adjustment for SELL stop modifications | More accurate SL placement on sell trades |

---

## 7. Sources

| Repo | Stars | URL | Key Feature |
|------|-------|-----|-------------|
| EarnForex/Trailing-Stop-on-Profit | 64 | https://github.com/EarnForex/Trailing-Stop-on-Profit | Profit-gated activation |
| EarnForex/ATR-Trailing-Stop | 19 | https://github.com/EarnForex/ATR-Trailing-Stop | ATR-adaptive distance + dual activation gate |
| EarnForex/PSAR-Trailing-Stop | 15 | https://github.com/EarnForex/PSAR-Trailing-Stop | Parabolic SAR trailing |
| EarnForex/Fractals-Trailing-Stop | 15 | https://github.com/EarnForex/Fractals-Trailing-Stop | Nth fractal swing levels (Donchian-like) |
| EarnForex/Supertrend-Trailing-Stop | 10 | https://github.com/EarnForex/Supertrend-Trailing-Stop | Self-flipping Supertrend + configurable TF |
| Exobeacon-Labs/UTBotAlerts | 0 | https://github.com/Exobeacon-Labs/UTBotAlerts | ATR adaptive trailing (TradingView port) |

---

*Research conducted: 2026-05-26 | DESTROYER QUANTUM V29.00 analysis*
