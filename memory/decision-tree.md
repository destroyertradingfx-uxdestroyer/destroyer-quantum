# Decision Tree — DESTROYER QUANTUM

*Every major decision recorded with full context. Prevents re-debating settled questions.*

---

## Settled Decisions (DO NOT REVISIT)

### DEC-001: Cut Silicon-X
- **Date:** 2026-05-13
- **Context:** Silicon-X (Magic 984651) showed PF 0.77 over 43 trades, -$195 net loss
- **Options Considered:**
  1. Keep and tune Silicon-X parameters
  2. Reduce position size
  3. Cut permanently
- **Decision:** Permanently disable Silicon-X
- **Reasoning:** Negative expected value. Every trade it takes has negative EV. Removing it frees risk budget for profitable strategies.
- **Outcome:** ✅ DONE. Never re-enable.
- **Confidence:** 100%
- **Status:** LOCKED — Do not revisit

---

### DEC-002: Keep Nexus Parameters Tight
- **Date:** 2026-05-13
- **Context:** Nexus: 4 trades in 6 years, PF 4.31-4.38. V27.12 tried loosening parameters.
- **Options Considered:**
  1. Loosen CompressionRatio 0.75→0.85, CompressionBars 3→2 (more trades)
  2. Keep tight parameters
- **Decision:** Do NOT loosen Nexus's parameters
- **Reasoning:** Nexus's edge depends on extreme selectivity. More trades = lower quality = edge destruction. V27.12 loosened and quickly reverted.
- **Outcome:** ✅ DONE. Nexus remains at PF 4.31 with 4 trades.
- **Confidence:** 100%
- **Status:** LOCKED — Do not revisit

---

### DEC-003: Per-Strategy Adaptive Over Daily Caps
- **Date:** 2026-05-14
- **Context:** Testing different risk management approaches
- **Evidence:**
  - V27.14: $500 daily cap → profit $8,972 (blocked 190 trades)
  - V27.16: $1,000 daily cap → blocked 109 trades, profit $22,791
  - V27.18: Removed daily cap → profit $29,632
- **Options Considered:**
  1. $500 daily loss cap (too restrictive)
  2. $1,000 daily loss cap (still restrictive)
  3. No daily cap, per-strategy adaptive sizing
- **Decision:** Use per-strategy adaptive risk unwind instead of global daily loss caps
- **Reasoning:** Daily caps are too blunt. They block recovery trades alongside losing trades. Per-strategy sizing is surgical — losers shrink, winners keep running.
- **Outcome:** ✅ DONE. Profit increased $6,841 from capped to uncapped.
- **Confidence:** 100%
- **Status:** LOCKED — Do not revisit

---

### DEC-004: V28.06 as Proven Base
- **Date:** 2026-05-22
- **Context:** V28.06 backtested at $50,399, PF 1.92, DD 19.40% — best in project history
- **Options Considered:**
  1. Continue iterating from V27.18
  2. Use V28.03 as base
  3. Use V28.06 as base
- **Decision:** V28.06 is the proven foundation. All future work builds on top, not sideways.
- **Reasoning:** Every time we broke the baseline to try something new, we got worse results. V28.06 has best profit ($50,399), best PF (1.92), and best DD (19.40%). Build on top.
- **Outcome:** ✅ DONE. V28.06 is the standard.
- **Confidence:** 100%
- **Status:** LOCKED — Do not revisit

---

### DEC-005: Fix V28.09 Bugs Before Adding Features
- **Date:** 2026-05-22
- **Context:** V28.09 was catastrophic (-$5,775, PF 0.81, DD 94.48%). Root cause: triple GetStrategyIndex conflict.
- **Options Considered:**
  1. Add new features on top of V28.09
  2. Revert to V28.06 and fix bugs separately
  3. Build V28.10 with bug fixes on V28.06 base
- **Decision:** Build V28.10 on V28.06 base with 4 bug fixes + Sentinel
- **Reasoning:** V28.09's bugs were catastrophic. Adding features on broken code is building on sand. Fix foundation first.
- **Outcome:** ✅ DONE. V28.10 code complete, awaiting backtest.
- **Confidence:** 95%
- **Status:** Awaiting validation via backtest

---

