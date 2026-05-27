# A+ Strategy (FVG Breakout)

**Source:** YouTube — 9-year trader, 81% win rate, $15K/month
**Pair:** Any (futures, stocks, crypto, forex)
**Type:** Range breakout + Fair Value Gap entry
**Timeframes:** 15min range, 5min entry (adapted to H4 for DQ)
**Frequency:** 1 trade per day
**R:R:** Fixed 1:2

## The 3 Steps (Original)

### Step 1: Mark the Range
- 15min chart
- Mark HIGH and LOW of first 15-min candle (9:30-9:45 AM EST)
- This is your trading range for the day

### Step 2: Wait for Break with FVG
- 5min chart
- Wait for price to break OUT of the range
- **CRITICAL:** Must have a Fair Value Gap (FVG) at the break
- No FVG = NO TRADE (even on big candles)
- FVG = gap between candle 1's high and candle 3's low (bullish) or candle 3's high and candle 1's low (bearish)

### Step 3: Limit Order on FVG
- Place LIMIT ORDER at the FVG zone
- Stop Loss at candle 1 base (NOT the gap candle)
- Target: Fixed 1:2 R:R
- Sit back and let it work

## Key Rules
- **No FVG = No Trade** — the FVG is the filter that keeps win rate high
- **Time cutoff:** FVG must form before 12 PM EST (no late entries)
- **Direction:** Break above range + FVG = LONG. Break below range + FVG = SHORT.
- **Stop placement:** At candle 1 base of the 3-candle FVG pattern
- **Target:** Fixed 2:1 R:R (drag position tool)

## Choppy Day Types (How to Avoid)

### Type 1: "Mix Up"
- Price hits both sides of the range
- Wicks everywhere, no clean FVG
- **Solution:** No FVG = no trade. Wait it out.

### Type 2: "Steady"
- Price slowly grinds in one direction
- No FVG forms, just steady movement
- **Solution:** Wait for FVG. Don't chase.

## Adaptation for DESTROYER QUANTUM (H4)

Since we trade H4, adapt the concept:

### H4 Adaptation
1. **Range:** Use previous day's high/low (or Asian session range)
2. **Break:** Wait for H4 candle to close outside the range
3. **FVG:** Must have FVG on the break candle
4. **Entry:** Limit order at FVG zone
5. **Stop:** At candle 1 base of FVG pattern
6. **Target:** Fixed 1:2 R:R

### Why This Works on H4
- Previous day range = reliable reference
- H4 FVG = stronger signal than 5min FVG
- Fewer trades = less noise
- Same concept, higher timeframe

## Backtest Results (Original - 5min)
- 16 trades in 1 month
- 81% win rate (13 wins, 3 losses)
- $15,455 net profit
- $1,635 max drawdown
- Works on prop firms

## Codability Assessment
- **Difficulty:** EASY — very mechanical
- **Reliability:** High (FVG filter removes noise)
- **Time-based:** Range = previous day high/low
- **FVG detection:** Already coded in Fractal Model
- **Recommendation:** A-Tier — should be added to EA

## Integration Notes
- Works on H4 timeframe (our primary)
- Range: previous day high/low
- FVG detection: reuse from Fractal Model
- Entry: limit order at FVG
- Stop: candle 1 base
- Target: fixed 1:2 R:R
- Magic number needed: 9013
- Default DISABLED until backtest confirms

## References
- "A+ Strategy" — 9-year trader
- 81% win rate, $15K/month
- Fair Value Gap as entry filter
- "No FVG = No Trade"
