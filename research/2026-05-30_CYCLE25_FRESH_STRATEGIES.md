# Cycle 25 Fresh Strategy Research
**Date:** 2026-05-30  
**Target:** EURUSD H4 — New edge sources to push from $138K → $170K projected  
**Sources:** GitHub MQL4 repos, ForexFactory extracted threads, EA31337 project

---

## EXISTING EDGE INVENTORY (What We Already Have)
| Strategy | Type | PF | Trades | Issue |
|----------|------|-----|--------|-------|
| Phantom | Monday gap fader | 1.91 | Moderate | Strong |
| Reaper | Grid | 1.52 | Many | Moderate DD |
| MeanReversion | BB+RSI | — | Too strict | Needs relaxation |
| SessionMomentum | Session | — | ~2 | Too few signals |
| DivergenceMR | Divergence | — | ~1 | Too few signals |

**V29.00 Features:** ICT Order Block, Fair Value Gap, 8AM ORB, Chandelier Trail, MTF alignment, Kill Zones

---

## CATEGORY 1: TIME-OF-DAY / SESSION-SPECIFIC EAs

### Strategy 1A: London Open EMA Fade (ForexFactory "London Open Strategy")
**Source:** `AaronL725/Hermes` — ForexFactory rawdata  
**Link:** https://www.forexfactory.com/thread/post/7601307  

**Core Logic:**
- **Time Window:** London Open (8:00 GMT / 08:00 BST)
- **Chart:** EURUSD M5 with 15 EMA
- **Entry:** At London open candle, determine direction based on EMA slope in preceding 30 min. If price was pushing UP into open → SELL (fade momentum). If pushing DOWN → BUY.
- **Stop Loss:** 20 pips initial hard stop, reduce to 10 pips once price moves favorably
- **Take Profit:** 10 pips (conservative) or trail with manual management
- **Filter:** No trade if Asian range was flat (8 pips or less) with flat EMA — no direction/momentum to fade
- **Win Rate:** ~65% over 40-day sample with 10 pip TP / 10+spread SL

**Performance Claims:**
- 4 consecutive winning days at time of posting
- $3000 account, 5% risk, 1.25 lots → $125/day at 10 pips → 16.5% in 4 days
- Author notes "65% of winning trades going to 10 pips with a 10 pip +spread stop loss"

**Adaptation for H4:**
- Use H4 candle close at 08:00, 12:00, 16:00 GMT as session anchors
- Fade the first H4 candle direction at London open
- Larger SL/TP proportional to H4 ATR (e.g., SL = 0.5×ATR14, TP = 0.3×ATR14)

**MQL4 Pseudocode:**
```mql4
// London Open Fade - H4 Adapted
int start() {
    if(Hour() == 8 && Minute() < 30) { // London open window
        double ema = iMA(NULL, PERIOD_H4, 15, 0, MODE_EMA, PRICE_CLOSE, 0);
        double prevHigh = iHigh(NULL, PERIOD_H4, 1);
        double prevLow = iLow(NULL, PERIOD_H4, 1);
        double asianRange = prevHigh - prevLow;
        
        if(asianRange > 30 * Point) { // Filter: minimum range
            if(Close[0] > ema && Close[1] > ema) // Momentum up → fade
                OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 
                         Ask + 50*Point, Bid - 30*Point);
            else if(Close[0] < ema && Close[1] < ema) // Momentum down → fade
                OrderSend(Symbol(), OP_BUY, lots, Ask, 3,
                         Bid - 50*Point, Ask + 30*Point);
        }
    }
}
```

---

### Strategy 1B: Asian Range Breakout (ForexFactory "A Simple London Breakout")
**Source:** `AaronL725/Hermes` — ForexFactory rawdata  
**Link:** https://www.forexfactory.com/thread/post/xxx  

**Core Logic:**
- **Box Definition:** 03:00–06:00 GMT (3 hours before Frankfurt open) on M15 chart
- **Entry Points:** At the 27.2% and 38.2% Fibonacci extensions beyond the box
- **Profit Target:** Equal to box size in pips (if box = 40 pips, TP = 40 pips from entry)
- **Stop Loss:** Opposite end of box
- **Max Box Size:** Filter out boxes > 40-50 pips (pre-existing volatility = lower probability)
- **Pairs:** EURUSD, GBPUSD, USDJPY, EURJPY, USDCHF
- **Win Rate:** 65-75% claimed
- **EA Available:** Steve Hopwood's EA modified by squalou (V4.0 with trailing stop, break-even, max risk)

**Key EA Parameters:**
```
TrailingStopPips (0 = fixed SL)
TrailingStopStep (1)
BreakEvenPips (>0 enables BE)
BreakEvenProfitInPips
MaxRisk (auto position sizing)
MaxBoxSizeInPips
MinExtentInPips
MaxExtentInPips
```