### DEC-006: Cut LiquiditySweep
- **Date:** 2026-05-22
- **Context:** LiquiditySweep: 12 trades, -$1,439, PF 0.84 — negative EV
- **Options Considered:**
  1. Tune LiquiditySweep parameters
  2. Reduce position size
  3. Cut permanently
- **Decision:** Cut LiquiditySweep permanently
- **Reasoning:** Negative expected value. Same pattern that destroyed V27.28.01. Bad strategies don't just fail — they actively harm good ones.
- **Outcome:** ✅ DONE. Cut in V28.04 surgical patch.
- **Confidence:** 100%
- **Status:** LOCKED — Do not revisit

---

### DEC-007: V28.11 Debate Layer Design
- **Date:** 2026-05-24
- **Context:** V28.06 has 12 strategies executing independently with no coordination. Phantom says BUY, Mean Reversion says SELL — both execute and cancel each other.
- **Options Considered:**
  1. Add more strategies (quantity over quality)
  2. Tune existing strategies (parameter tweaking)
  3. Add signal debate layer (intelligence over volume)
  4. Add regime-based strategy weights
- **Decision:** Implement Debate Layer — signal collection → weighted debate → 3-way risk panel → execution
- **Reasoning:** Inspired by TradingAgents (79K ★). Don't touch proven V28.06 logic. Bolt intelligence on top. Debate before execution means only consensus trades execute.
- **Expected Impact:** PF 2.0-2.3, DD 14-16%, trades 600-700
- **Outcome:** Code complete. Awaiting backtest.
- **Confidence:** 70% (untested — design looks sound but needs validation)
- **Status:** 🟡 AWAITING BACKTEST

---

### DEC-008: Three Root Cause Fixes Priority
- **Date:** 2026-05-15
- **Context:** Root Cause Solutions Framework identified $12K-$17K in recoverable losses
- **Root Causes:**
  1. Position Sizing Creep (-$5K to -$8K drain) → Fix: Profit-Lock System
  2. Consecutive Loss Avalanche (-$4K to -$6K drain) → Fix: Accelerated Shrink + Time Lockout
  3. Regime Change Blindness (-$3K to -$5K drain) → Fix: Regime-Based Weights + Vol-Adjusted Sizing
- **Options Considered:**
  1. Add new strategies for more profit
  2. Fix all three root causes
  3. Fix the biggest one first
- **Decision:** Fix all three root causes in sequence, one at a time
- **Reasoning:** Fix the foundation before building the roof. New strategies are worthless if existing ones leak money.
- **Outcome:** V27.22 (Profit-Lock) built but never backtested. Others pending.
- **Confidence:** 85%
- **Status:** 🟡 IN PROGRESS

---

## Pending Decisions

### DEC-P01: V28.10 vs V28.11 Backtest Priority
- **Context:** Both are code-complete. V28.10 is bug fixes, V28.11 is new feature.
- **Recommendation:** Backtest V28.10 first (simpler, validates bug fixes), then V28.11
- **Status:** 🟡 PENDING RYAN'S BACKTEST

### DEC-P02: Path to $300K — Scaling Strategy
- **Context:** V28.06 makes $50K. Target is $300K+. Gap is 6x.
- **Options:**
  1. Larger account start ($50K → ~$241K from V28.06 compounding)
  2. More trade frequency (500+ quality trades)
  3. Better compounding engine (adaptive Kelly)
  4. More SessionMomentum-type strategies (rare, high-conviction, big payoff)
  5. Reduce average loss ($770 avg loss is high)
- **Status:** 🔴 NOT STARTED

---

## Decision Rules (from SOUL.md)

1. **Never re-enable Silicon-X** — PF 0.77, negative EV. Cut permanently.
2. **Never loosen Nexus parameters** — Edge depends on extreme selectivity.
3. **Never add strategies without proving positive EV** — Backtest or don't add.
4. **Never use daily loss caps** — Per-strategy adaptive is surgical.
5. **Never create a version and move on** — Backtest first, then build next.
6. **Never change more than one thing** — Isolate what improved or regressed.
7. **Never parameter tweak without root cause** — Understand why before changing.
8. **Always compare to baseline** — V28.06: $50,399, PF 1.92, DD 19.40%.

---

*🔷 DESTROYER QUANTUM — VENI VIDI VICI*
