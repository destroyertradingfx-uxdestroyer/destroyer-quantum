# Latest Backtest Results

## Version: V28.09 (TESTED — CATASTROPHIC FAILURE)
- Net Profit: -$5,775
- Profit Factor: 0.81
- Max Drawdown: 94.48%
- Total Trades: 830
- Win Rate: 51.81%
- Final Equity: $4,224 (from $10,000)
- **ACCOUNT BLOWN — DO NOT USE**

### Per-Strategy Breakdown
| Strategy | Trades | Net Profit | Profit Factor |
|---|---|---|---|
| SessionMomentum | 2 | $98 | 999 |
| Nexus | 4 | $112 | 4.57 |
| Phantom | 274 | $3,517 | 1.40 |
| NoiseBreakout | 63 | $497 | 1.38 |
| Reaper Protocol | 289 | -$100 | 0.98 |
| Mean Reversion | 1 | $33 | 999 |
| Sentinel | 0 | — | — |

### Root Cause
1. **Triple GetStrategyIndex conflict** — GetStrategyIndexByMagic had WRONG indices. MoneyManagement_Quantum pulled Kelly/heat from wrong strategies. SessionMomentum/Nexus got tiny lot sizes.
2. **Sentinel not in IsOurMagicNumber** — 197 invisible trades
3. **Array size mismatch** — [17] vs [18]
4. **Phantom Tuesday gap extension** — Flooded with low-quality gap trades
5. **NB relaxation** — Added noise trades

## Version: V28.10 (AWAITING BACKTEST)
- Built on V28.06 proven base ($50,399, PF 1.92, DD 19.40%, 601 trades)
- 4 bug fixes (unified mapping, IsOurMagicNumber, arrays, reconciliation)
- NEW Sentinel strategy (EMA21/50 + RSI14, 2:1 R:R, magic 777015)
- V28.06 strategy logic preserved exactly (no Tuesday gap, no NB relaxation)
- Target: $55K-$60K

## Version: V28.06 (BEST PROFIT — PROVEN BASE)
- Net Profit: $50,399
- Profit Factor: 1.92
- Max Drawdown: 19.40%
- Total Trades: 601
- Win Rate: 75.21%
- Profit-to-DD Ratio: 2.59x

### Per-Strategy Breakdown
| Strategy | Trades | Net Profit | Profit Factor |
|---|---|---|---|
| SessionMomentum | 2 | $8,588 | 999 |
| Nexus | 4 | $5,799 | 4.31 |
| Phantom | 166 | $24,061 | 1.71 |
| NoiseBreakout | 52 | $7,093 | 1.77 |
| Reaper Protocol | 376 | $4,462 | 1.45 |
| Mean Reversion | 1 | $396 | 999 |
