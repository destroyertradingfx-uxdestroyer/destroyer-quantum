# System State — DESTROYER QUANTUM
*Last Updated: 2026-05-24*

---

## Current Version

| Attribute | Value |
|-----------|-------|
| **Current Version** | V28.11 (Debate Layer) |
| **Code Status** | ✅ COMPLETE — AWAITING BACKTEST |
| **Proven Base** | V28.06 ($50,399, PF 1.92, DD 19.40%) |
| **Latest Backtested** | V28.09 (CATASTROPHE — do not use) |
| **Last Good Backtest** | V28.06 |
| **Platform** | MetaTrader 4, EURUSD H4 |
| **Start Capital** | $10,000 |

---

## Version Status Matrix

| Version | Status | Profit | PF | DD | Trades | Notes |
|---------|--------|--------|----|----|--------|-------|
| V28.06 | ⭐ BEST BASE | $50,399 | 1.92 | 19.40% | 601 | Proven base |
| V28.07 | ❌ Regression | $48,153 | 1.88 | 20.70% | 653 | Degrades from base |
| V28.08 | ❌ Regression | $47,808 | 1.85 | 19.27% | 592 | Degrades from base |
| V28.09 | ❌ Catastrophe | -$5,775 | 0.81 | 94.48% | 830 | Account blown |
| V28.10 | 🔨 Unbuilt | — | — | — | — | Bug fixes + Sentinel |
| V28.11 | 🔨 Unbuilt | — | — | — | — | Debate Layer |

---

## What's Being Tested

**V28.10 (Bug Stomper):**
- Unified magic→index mapping (fixes V28.09 catastrophe)
- Added Sentinel strategy (EMA21/50 + RSI14, magic 777015)
- Preserves V28.06 strategy logic exactly
- **Status:** Code complete. Needs Ryan to run backtest in MT4.

**V28.11 (Debate Layer):**
- Signal debate: strategies vote before execution
- 3-way Risk Panel (Aggressive/Conservative/Neutral)
- 5-tier position sizing based on consensus
- Deferred reflection with post-close analysis
- **Status:** Code complete. Needs V28.10 backtest first, then V28.11 backtest.

---

## What's Pending

1. 🔴 **BACKTEST V28.10** — Ryan needs to run in MT4 (OHLC, 6.3yr, $10K)
2. 🔴 **BACKTEST V28.11** — After V28.10 validates
3. 🟡 **Sentinel validation** — Only 0-2 trades expected, needs more data
4. 🟡 **SessionMomentum validation** — 2 trades at $4,294/trade, not statistically significant
5. ⚫ **Three Root Cause Fixes** — Profit-Lock, Accelerated Shrink, Regime Weights (pending)

---

## Active Goals

| Goal | Target | Current | Status |
|------|--------|---------|--------|
| GOAL-001: Beat V27.18 Baseline | Profit>$33K, PF>1.85, DD<22% | V28.06: $50,399 ✅ | 🟢 ACHIEVED (V28.06) |
| GOAL-002: Reduce DD Below 20% | DD<20% | V28.06: 19.40% ✅ | 🟢 ACHIEVED (V28.06) |
| GOAL-003: Path to $70K | Profit>$70K, DD<25% | V28.06: $50,399 | 🟡 IN PROGRESS |

---

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| V28.10 not backtested | Can't validate bug fixes | Ryan runs backtest |
| V28.11 not backtested | Can't validate Debate Layer | After V28.10 |
| $300K gap | Current: ~$50K, Target: $300K+ | Needs compounding engine + more edge |

---

## Strategy Roster (V28.06)

| Strategy | Trades | Profit | PF | Status |
|----------|--------|--------|----|--------|
| Phantom | 166 | $24,061 | 1.71 | ✅ Backbone (48% of profit) |
| SessionMomentum | 2 | $8,588 | 999 | ✅ Elite (needs validation) |
| NoiseBreakout | 52 | $7,093 | 1.77 | ✅ Consistent |
| Nexus | 4 | $5,799 | 4.31 | ✅ Elite sniper |
| Reaper Protocol | 376 | $4,462 | 1.45 | ✅ Workhorse |
| Mean Reversion | 1 | $396 | 999 | ⚠️ Limited data |
| Sentinel | 0 | — | — | 🆕 New (untested) |
| Silicon-X | — | — | 0.77 | ❌ CUT (never re-enable) |
| Titan | — | — | — | ❌ Disabled |
| Warden | — | — | — | ❌ Disabled |
| LiquiditySweep | — | — | 0.84 | ❌ CUT (negative EV) |

---

## Risk Stack (V28.06)

- Per-strategy adaptive risk unwind (+10%/-20%)
- Per-strategy lockout after 3 consecutive losses
- Event Shield (1h/30min blackout before high-impact events)
- ATR Spike Circuit Breaker (1.8x)
- Queen Bee (5% DD kill switch)
- 2.5 lot cap
- V23 empirical probability engine
- Kelly Criterion position sizing (V27.19)
- Heat Score capital allocation

---

## Key Discoveries (Cumulative)

1. Bad strategies don't just fail — they actively harm good ones
2. Daily loss caps are amputation; per-strategy sizing is surgical
3. Nexus's edge depends on extreme selectivity (4 trades at PF 4.31)
4. Untested versions are dead code
5. Parameter tweaking without root cause analysis produces 22 bad versions
6. Triple GetStrategyIndex with different indices → account blown
7. Always add new magic numbers to IsOurMagicNumber()
8. Expand winners, don't fix losers
9. Quality over quantity: V28.03 makes $172/trade vs V27.18's $97/trade

---

*🔷 DESTROYER QUANTUM — VENI VIDI VICI*
