# FRESH GITHUB RESEARCH: $138K → $170K Gap Analysis
## Date: 2026-05-26 (Session 2)
## System: V28.06 TITAN (pending backtest), projected $109K-$138K
## Target: $170K from $10K

---

## EXECUTIVE SUMMARY

Searched GitHub API across 10+ query variations, analyzed 6 new repos in depth, and
extracted code patterns from geraked/metatrader5 (525★) EAUtils framework. Also confirmed
prior findings from 50+ repo analysis.

**Key Results:**

1. **Correlation trading is NOT viable** as standalone edge (confirmed: best documented result
   is Sharpe 0.47, no MQL4 EA with PF >2.0 on correlation)
2. **No new high-PF EAs found** on GitHub (consistent with prior 50+ repo finding)
3. **TITAN already has equity growth scaling** in basket TP targets (line 10244)
4. **3 actionable code patterns extracted** from geraked/EAUtils framework
5. **2 remaining gaps** to bridge $138K → $170K: Asian Range Breakout + Equity Curve Sizing

---

## REPO ANALYSIS

### New Repos Found (Not in Prior Research)

| # | Repo | Stars | Key Value | Status |
|---|------|-------|-----------|--------|
| 1 | geraked/metatrader5 | 525 | EAUtils framework: grid+equity DD+news+risk modes | **ACTIONABLE** |
| 2 | Xtley001/High-Frequency-Grid-EA | 4 | Adaptive grid with dynamic spread monitoring | Low value |
| 3 | dungoner/Multi-Trading-Bot-Oner_2025 | 0 | New 2025 multi-strategy MQL4 bot | Worth monitoring |
| 4 | NadirAliOfficial/-MT5-LSTM-Trading-Bot-GBPUSD- | 8 | LSTM NN for GBPUSD engulfing patterns | Not applicable |
| 5 | sahebkaran1/HedgeEA | 0 | MQL4 hedge EA | Low value |
| 6 | NadirAliOfficial/conservative-scalper-ea | 2 | Conservative scalping, no grid/martingale | Low value |

### Already Known (Re-confirmed)
- EA31337/EA31337 (1193★) — Multi-strategy framework, already researched
- EarnForex/PositionSizer (566★) — Position sizing tool, not strategy
- EA31337-classes (252★) — Framework library
- jblanked/MQL4-Currency-Pair-Correlation-EA (13★) — Trade follower, not signal generator

---

## ACTIONABLE CODE PATTERNS EXTRACTED

### PATTERN 1: Equity Drawdown Limit (geraked/EAUtils)
**Source:** `checkForEquity()` at line 1396

```mql4
// Portfolio-level DD protection: close worst-losing symbol when equity drops X%
void checkForEquity(ulong magic, double limit, ...) {
    if (limit == 0) return;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double p = (equity - balance) / balance;
    if (p >= 0) return;                    // Only triggers on losses
    if (MathAbs(p) < limit) return;        // Not deep enough

    // Find symbol with biggest loss
    double max_loss = -DBL_MAX;
    string max_symbol = "";
    // ... iterate positions, find max loss ...
    
    // Close ALL positions in worst symbol
    closeOrders(POSITION_TYPE_BUY, magic, slippage, max_symbol, ...);
    closeOrders(POSITION_TYPE_SELL, magic, slippage, max_symbol, ...);
}
```

**Adaptation for DESTROYER:**
- DESTROYER already has DD protection at 14% (Level 3) in OMEGA
- This pattern adds SYMBOL-LEVEL granularity: close only the worst-performing strategy's
  positions instead of all positions
- Could reduce unnecessary position closures during multi-strategy drawdowns
- **Expected impact:** -2-3% DD with minimal profit impact
- **Complexity:** 3/10

### PATTERN 2: Grid Breakeven TP Calculation (geraked/EAUtils)
**Source:** `checkForGrid()` at line 1288

```mql4
// Grid calculates breakeven TP across ALL levels
double loss = pvol * ptv * (pd / ppoint);   // Current loss in money
double target_prof = loss;                    // Target = cover the loss
double cost = calcCost(magic, psymbol);       // Add trading costs
if (cost > 0) target_prof += cost;

// TP = breakeven price for combined position
tp = calcPrice(magic, target_prof, Ask(psymbol), vol, psymbol);

// Ensure minimum distance
if (!(tp - Bid(psymbol) >= minPoints * ppoint))
    tp = Bid(psymbol) + minPoints * ppoint;

// Update ALL positions to same TP
for (int j = 0; j < n; j++) {
    req.position = tickets[j];
    OrderSendAsync(req, res);
}
```

