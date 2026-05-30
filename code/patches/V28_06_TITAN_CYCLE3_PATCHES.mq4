// === DESTROYER QUANTUM — CYCLE 3 PATCHES ===
// Date: 2026-05-28
// For: V28.06 TITAN (after applying Cycle 1 + Cycle 2 patches)
// Purpose: Additional optimizations to bridge the remaining gap to $170K
//
// INSTRUCTIONS: Apply these AFTER Cycle 1 + Cycle 2 patches are backtested.
// Each approach should be backtested independently before combining.

// ============================================================
// APPROACH 1: REAPER ADAPTIVE GRID SPACING
// ============================================================
// LOCATION: Replace fixed Reaper grid spacing calculation
// IMPACT: +$8K-$15K, DD -3-5%
// CONCEPT: Use ATR to dynamically set grid distance

/*
// === REAPER ADAPTIVE GRID (V28.06.3) ===
// Call this instead of using fixed grid spacing for Reaper Protocol

double GetAdaptiveGridSpacing() {
    double atr14 = iATR(Symbol(), PERIOD_H4, 14, 0);
    double atr100 = iATR(Symbol(), PERIOD_H4, 100, 0);

    if(atr100 < Point * 10) return 30 * Point * 10; // Safety: default 30 pips

    // Base grid = 0.5x ATR (half the average H4 range)
    double baseGrid = atr14 * 0.5;

    // Volatility adjustment
    double volRatio = atr14 / atr100;
    if(volRatio > 1.3) baseGrid *= 1.3;      // Widen grid in high vol
    else if(volRatio > 1.1) baseGrid *= 1.15; // Slightly wider
    else if(volRatio < 0.7) baseGrid *= 0.8;  // Tighten in low vol
    else if(volRatio < 0.85) baseGrid *= 0.9; // Slightly tighter

    // Enforce minimum (prevent micro-grids)
    double minGrid = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point * 2;
    if(minGrid < Point * 10) minGrid = Point * 10; // At least 1 pip

    return MathMax(baseGrid, minGrid);
}

// Also adapt lot multiplier based on grid depth
// Reduces aggression at deeper levels (fewer blowups)
double GetAdaptiveLotMultiplier(int gridLevel) {
    // Level 0: 1.4x, Level 1: 1.3x, Level 2: 1.2x, Level 3+: 1.1x
    return MathMax(1.1, 1.4 - (gridLevel * 0.1));
}

// USAGE: In Reaper Protocol entry logic, replace:
//   double gridSpacing = [fixed value];
// WITH:
//   double gridSpacing = GetAdaptiveGridSpacing();
//
// And replace:
//   double lotMult = [fixed LotMultiplier];
// WITH:
//   double lotMult = GetAdaptiveLotMultiplier(currentGridLevel);
*/


// ============================================================
// APPROACH 2: STRATEGY-SPECIFIC SESSION FILTERS
// ============================================================
// LOCATION: Add to each strategy's entry check before trade execution
// IMPACT: +$3K-$8K, DD -2-3%
// CONCEPT: Skip low-quality Asian session trades

/*
// === SESSION FILTER (V28.06.3) ===
// Call this before each strategy's entry logic

bool IsOptimalTradingSession(int strategyIndex) {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int hour = dt.hour;
    int dow = dt.day_of_week;

    // No trading on Sunday or Friday after 20:00
    if(dow == 0 || (dow == 5 && hour >= 20)) return false;

    // Strategy-specific session windows
    switch(strategyIndex) {
        case 0: // Phantom -- London + NY only (07:00-20:00 server time)
            return (hour >= 7 && hour < 20);

        case 1: // Reaper -- Extended but skip Asian (06:00-21:00)
            return (hour >= 6 && hour < 21);

        case 2: // SessionMomentum -- already session-filtered
            return true;

        case 3: // NoiseBreakout -- London + NY overlap only (08:00-16:00)
            return (hour >= 8 && hour < 16);

        case 4: // DivergenceMR -- London session (07:00-16:00)
            return (hour >= 7 && hour < 16);

        case 5: // Nexus -- NY session only (13:00-20:00)
            return (hour >= 13 && hour < 20);

        default:
            return true;
    }
}

// USAGE: In each strategy's entry function, add at the top:
//   if(!IsOptimalTradingSession(strategyIndex)) return;
//
// This is a 3-line addition to each strategy function.
*/