**Adaptation for H4:**
- Use the first H4 candle of Asian session (00:00-04:00 GMT) as the box
- Entry at 27.2% extension of box height
- TP = 1× box height, SL = 0.5× box height (better R:R on H4)

---

### Strategy 1C: Monday-Tuesday Breakout EA
**Source:** GitHub — `AaronL725/Hermes` ForexFactory data  

**Core Logic:**
- Defines Monday's range as the box
- Trades breakout of Monday range on Tuesday
- Direction determined by which side breaks first

---

## CATEGORY 2: VOLATILITY BREAKOUT EAs

### Strategy 2A: ATR Break Out (ABO) — by abokwaik
**Source:** ForexFactory thread, EA code available  

**Core Logic:**
- Uses ATR(50) as volatility measure
- Pending Stop Orders calculated at start of each new bar
- **Breakout Entry:** Price breaks ATR × multiplier above/below current bar
- **Stop Loss:** ATR × SL multiplier
- **Take Profit:** ATR × TP multiplier  
- **Trailing Stop:** ATR × TS multiplier
- Un-triggered orders deleted before placing new ones

**Default Parameters:**
```
ATR Period: 50
Breakout Multiplier: 2.0 (aggressive) / 3.0 (normal)
SL Multiplier: 2.0 (aggressive) / 4.0 (normal)
TP Multiplier: 4.0 (aggressive) / 20.0 (normal)
TS Multiplier: 6.0
```

**"Crazy Set" (EURUSD H1):**
```
Breakout: 2×ATR
SL: 4×ATR (wide)
TS: 6×ATR
TP: 20×ATR (very wide, trend-catching)
Multiple Orders: 99
Filters: None (RSI/MACD disabled)
```

**Performance Claims:**
- Compounding trend-following system
- Suffers many small losses before catching a trend
- Few winners recover losses and add to equity
- Works best on trending instruments

**Adaptation for H4:**
- ATR(20) on H4 (shorter lookback for faster adaptation)
- Breakout: 1.5×ATR, SL: 2×ATR, TP: 4×ATR
- Add time filter: only trade during London/NY kill zones (08:00-17:00 GMT)
- Add RSI filter: only buy if RSI(14) > 40, only sell if RSI(14) < 60

**MQL4 Core Logic:**
```mql4
double atr = iATR(NULL, PERIOD_H4, 20, 0);
double breakoutLevel = atr * 1.5;
double sl = atr * 2.0;
double tp = atr * 4.0;

// Buy stop at current close + breakoutLevel
// Sell stop at current close - breakoutLevel
// Delete untriggered orders at bar close, recalculate
```

---

### Strategy 2B: 4H Box Breakout (NanningBob System)
**Source:** ForexFactory — Nanningbob 4H trading system  
**Claimed Performance:** 14,195 pips in 10 months (Aug 2009 – Jun 2010)

**Core Logic:**
- Uses 4H timeframe with Bollinger Bands (20, 2.0), Stochastic, MACD
- **Primary Trade:** When all three indicators align (Red, White, Blue = MACD, Stochastic, BB)
- **Secondary Trade:** Counter-trend at BB extremes with S/R confirmation
- **EA Entry:** Uses 3×3 MA cross for entries, managed manually
- **Recovery System:** 2.4.2 recovery (grid-like position management)
- **Pairs:** Multiple (best 11 pairs listed)

**Key Parameters:**
```
BB Period: 20, Deviation: 2.0
Stochastic: 14, 3, 3
MACD: True MACD variant
MA Cross: 3-period for 4H entries
SL: Dynamic (varies by pair volatility grouping)
```

**Monthly Results (claimed):**
- Aug 2009: +1020 pips
- Sep 2009: +2651 pips
- Oct 2009: +1335 pips
- Nov 2009: +1628 pips
- Jan 2010: +1757 pips
- Apr 2010: +4951 pips (best month)
- May 2010: -3386 pips (Euro news event)
- 2009 total: +5597 pips
- 2010 total: +8598 pips

**Adaptation for DESTROYER:**
- Use BB(20,2.0) on H4 for mean reversion zones
- Combine with existing ICT Order Block logic for confluence
- Add Stochastic(14,3,3) oversold/overbought as filter
- Trade secondary (counter-trend) entries at BB extremes with S/R

---

## CATEGORY 3: MEAN REVERSION EAs (H4 Optimized)

### Strategy 3A: Simple Mean Reversion — Cycle-Based (AlphaOmega)
**Source:** ForexFactory — "Simple Mean Reversion" thread  
**Claimed Performance:** 85-90% profitable days, 98%+ with optimizations

