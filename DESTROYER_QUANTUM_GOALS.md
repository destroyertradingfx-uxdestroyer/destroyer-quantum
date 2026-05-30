# DESTROYER QUANTUM — GOALS

> Target: $10K → $5M. Current: V28.08 Oblivion v7 ($61K, PF 2.27, DD 17.2%, 554 trades)

---

## ACTIVE GOALS

### GOAL 1: Push to $170K+ via 5-Patch Strategy
**Status: RESEARCH COMPLETE — CODE PATCHES READY — AWAITING BACKTEST**
**Priority: HIGHEST**

Cycle 17 research identified 5 levers to close the $109K gap:

| # | Lever | Profit | DD | Code Ready? |
|---|-------|--------|-----|-------------|
| 1 | DD Headroom (risk params) | +$25-40K | +5-7% | ✅ Patches 1-2 |
| 2 | Dead Strategy Activation | +$15-25K | +2-3% | ✅ Patches 5-7 |
| 3 | Equity Curve Amplification | +$15-25K | -2-4% | ✅ Patch 4 |
| 4 | Partial Close at 2R/4R | +$8-15K | -1-2% | ✅ Patch 8 |
| 5 | Win/Loss Streak Momentum | +$5-10K | +0-1% | ✅ Patch 3 |

**Combined conservative estimate: +$34-58K → $95K-$119K**
**Combined optimistic estimate: +$54-92K → $115K-$153K**
**Gap remaining: $17K-$75K (close via MT4 genetic optimization)**

**Code patches file:** `/code/patches/V28_09_PUSH_TO_170K_PATCHES.mq4`
**Research file:** `/research/CYCLE_17_GITHUB_RESEARCH_FINDINGS.md`

**Process: Apply patches → backtest → compare to V28.08 baseline → iterate**

### GOAL 2: Build ML Filter for trade gating
**Status: PAUSED (proven concept, needs integration)**
**Priority: MEDIUM**

61% of bars should NOT be traded. ML filter proven in Python (Mean Reversion PF 0.29→1.36). Need to port to MQL4 or use as pre-trade filter.

### GOAL 3: Achieve $300K milestone
**Status: BLOCKED on Goal 1**
**Priority: HIGH (but can't start until $170K+ is proven)**

---

## COMPLETED GOALS

- [x] V28.06 baseline established ($68,938, PF 1.89)
- [x] Deep research on 50+ GitHub repos for improvements
- [x] Comprehensive improvement roadmap created (13 cycles)
- [x] RESURRECTION codebase audited
- [x] V28.06 TITAN built with Kelly amplification + MR activation + Session expansion
- [x] All code patches documented and ready for application
- [x] Equity curve + GBPUSD filter code written (V29_00_EQUITY_CURVE.mq4)
- [x] Identified 3 unfinished code stubs (partial close, hedging, scaling)
- [x] V28.08 Oblivion v7 backtested ($61K, PF 2.27, DD 17.2%)
- [x] Cycle 17 GitHub research complete (Ikarus flexATR, EarnForex, davejlin)
- [x] 9 code patches written and documented (V28_09_PUSH_TO_170K_PATCHES.mq4)

---

## BLOCKED

Nothing currently blocked. All immediate next steps can be executed by Ryan.

---

## KEY FINDINGS (Cycle 17)

1. **DD headroom is the biggest lever** — 6.8% unused (17.2% vs 24% limit) = leaving $25-40K on table
2. **12 dead strategies** — Titan, Warden, Quantum Oscillator, Apex, Microstructure, MathReversal, SPECTRE, AETHER GAP, Vortex, RegimeShift, Chronos, SessionMomentum all produce 0 trades
3. **Ikarus flexATR concept** — Grid EA uses ATR-proportional sizing, worth adopting for Reaper Protocol
4. **Partial close stub is EMPTY** — Lines 12048-12060 have framework but no OrderClose() calls
5. **Streak data unused** — g_consecutiveWins/Losses tracked but not in MoneyManagement_Quantum()

---

*Last updated: 2026-05-30 (Cycle 17)*
