# Version Journal — DESTROYER QUANTUM

*Detailed history of every version from V26 to V28.11.*
*What changed, why, results, lessons.*

---

## V26.0 — "MATH-FIRST" (January 2026)

### What Changed
- **MathReversal Strategy:** Pure math signal generator. No RSI/BB required.
  Triggers on Empirical Probability >0.7, Deviation >1.5, Normalized Entropy <0.6,
  R-Expectancy >0, Regime Confidence >0.5.
- **Paradigm Shift:** Math generates signals instead of filtering them. Bypasses
  V18 binary logic when math is confident.
- Integrated V25 enhancements (Marginal VAR, Regime Probation, Continuous Scoring,
  Complete Re-entries).

### Why
V25's elastic layer was throttled by V18 indicator rarity (~190 signals). To reach
600-900 trades with PF >3.5, needed math to generate new signals independently.

### Expected Results
- Trade Count: 190 → 650-950
- Profit Factor: 3.6-4.0
- Max Drawdown: 9-11%
- Win Rate: >70%

### Actual Results
Not separately backtested — integrated into later versions.

### Lessons
- Math-first approach is philosophically sound
- V23 empirical probability engine provides the mathematical foundation
- Continuous scoring produces more signals than binary gates

---

## V27.18 — "THE ORIGINAL BASELINE" (May 15, 2026)

### What Changed
- Removed daily loss caps entirely
- Per-strategy adaptive risk unwind (+10%/-20%)
- Per-strategy lockout after 3 consecutive losses
- Finalized risk stack: Event Shield, ATR Circuit Breaker, Queen Bee, 2.5 lot cap

### Why
After V27.14 ($500 cap killed profit to $8,972) and V27.16 ($1,000 cap blocked
109 trades), removing caps and using surgical per-strategy sizing was the answer.

### Results
- Net Profit: $29,632
- Profit Factor: 1.79
- Max Drawdown: 24.13%
- Total Trades: 304
- Win Rate: ~73%

### Lessons
- Per-strategy adaptive sizing beats daily caps
- 304 trades in 6.3 years = ~48/year = ~4/month (acceptable for quality)
- This became THE baseline for all future comparison

---

## V27.19 — "DYNAMIC KELLY" (May 18, 2026)

### What Changed
- **Rolling Kelly Criterion:** Per-strategy, 60-trade circular buffer
- **Dynamic Tier Caps:** PF≥3.0→4.0x, PF≥2.0→3.0x, PF≥1.5→2.5x (not hardcoded)
- **Heat Score:** Composite of PF (30%), Win Rate (15%), Kelly (25%), Sharpe (15%),
  Streak (15%). EWMA-smoothed (70% old, 30% new).
- **Reaper Grid Amplification:** Initial lot 0.01→0.05, max exposure ~1.2 lots
- **Portfolio Risk Budget:** Raised to 8%

### Why
V27.8 used static 10%/20% win/loss multiplier with hardcoded tier caps. This was
arbitrary. Kelly Criterion mathematically determines optimal bet size based on
actual strategy performance.

### Philosophy
"Let the Math Decide — Kelly Governs, Heat Allocates"

### Expected Results
- Strategies self-optimize: winners amplify, losers shrink
- High PF strategies (Reaper, Nexus) get proportionally more capital
- Drawdown controlled by Kelly's natural negative-feedback
- Target: $100K+

### Lessons
- Kelly Criterion is the gold standard for position sizing
- Rolling window (60 trades) prevents overfitting to historical data
- EWMA smoothing prevents whipsaw in heat score

---

## V27.28.01 — "THE REGRESSION" (May 2026)

### What Changed
- Added 4 new strategies after V27.27
- Strategy filters loosened

### Why
Attempt to increase trade frequency and diversify strategy roster.

