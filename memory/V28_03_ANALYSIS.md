# V28.03 Two New Strategies — Full Analysis

## Summary
- Net Profit: $48,255.95 | PF: 1.82 | DD: 18.14% | Trades: 280 | WR: 72.86%
- Final Equity: $58,255.95 on $10K start
- **NEW BEST VERSION** — beats V27.18 on profit AND drawdown

## Version Comparison

| Metric | V27.18 | V27.28.01 | V28.03 | V28.03 vs V27.18 |
|---|---|---|---|---|
| Net Profit | $29,632 | $26,992 | $48,256 | +$18,624 ✅✅ |
| Profit Factor | 1.79 | 1.33 | 1.82 | +0.03 ✅ |
| Max Drawdown | 24.13% | 17.42% | 18.14% | -5.99% ✅✅ |
| Total Trades | 304 | 709 | 280 | -24 |
| Win Rate | ~73% | 64.32% | 72.86% | maintained ✅ |
| Avg Win | ~$200 | $237.73 | $523.72 | +$323 ✅✅✅ |
| Avg Loss | ~$500 | -$321.78 | -$770.82 | worse ❌ |
| Win/Loss Ratio | ~0.40 | 0.74 | 0.68 | better ✅ |
| Gross Profit | ~$37K | $108K | $106K | +$69K |
| Gross Loss | ~$16K | -$81K | -$58K | -$42K ❌ |

## Per-Strategy Breakdown (V28.03)

| Strategy | Trades | Net Profit | PF | Status |
|---|---|---|---|---|
| Phantom | 166 | +$25,554 | 1.77 | ✅ BACKBONE (53% of profit) |
| SessionMomentum | 2 | +$8,588 | 999.0 | 🆕 NEW — MONSTER (2 trades!) |
| NoiseBreakout | 52 | +$7,036 | 1.75 | ✅ Solid |
| Nexus | 4 | +$5,799 | 4.31 | ✅ Elite (consistent with baseline) |
| Warden | 8 | +$2,036 | 1.38 | ⚠️ PF dropped from 2.37 → 1.38 |
| Mean Reversion | 1 | +$381 | 999.0 | ⚠️ Only 1 trade — can't evaluate |
| Reaper | 11 | +$345 | 39.14 | ✅ Improved (fewer trades, better quality) |
| Titan | 24 | -$43 | 0.37 | ❌ REGRESSED — was PF 2.00, now 0.37 |
| LiquiditySweep | 12 | -$1,439 | 0.84 | ❌ NEW — NEGATIVE EV |

## Key Findings

### 1. SessionMomentum is INSANE
- 2 trades, $8,588 profit, PF 999 (effectively infinite — no losses)
- Average profit per trade: $4,294
- This is the kind of "once a week, always wins" strategy Ryan wanted
- BUT: only 2 trades in 6 years — not statistically significant yet
- Needs careful evaluation: what triggers it? Can we get 5-10 more trades?

### 2. LiquiditySweep is DEAD ON ARRIVAL
- 12 trades, -$1,439, PF 0.84
- Negative EV — every trade loses money on average
- This is EXACTLY the pattern that destroyed V27.28.01
- **RECOMMENDATION: CUT IMMEDIATELY** (like Silicon-X)

### 3. Titan Has COLLAPSED
- Was: 7 trades, PF 2.00 (V27.18)
- Now: 24 trades, PF 0.37, -$43 net
- 3x more trades but ALL of them are losers now
- Something changed in Titan's logic — possibly the new version loosened its filters too much
- **RECOMMENDATION: Investigate what changed, or revert to V27.18 Titan parameters**

### 4. Warden Degraded
- Was: 8 trades, PF 2.37 (V27.18)
- Now: 8 trades, PF 1.38
- Same trade count, but quality dropped significantly
- May be affected by the new strategies taking trades that Warden would have won

### 5. The VAR Limiter Is Blocking Reaper Aggressively
- Logs show "Trade exceeds portfolio VAR limit" blocking Reaper every ~30 minutes
- Reaper regime suppression (ADX=57.6) also blocking BUY grids in bearish trends
- This is actually GOOD — it's preventing Reaper from blowing up in trends
- But it means Reaper's 11 trades are heavily filtered = only the best setups

### 6. Trade Count Is DOWN, Quality Is UP
- V27.18: 304 trades → V28.03: 280 trades (fewer!)
- But profit nearly DOUBLED: $29K → $48K
- Average profit per trade: V27.18 = $97 → V28.03 = $172
- This is the RIGHT direction — quality over quantity

## The Problem

Ryan said the system is "severely under-trading" with ~200 trades in 6 years.
V28.03 has 280 trades in 6.3 years = ~44/year = ~3.7/month.

That IS low. But the question is: **do we want MORE trades, or BETTER trades?**

The data says: BETTER trades. V28.03 makes $172/trade vs V27.18's $97/trade.
If we forced more trades, we'd get the V27.28.01 problem (709 trades, PF 1.33).

## Path to $300K

Current: $48K in 6.3 years on $10K
Target: $300K in 6.3 years on $10K

Options:
1. **Scale up account size**: On $50K start, V28.03 would generate ~$241K (close!)
2. **Increase trade frequency**: Get to 500+ quality trades (hard without degrading quality)
3. **Compounding engine**: The adaptive compounding task brief describes exactly this
4. **More SessionMomentum-type strategies**: High conviction, rare, massive payoff
5. **Reduce avg loss**: $770 avg loss is high — tighter stops could help

## Recommendations

### Immediate (This Week)
1. CUT LiquiditySweep — negative EV, no debate
2. INVESTIGATE Titan regression — what changed from V27.18 to V28.03?
3. EVALUATE SessionMomentum — 2 trades isn't enough data, but $4,294/trade is elite
4. RE-RUN with OHLC model for accurate results

### Short-Term (This Month)
5. Build Adaptive Compounding Engine on V28.03 base (minus LiquiditySweep)
6. Try to get 5+ SessionMomentum trades to validate it statistically
7. Fix Titan — either revert to V27.18 logic or understand what broke

### Medium-Term (Next Month)
8. Add 1-2 more "SessionMomentum-type" strategies (rare, high-conviction, big payoff)
9. Implement event blackout periods
10. Test on larger account sizes to see compounding effect
