# Decisions Log

_(Record every major decision with reasoning. This prevents re-debating settled questions.)_

---

## 2026-05-13: Cut Silicon-X
- **Decision:** Permanently disable Silicon-X (Magic 984651)
- **Evidence:** PF 0.77 over 43 trades, -$195 net loss
- **Reasoning:** Negative expected value. Every trade it takes has negative EV. Removing it frees risk budget for profitable strategies.
- **Status:** ✅ DONE

## 2026-05-13: Keep Nexus Parameters Tight
- **Decision:** Do NOT loosen Nexus's parameters to generate more trades
- **Evidence:** PF 4.38 at 4 trades. V27.12 loosened CompressionRatio 0.75→0.85, CompressionBars 3→2. Quickly reverted.
- **Reasoning:** Nexus's edge depends on extreme selectivity. More trades = lower quality = edge destruction.
- **Status:** ✅ DONE

## 2026-05-14: Per-Strategy Adaptive Over Daily Caps
- **Decision:** Use per-strategy adaptive risk unwind instead of global daily loss caps
- **Evidence:** V27.14 ($500 cap) → $8,972 profit. V27.16 ($1,000 cap) → $22,791. V27.18 (no cap) → $29,632.
- **Reasoning:** Daily caps are too blunt. They block recovery trades alongside losing trades. Per-strategy sizing is surgical.
- **Status:** ✅ DONE

## 2026-05-15: V27.18 as Proven Baseline
- **Decision:** V27.18 is the foundation. All future work builds on top, not sideways.
- **Evidence:** $29,632, PF 1.79, DD 24.13%, 304 trades. Best balance of profit and risk.
- **Reasoning:** Every time we broke the baseline to try something new, we got worse results. Build on top.
- **Status:** ✅ DONE

## 2026-05-15: Three Root Cause Fixes Before Anything Else
- **Decision:** Focus on Profit-Lock, Accelerated Shrink+Lockout, and Regime Weights before adding new features
- **Evidence:** Root Cause Solutions Framework identified $12K-$17K in recoverable losses across three structural problems
- **Reasoning:** Fix the foundation before building the roof. New strategies are worthless if the existing ones leak money.
- **Status:** 🟡 IN PROGRESS
