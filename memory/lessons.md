# Lessons Learned

_(This file accumulates over time. Never delete entries. Only append.)_

---

## 2026-05-13 — Strategy Contamination
- Adding random strategies (Volatility Expansion, Momentum Breakout, Statistical Reversion) degraded Phantom's PF from 1.60 to 1.36
- Bad strategies don't just fail to contribute — they actively harm good strategies by consuming equity and triggering circuit breakers
- **Lesson:** Never add a strategy without proving positive expected value via backtest first

## 2026-05-13 — Dead Event Shield
- Event Shield function only had 2026 dates. For 2020-2025 backtest, it was completely dead.
- Caused ~$5K-$7K in preventable losses around FOMC/ECB/NFP/CPI events
- **Lesson:** Always validate that protective systems cover the ENTIRE backtest period, not just current year

## 2026-05-14 — Daily Loss Caps Are Too Blunt
- V27.14: $500 daily cap → profit crashed to $8,972 (blocked 190 trades)
- V27.16: $1,000 daily cap → blocked 109 trades, profit $22,791
- V27.18: Removed daily cap entirely → profit $29,632
- **Lesson:** Per-strategy adaptive sizing is surgical. Daily caps are amputation.

## 2026-05-14 — Nexus Selectivity
- Nexus: 4 trades in 6 years, PF 4.31-4.38
- V27.12 tried loosening parameters to get more trades
- Analysis confirmed: Nexus's edge DEPENDS on tight parameters
- **Lesson:** Rare-but-deadly is a feature, not a bug. Never loosen elite strategy parameters.

## 2026-05-15 — Untested Versions Are Dead Code
- V27.19 through V27.22: built in one day, none backtested
- Each new idea superseded the previous one before it could be tested
- **Lesson:** Never create a version and move on. Backtest first, then build the next one.

## 2026-05-15 — Parameter Tweaking Is Not Engineering
- V27.8a/b/c: Three parameter iterations, profit dropped $7K from V27.6
- Adjusting numbers without understanding root cause produces 22 versions that don't work
- **Lesson:** If the proposed change is "adjust this number," stop. Research the root cause first.

## 2026-05-26 — Non-ASCII Characters Break MQL4 Compilation
- Every .mq4 file in the repo had ~2000+ non-ASCII characters
- Emoji (🚀🎯📊), Unicode arrows (→), special math chars (±≥≤√), box drawing (─═)
- MQL4 compiler REJECTS these files — none would compile
- Root cause: research notes and changelog comments were written with Unicode
- Fix: `re.sub(r'[^\x00-\x7F]', '', content)` — strip ALL non-ASCII
- Also replace before writing: → becomes ->, ≥ becomes >=, ± becomes +/-
- **Lesson:** ALWAYS sanitize .mq4 files before delivery. Run non-ASCII check on every version.
- Verified: brace balance = 0 on all 27 files after sanitization

## 2026-05-26 — Correlation Trading Is NOT Viable for DESTROYER
- Searched 6 repos implementing EURUSD/GBPUSD correlation/pairs trading
- Best documented result: Sharpe 0.47 (3.6% annual profit) — author says "minimal edge"
- No MQL4 EA with PF >2.0 on correlation strategies
- EURUSD/GBPUSD correlation 0.85-0.95 on H4 — too stable for mean reversion
- When correlation breaks (Brexit, ECB divergence), it's fundamental — not revertible
- **Lesson:** Use correlation only as a RISK FILTER (reduce exposure when correlation breaks), not as an edge source
