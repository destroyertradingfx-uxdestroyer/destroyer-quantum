# Gartley Harmonic Pattern Strategy

**Source:** YouTube interview with professional trader (Azarel Cobos call)
**Origin:** H.M. Gartley "Profits in the Stock Market" (1935)
**Type:** Harmonic / Fibonacci reversal pattern
**Timeframes:** H4 detection, can be used on any timeframe

## Pattern Structure

The Gartley is a 5-point reversal pattern (X-A-B-C-D):

```
Bullish Gartley:          Bearish Gartley:
       A                         X
      / \                       / \
     /   \                     /   \
    X     C                   A     C
     \   / \                   \   /
      \ /   \                   \ /   \
       B     D (BUY)             B     D (SELL)
```

## Fibonacci Ratios

| Leg | Ratio | Tolerance |
|-----|-------|-----------|
| X-A | Initial impulse | - |
| A-B | 61.8% retracement of X-A | +-8% |
| B-C | 38.2% to 88.6% retracement of A-B | +-5% |
| C-D | 78.6% retracement of X-A | +-10% |

## Entry Rules

**Bullish:**
- Entry at D (78.6% retracement of X-A, near recent low)
- Stop loss below X (with 5% buffer)
- Take profit at 61.8% retracement of C-D

**Bearish:**
- Entry at D (78.6% retracement of X-A, near recent high)
- Stop loss above X (with 5% buffer)
- Take profit at 61.8% retracement of C-D

## Edge Quality

- **Win rate:** ~60-65% (when pattern is valid)
- **R:R ratio:** 1:1.5 to 1:2
- **Frequency:** 2-4 patterns per month on H4 EURUSD
- **Best in:** Ranging markets, after clear impulse moves

## Codability Assessment

- **Difficulty:** Medium-High (requires ZigZag swing detection)
- **Reliability:** High when Fibonacci ratios match
- **Risk:** False patterns in trending markets
- **Recommendation:** Use as confirmation filter, not standalone

## Integration Notes

- Magic numbers: 9008 (bullish), 9009 (bearish)
- Needs ZigZag-like swing detection (implemented)
- Works best when combined with existing support/resistance
- Default DISABLED - enable after backtest validation

## References

- H.M. Gartley "Profits in the Stock Market" (1935)
- Scott Carney "Harmonic Trading" (modern interpretation)
- djoffrey/HarmonicPatterns GitHub (Python reference implementation)
