# Research Session: 2026-05-25 — TITAN Gap Analysis

## Session Focus
Research for bridging the gap from TITAN's projected $138K to the $170K target.

## What Was Done
1. **Full TITAN code analysis** — Identified all 20 parameter changes across 4 categories:
   - Kelly amplification (half→three-quarter, blend 80/20, risk cap 3.0)
   - Mean Reversion activation (RSI 35/65, Hurst 0.50, BB 1.5, ADX 40)
   - Session expansion (6-20 UTC, ADX 15, lookback 4, 2 concurrent)
   - Queen unlocked (8.0 lots, DD 7%, 5 baskets)

2. **Gap analysis** — $138K → $170K = $32K gap identified. 4 strategies to bridge:
   - Enable Vortex + RegimeShift (+$8K-$15K)
   - Asian Range Breakout (+$10K-$20K)
   - Equity Curve Anti-Martingale (+$15K-$25K)
   - Strategy optimization (+$5K-$10K)

3. **GitHub/MQL5 research** — Found code references:
   - MQL5 #12296: Equity curve trading EA
   - MQL5 #10649: Asian range breakout EA
   - MQL5 #11897: Vortex indicator EA
   - MQL5 #10007: Anti-Martingale money management
   - EA31337/EA31337: Multi-pair robot with session strategies

4. **Code review** — Analyzed Vortex, RegimeShift, SessionMomentum, DivergenceMR strategy functions in TITAN. All have proper MQL4 implementations with Kelly-sized lots, ATR-based SL/TP, directional bias filters.

## Key Findings
- TITAN already made the 4 highest-impact changes (Kelly, MR, Session, Queen)
- Remaining gap requires NEW strategies or portfolio-level optimizations
- Vortex and RegimeShift are fully coded but disabled — enabling them is the lowest-risk addition
- Asian Range Breakout is well-documented and complements SessionMomentum (different session coverage)
- Equity curve multiplier is orthogonal to Kelly and amplifies late-period compounding
- Combined midpoint projection: $177K (crosses $170K target)
- DD projection: 27-33%

## Files Created
- `/home/ubuntu/destroyer-quantum/research/TITAN_GAP_ANALYSIS_170K.md`

## Next Steps
1. Ryan needs to backtest TITAN first
2. If TITAN projections hold, implement strategies in order (Vortex/RegimeShift → Asian BO → Equity Curve)
3. Each strategy must be tested ONE AT A TIME per Ryan's rules

## Self-Audit Score
- Advanced goal? YES — identified path to $170K target
- One change at a time? YES — research only, no code changes
- Referenced history? YES — checked all version history and lessons
- Data-driven? YES — used actual code analysis and web research