**Core Logic:**
- **Framework:** Daily trading cycle (01:00-23:00 GMT+2)
- **Entry (Sell):** When price = daily high AND time < mid-cycle (12:00)
- **Entry (Buy):** When price = daily low AND time < mid-cycle (12:00)
- **Position Building:** Inverted pyramid (1 unit, then +2, then +3, etc.)
- **Add Step:** 10% of Daily ATR between additions
- **TP (before 12:00):** 50% retracement of range (mid-point)
- **TP (after 12:00):** 25% retracement of range
- **Hard Close:** All positions closed at end of cycle (00:00/23:00)
- **Minimum Range Filter:** ATR × 0.1 (don't trade tiny ranges)

**Critical MQL4 Code (from thread):**
```mql4
double price = Bid;
int time = Hour();
double high = iHigh(Symbol, PERIOD_D1, 0);
double low = iLow(Symbol, PERIOD_D1, 0);
double range = high - low;
double atr = iATR(Symbol, PERIOD_D1, 20, 0);
double retr50 = (high + low) / 2;
double retr25sell = high - (range * 0.25);
double retr25buy = low + (range * 0.25);
double addstep = atr * 0.1;
double minRange = atr * 0.1;
```

**Statistical Edge (10-year EURUSD backtest):**
- 95% probability: 25% retracement occurs before range doubles (when entering at 30+ pip range)
- 25% retracement occurs within 2 hours, 94% of the time (first half of cycle)
- Max observed range before retracement: 8× initial range (rare, news-driven)
- 14-year test (2004-2017): 15,891 trades, $10K → $16,703 (0.01 lots)
- Works well until 2011, then degrades (market regime change)

**Critical Warning:**
- DD almost equals annual return on single pair
- Must diversify across 10-15 uncorrelated markets
- Fat tail events (news) are the Achilles' heel
- Avoid trading during high-impact news

**Adaptation for H4 Cycle Mean Reversion:**
- Instead of daily cycle, use H4 candles as mini-cycles
- Track H4 high, low, mid for each 4-hour period
- Enter mean reversion when price hits H4 extreme in first half of candle
- TP at 50% retracement of H4 range
- Close all at H4 candle close
- Filter: Only trade during 08:00-20:00 GMT (active sessions)

---

### Strategy 3B: Bollinger Band Mean Reversion (NanningBob BB System)
**Already integrated partially** — Our existing MeanReversion uses BB+RSI but is "too strict"

**Relaxation Parameters:**
```
Current: BB(20, 2.0) — only trades at outer band touch
Proposed: BB(20, 1.8) — wider trigger zone
Current: RSI(14) < 30 / > 70
Proposed: RSI(14) < 35 / > 65
Add: Stochastic(14,3,3) confirmation
Add: Time filter — only during 08:00-16:00 GMT
```

**Additional BB Strategy from Thread:**
- Use BB on H4 with 2.0 deviation
- Entry when price touches outer BB AND candle closes back inside
- TP: Middle BB (20 SMA)
- SL: Beyond the wick + ATR buffer
- Expected: ~60% win rate, 1:1.5 R:R

---

## CATEGORY 4: HIGH PROFIT FACTOR (>2.0) EAs

### Strategy 4A: Mister ED's 4-Hour Heikin Ashi System
**Source:** ForexFactory thread  
**Claimed Performance:** 4,976 pips/month average (11 pairs), 69% strike rate (820W/369L)

**Core Logic:**
- **Timeframe:** 4H (perfect for our target)
- **Signal:** Heikin Ashi color change
- **Entry:** At close of HA color-change candle
- **Measurements:** From regular candlesticks (not HA)
- **Position:** Split into 2 parts
  - Part 1: TP1 = 1× candle range, then close
  - Part 2: Trailing stop using HA wick (high/low of previous HA candle)
- **Retrace Entry:** Optional second entry on pullback
- **Pairs:** 10+ pairs including EURUSD, GBPUSD, USDJPY, Gold

**Parameters:**
```
TP1: 1× candle body range
TSL: Previous HA candle high/low
Part 1: 50% of position
Part 2: 50% trailing
```

**Performance Details:**
- Oct 2008: 11,199 pips (long trends)
- Feb (worst): 1,552 pips (68% strike rate)
- Current month at posting: 21W/4L
- 738 pips in first week from GBPJPY, GBPUSD, EURUSD, USDJPY, Gold

**Adaptation for DESTROYER H4:**
- Already on H4 — minimal adaptation needed
- Use existing Chandelier Trail for Part 2 trailing
- HA color change as additional confirmation for ICT Order Block entries
- TP1 at 1× recent H4 candle range, trail remainder

---

### Strategy 4B: EA31337 — Multi-Strategy Framework
**Source:** GitHub — `EA31337/EA31337` (open source, MQL4/MQL5)  
**URL:** https://github.com/EA31337/EA31337  

**Architecture:**
- Multi-strategy EA running multiple sub-strategies simultaneously
- Each sub-strategy can be independently enabled/disabled
- Strategies include: trend, breakout, mean reversion, scalping
- Uses indicators: EWO (Elliott Wave Oscillator), SVEBB (SVE Bollinger Band), TMA (Triangular MA), Supertrend
- Per-strategy risk management and position sizing

**Key Features for DESTROYER:**
- Modular strategy architecture (similar to our multi-signal approach)
- Can run multiple strategies on same pair with different magic numbers
- Built-in compounding and risk management
- Tested across multiple pairs and timeframes

**Potential Integration:**
- Study their strategy modules for ideas to add to DESTROYER
- Their TMA/BB combination could enhance our MeanReversion
- Their breakout module could inform ATR-based entries

---

## CATEGORY 5: ADDITIONAL STRATEGIES FROM GITHUB SEARCH

### 5A: OmegaTrendEA v7.0 EURUSD
**Source:** `RoyluxuryTrading/Super-trading` on GitHub  
**Config files available** — EURUSD-specific optimization

### 5B: MondayTuesday Breakout EA
**Source:** `AaronL725/Hermes` ForexFactory data  
- Defines Monday range, trades Tuesday breakout
- Simple day-of-week filter combined with range breakout

---

## RECOMMENDED NEW STRATEGIES FOR DESTROYER V30

### Priority 1: London Open Session Fade (Strategy 1A)
**Why:** Time-specific, high win rate (~65%), simple logic, complementary to existing kill zone system  
**Implementation:** Add as new signal module alongside 8AM ORB  
**Expected Impact:** +1-2 trades/day, PF target 1.5-2.0  
**Risk:** Low — fade at known volatile time with tight SL

### Priority 2: ATR Volatility Breakout (Strategy 2A)  
**Why:** Adapts to market conditions automatically, proven EA exists  
**Implementation:** New breakout signal module with ATR-based entries  
**Expected Impact:** +2-4 trades/week, PF target 1.8-2.5  
**Risk:** Medium — many small losses, needs trend-catching TP

### Priority 3: Cycle Mean Reversion (Strategy 3A)
**Why:** 95% statistical edge on 25% retracement, works on EURUSD  
**Implementation:** New mean reversion module using H4 cycles instead of daily  
**Expected Impact:** +3-5 trades/day (if adapted to H4), PF target 1.5-2.0  
**Risk:** HIGH — fat tail exposure, needs hard stops and diversification

### Priority 4: Heikin Ashi Confirmation (Strategy 4A)
**Why:** Already on H4, 69% win rate, 4976 pips/month across pairs  
**Implementation:** HA color change as additional filter for existing entries  
**Expected Impact:** Improves win rate of existing signals by 10-15%  
**Risk:** Low — filter only, doesn't change core logic

### Priority 5: Relax MeanReversion Parameters (Strategy 3B)
**Why:** Already coded, just needs parameter adjustment  
**Implementation:** Change BB deviation from 2.0→1.8, RSI from 30/70→35/65  
**Expected Impact:** +50-100% more trades from MeanReversion module  
**Risk:** Medium — more trades but potentially lower quality

---

## PARAMETER SUMMARY TABLE

| Strategy | BB Dev | RSI OB/OS | ATR Mult | SL | TP | Time Filter |
|----------|--------|-----------|----------|----|----|-------------|
| London Fade | — | — | — | 0.5×ATR | 0.3×ATR | 08:00 GMT ±30m |
| ATR Breakout | — | 40/60 | 1.5× | 2×ATR | 4×ATR | 08:00-17:00 GMT |
| Cycle MR | — | — | 0.1×min | End of cycle | 25-50% retrace | First half cycle |
| HA Confirm | — | — | — | HA wick | 1× candle | 4H close |
| Relaxed MR | 1.8 | 35/65 | — | BB outer+buf | BB middle | 08:00-16:00 GMT |

---

## FILES REFERENCED
- GitHub: `EA31337/EA31337` — Multi-strategy EA framework
- GitHub: `RoyluxuryTrading/Super-trading` — OmegaTrendEA configs
- GitHub: `AaronL725/Hermes` — ForexFactory extracted threads (500+ strategies)
- ForexFactory: London Open Strategy, Simple London Breakout, ATR Break Out, NanningBob 4H, Simple Mean Reversion, Mister ED 4H HA

## NEXT STEPS
1. Code London Open Session Fade as standalone module
2. Implement ATR Breakout with time filters
3. Modify MeanReversion BB parameters (2.0→1.8, RSI 30/70→35/65)
4. Add HA color change confirmation filter
5. Backtest all new modules on EURUSD H4 (2020-2026)
6. Integrate top 2-3 performers into V30

---

*Research compiled from GitHub code search and ForexFactory extracted data. Performance claims are from original authors and have NOT been independently verified. All strategies require backtesting before live deployment.*
