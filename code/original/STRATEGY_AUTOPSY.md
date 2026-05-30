# VENDETTA $64K — STRATEGY AUTOPSY
# Date: 2026-05-28

## THE CORE PROBLEM
Phantom makes $28,397 (76% of all profit). Without Phantom, the system makes $9K in 6 years.
That's a single point of failure. We need EVERY strategy contributing.

## PER-STRATEGY DIAGNOSTIC

### CARRYING THE SYSTEM
| Strategy | Trades | Net Profit | PF | Problem |
|----------|--------|------------|-----|---------|
| Phantom | 170 | $28,397 | 1.57 | None — this is what GOOD looks like |

### WORKING BUT UNDERPERFORMING
| Strategy | Trades | Net Profit | PF | Problem |
|----------|--------|------------|-----|---------|
| Reaper Protocol | 304 | $1,660 | 1.12 | PF too low — wins barely cover losses |
| NoiseBreakout | 51 | $2,758 | 1.85 | Good PF but DD is $21K — position sizing too large |
| AetherGap | 145 | $4,202 | 1.06 | PF barely above 1 — needs tighter entries |

### BARELY ALIVE (under-trading)
| Strategy | Trades | Net Profit | PF | Problem |
|----------|--------|------------|-----|---------|
| SessionMomentum | 2 | $1,441 | 999 | 5 stacked filters — almost never fires |
| Nexus | 4 | $695 | 2.70 | ATR compression + directional bias + Reaper gate — too selective |
| Silicon-X | 14 | $185 | 4.63 | Grid system, low frequency by design |
| Mean Reversion | 1 | $30 | N/A | 1 trade in 6 years — effectively dead |

### DEAD (0 trades despite being enabled)
| Strategy | Trades | Status | Problem |
|----------|--------|--------|---------|
| Titan | 0 | Enabled | Chimera Protocol too complex — 100-bar ATR stats + volatility filter |
| Warden | 0 | Enabled | Unknown — need to check execution logic |
| Market Microstructure | 0 | Enabled | Unknown — need to check |
| Apex | 0 | Enabled | Unknown — need to check |
| MathReversal | 0 | Enabled | Unknown — need to check |

### DISABLED
| Strategy | Reason |
|----------|--------|
| Vortex | false |
| RegimeShift | false |
| LiquiditySweep | CUT — PF 0.84, negative EV |

### LOSING MONEY
| Strategy | Trades | Net Profit | PF | Problem |
|----------|--------|------------|-----|---------|
| Spectre | 1 | -$1,990 | 0 | 1 trade, lost — too early to judge |

## ROOT CAUSES

### 1. FILTER STACKING
Most strategies have 3-5 filters that ALL must pass:
- H4 timeframe (OK)
- Time filter (London/NY hours only)
- ADX threshold
- Directional bias check
- Strategy health check
- Spread filter
- Cross-strategy gate (don't oppose Reaper)

Each filter individually is reasonable. Together they make trades almost impossible.

### 2. IsStrategyHealthy() KILLING STRATEGIES
The Queen health check can disable strategies that underperform. But with 0 trades, there's no data to judge — chicken and egg problem.

### 3. CROSS-STRATEGY GATES
Nexus won't trade if Reaper has opposing positions. This creates dependency — if Reaper is in a long trade, Nexus can't go short even if its signal is perfect.

### 4. SINGLE STRATEGY CONCENTRATION
Phantom = 76% of profit. If Phantom's edge degrades, the entire system collapses.

## ACTION PLAN TO HIT $75K

### PHASE 1: UNLOCK THE DEAD STRATEGIES
1. Diagnose WHY Titan, Warden, Microstructure, Apex, MathReversal have 0 trades
2. Loosen entry filters — not remove, just widen thresholds
3. Add logging so we can see what's being rejected and why

### PHASE 2: BOOST UNDER-TRADERS
4. SessionMomentum: Remove or widen time filter, lower ADX threshold
5. Nexus: Reduce compression bars, remove Reaper gate
6. Mean Reversion: Check what's blocking it

### PHASE 3: FIX LOSERS
7. Reaper Protocol: Tighten entries (PF 1.12 is too thin)
8. NoiseBreakout: Reduce position size (DD $21K is too high)
9. Spectre: More data needed — leave enabled

### PHASE 4: UPGRADE PERFORMANCE REPORT
10. Replace Geneva V4.1 with comprehensive per-strategy diagnostic
11. Show: trade count, win rate, avg win/loss, DD, Sharpe, consecutive losses
12. Show: filter rejection counts (what's blocking trades)
13. Tag each strategy: [ELITE] / [PROFITABLE] / [BREAKEVEN] / [LOSING] / [DEAD]

### PHASE 5: ADD NEW STRATEGIES
14. Research strategies that complement existing ones
15. Focus on uncorrelated returns
16. Prop firm compatible (low DD, consistent profits)
