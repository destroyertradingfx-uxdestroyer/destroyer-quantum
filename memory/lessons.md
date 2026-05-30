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

## 2026-05-27 — V28.06 TITAN Code Audit Reveals 6 Improvements Toward $170K
- Deep code analysis of V28.06 TITAN (14,522 lines) + GitHub research across 10+ repos
- Found 4 conflicting Kelly implementations (CalculateKellyFraction, GetKellyLotSize, GetLotSize_Ascension, CalculateRollingKelly) — only CalculateRollingKelly uses real data
- Found array buffer overflow bug: g_stratProfits[15][60] but 17 strategies exist (indices 15-16 overflow)
- Found DivergenceMR (magic 9004) is NOT actual divergence — just RSI < 35 / > 65 (oversold/overbought)
- Found equity curve trading patch exists but NOT integrated into MoneyManagement_Quantum() where V28+ strategies call
- Found SessionMomentum uses 16-hour H4 range (not session-specific), should use ATR-based ORB
- GitHub research: No MQL4 Hurst exponent or equity curve trading implementations found — DESTROYER is ahead of open-source
- Most valuable GitHub find: JamesORB ATR-based Opening Range Breakout (1.65x ATR stop, 2.5x ATR target)
- **Lesson:** When an EA has multiple versions (28+), dead code accumulates. Audit every function for actual usage before assuming it works. Name functions accurately — "DivergenceMR" that doesn't detect divergence is a trap.

---

## 2026-05-30 — Cycle 17: DD Headroom Is the Biggest Untapped Lever

**What happened:** V28.08 backtest shows $61K profit with only 17.2% DD — well below the 24% limit. This means 6.8% of DD capacity is unused, representing $25-40K in untapped profit.

**Why it happened:** Conservative risk parameters (5% per-trade, 8% portfolio) were set early when the system was unproven. Now that PF is 2.27 and DD is controlled, these limits are artificially capping returns.

**What to do differently:**
1. Always check DD utilization ratio (actual DD / max DD limit)
2. If DD utilization < 70%, increase risk parameters proportionally
3. Kelly blend should be 80/20 (not 60/40) when PF > 2.0
4. Dead strategies (0 trades) are a sign of over-filtering — relax thresholds incrementally

**Key insight:** The Ikarus EA (fraggli/Icarus) uses flexATR adaptive sizing — ATR-proportional grid spacing. This concept can improve our Reaper Protocol from fixed 1.4x LotMultiplier to volatility-adaptive sizing.

**GitHub sources studied:**
- fraggli/Icarus — Ikarus_4.73___flexATR.mq4 (169KB grid EA)
- EarnForex/Account-Protector — Emergency DD management patterns
- davejlin/trading — Partial close implementations

---

## 2026-05-30 — Code Quality: Partial Close Stub Is Empty

**What happened:** Lines 12048-12060 in V29_00 have a partial close framework but NO OrderClose() calls. The comment says "Partial close logic here" but the actual implementation is missing.

**Why it happened:** Likely was a placeholder during rapid development that never got filled in.

**What to do differently:** When writing stubs, at minimum include a TODO comment with the exact function signature and parameters needed. Empty stubs that look implemented are worse than no stubs at all.

**Fix:** Full OrderClosePartial() implementation written in V28_09_PUSH_TO_170K_PATCHES.mq4 (Patch 8).


