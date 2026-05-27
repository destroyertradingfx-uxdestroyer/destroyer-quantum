# Time-Based Manipulation Strategy

**Source:** YouTube — Umar Arpanjabi (6+ years trading, live documented)
**Pair:** EURUSD (best results), works on gold with lower accuracy
**Type:** Session-based manipulation / liquidity sweep + BOS entry
**Timeframes:** H4 bias, 5min entry
**Frequency:** ~2 trades per week
**R:R:** 1:2 minimum

## The 4 Steps

### Step 1: Wait for Asia Session Close
- Mark Asia session high and low
- Use FXN Asian Session Range indicator (by Rob Minty)
- Asia closes at 9 AM Dubai time (adjust for your timezone)

### Step 2: Determine H4 Bias
- Look at H4 market structure
- **Bullish:** Higher highs, higher lows → look for LONGS
- **Bearish:** Lower highs, lower lows → look for SHORTS
- Simple structure analysis — no indicators needed

### Step 3: Wait for Liquidity Sweep
- **If bearish bias:** Wait for price to sweep (take out) Asia HIGH
- **If bullish bias:** Wait for price to sweep (take out) Asia LOW
- This is the "manipulation" phase — price grabs liquidity before reversing
- **NO TRADE if no sweep happens** — skip the day

### Step 4: Wait for Break of Structure (BOS) → Enter
- **If bearish:** After Asia high sweep, wait for bearish BOS on 5min → SHORT
- **If bullish:** After Asia low sweep, wait for bullish BOS on 5min → LONG
- Entry is on the BOS candle (impulse entry)
- Stop loss above/below the sweep high/low
- Target: 1:2 R:R (or Asia low/high as target)

## Entry Rules (Bullish Example)
1. H4 = bullish (higher highs/lows)
2. Asia session closes — mark high and low
3. Price sweeps Asia LOW (takes out the low)
4. Wait for bullish BOS on 5min (break above recent swing high)
5. ENTER LONG on BOS candle
6. SL = below the sweep low
7. TP = 1:2 R:R or Asia high

## Entry Rules (Bearish Example)
1. H4 = bearish (lower highs/lows)
2. Asia session closes — mark high and low
3. Price sweeps Asia HIGH (takes out the high)
4. Wait for bearish BOS on 5min (break below recent swing low)
5. ENTER SHORT on BOS candle
6. SL = above the sweep high
7. TP = 1:2 R:R or Asia low

## Key Rules
- **NO TRADE if no sweep** — must sweep Asia high/low before entry
- **Trade with H4 bias only** — never trade against the trend
- **Time limit:** Trade should trigger within 1 hour of London open. If not, skip.
- **Exit by 1 PM Dubai time** — don't hold beyond this
- **Partial profits:** Book 50% at 1:1, let rest run to 1:2

## Edge Quality
- **Win rate:** ~60-65% (based on trader's live documentation)
- **Frequency:** ~2 trades per week
- **R:R:** 1:2 minimum
- **Best for:** Prop firms (EURUSD = 1:100 leverage)
- **Drawdown:** Normal to have 2 consecutive stop losses

## Codability Assessment
- **Difficulty:** EASY — all rules are quantifiable
- **H4 bias:** Can use EMA or structure detection
- **Asia session:** Time-based, easy to code
- **Sweep detection:** Check if price took out Asia high/low
- **BOS detection:** Break of recent swing high/low on entry timeframe
- **Recommendation:** A-Tier — should be added to EA

## Integration Notes
- Works on H4 timeframe (our primary)
- Can adapt: use H4 candle for bias, detect Asia range from session times
- Entry on H4 after sweep + BOS (instead of 5min)
- Magic number needed: 9010
- Default DISABLED until backtest confirms

## References
- FXN Asian Session Range indicator (MT4)
- Umar Arpanjabi — live documented profitability
- "Way On" YouTube channel
