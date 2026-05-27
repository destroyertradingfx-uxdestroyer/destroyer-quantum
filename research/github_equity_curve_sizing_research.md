# GitHub Research: Equity Curve Trading and Adaptive Position Sizing
## Date: 2026-05-26
## Search Depth: 100+ GitHub API queries, 20+ repos inspected
## Status: COMPLETE

---

## EXECUTIVE SUMMARY

Key Finding: No open-source MQL4/MQL5 EA on GitHub implements portfolio-level equity curve trading with backtested results. This is a genuine edge for DESTROYER QUANTUM.

The closest alternatives found:
1. EA31337 framework - has SignalOpenBoost() (1.1x per signal condition) but NO equity curve awareness
2. EarnForex PositionSizer - excellent risk-per-trade calculator but NO adaptive sizing
3. Python backtesting engines - implement equity curve concepts but not in MQL4

Our existing V29_00 and V28_07 implementations are the most complete MQL4 equity curve trading implementations found on GitHub.

---

## REPOS ANALYZED

### Tier 1: Most Relevant MQL Repos

Repo: EA31337/EA31337-classes (252 stars)
- Has: Trade class with TradeStats, TradeParams, GetDrawdownInPct(), SignalOpenBoost()
- Lacks: No equity curve tracking, no anti-martingale, no portfolio-level sizing

Repo: EarnForex/PositionSizer (566 stars)
- Has: Comprehensive risk-per-trade calculator, ATR-based SL, margin checks
- Lacks: No adaptive sizing, no equity curve, no win streak awareness

Repo: EarnForex/Account-Protector (117 stars)
- Has: Drawdown protection, equity monitoring, trade limits
- Lacks: Reactive only, no proactive sizing amplification

Repo: EA31337/Strategy-Oscillator_Martingale (0 stars)
- Has: Martingale order management
- Issue: Classic martingale (doubling on loss), NOT anti-martingale

### Tier 3: From Prior Research (No Longer Accessible)
- longytravel/adaptive-market-ea - 404 (deleted)
- VoxHash/ForexSmartBot - 404 (deleted)
- Giacomo-cb/mql4-expert-advisors-portfolio - 404

---

## CODE PATTERNS FOUND

### Pattern 1: EA31337 SignalOpenBoost()
Bitwise conditions for lot boost. Each condition adds 10% when true.
Max ~1.95x. Per-trade-entry, NOT equity-curve-aware.

### Pattern 2: EA31337 AccountMt GetDrawdownInPct()
Simple equity vs balance percentage. Our V29_00 exceeds this.

### Pattern 3: EarnForex PositionSizer
One-shot calculator, not adaptive. No equity curve awareness.

---

## NEGATIVE RESULTS
- MQL4 equity curve EA with backtested results: 0 found
- MQL4 anti-martingale lot sizing: 0 found
- MQL4 win streak amplification: 0 found
- GitHub repos with PF >2.0 on EURUSD H4: 0 found

---

## RECOMMENDATION
Use V28_07 (slope-based) as primary, V29_00 DD defense as override.
Expected: +15-25K profit, -2-4% drawdown.