// ============================================================
// APPROACH 3: PROGRESSIVE WIN STREAK SIZING (PER-STRATEGY)
// ============================================================
// LOCATION: Add to MoneyManagement_Quantum() after volatility regime multiplier
// IMPACT: +$8K-$15K, DD -2-4%
// CONCEPT: Scale lots per-strategy based on consecutive wins/losses

/*
// === WIN STREAK SIZING (V28.06.3) ===
// Add to global declarations:
int g_stratConsecWins[17] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int g_stratConsecLosses[17] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

// Call this when a trade closes (in OnTradeClose or equivalent)
void UpdateStrategyStreak(int stratIdx, bool isWin) {
    if(stratIdx < 0 || stratIdx >= 17) return; // Safety

    if(isWin) {
        g_stratConsecWins[stratIdx]++;
        g_stratConsecLosses[stratIdx] = 0;
    } else {
        g_stratConsecLosses[stratIdx]++;
        g_stratConsecWins[stratIdx] = 0;
    }
}

// Call this in MoneyManagement_Quantum() to get the streak multiplier
double GetWinStreakMultiplier(int stratIdx) {
    if(stratIdx < 0 || stratIdx >= 17) return 1.0;

    int wins = g_stratConsecWins[stratIdx];
    int losses = g_stratConsecLosses[stratIdx];

    // Win streak amplification (max 1.5x at 5+ wins)
    if(wins >= 5) return 1.50;
    if(wins >= 4) return 1.40;
    if(wins >= 3) return 1.30;
    if(wins >= 2) return 1.15;

    // Loss streak reduction (min 0.5x at 4+ losses)
    if(losses >= 4) return 0.50;
    if(losses >= 3) return 0.65;
    if(losses >= 2) return 0.80;

    return 1.0; // Neutral
}

// USAGE: In MoneyManagement_Quantum(), add after volatility regime multiplier:
//   double streakMult = GetWinStreakMultiplier(strategyIndex);
//   finalLots = finalLots * streakMult;
*/


// ============================================================
// APPROACH 4: FVG STRATEGY INTEGRATION
// ============================================================
// LOCATION: Wire the existing FVG_Strategy_Implementation.mq4 into main EA
// IMPACT: +$5K-$15K, DD +1-2%
// CONCEPT: Add institutional order flow strategy (FVG + liquidity sweeps)
//
// The FVG code is already complete at:
// /home/ubuntu/destroyer-quantum/code/FVG_Strategy_Implementation.mq4
//
// Integration steps:
// 1. Copy the FVG struct definition and globals into main EA
// 2. Add the FVG functions (ScanForFVGs, AddFVG, UpdateFVG_Mitigation, etc.)
// 3. Add magic 9007 to IsOurMagicNumber()
// 4. Expand g_stratProfits from [17] to [19] (add index 18 for FVG)
// 5. Call ScanForFVGs() on new H4 bar
// 6. Call ExecuteFVGTrade() in OnTick()
// 7. Add FVG inputs to EA's input section
//
// NOTE: FVG uses London/NY sessions only (already filtered in code)
// NOTE: FVG uses EMA trend alignment (already in code)
// NOTE: FVG uses ATR-based SL/TP (already in code)


// ============================================================
// VERIFICATION CHECKLIST
// ============================================================
// After applying each approach:
// [ ] Compile in MetaEditor (zero errors/warnings)
// [ ] Backtest 2020-01-01 to 2024-12-31 on EURUSD H4
// [ ] Compare: Net Profit, PF, DD, Trade Count vs Cycle 2 baseline
// [ ] If DD > 35%, reduce multipliers
// [ ] If PF < 1.8, revert that specific approach
//
// ORDER OF APPLICATION (after Cycle 2 patches):
// 1. FVG Integration (code ready, just wire in) -- 2-3 hr, low risk
// 2. Backtest FVG alone
// 3. Reaper Adaptive Grid -- 3-4 hr, medium risk
// 4. Backtest FVG + Adaptive Grid
// 5. Session Filters -- 1-2 hr, low risk
// 6. Backtest all three
// 7. Win Streak Sizing -- 2-3 hr, medium risk
// 8. Backtest ALL combined
// 9. Walk-forward optimization on multiplier parameters
//
// EXPECTED COMBINED RESULT:
// Conservative: $155K | Optimistic: $185K | Realistic: $160K-$175K
// DD: 25-32% | PF: 2.05-2.30 | Trades: 650-850
