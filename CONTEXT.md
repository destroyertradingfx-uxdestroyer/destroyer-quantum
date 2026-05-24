# DESTROYER QUANTUM — Project Context (Always Load This)

## Project Identity
- **Name:** DESTROYER QUANTUM
- **Type:** Multi-Strategy MQL4 Expert Advisor
- **Platform:** MetaTrader 4
- **Symbol:** EURUSD H4 (OHLC only, no tick volume)
- **Starting Capital:** $10,000
- **Target:** $5M-$10M via compounding (150x-300x over ~6 years)
- **Partnership:** Ryan (commander), Hermes Agent (analysis & coding)
- **Slogan:** VENI VIDI VICI 🔷

## Current State
- **Latest Baseline:** V28.06 — $50,399 profit, PF 1.92, DD 19.40%, 601 trades
- **Latest Code:** V28.10 — AWAITING BACKTEST (built on V28.06 base + 4 bug fixes + Sentinel)
- **Active Strategies:** Phantom (166/$24K), NoiseBreakout (52/$7K), Reaper (376/$4.5K), SessionMomentum (2/$8.6K), Nexus (4/$5.8K), MeanReversion (1/$396), Sentinel (NEW)
- **Disabled:** Silicon-X (PF 0.77), Titan (7 trades), Warden (8 trades)

## Standard Backtest Parameters
- Symbol: EURUSD H4
- Period: ~6.3 years (2020-2026)
- Data: OHLC only
- Start Capital: $10,000
- Report: Net Profit, PF, Max DD, Total Trades, Win Rate, per-strategy breakdown

## Version History (Key Milestones)
| Version | Profit | PF | DD | Trades | Verdict |
|---|---|---|---|---|---|
| V28.06 | $50,399 | 1.92 | 19.40% | 601 | **BEST BASE** |
| V28.07 | $48,153 | 1.88 | 20.70% | 653 | REGRESSION |
| V28.08 | $47,808 | 1.85 | 19.27% | 592 | REGRESSION |
| V28.09 | -$5,775 | 0.81 | 94.48% | 830 | **CATASTROPHIC** (bugs) |
| V28.10 | AWAITING | — | — | — | Bug fixes + Sentinel |

## Critical Bug Found (V28.09 Catastrophe)
Triple GetStrategyIndex conflict — 3 mapping functions with DIFFERENT indices.
GetStrategyIndexByMagic had Reaper→0 (should be 4), Phantom→5 (should be 9), Nexus→7 (should be 10).
MoneyManagement_Quantum pulled Kelly/heat from WRONG strategies → 98% profit collapse on SessionMomentum/Nexus.
**Fixed in V28.10.**

## Priority Queue
1. **BACKTEST V28.10** — Bug fixes + Sentinel on V28.06 base
2. **Research TradingView strategies** — For V28.11+ (Ryan has strategies to share)
3. **Cron jobs** — Work on system improvements while Ryan tests

## Key Discoveries
- Don't fight a strategy's nature (grids need room to breathe)
- Expand winners, don't fix losers (V28.08 lesson)
- Always verify code matches comments (V28.06 bug)
- Never have multiple index mapping functions with different assignments (V28.09 killer)
- Always add new magic numbers to IsOurMagicNumber() (V28.09 invisible trades)
