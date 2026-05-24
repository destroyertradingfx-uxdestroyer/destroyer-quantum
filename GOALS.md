# GOALS.md — DESTROYER QUANTUM Goal Tracker

This file is the single source of truth for what you are working toward. Read it at the start of every session. Update it as you make progress. Do not remove a goal until Ryan confirms it is achieved.

---

## HOW GOALS WORK

1. Ryan sets a goal with a target and success criteria
2. You work toward it — autonomously if needed
3. You update the goal status as you make progress
4. When you believe a goal is achieved, you present evidence to Ryan for confirmation
5. Only Ryan marks a goal as DONE

### Goal States
- 🔴 **BLOCKED** — Cannot proceed. State what is blocking and what you need.
- 🟡 **IN PROGRESS** — Actively working on it.
- 🟢 **ACHIEVED** — Evidence collected. Awaiting Ryan's confirmation.
- ✅ **DONE** — Confirmed by Ryan.
- ⚫ **ABANDONED** — Ryan decided to drop it.

---

## ACTIVE GOALS

### GOAL-001: Beat V27.18 Baseline
- **Target:** Profit > $33,000 AND PF > 1.85 AND DD < 22%
- **Current Best:** V27.18 — $29,632, PF 1.79, DD 24.13%
- **Status:** 🟡 IN PROGRESS
- **Strategy:** Implement three root cause fixes in sequence
- **Progress:**
  - [ ] Backtest V27.22 (Profit-Lock System)
  - [ ] Build + Backtest Fix #2 (Accelerated Shrink + Time Lockout)
  - [ ] Build + Backtest Fix #3 (Regime-Based Weights + Vol Sizing)
  - [ ] Combine best-performing fixes into final version
- **Last Updated:** 2026-05-16
- **Notes:** V27.22 code exists but was never backtested. Start there.

---

### GOAL-002: Reduce Max Drawdown Below 20%
- **Target:** DD < 20% without sacrificing more than $3K in profit
- **Current Best:** V27.16 — DD 18.59% but profit only $22,791
- **Status:** 🟡 IN PROGRESS (tied to GOAL-001)
- **Progress:**
  - [ ] Identify which fix contributes most to DD reduction
  - [ ] Test combinations to find profit/DD sweet spot
- **Last Updated:** 2026-05-16

---

### GOAL-003: Path to $70K
- **Target:** Net Profit > $70,000 over 6.3 year backtest, DD < 25%
- **Status:** 🔴 BLOCKED (depends on GOAL-001)
- **Progress:**
  - [ ] Achieve GOAL-001 first
  - [ ] Evaluate compounding effect of smoother equity curve
  - [ ] Research additional edge sources (not just more strategies)
- **Last Updated:** 2026-05-16

---

## COMPLETED GOALS

_(None yet)_

---

## GOAL LOG

Track every session's contribution toward goals here. One line per session.

| Date | Session Focus | Progress Made | Next Step |
|---|---|---|---|
| 2026-05-16 | Initial goal setup | Goals defined, plan created | Backtest V27.22 |
| | | | |
