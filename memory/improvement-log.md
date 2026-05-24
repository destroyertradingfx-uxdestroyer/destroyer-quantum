# Improvement Log — DESTROYER QUANTUM

*Every time the agent learns something new or improves its approach.*
*Format: Date | What was learned | How it changes future behavior | Confidence*

---

## 2026-05-13 — Strategy Contamination Principle

**What was learned:**
Adding random strategies (Volatility Expansion, Momentum Breakout, Statistical
Reversion) degraded Phantom's PF from 1.60 to 1.36. Bad strategies don't just
fail to contribute — they actively harm good strategies by consuming equity and
triggering circuit breakers.

**How it changes future behavior:**
Never add a strategy without proving positive expected value via backtest first.
"It looks good on paper" is not enough. Backtest or don't add it.

**Confidence:** 95%

---

## 2026-05-13 — Dead Event Shield

**What was learned:**
Event Shield function only had 2026 dates. For 2020-2025 backtest, it was
completely dead. Caused ~$5K-$7K in preventable losses around FOMC/ECB/NFP/CPI.

**How it changes future behavior:**
Always validate that protective systems cover the ENTIRE backtest period, not
just current year. Check date ranges before deploying any time-based filter.

**Confidence:** 100%

---

## 2026-05-14 — Daily Loss Caps Are Amputation

**What was learned:**
- V27.14: $500 daily cap → profit crashed to $8,972 (blocked 190 trades)
- V27.16: $1,000 daily cap → blocked 109 trades, profit $22,791
- V27.18: Removed daily cap entirely → profit $29,632

**How it changes future behavior:**
Per-strategy adaptive sizing is surgical. Daily caps are amputation. Never
propose a daily loss cap again. Use per-strategy risk unwind instead.

**Confidence:** 100%

---

## 2026-05-14 — Nexus Selectivity Is a Feature

**What was learned:**
Nexus: 4 trades in 6 years, PF 4.31-4.38. V27.12 tried loosening parameters
to get more trades. Analysis confirmed: Nexus's edge DEPENDS on tight parameters.

**How it changes future behavior:**
Rare-but-deadly is a feature, not a bug. Never loosen elite strategy parameters.
If a strategy has high PF with few trades, that's exactly what you want.

**Confidence:** 100%

---

## 2026-05-15 — Untested Versions Are Dead Code

**What was learned:**
V27.19 through V27.22: built in one day, none backtested. Each new idea
superseded the previous one before it could be tested. Four versions, zero data.

**How it changes future behavior:**
Never create a version and move on. Backtest first, then build the next one.
If you build it, you backtest it. "I'll test it later" means you are taking
the easy way out.

**Confidence:** 100%

---

## 2026-05-15 — Parameter Tweaking Is Not Engineering

**What was learned:**
V27.8a/b/c: Three parameter iterations, profit dropped $7K from V27.6.
Adjusting numbers without understanding root cause produces 22 versions that
don't work.

**How it changes future behavior:**
If the proposed change is "adjust this number," stop. Research the root cause
first. Think harder. Find the structural problem, not the surface symptom.

**Confidence:** 100%

---

## 2026-05-22 — Triple Index Mapping Is Fatal

**What was learned:**
V28.09 catastrophe: three mapping functions (GetStrategyIndexByMagic,
GetStrategyIndex, and switch statements) had DIFFERENT index assignments.
Reaper→0 (should be 4), Phantom→5 (should be 9), Nexus→7 (should be 10).
MoneyManagement_Quantum pulled Kelly/heat from WRONG strategies.

**How it changes future behavior:**
NEVER have multiple index mapping functions with different assignments. Use a
single canonical mapping function. If you must have multiple, they must all
reference the same source of truth. Audit all mapping functions before shipping.

**Confidence:** 100%

---

## 2026-05-22 — Always Add New Magic Numbers

**What was learned:**
V28.09: Sentinel (magic 777015) was not in IsOurMagicNumber(). 197 trades
were invisible to the risk management system.

**How it changes future behavior:**
When adding ANY new strategy, immediately add its magic number to:
1. IsOurMagicNumber()
2. GetStrategyIndexByMagic()
3. All switch statements and arrays
4. Check array sizes match [N] declarations

**Confidence:** 100%

---

## 2026-05-22 — Expand Winners, Don't Fix Losers

**What was learned:**
V28.08 tried to fix/regress strategies that were working in V28.06. Result:
profit dropped. The correct approach is to expand what's working (SessionMomentum
at $4,294/trade, Nexus at PF 4.31) rather than fixing what's marginal.

**How it changes future behavior:**
When a version regresses, don't try to fix the regression. Revert to the last
good version and build from there. Focus effort on amplifying winners.

**Confidence:** 90%

---

## 2026-05-22 — Quality Over Quantity

**What was learned:**
V28.03: 280 trades at $172/trade. V27.18: 304 trades at $97/trade.
V28.03 made nearly DOUBLE the profit with FEWER trades. V27.28.01: 709 trades
at $38/trade — more trades, much worse results.

**How it changes future behavior:**
Don't optimize for trade count. Optimize for per-trade profit. High-frequency
trading with mediocre quality destroys value. The $300K path is better trades,
not more trades.

**Confidence:** 90%

---

## 2026-05-24 — Debate Layer Architecture

**What was learned:**
TradingAgents (79K ★) uses debate before execution. In MQL4, we can implement
this as: Signal Collection → Weighted Debate → Risk Panel → Execution.
Strategies vote, weights based on rolling PF, 3 risk analysts must reach consensus.

**How it changes future behavior:**
Future strategy additions should be "debate-native" — output signals with
conviction scores rather than calling OrderSend() directly. The debate layer
is the new execution gateway.

**Confidence:** 70% (untested — design looks sound, needs backtest validation)

---

## 2026-05-24 — V28.06 Profit-to-Drawdown Ratio

**What was learned:**
V28.06 has a Profit-to-Drawdown ratio of 2.59x ($50,399 / 19.40%). This is
the best in project history. This metric matters more than raw profit for
real-world deployment — it tells you how much pain you endure per dollar of gain.

**How it changes future behavior:**
Track Profit-to-DD ratio as a primary metric alongside Profit, PF, and DD.
Target ratio: >2.5x. Any version below 2.0x is suspect.

**Confidence:** 85%

---

## 2026-05-24 — Autonomous Work Protocol

**What was learned:**
The AGENTS.md file defines an autonomous work protocol: never sit idle, always
advance at least one goal per session, prepare backtest instructions for Ryan
when blocked, review own work before stopping.

**How it changes future behavior:**
Every session must end with: (1) what was accomplished, (2) current state,
(3) next action, (4) what Ryan needs to do. No session ends in silence.

**Confidence:** 100%

---

*🔷 DESTROYER QUANTUM — VENI VIDI VICI*
*Every lesson makes us stronger. Every failure teaches us something.*
