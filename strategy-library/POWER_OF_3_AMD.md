# 4-Hour Power of 3 (AMD) Strategy

**Source:** YouTube — ICT/SMC concept (Power of 3 / AMD)
**Pair:** EURUSD, Gold, NQ, any instrument
**Type:** Intraday candle structure / AMD model
**Timeframes:** Daily bias → 4H candle → 15min/5min entries
**Frequency:** 1-3 trades per day
**R:R:** 1:2 to 1:3

## Core Concept: Power of 3 / AMD

Every 4-hour candle has 3 phases:
1. **Accumulation** — Candle 1: consolidation range
2. **Manipulation** — Candle 2: opposing run (wick) that grabs liquidity
3. **Distribution** — Candle 3: the real move (expansion)

**The Goal:** Trade the distribution candle (Candle 3) or the expansion within Candle 2.

## Two Scenarios

### Scenario 1: Continuation Expansion (Candle 3)
- Candle 1 = Accumulation (consolidation)
- Candle 2 = Large opposing run (big wick) → does NOT support expansion
- Candle 3 = Wait for shallow wick → trade the expansion

### Scenario 2: Reversal Expansion (Candle 2)
- Candle 1 = Accumulation (consolidation)
- Candle 2 = Shallow wick → supports expansion within same candle
- Trade the expansion within Candle 2

## Key Rule
**"Let the wick form, then trade the body."**
- Never try to catch the wick
- Wait for the wick to form (protected swing / CISD)
- Then trade the continuation (the body)

## Time-Based Structure (Forex)

Each 4-hour candle opens at specific times:
- **2:00 AM** — London pre-session
- **6:00 AM** — London session
- **10:00 AM** — London/NY overlap
- **2:00 PM** — NY session

**Pattern:** 6 AM reversal → 10 AM continuation (most common)

## Entry Rules

### Step 1: Daily Bias
- Look at daily candle structure
- Identify if we're looking for longs or shorts
- Previous day high/low = target

### Step 2: 4-Hour Candle Analysis
- Identify which 4H candle we're in
- Look at previous 4H candle for reversal/continuation
- Determine if we're in Scenario 1 or Scenario 2

### Step 3: Lower Timeframe Entry (15min/5min/3min)
- Wait for wick to form (protected swing)
- Look for Change in State of Delivery (CISD)
- Entry on CISD confirmation
- Stop loss on protected swing or above 50% of CISD

### Step 4: Target
- Previous day high/low
- 2R minimum
- -1 standard deviation (for large opposing runs)

## Entry Types

### Type A: Position Entry (High Confidence)
- Enter at open of new 4H candle
- Stop on protected swing
- Target: 2R
- Use when: Strong reversal + shallow wick expected

### Type B: Continuation Entry
- Wait for protected swing to form
- Enter on CISD confirmation
- Stop on protected swing
- Target: 2R or previous day high/low
- Use when: Need more confirmation

### Type C: Fractal Model Entry
- Use 5min/3min fractal model within 4H candle
- Wait for consolidation → manipulation → expansion
- Entry on fractal model confirmation
- Tightest stop, highest R:R

## Codability Assessment

- **Difficulty:** Medium (requires multi-timeframe analysis)
- **Reliability:** High when daily bias aligns with 4H structure
- **Time-based:** Very codable — 4H candle times are fixed
- **Wick detection:** Can measure wick-to-body ratio
- **CISD detection:** Can detect break of protected swing
- **Recommendation:** A-Tier — highly mechanical, great for automation

## Integration Notes

- Works on H4 timeframe (our primary)
- Daily bias can use EMA or structure detection
- 4H candle analysis: measure wick size, detect AMD phases
- Entry on H4 candle open or after CISD on lower timeframe
- Magic number needed: 9011
- Default DISABLED until backtest confirms

## Key Times (Forex Server Time)
- 02:00 — Candle 1 open (London pre)
- 06:00 — Candle 2 open (London)
- 10:00 — Candle 3 open (London/NY overlap)
- 14:00 — Candle 4 open (NY)
- 18:00 — Candle 5 open (NY close)
- 22:00 — Candle 6 open (Asian)

## References
- ICT (Inner Circle Trader) — Power of 3 concept
- AMD model (Accumulation, Manipulation, Distribution)
- "Let the wick form, then trade the body"