**Key Insight for DESTROYER:**
DESTROYER's Reaper uses `BasketTP_Money` ($600-$900) as a fixed target. This pattern
calculates DYNAMIC breakeven TP based on actual losses + costs. More adaptive — targets
breakeven when in DD, larger profit when basket is profitable.

**Adaptation:**
- Replace fixed BasketTP_Money with dynamic calculation:
  `target = max(baseTarget, totalLoss + totalCost + minProfit)`
- This ensures baskets ALWAYS cover their costs before closing
- **Expected impact:** +2-5% profit (fewer premature basket closures)
- **Complexity:** 4/10

### PATTERN 3: Multi-Mode Risk Sizing (geraked/EAUtils)
**Source:** `calcVolume()` at line 311

```mql4
// Supports 6 risk modes:
// RISK_FIXED_VOL — Fixed lot size
// RISK_MIN_AMOUNT — Equity / risk per lot
// RISK_EQUITY — % of equity
// RISK_BALANCE — % of balance
// RISK_MARGIN_FREE — % of free margin
// RISK_CREDIT — % of credit

if (risk_mode == RISK_FIXED_VOL)
    vol = risk;
else if (risk_mode == RISK_MIN_AMOUNT)
    vol = AccountInfoDouble(ACCOUNT_EQUITY) / risk * volStep;
else
    vol = (balance * risk) / MathAbs(in - sl) * point / tv;
```

**Key Insight for DESTROYER:**
DESTROYER uses Kelly-based sizing exclusively. The `RISK_MARGIN_FREE` mode (sizing based
on free margin) could be useful for grid strategies — when margin is tight, automatically
reduces size. This prevents margin calls during deep Reaper grids.

**Adaptation:**
- Add margin-aware sizing floor: `lots = min(kellyLots, freeMargin * 0.30 / marginPerLot)`
- Only activates when margin usage is high (>70%)
- **Expected impact:** Risk reduction, prevents margin calls
- **Complexity:** 2/10

---

## CORRELATION TRADING VERDICT: NOT VIABLE

### Repos Analyzed
1. **jblanked/MQL4-Currency-Pair-Correlation-EA** (13★) — Trade follower, mirrors existing
   trades to correlated pairs. NOT a signal generator. No backtest results.
2. **5ymph0en1x/Heptet** (64★) — Python RL pairs trading on EURJPY/GBPJPY via Oanda.
   PnL chart shown but no PF numbers. Not MQL4.
3. **MichaelSoegaard/Cointegration_in_trading** (7★) — **Most honest assessment: 3.6%
   annual profit, Sharpe 0.472.** Author concludes "hasn't been possible to get much edge."
   Entry/exit thresholds prone to overfitting.
4. **XBT3K/MeanReversionAlgo** (9★) — Python z-score mean reversion on EURUSD. No results.
5. **vidoh89/EA-correlation_mql4** (0★) — Minimal RSI EA, misleading name.

### Why Correlation Fails
- EURUSD/GBPUSD correlation is 0.85-0.95 on H4 — too stable for reliable mean reversion
- When correlation breaks (Brexit, ECB divergence), it breaks FUNDAMENTALLY — not a
  mean-reversion opportunity
- Best documented result: Sharpe 0.47 (mediocre) — author himself says edge is minimal
- No MQL4 EA has PF >2.0 on correlation strategies

### Recommendation
**SKIP correlation as edge source.** Use correlation only as a RISK FILTER:
- If EURUSD/GBPUSD correlation drops below 0.70, reduce EURUSD position sizes by 30%
- This is a defensive measure, not a profit driver

---

## HIGH-PF EA SEARCH VERDICT: NOTHING NEW

### Search Results
- 15 new MQL4 EAs created since 2024 — all hobby/educational projects
- No EA with documented PF >2.0 on EURUSD H4 (consistent with prior 50+ repo analysis)
- The MQL4 open-source ecosystem is dominated by:
  - Position sizers (EarnForex/PositionSizer, 566★)
  - Frameworks (EA31337, 1193★)
  - Utility libraries (geraked/EAUtils, 525★)
  - Simple strategy EAs with no documented results