### Results
- Net Profit: $26,992 (DOWN from V27.18's $29,632)
- Profit Factor: 1.33 (DOWN from 1.79)
- Max Drawdown: 17.42% (improved — lower DD)
- Total Trades: 709 (UP from 304)
- Win Rate: 64.32% (DOWN from ~73%)
- Gross Loss: $81,411 (UP from ~$16K — nearly DOUBLED)

### Root Cause Analysis
- Gross losses nearly doubled ($38K → $81K)
- Win rate dropped from ~73% to 64.32%
- More trades (304→709) but each trade was WORSE on average
- New strategies were "perfect condition only" — work in ideal setups but bleed
  in normal conditions

### Lessons
- More trades ≠ better results
- New strategies destroyed quality without adding value
- Every new strategy must prove positive EV before inclusion
- Win rate matters as much as trade count

---

## V28.03 — "BREAKTHROUGH" (May 2026)

### What Changed
- Added SessionMomentum strategy
- Added LiquiditySweep strategy
- Modified existing strategies

### Why
To increase profit while maintaining or improving drawdown.

### Results
- Net Profit: $48,256 (+$18,624 vs V27.18)
- Profit Factor: 1.82 (+0.03 vs V27.18)
- Max Drawdown: 18.14% (-5.99% vs V27.18)
- Total Trades: 280
- Win Rate: 72.86%
- Average profit per trade: $172 (vs V27.18's $97)

### Per-Strategy Highlights
- **SessionMomentum:** 2 trades, $8,588, PF 999 — INSANE ($4,294/trade!)
- **LiquiditySweep:** 12 trades, -$1,439, PF 0.84 — CUT (negative EV)
- **Titan:** COLLAPSED from PF 2.00 to 0.37
- **Nexus:** 4 trades, $5,799, PF 4.31 — consistent elite

### Lessons
- SessionMomentum is a potential game-changer (2 trades, $8,588)
- Quality over quantity: $172/trade vs $97/trade
- LiquiditySweep proves: negative EV strategies must be cut immediately
- Titan regression needs investigation

---

## V28.04 — "SURGICAL PATCH" (May 22, 2026)

### What Changed (5 fixes)
1. **CUT LiquiditySweep** (9005) — PF 0.84, negative EV (-$1,439). Disabled.
2. **REVERTED Titan volatility threshold** — 0.25→0.4. Restored Valkyrie filter.
   V27.27 loosened these and let in 17 garbage trades (PF 2.00→0.37).
3. **FIXED duplicate GetStrategySpecificRisk** — renamed second definition.
4. **ADDED lot sizing fallback** for new strategies 9003-9006.
   SessionMomentum gets 1.5x (high-PF potential), others get 1.0x or 0.5x.
5. **ADJUSTED DivergenceMR Hurst threshold** — 0.5→0.55.
   Extended StructuralRetest retest window — 10→20 bars.

### Why
V28.03 showed clear winners and losers. Surgical fixes to cut losers and fix bugs
without touching what was working.

### Expected Impact
- Cut ~$1,439 in losses from LiquiditySweep
- Restore Titan to PF 2.00+
- DivergenceMR + StructuralRetest may now generate trades
- Estimated: $49K-$51K profit, PF 1.85-1.90, DD <18%

---

## V28.06 — "THE BASE" ⭐ (May 2026)

### What Changed
Built on V28.03/V28.04 foundations with refinements.

### Results
- Net Profit: $50,399 ⭐ BEST IN PROJECT HISTORY
- Profit Factor: 1.92
- Max Drawdown: 19.40%
- Total Trades: 601
- Win Rate: 75.21%
- Profit-to-DD Ratio: 2.59x

### Per-Strategy Breakdown
| Strategy | Trades | Profit | PF | % of Total |
|----------|--------|--------|----|------------|
| Phantom | 166 | $24,061 | 1.71 | 47.7% |
| SessionMomentum | 2 | $8,588 | 999 | 17.0% |
| NoiseBreakout | 52 | $7,093 | 1.77 | 14.1% |
| Nexus | 4 | $5,799 | 4.31 | 11.5% |
| Reaper | 376 | $4,462 | 1.45 | 8.9% |
| Mean Reversion | 1 | $396 | 999 | 0.8% |

### Why It's The Base
- Highest profit ($50,399)
- Highest PF (1.92)
- Lowest DD among profitable versions (19.40%)
- Best Profit-to-DD ratio (2.59x)
- 6 active strategies, all profitable

### Lessons
- V28.06 proves: fix the foundation, then build on top
- Phantom is the backbone (47.7% of profit)
- SessionMomentum at $4,294/trade is the future (if validated)
- 601 trades is a healthy frequency for quality

---

## V28.07 — "REGRESSION" (May 2026)

### What Changed
Various modifications that degraded from V28.06.

### Results
- Net Profit: $48,153 (DOWN $2,246)
- Profit Factor: 1.88 (DOWN 0.04)
- Max Drawdown: 20.70% (UP 1.30%)
- Total Trades: 653 (UP 52)

### Lessons
- Don't fix what isn't broken
- Every regression teaches: V28.06 is hard to beat

---

## V28.08 — "REGRESSION" (May 2026)

### What Changed
Tweaks that further degraded from V28.06.

### Results
- Net Profit: $47,808 (DOWN $2,591)
- Profit Factor: 1.85 (DOWN 0.07)
- Max Drawdown: 19.27% (DOWN 0.13% — slight DD improvement)
- Total Trades: 592 (DOWN 9)

### Lessons
- Expand winners, don't fix losers
- Slight DD improvement doesn't justify profit loss

---

## V28.09 — "CATASTROPHE" ❌ (May 22, 2026)

### What Changed
- Added Sentinel strategy (EMA21/50 + RSI14, magic 777015)
- Modified Phantom Tuesday gap extension
- Relaxed NoiseBreakout parameters
- Used inconsistent strategy index mappings

### Why
Attempted to add Sentinel and improve trade frequency.

### Results
- Net Profit: -$5,775 ❌❌❌
- Profit Factor: 0.81
- Max Drawdown: 94.48%
- Total Trades: 830
- Win Rate: 51.81%
- Final Equity: $4,224 (from $10,000)
- **ACCOUNT BLOWN**

### Root Cause (Triple Bug)
1. **GetStrategyIndex conflict:** Three mapping functions with DIFFERENT indices.
   Reaper→0 (should be 4), Phantom→5 (should be 9), Nexus→7 (should be 10).
   MoneyManagement_Quantum pulled Kelly/heat from WRONG strategies.
2. **Sentinel not in IsOurMagicNumber:** 197 invisible trades.
3. **Array size mismatch:** [17] vs [18] declarations.
4. **Phantom Tuesday gap extension:** Flooded with low-quality trades.
5. **NB relaxation:** Added noise trades.

### Lessons (CRITICAL)
- **NEVER have multiple index mapping functions with different assignments**
- **ALWAYS add new magic numbers to IsOurMagicNumber()**
- **ALWAYS verify array sizes match declarations**
- This is the most expensive lesson in the project

---

## V28.10 — "BUG STOMPER" (May 22, 2026)

### What Changed (4 bug fixes + 1 new strategy)
1. Unified magic→index mapping in all 3 functions
2. Fixed IsOurMagicNumber to include Sentinel (magic 777015)
3. Fixed array size mismatch [17] vs [18]
4. Added reconciliation check between mapping functions
5. NEW Sentinel strategy (EMA21/50 + RSI14, 2:1 R:R)

### Why
V28.09's bugs were catastrophic. These are structural fixes, not parameter tweaks.

### Base
Built on V28.06 proven base ($50,399, PF 1.92, DD 19.40%, 601 trades).

### Expected Results
- $55K-$60K (V28.06 base + Sentinel trades)
- PF 1.90+
- DD <20%

### Status
✅ CODE COMPLETE — AWAITING BACKTEST

---

## V28.11 — "DEBATE LAYER" (May 2026)

### What Changed
- **Signal Debate Layer:** Strategies vote before execution (inspired by TradingAgents)
- **3-Way Risk Panel:** Aggressive, Conservative, Neutral analysts
- **5-Tier Position Sizing:** STRONG BUY (1.5x) → CAUTIOUS BUY (0.7x)
- **Deferred Reflection:** Trade logging with post-close thesis validation
- **Strategy Weights:** Based on rolling PF (elite strategies get 3x voice)
- **Divergence Detection:** Size reduced 50% when strategies disagree

### Architecture
```
OnNewBar()
  → PHASE 1: Signal Collection (each strategy outputs signal + conviction)
  → PHASE 2: Signal Debate (weighted voting, divergence detection)
  → PHASE 3: Risk Panel (3 analysts, 2/3 must approve)
  → PHASE 4: Execution (debate-adjusted size on top of Kelly/Heat)
```

### Why
V28.06 has 12 strategies executing independently with no coordination. Phantom
says BUY, Mean Reversion says SELL — both execute, cancel each other out. The
debate layer adds intelligence to the aggregation.

### Design Principles
- Don't touch proven V28.06 logic. Bolt on top.
- One change at a time. Test after each step.
- Reaper grid first entry goes through debate, grid levels manage independently.

### Expected Results
- Trades: 600-700 (fewer, higher quality)
- PF: 2.0-2.3 (consensus filtering)
- DD: 14-16% (risk panel protection)
- Profit: $50K-$55K

### Risks
- Over-filtering might block too many trades
- More moving parts = more potential bugs
- Reaper doesn't fit debate model well

### Status
✅ CODE COMPLETE — AWAITING BACKTEST

---

## Version Performance Summary

| Version | Codename | Profit | PF | DD | Trades | Verdict |
|---------|----------|--------|----|----|--------|---------|
| V27.18 | Baseline | $29,632 | 1.79 | 24.13% | 304 | ✅ Former baseline |
| V27.28.01 | — | $26,992 | 1.33 | 17.42% | 709 | ❌ Regression |
| V28.03 | Breakthrough | $48,256 | 1.82 | 18.14% | 280 | ✅ Major improvement |
| V28.06 | The Base | $50,399 | 1.92 | 19.40% | 601 | ⭐ BEST |
| V28.07 | — | $48,153 | 1.88 | 20.70% | 653 | ❌ Regression |
| V28.08 | — | $47,808 | 1.85 | 19.27% | 592 | ❌ Regression |
| V28.09 | Catastrophe | -$5,775 | 0.81 | 94.48% | 830 | ❌ Account blown |
| V28.10 | Bug Stomper | — | — | — | — | 🔨 Awaiting test |
| V28.11 | Debate Layer | — | — | — | — | 🔨 Awaiting test |

---

*🔷 DESTROYER QUANTUM — VENI VIDI VICI*
*Math decides. Code executes. Profit follows.*
