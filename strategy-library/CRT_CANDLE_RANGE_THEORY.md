# CRT (Candle Range Theory) — 1AM, 5AM, 9AM

**Source:** PDFs by @Im-speculator (ICT/SMC methodology)
**Pair:** EURUSD (best), GBPUSD, any forex pair
**Type:** Session-based candle range theory / time-based structure
**Timeframes:** H4 CRT candles → M15/M5 entries
**Frequency:** 1-3 trades per day (one per CRT window)
**R:R:** 1:2 to 1:3

## Core Concept

CRT = Candle Range Theory. Each H4 candle creates a range (high/low). The interaction between consecutive CRT candles determines market direction.

**3 CRT candles per day:**
- **1:00 AM CRT** — London session
- **5:00 AM CRT** — London lunch / NY opening
- **9:00 AM CRT** — NY session (highest probability)

## The 3 CRT Candles

Each CRT window uses 3 consecutive H4 candles:
1. **First candle** = Generation of liquidity (creates the range)
2. **Second candle** = Purging of liquidity (sweeps the range)
3. **Third candle** = Neutralization of liquidity (confirms direction)

## Step 1: Determine Draw on Liquidity (DOL)

**DOL is the most important aspect. Without it, you're pattern trading.**

DOL determines WHERE price is going. Forms:
- **Previous day/week high/low** — easiest to identify
- **CRT high/low** — from the first candle
- **Order flow** — bullish = breaking above highs, rejecting below lows
- **Key levels** — OB, FVG, highs, lows

**Order flow rules:**
- Bullish: Breaking above highs + rejecting below lows
- Bearish: Breaking below lows + rejecting above highs

**DOL + Order flow:**
- Short-term DOL = 1st candle low (if bullish)
- Long-term DOL = 1st candle high (if bullish)
- Vice versa for bearish

## Step 2: Build Narrative & Key Level

Two types of narratives:
1. **Price-based** — Market maker models, Power of 3, dealing ranges, OHLC, candle ranges
2. **Time-based** — Session behavior, intraday profiles, weekly profiles

Key levels to mark:
- Order Blocks (OB)
- Breaker Blocks (BB)
- Rejection Blocks (RB)
- Fair Value Gaps (FVG)
- Highs and Lows

## Step 3: Find CRT

For each CRT window, identify the 3 candles:

### 1AM CRT (London)
- CRT candles: 5PM, 9PM, 1AM
- 5PM + 9PM = CBDR & Asia Range (consolidation)
- 1AM = London session (manipulation + expansion)
- **Trade only expansion and reversal**

### 5AM CRT (London Lunch / NY Open)
- CRT candles: 5PM, 9PM, 1AM
- 5PM + 9PM = CBDR & Asia Range
- 1AM = London session

### 9AM CRT (NY Session) — HIGHEST PROBABILITY
- CRT candles: 9PM, 1AM, 5AM
- 9PM = Asia Range
- 1AM = London session
- 5AM = London lunch & NY opening
- **"If you just master the 9am CRT, it's enough to become profitable"**

## Step 4: Intraday Profile

### For 5AM CRT — 3 profiles:
1. **London lunch low of the day**
2. **NY continuation**
3. **NY reversal**

### For 9AM CRT — 2 profiles:
1. **NY continuation** — price continues in direction of London
2. **NY reversal** — price reverses from London direction

## Step 5: OHLC/OLHC of H4 CRT Candle

- **OHLC** = Open, High, Low, Close (bearish setup)
- **OLHC** = Open, Low, High, Close (bullish setup)
- Sell above opening price of CRT candle (OHLC)
- Buy below opening price of CRT candle (OLHC)

## Step 6: SMT (Smart Money Tool)

Compare correlated pairs (EURUSD vs GBPUSD):
- **London lunch with London** — SMT between EU and GU during London
- **London lunch with NY** — SMT between London and NY sessions
- **NY with London** — SMT between NY and London sessions
- Divergence = trade signal

## Step 7: Key Times

### For 5AM CRT:
- 6:00 AM - 7:00 AM (London lunch time)
- 7:00 AM - 8:30 AM (NY opening time)

### For 9AM CRT:
- Key time = 10:00 AM - 11:30 AM (NY session)

## Step 8: Entry

- Entry = Order Block on M5 timeframe
- Target = 1:2 or 1:3 R:R
- Stop = Protected swing

## 9AM H1 CRT Protocol

When bias is very clear, trade the 9AM H1 CRT:
1. Bias and DOL must be very clear
2. Identify key level: OB, FVG, Highs, Lows
3. Asia high/low and London high/low must be protected
4. Mark the 8AM CRH and CRL
5. Wait for confirmation
6. Confirmation = Market purges CRH/CRL, taps into key level, forms OB on M5

## Codability Assessment

- **Difficulty:** Medium (requires session timing + CRT logic)
- **Reliability:** Very high (9AM CRT is "enough to become profitable")
- **Time-based:** Yes (fixed session times)
- **CRT detection:** Can code H4 candle range tracking
- **DOL detection:** Previous day/week high/low
- **Recommendation:** A-Tier — highly mechanical, time-based

## Integration Notes

- Works on H4 timeframe (our primary)
- CRT candles = H4 candles at specific times
- DOL = previous day high/low
- Entry at key time after CRT confirmation
- Magic number needed: 9014 (CRT)
- Default DISABLED until backtest confirms

## References
- @Im-speculator — CRT & TS Guide, DOL Guide, 1AM/5AM/9AM CRT PDFs
- Maharani — Time Dilation Theory (TDT) MORPHEUS
- ICT/SMC methodology
- "If you just master the 9am CRT, it's enough to become profitable"
