# DESTROYER QUANTUM — Strategy Audit & Rescue Prompt

## Context
You are reviewing DESTROYER QUANTUM (RESURRECTION_BASE.mq4), a multi-strategy EURUSD H4 Expert Advisor. The goal is $10K -> $300K.

The EA has 20 registered strategies (17 enabled + 3 effectively dead). The last backtest (V28.09) BLOWN THE ACCOUNT (-$5,775, PF 0.81, DD 94.48%). The proven baseline (V28.06) made $50,399 at PF 1.92 with only 601 trades over 6 years.

## Current Strategy Inventory

### ENABLED & ACTIVE (dispatched in OnTick):
| # | Strategy | Type | Status |
|---|----------|------|--------|
| 1 | MeanReversion | Reversion | ENABLED — 1 trade in V28.09, $33 |
| 2 | Chronos (M15 Scalper) | Microstructure | ENABLED — no trades in backtest (H4 test) |
| 3 | Reaper | Grid/Range | ENABLED — 289 trades, -$100, PF 0.98 (loser) |
| 4 | SiliconX | Grid/Breakout | ENABLED — no trades in latest backtest |
| 5 | Apex | Session Rollover | ENABLED — no trades in latest backtest |
| 6 | Phantom | Monday Gap Fader | ENABLED — 274 trades, $3,517, PF 1.40 (winner) |
| 7 | Nexus | Vol Compression | ENABLED — 4 trades, $112, PF 4.57 (winner) |
| 8 | NoiseBreakout | BB Squeeze | ENABLED — 63 trades, $497, PF 1.38 (marginal) |
| 9 | TBM | Time-Based Manipulation | ENABLED — A-Tier (refined by Claude) |
| 10 | PO3 | Power of 3 | ENABLED — A-Tier (refined by Claude) |
| 11 | FractalModel | Fractal | ENABLED — A-Tier (refined by Claude) |
| 12 | APlusFVG | FVG Reversion | ENABLED — A-Tier (refined by Claude) |
| 13 | CRT | Candle Range Theory | ENABLED — A-Tier (refined by Claude) |
| 14 | LondonBreakout | London Session | ENABLED — no trades in latest backtest |
| 15 | SessionMomentum | London/NY Breakout | ENABLED — 2 trades, $98 (tiny sample) |
| 16 | DivergenceMR | RSI Divergence | ENABLED — no trades in latest backtest |
| 17 | StructuralRetest | Break & Retest | ENABLED — no trades in latest backtest |

### ENABLED BUT DEAD (commented out in dispatch):
| # | Strategy | Reason |
|---|----------|--------|
| 18 | Titan | 7 trades in 6 years, $21 profit. 0.4% pass rate. |
| 19 | Warden | 8 trades in 6 years, $690 profit. VSA gate too rare. |

### CAPITAL PRESERVATION (not a strategy):
| # | Strategy | Role |
|---|----------|------|
| 20 | Huntsman | Risk scaler during drawdown periods |

### DISABLED:
- Vortex (false)
- RegimeShift (false)
- LiquiditySweep (false — cut: PF 0.84, -$1,439)

## V28.06 Proven Baseline (Best Result Ever)
- Net Profit: $50,399 | PF: 1.92 | DD: 19.40% | 601 trades | WR: 75.21%
- Only 6 strategies contributed: Phantom ($24K), SessionMomentum ($8.5K), Nexus ($5.8K), + 3 others

## V28.09 Catastrophic Failure
- Net Profit: -$5,775 | PF: 0.81 | DD: 94.48% | 830 trades | ACCOUNT BLOWN
- Root causes: GetStrategyIndex mapping bugs, Sentinel missing from IsOurMagicNumber, Phantom Tuesday gap flood, NB relaxation

## YOUR TASK

For each of the 17 active strategies, analyze and recommend:

### 1. STRATEGY CLASSIFICATION
- Is it a WINNER (PF > 1.3 with enough trades), LOSER (PF < 1.0), MARGINAL (PF 1.0-1.3), or UNPROVEN (too few trades to judge)?
- What market regime does it perform in? (trending, ranging, volatile, quiet)

### 2. FROM LOSER TO WINNER — Specific Fixes
For each LOSER/MARGINAL strategy:
- What is the likely root cause of poor performance?
- What specific parameter changes could improve it?
- What logic changes would fix the edge?
- Should it be CUT entirely, or is there a salvageable edge?

### 3. FROM UNPROVEN TO PROVEN
For each UNPROVEN strategy (few/no trades):
- Is the logic sound? Does it have a theoretical edge?
- Are the filters too tight? What specific relaxation would generate trades?
- What is the expected trade frequency on EURUSD H4?

### 4. STRATEGY INTERACTIONS
- Which strategies CONFLICT (e.g., both trying to fade the same move)?
- Which strategies COMPLEMENT (e.g., trend + reversion pair)?
- What is the optimal ENABLED set for maximum profit with < 25% DD?

### 5. THE $300K ROADMAP
- Given V28.06 made $50K in 6 years, what changes would get to $300K?
- Is it more strategies, more risk, or better strategy selection?
- What is the realistic timeline with compounding?

Be specific. Give exact parameter values, exact code changes, exact strategy combinations. No hand-waving. This is a $10K account — every dollar matters.