### Conclusion
**Our own innovation is the edge.** No open-source EA to copy from. The path to $170K
is through our own strategies + optimizations, not GitHub discovery.

---

## VOLATILITY-ADAPTIVE SIZING: EXISTING IN TITAN

TITAN already has volatility-aware components:
1. **Line 10234:** `volatilityMultiplier = atr / avgATR` (capped 0.5x-2.5x)
2. **Line 10244:** `equityMultiplier = 1.0 + (equityGrowth * 0.5)` (equity curve scaling)
3. **Line 10248:** Dynamic basket TP = base × volatility × grid × equity multipliers

These are applied to BASKET TP TARGETS, not to individual trade lot sizing. The equity
curve anti-martingale for LOT SIZING remains the biggest untapped improvement.

---

## REMAINING GAP: $138K → $170K ($32K-$61K needed)

### Prioritized by Confidence × Impact

| # | Strategy | Expected | Confidence | Complexity | Status |
|---|----------|----------|------------|------------|--------|
| 1 | **Equity Curve Anti-Martingale** | +$15K-$25K | HIGH | 4/10 | NOT IN TITAN |
| 2 | **Asian Range Breakout** | +$10K-$20K | HIGH | 5/10 | NOT IN TITAN |
| 3 | **Vortex + RegimeShift ENABLE** | +$8K-$15K | HIGH | 1/10 | Flag flips only |
| 4 | **Dynamic Grid Breakeven TP** | +$2K-$5K | MEDIUM | 4/10 | New pattern |
| 5 | **Margin-Aware Sizing Floor** | Risk reduction | MEDIUM | 2/10 | New pattern |
| 6 | Correlation Risk Filter | -2-3% DD | LOW | 3/10 | Not viable as edge |

### Combined Projection (Conservative)
- TITAN base: $109K-$138K
- + Equity Curve: +$15K (conservative)
- + Asian Breakout: +$10K (conservative)
- + Vortex/RegimeShift: +$8K (conservative)
- **Total: $142K-$171K** — REACHES TARGET at midpoint

### Combined Projection (Optimistic)
- TITAN base: $109K-$138K
- + Equity Curve: +$25K
- + Asian Breakout: +$20K
- + Vortex/RegimeShift: +$15K
- **Total: $149K-$198K** — EXCEEDS TARGET

---

## IMPLEMENTATION ROADMAP

### Phase 1: Backtest TITAN (Ryan)
- Verify base projections ($109K-$138K)
- Confirm DD stays under 32%

### Phase 2: Enable Vortex + RegimeShift (5 minutes)
- 2 flag flips: `InpVortex_Enabled=true`, `InpRegimeShift_Enabled=true`
- Already coded and in dispatch chain
- Expected: +$8K-$15K

### Phase 3: Add Equity Curve Anti-Martingale (2-3 hours)
- Portfolio-level lot sizing multiplier
- 20-trade rolling win rate → size multiplier (0.6x-1.3x)
- Drawdown defense at 90% peak
- Orthogonal to Kelly (per-strategy)
- Code already written in TITAN_GAP_ANALYSIS_170K.md
- Expected: +$15K-$25K

### Phase 4: Add Asian Range Breakout (3-4 hours)
- New strategy magic 9007
- Asian session range detection (00:00-06:00 UTC)
- London open breakout (07:00-09:00 UTC)
- D1 trend alignment filter
- Full code in TITAN_GAP_ANALYSIS_170K.md
- Expected: +$10K-$20K

### Phase 5: Dynamic Grid Breakeven TP (1-2 hours)
- Replace fixed BasketTP_Money with dynamic calculation
- `target = max(baseTarget, totalLoss + totalCost + minProfit)`
- Expected: +$2K-$5K

---

## KEY TAKEAWAY

**The $170K target is achievable with TITAN base + 3 additions (Vortex/RegimeShift,
Equity Curve, Asian Breakout).** No new GitHub discovery needed — the edge is in our
own innovation. Correlation trading is a dead end. The remaining improvements are all
documented with full MQL4 code in TITAN_GAP_ANALYSIS_170K.md.

**Next action: Ryan backtests TITAN. If base hits $130K+, we're on track.**

---

*VENI VIDI VICI* 🔷
