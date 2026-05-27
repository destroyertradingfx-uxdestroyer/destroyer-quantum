# Fractal Model Strategy

**Source:** YouTube — ICT/SMC concept (Fractal Model / Multi-Timeframe Alignment)
**Pair:** EURUSD, Gold, Oil, any instrument
**Type:** Multi-timeframe fractal alignment / swing point + CISD + continuation
**Timeframes:** Daily bias → H1 structure → M5 entry (fractal pairing)
**Frequency:** 1-2 trades per day
**R:R:** 1:2 to 1:3+

## Core Concept

**"Price cannot reverse without a swing point."**
- If price goes bearish → bullish, it forms a bullish swing point
- If price goes bullish → bearish, it forms a bearish swing point
- Look for swing points at points of interest (FVG, OB)
- When all timeframes align → expansion occurs

## Timeframe Pairing (Fractal)

| Structure TF | Entry TF |
|---|---|
| Monthly | Daily |
| Daily | H1 |
| H4 | M15/M5 |
| H1 | M5 |
| M30 | M3 |

## The 5 Steps

### Step 1: Daily Bias
- **Continuation:** Previous day close outside range (above high = bullish, below low = bearish)
- **Reversal:** Price sweeps previous day low/high and closes back inside (sweep + close back = reversal bias)
- This determines direction for the day

### Step 2: Structure Timeframe (H1/H4)
- Look for point of interest in the previous day's range
- **Bullish:** Fair Value Gap near a low, or bullish order block
- **Bearish:** Fair Value Gap near a high, or bearish order block
- Wait for price to reach this zone

### Step 3: Candle 2 or Candle 3 Closure at POI
- **Candle 2 closure:** Price reaches POI and closes with reversal candle (wick + close back)
- **Candle 3 closure:** Price sweeps level and closes back (more aggressive)
- This is the "wick forming" phase

### Step 4: Lower Timeframe Entry (M5/M15)
- Drop to entry timeframe using fractal pairing
- Wait for **Change in State of Delivery (CISD)** — confirms swing point
- Then wait for **Continuation Order Block** — close through series of opposing candles
- Entry on continuation OB close or retest
- Stop loss on protected swing (body of candle, not wick)

### Step 5: Target
- 2R minimum
- Previous day high/low
- Daily Fair Value Gap
- Can refine further for higher R:R

## Entry Types

### Type A: Wick Entry (Aggressive)
- Enter on Candle 2/Candle 3 closure at POI
- Stop on protected swing
- Target: 2R
- Higher risk, earlier entry

### Type B: Continuation Entry (Conservative)
- Wait for CISD on lower timeframe
- Wait for continuation order block
- Enter on OB close or retest
- Stop on protected swing
- Target: 2R or previous day level
- Lower risk, more confirmation

### Type C: Fractal Refinement Entry (Advanced)
- Use all timeframe pairs (Monthly→Daily→H1→M5)
- Enter on lowest timeframe after all confirmations
- Tightest stop, highest R:R
- Most complex

## Key Rules

1. **Daily bias FIRST** — no bias, no trade
2. **Point of Interest required** — FVG or OB at the right location
3. **Candle closure required** — never enter on wick alone
4. **CISD confirms swing** — don't enter until CISD forms
5. **Continuation OB for entry** — close through series of opposing candles
6. **Stop on protected swing** — body high/low, not wick
7. **Target higher TF levels** — previous day high/low, daily FVG
8. **No continuation = range** — avoid until one side breaks

## When NOT to Trade

- No clear daily bias
- Price in consolidation (no swing point formed)
- Multiple failed continuations = range
- Price too close to opposite side of range
- Don't force trades on messy structure

## Codability Assessment

- **Difficulty:** Medium-Hard (multi-timeframe logic)
- **Reliability:** Very high when all timeframes align
- **Time-based:** Yes (daily bias uses previous day close)
- **Swing point detection:** Can code using ZigZag or structure detection
- **CISD detection:** Break of protected swing
- **Continuation OB:** Close through series of opposing candles
- **Recommendation:** A-Tier — best system for DESTROYER QUANTUM

## Integration Notes

- Works on H4 timeframe (our primary)
- Daily bias: use previous day close vs high/low
- Structure: H4 swing points + FVG detection
- Entry: H4 continuation OB or CISD
- Stop: protected swing (body, not wick)
- Target: previous day high/low or 2R
- Magic number needed: 9012
- Default DISABLED until backtest confirms

## References
- ICT (Inner Circle Trader) — Fractal Model
- "Price cannot reverse without a swing point"
- Multi-timeframe alignment concept
- Continuation Order Block entry
