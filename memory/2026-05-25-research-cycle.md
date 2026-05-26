# Session Log — 2026-05-25 (Research Cycle)

## What Was Done

### 1. GitHub Research (50+ repos analyzed)
- Searched for MQL4 equity curve, anti-martingale, correlation, session breakout strategies
- **Finding:** No open-source EA with verified PF >2.0 on EURUSD H4 exists
- Best patterns extracted from: adaptive-market-ea (equity curve sizing), ForexSmartBot (composite sizing), Giacomo-cb (Asian breakout)

### 2. Critical Discovery: Version Divergence
- **V28.07 RESURRECTION** (latest commit) has equity curve + regime detection + volatility targeting + ML filter
- **V28.06 TITAN** (prior version) has Kelly amplification + session expansion + Nexus relaxation + Queen unlocked
- **Neither version is complete.** Need to merge.
- V28.07 has Silicon-X ENABLED (confirmed net negative) and Queen at 2.0 (starves Reaper)

### 3. Implementation Guides Created
- `research/github_equity_curve_research.md` — Consolidated findings, all repos, code patterns
- `research/implementation_guide_170k.md` — Exact 10-step checklist for Asian Breakout + Equity Curve
- `research/VERSION_DIVERGENCE_ANALYSIS.md` — The merge plan with expected impact

### 4. Expected Impact of Full Merge
- TITAN base: $109K-$138K
- + Equity curve: +$15K-$25K
- + Regime detection: +$5K-$10K
- + Vol targeting: +$5K-$10K
- + ML filter: +$3K-$5K
- + Asian Breakout: +$10K-$20K
- **Total: $147K-$208K (midpoint ~$178K)** — exceeds $170K target

## Files Pushed to GitHub
- 0bec9a1: RESEARCH: Equity curve + Asian Breakout implementation + Version divergence analysis

## Next Steps (For Ryan)
1. Decide: merge TITAN improvements into V28.07, or merge V28.07 features into TITAN
2. I implement the merge
3. Ryan backtests
4. Add Asian Breakout if still below $170K
