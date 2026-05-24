# FAILURE PLAYBOOK.md — What To Do When Things Go Wrong

The agent should consult this file when backtests fail or produce unexpected results. Each failure mode has a specific diagnostic path.

---

## Failure Mode 1: Profit Dropped Significantly (> $5K below baseline)

### Diagnosis
1. Which strategies regressed? Compare per-strategy breakdown to V27.18
2. Did trade count change dramatically? (Fewer trades = filters too tight. More trades = filters too loose)
3. Did one strategy drag the whole system down? (Check if any went negative)

### Common Causes
- New filter blocking profitable entries
- Risk management too aggressive (shrinking positions too fast)
- Strategy parameter change broke a working edge
- Event Shield blocking recovery trades (V27.14 lesson)

### Action Path
- If ONE strategy regressed: isolate the change that affected it. Revert that specific change.
- If ALL strategies regressed: the change affected shared infrastructure (lot sizing, risk management). Revert and redesign.
- If trade count dropped >30%: the filter is too aggressive. Loosen it, but one parameter at a time.

---

## Failure Mode 2: Drawdown Increased (> 5% above baseline)

### Diagnosis
1. When did the max DD occur? (Specific date/time period)
2. Was it one loss cluster or gradual?
3. Which strategy caused it?
4. Was there a high-impact event during that period?

### Common Causes
- Position sizing grew too large during winning streak (sizing creep)
- Event Shield missed a major event (dates incomplete)
- New strategy opened positions in adverse conditions
- Circuit breaker failed to trigger

### Action Path
- If event-driven: check Event Shield coverage. Add the missing event dates.
- If sizing-driven: implement or tighten Profit-Lock or max lot cap
- If strategy-specific: evaluate if the strategy should be disabled or reined in
- If gradual: the risk unwind is not aggressive enough. Tighten the loss decay.

---

## Failure Mode 3: Profit Factor Dropped (< 1.50)

### Diagnosis
1. Did win rate drop or did avg win/avg loss ratio worsen?
2. Is one strategy dragging PF down with many small losses?
3. Did the system take more trades (lower quality entries)?

### Common Causes
- Strategy filter loosened, admitting marginal trades
- New strategy has low PF that drags system average
- Market regime changed and strategy hasn't adapted

### Action Path
- If win rate dropped: check entry filters. Tighten them.
- If R:R worsened: check SL/TP settings. Wider SL = more wins but bigger losses.
- If new strategy: evaluate its individual PF. If < 1.0 after 20+ trades, disable it.

---

## Failure Mode 4: Too Few Trades (< 200 over 6 years)

### Diagnosis
1. Which strategies are underperforming their expected trade count?
2. Are filters too strict?
3. Is the Event Shield blocking too many periods?

### Expected Trade Counts (from V27.18)
- Phantom: ~164 trades
- NoiseBreakout: ~65 trades
- Warden: ~8 trades (selective)
- Nexus: ~4 trades (elite sniper)
- Reaper: ~24 trades
- Mean Rev: ~17 trades
- Titan: ~7 trades

### Action Path
- If a strategy has 0 trades: check for bugs (V27.11 Warden lesson). Verify entry conditions can actually trigger.
- If total trades < 200: check Event Shield windows. V27.14 blocked 190 trades with $500 daily cap.
- If one strategy dropped: check its specific entry conditions. Did a parameter change make it impossible to trigger?

---

## Failure Mode 5: Compilation Error

### Common MQL4 Compilation Errors
1. **Undeclared identifier** — Variable used before declaration. Check extern/input declarations.
2. **Unexpected token** — Missing semicolon, bracket, or parenthesis.
3. **Type mismatch** — Assigning string to int, double to string, etc.
4. **Array out of range** — Buffer accessed beyond its size. Check ArrayResize.
5. **Function not defined** — Calling a function that doesn't exist or is in wrong scope.

### Action Path
1. Read the error message. It tells you the line number.
2. Go to that line. The error is usually at or just before the reported line.
3. Fix ONE error at a time. Recompile. Don't try to fix multiple at once.
4. If the error is in code you didn't change: DO NOT TOUCH IT. Report to Ryan.

---

## Failure Mode 6: Backtest Runs But Opens No Trades

### Diagnosis
1. Check the Experts tab for errors
2. Verify the EA is attached to EURUSD H4 chart
3. Check if any filters are blocking ALL entries (Event Shield covering entire period?)
4. Verify indicator data is available for the backtest period

### Action Path
- If Experts tab has errors: fix the code first
- If no errors but no trades: add Print() statements to entry conditions to see where it's blocking
- Check: is the start date within the backtest range?
- Check: is the Magic Number set correctly?

---

## Decision Tree: Backtest Failed, What Now?

```
Backtest Result: REGRESSION
    │
    ├── Profit dropped > $5K?
    │   ├── One strategy regressed → Revert that strategy's change
    │   └── All strategies regressed → Revert shared infrastructure change
    │
    ├── DD increased > 5%?
    │   ├── Event-driven → Fix Event Shield dates
    │   ├── Sizing-driven → Tighten Profit-Lock
    │   └── Strategy-specific → Evaluate disable vs. rein in
    │
    ├── PF dropped < 1.50?
    │   ├── Win rate dropped → Tighten entry filters
    │   ├── R:R worsened → Review SL/TP
    │   └── New strategy dragging → Evaluate individual PF
    │
    └── Trade count wrong?
        ├── Too few → Check filters, Event Shield, bugs
        └── Too many → Check if filters loosened accidentally
```
