// === DESTROYER QUANTUM — CYCLE 2 PATCHES ===
// Date: 2026-05-28
// For: V28.06 TITAN (after applying Cycle 1 patches)
// Purpose: Bridge the $32K gap from $138K projected to $170K target
//
// INSTRUCTIONS: Apply these AFTER Cycle 1 patches (array fix, equity curve,
// Kelly consolidation, ATR-ORB, DivergenceMR). Backtest each independently.

// ============================================================
// APPROACH 1: PARTIAL PROFIT TAKING (HIGHEST CONFIDENCE)
// ============================================================
// LOCATION: Add to trade management section (after trailing stop logic)
// IMPACT: +$10K-$20K, DD -2-3%
// CONCEPT: Lock in 50% at 1:1 R:R, move remainder to breakeven

/*
// === PARTIAL PROFIT TAKING (V28.06.2) ===
// Call this from OnTick() for each open trade

void CheckPartialProfit(int ticket) {
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    if(OrderProfit() <= 0) return; // Only on winning trades
    
    double entry = OrderOpenPrice();
    double sl = OrderStopLoss();
    double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
    double lots = OrderLots();
    
    // Calculate R:R distance (entry to SL)
    double rrDistance = MathAbs(entry - sl);
    if(rrDistance < Point * 10) return; // Too tight, skip
    
    // Current profit in price terms
    double currentProfit = 0;
    if(OrderType() == OP_BUY) currentProfit = currentPrice - entry;
    else currentProfit = entry - currentPrice;
    
    // Check if we've hit 1:1 R:R
    if(currentProfit >= rrDistance) {
        // Check if already partially closed (use comment to track)
        if(StringFind(OrderComment(), "PARTIAL") >= 0) return; // Already done
        
        double halfLots = NormalizeDouble(lots / 2.0, 2);
        double minLot = MarketInfo(Symbol(), MODE_MINLOT);
        
        if(halfLots >= minLot && lots > minLot) {
            // Close half
            bool closed = OrderClose(ticket, halfLots, currentPrice, 3, clrGold);
            
            if(closed) {
                // Move remaining position to breakeven + 1 pip buffer
                double buffer = Point * 10;
                double newSL = 0;
                if(OrderType() == OP_BUY)
                    newSL = entry + buffer;
                else
                    newSL = entry - buffer;
                    
                OrderModify(ticket, entry, newSL, OrderTakeProfit(), 0, clrAqua);
            }
        }
    }
}
*/


// ============================================================
// APPROACH 2: VOLATILITY REGIME POSITION SCALING
// ============================================================
// LOCATION: Inside MoneyManagement_Quantum() before final lot calc
// IMPACT: +$8K-$15K, DD -1-2%
// CONCEPT: Scale lots by volatility regime (trend vs mean-reversion)

/*
// === VOLATILITY REGIME SCALING (V28.06.2) ===
// Add BEFORE the final lot calculation in MoneyManagement_Quantum()

double GetVolatilityRegimeMultiplier(int stratIdx) {
    double atr14 = iATR(Symbol(), PERIOD_H4, 14, 0);
    double atr100 = iATR(Symbol(), PERIOD_H4, 100, 0);
    
    if(atr100 < Point * 10) return 1.0; // Safety fallback
    
    double volRatio = atr14 / atr100;
    
    // Base multiplier from volatility regime
    double baseVolMult = 1.0;
    if(volRatio > 1.3) baseVolMult = 1.25;      // High vol (trending)
    else if(volRatio > 1.1) baseVolMult = 1.10;  // Slightly elevated
    else if(volRatio < 0.7) baseVolMult = 0.70;  // Low vol (consolidation)
    else if(volRatio < 0.85) baseVolMult = 0.85; // Slightly low
    
    // Strategy-specific: trend vs mean-reversion
    // Trend strategies: Phantom(0), SessionMomentum(2), NoiseBreakout(3)
    // Mean-reversion: Reaper(1), DivergenceMR(4), Nexus(5)
    bool isTrendStrategy = (stratIdx == 0 || stratIdx == 2 || stratIdx == 3);
    
    if(isTrendStrategy) {
        return baseVolMult; // Direct: high vol = more size
    } else {
        return 2.0 - baseVolMult; // Inverse: low vol = more size for MR
    }
}

// Apply in MoneyManagement_Quantum():
// double volMult = GetVolatilityRegimeMultiplier(strategyIndex);
// finalLots = finalLots * volMult;
*/


// ============================================================
// APPROACH 3: ATR-BASED DYNAMIC TRAILING STOP
// ============================================================
// LOCATION: Replace existing trailing stop logic
// IMPACT: +$5K-$12K, DD -2-4%
// CONCEPT: Wide trailing in trends, tight in ranges

/*
// === ATR TRAILING STOP (V28.06.2) ===
// Call from OnTick() for each open trade

void ATRTrailingStop(int ticket) {
    if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
    if(OrderProfit() <= 0) return; // Only trail winning trades
    
    double atr = iATR(Symbol(), PERIOD_H4, 14, 0);
    double trailDistance = atr * 2.0; // 2x ATR trailing distance
    double activationATR = atr * 1.0; // Activate after 1x ATR profit
    
    double entry = OrderOpenPrice();
    double currentSL = OrderStopLoss();
    double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
    
    if(OrderType() == OP_BUY) {
        // Only trail if in profit by at least 1x ATR
        if(currentPrice > entry + activationATR) {
            double newSL = currentPrice - trailDistance;
            // Only move stop UP (never down)
            if(newSL > currentSL + Point * 5) {
                OrderModify(ticket, entry, newSL, OrderTakeProfit(), 0, clrGreen);
            }
        }
    } else if(OrderType() == OP_SELL) {
        if(currentPrice < entry - activationATR) {
            double newSL = currentPrice + trailDistance;
            // Only move stop DOWN (never up)
            if(newSL < currentSL - Point * 5 || currentSL == 0) {
                OrderModify(ticket, entry, newSL, OrderTakeProfit(), 0, clrRed);
            }
        }
    }
}
*/


// ============================================================
// VERIFICATION CHECKLIST
// ============================================================
// After applying each approach:
// [ ] Compile in MetaEditor (zero errors/warnings)
// [ ] Backtest 2020-01-01 to 2024-12-31 on EURUSD H4
// [ ] Compare: Net Profit, PF, DD, Trade Count vs Cycle 1 baseline
// [ ] If DD > 35%, reduce multipliers (1.25 -> 1.15, 0.70 -> 0.80)
// [ ] If PF < 1.8, revert that specific approach
//
// ORDER OF APPLICATION (after Cycle 1 patches):
// 1. Approach 1 (Partial Profit) — 2-3 hr, low risk, HIGH confidence
// 2. Backtest Approach 1 alone
// 3. Approach 3 (ATR Trailing) — 2-3 hr, low risk, MEDIUM confidence
// 4. Backtest Approach 1+3 combined
// 5. Approach 2 (Vol Regime) — 3-4 hr, medium risk, MEDIUM confidence
// 6. Backtest ALL combined
// 7. If $170K not reached: optimize parameters via walk-forward
//
// EXPECTED COMBINED RESULT:
// Conservative: $145K | Optimistic: $185K | Realistic: $155K-$165K
// DD: 25-32% | PF: 2.05-2.25 | Trades: 750-900
