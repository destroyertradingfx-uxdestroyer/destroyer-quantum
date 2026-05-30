//+------------------------------------------------------------------+
//| DESTROYER QUANTUM — Exit Management Module v1.0                  |
//| Cycle 17 — Ready for integration into V28.17+ RECKONING         |
//|                                                                  |
//| FEATURES:                                                        |
//|   1. Partial Close + Breakeven (at configurable R:R)            |
//|   2. Chandelier Exit Adaptive Trailing                           |
//|   3. Equity Curve Drawdown-Based Lot Scaling                    |
//|   4. Time-Decay Exit (close stale trades)                       |
//|   5. Session-Aware Lot Sizing                                   |
//|   6. Anti-Martingale Win Streak Sizing                          |
//|                                                                  |
//| HOW TO INTEGRATE:                                                |
//|   1. Copy this file to your MT4 Experts folder                  |
//|   2. Add #include "DQ_ExitManagement.mqh" to your EA           |
//|   3. Call DQ_InitExitManagement() in OnInit()                   |
//|   4. Call DQ_ManageExits() at the START of OnTick()             |
//|   5. Use DQ_GetFinalLotMultiplier() in your lot calculations    |
//+------------------------------------------------------------------+

#ifndef DQ_EXIT_MANAGEMENT_MQH
#define DQ_EXIT_MANAGEMENT_MQH

#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

// === PARTIAL CLOSE ===
input string   SEC_PARTIAL     = "======= PARTIAL CLOSE ======";     //---------------
input bool     DQ_UsePartialClose     = true;     // Enable partial close
input double   DQ_PartialClosePct     = 50.0;     // % of position to close at TP1
input double   DQ_PartialCloseRR      = 1.0;      // R:R ratio to trigger partial close
input bool     DQ_MoveSLToBE          = true;     // Move SL to breakeven after partial

// === ADAPTIVE TRAILING ===
input string   SEC_TRAIL       = "======= ADAPTIVE TRAILING ======"; //---------------
input bool     DQ_UseAdaptiveTrail    = true;     // Enable adaptive trailing
input int      DQ_TrailMethod         = 2;        // 0=Fixed, 1=ATR, 2=Chandelier
input double   DQ_TrailATRMult        = 2.5;     // ATR multiplier for trail distance
input int      DQ_TrailATRPeriod      = 14;       // ATR period
input int      DQ_TrailChandelierPer  = 22;       // Chandelier lookback bars
input double   DQ_TrailFixedPips      = 40.0;     // Fixed trail pips (method 0)
input ENUM_TIMEFRAMES DQ_TrailTimeframe = PERIOD_H4; // Timeframe for trailing indicators

// === EQUITY CURVE SCALING ===
input string   SEC_EQUITY      = "======= EQUITY SCALING ======";    //---------------
input bool     DQ_UseEquityScaling    = true;     // Enable equity curve scaling
input double   DQ_EquityDDStart       = 0.05;     // Start scaling at 5% DD
input double   DQ_EquityDDMax         = 0.20;     // Max DD for scaling (20%)
input double   DQ_EquityScaleMin      = 0.30;     // Minimum lot multiplier at max DD

// === TIME-DECAY EXIT ===
input string   SEC_TIMEEXIT    = "======= TIME EXIT ======";        //---------------
input bool     DQ_UseTimeExit         = true;     // Enable time-decay exit
input int      DQ_TimeExitBars        = 12;       // Exit after N H4 bars if not profitable
input double   DQ_TimeExitMinProfit   = 0.0;      // Min profit % to keep trade open

// === SESSION-AWARE SIZING ===
input string   SEC_SESSION     = "======= SESSION SIZING ======";   //---------------
input bool     DQ_UseSessionSizing    = true;     // Enable session-aware sizing
input double   DQ_SessionAsian        = 0.80;     // Asian session multiplier
input double   DQ_SessionLondonAM     = 1.20;     // London AM multiplier
input double   DQ_SessionNYOverlap    = 1.30;     // NY overlap multiplier
input double   DQ_SessionNYPM         = 1.10;     // NY PM multiplier
input double   DQ_SessionDeadZone     = 0.00;     // Dead zone multiplier (21-00)

// === ANTI-MARTINGALE ===
input string   SEC_ANTIMART    = "======= ANTI-MARTINGALE ======";   //---------------
input bool     DQ_UseAntiMartingale   = true;     // Enable streak-based sizing
input double   DQ_AM_WinStreak3       = 1.30;     // 3+ consecutive wins multiplier
input double   DQ_AM_WinStreak2       = 1.15;     // 2 consecutive wins multiplier
input double   DQ_AM_LossStreak3      = 0.50;     // 3+ consecutive losses multiplier
input double   DQ_AM_LossStreak2      = 0.70;     // 2 consecutive losses multiplier

//+------------------------------------------------------------------+
//| GLOBAL STATE                                                     |
//+------------------------------------------------------------------+

double DQ_g_peakEquity = 0;
int    DQ_g_consecutiveWins = 0;
int    DQ_g_consecutiveLosses = 0;

// Partial close tracking
#define DQ_MAX_PARTIAL_TRACK 200
int    DQ_g_partialTickets[DQ_MAX_PARTIAL_TRACK];
int    DQ_g_partialCount = 0;

// Trailing state
struct DQ_TrailState {
    int    ticket;
    double currentSL;
    bool   beApplied;
};
#define DQ_MAX_TRAIL_TRACK 100
DQ_TrailState DQ_g_trailStates[DQ_MAX_TRAIL_TRACK];
int    DQ_g_trailCount = 0;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
void DQ_InitExitManagement() {
    DQ_g_peakEquity = AccountEquity();
    DQ_g_partialCount = 0;
    DQ_g_trailCount = 0;
    DQ_g_consecutiveWins = 0;
    DQ_g_consecutiveLosses = 0;
    ArrayInitialize(DQ_g_partialTickets, 0);
    Print("[DQ-EM] Exit Management initialized. Peak equity: ", DoubleToStr(DQ_g_peakEquity, 2));
}

//+------------------------------------------------------------------+
//| MAIN ENTRY POINT — Call at start of OnTick()                     |
//+------------------------------------------------------------------+
void DQ_ManageExits(int magicBase, int magicRange) {
    DQ_ManagePartialClose(magicBase, magicRange);
    DQ_ManageAdaptiveTrailing(magicBase, magicRange);
    DQ_ManageTimeExit(magicBase, magicRange);
}

//+------------------------------------------------------------------+
//| MODULE 1: PARTIAL CLOSE + BREAKEVEN                             |
//+------------------------------------------------------------------+
void DQ_ManagePartialClose(int magicBase, int magicRange) {
    if (!DQ_UsePartialClose) return;
    
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() != Symbol()) continue;
        if (OrderMagicNumber() < magicBase || OrderMagicNumber() > magicBase + magicRange) continue;
        
        int ticket = OrderTicket();
        double openPrice = OrderOpenPrice();
        double currentSL = OrderStopLoss();
        double lots = OrderLots();
        int type = OrderType();
        
        // Check if already partially closed
        if (DQ_IsPartiallyClosed(ticket)) continue;
        
        // Calculate current R:R achieved
        double initialRisk = 0;
        double currentProfit = 0;
        
        if (type == OP_BUY) {
            if (currentSL > 0 && currentSL < openPrice) {
                initialRisk = openPrice - currentSL;
                currentProfit = Bid - openPrice;
            }
        } else if (type == OP_SELL) {
            if (currentSL > 0 && currentSL > openPrice) {
                initialRisk = currentSL - openPrice;
                currentProfit = openPrice - Ask;
            }
        }
        
        if (initialRisk <= 0) continue;
        
        double achievedRR = currentProfit / initialRisk;
        
        if (achievedRR >= DQ_PartialCloseRR) {
            double lotsToClose = NormalizeDouble(lots * DQ_PartialClosePct / 100.0, 2);
            double minLot = MarketInfo(Symbol(), MODE_MINLOT);
            double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
            
            lotsToClose = MathFloor(lotsToClose / lotStep) * lotStep;
            if (lotsToClose < minLot) lotsToClose = minLot;
            
            double remainingLots = lots - lotsToClose;
            if (remainingLots < minLot) lotsToClose = lots - minLot;
            if (lotsToClose < minLot) continue;
            
            double closePrice = (type == OP_BUY) ? Bid : Ask;
            if (OrderClose(ticket, lotsToClose, closePrice, 3, clrYellow)) {
                DQ_MarkPartiallyClosed(ticket);
                Print("[DQ-EM] Partial close: ticket=", ticket, " lots=", DoubleToStr(lotsToClose, 2));
                
                if (DQ_MoveSLToBE) {
                    double beSL = openPrice;
                    double spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
                    if (type == OP_BUY) beSL += spread;
                    else beSL -= spread;
                    
                    if (OrderSelect(ticket, SELECT_BY_TICKET)) {
                        if (OrderStopLoss() != beSL) {
                            OrderModify(ticket, openPrice, beSL, OrderTakeProfit(), 0, clrAqua);
                            Print("[DQ-EM] SL moved to breakeven: ticket=", ticket);
                        }
                    }
                }
            }
        }
    }
}

bool DQ_IsPartiallyClosed(int ticket) {
    for (int i = 0; i < DQ_g_partialCount; i++) {
        if (DQ_g_partialTickets[i] == ticket) return true;
    }
    return false;
}

void DQ_MarkPartiallyClosed(int ticket) {
    if (DQ_g_partialCount < DQ_MAX_PARTIAL_TRACK) {
        DQ_g_partialTickets[DQ_g_partialCount] = ticket;
        DQ_g_partialCount++;
    }
}

//+------------------------------------------------------------------+
//| MODULE 2: ADAPTIVE TRAILING STOP                                |
//+------------------------------------------------------------------+
void DQ_ManageAdaptiveTrailing(int magicBase, int magicRange) {
    if (!DQ_UseAdaptiveTrail) return;
    
    double atr = iATR(Symbol(), DQ_TrailTimeframe, DQ_TrailATRPeriod, 1);
    if (atr <= 0) return;
    
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() != Symbol()) continue;
        if (OrderMagicNumber() < magicBase || OrderMagicNumber() > magicBase + magicRange) continue;
        
        int ticket = OrderTicket();
        double openPrice = OrderOpenPrice();
        double currentSL = OrderStopLoss();
        int type = OrderType();
        
        double newSL = 0;
        
        if (type == OP_BUY) {
            switch (DQ_TrailMethod) {
                case 0:
                    newSL = Bid - DQ_TrailFixedPips * 10 * Point;
                    break;
                case 1:
                    newSL = Bid - (atr * DQ_TrailATRMult);
                    break;
                case 2:
                    int hhIdx = iHighest(Symbol(), DQ_TrailTimeframe, MODE_HIGH, DQ_TrailChandelierPer, 1);
                    if (hhIdx >= 0) {
                        double highestHigh = iHigh(Symbol(), DQ_TrailTimeframe, hhIdx);
                        newSL = highestHigh - (atr * DQ_TrailATRMult);
                    }
                    break;
            }
            
            // Only trail if new SL is above open price and above current SL
            if (newSL > openPrice && (currentSL == 0 || newSL > currentSL + Point)) {
                if (OrderModify(ticket, openPrice, newSL, OrderTakeProfit(), 0, clrLime)) {
                    // Print("[DQ-EM] Trail BUY: ticket=", ticket, " SL=", DoubleToStr(newSL, Digits));
                }
            }
            
        } else if (type == OP_SELL) {
            switch (DQ_TrailMethod) {
                case 0:
                    newSL = Ask + DQ_TrailFixedPips * 10 * Point;
                    break;
                case 1:
                    newSL = Ask + (atr * DQ_TrailATRMult);
                    break;
                case 2:
                    int llIdx = iLowest(Symbol(), DQ_TrailTimeframe, MODE_LOW, DQ_TrailChandelierPer, 1);
                    if (llIdx >= 0) {
                        double lowestLow = iLow(Symbol(), DQ_TrailTimeframe, llIdx);
                        newSL = lowestLow + (atr * DQ_TrailATRMult);
                    }
                    break;
            }
            
            if (newSL < openPrice && (currentSL == 0 || newSL < currentSL - Point)) {
                if (OrderModify(ticket, openPrice, newSL, OrderTakeProfit(), 0, clrLime)) {
                    // Print("[DQ-EM] Trail SELL: ticket=", ticket, " SL=", DoubleToStr(newSL, Digits));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| MODULE 3: TIME-DECAY EXIT                                       |
//+------------------------------------------------------------------+
void DQ_ManageTimeExit(int magicBase, int magicRange) {
    if (!DQ_UseTimeExit) return;
    
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() != Symbol()) continue;
        if (OrderMagicNumber() < magicBase || OrderMagicNumber() > magicBase + magicRange) continue;
        
        int barsHeld = iBarShift(Symbol(), PERIOD_H4, OrderOpenTime(), false);
        
        if (barsHeld >= DQ_TimeExitBars) {
            double profit = OrderProfit() + OrderSwap() + OrderCommission();
            double minProfit = DQ_TimeExitMinProfit * AccountBalance() / 100.0;
            
            if (profit < minProfit) {
                double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
                Print("[DQ-EM] Time exit: ticket=", OrderTicket(), " bars=", barsHeld, " profit=", DoubleToStr(profit, 2));
                OrderClose(OrderTicket(), OrderLots(), closePrice, 3, clrOrange);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| LOT MULTIPLIER — Call in your lot sizing function                |
//| Returns: composite multiplier from all enabled modules           |
//+------------------------------------------------------------------+
double DQ_GetFinalLotMultiplier() {
    double mult = 1.0;
    
    // Equity curve scaling
    mult *= DQ_GetEquityScaleMultiplier();
    
    // Session sizing
    mult *= DQ_GetSessionMultiplier();
    
    // Anti-martingale
    mult *= DQ_GetAntiMartingaleMultiplier();
    
    return MathMax(0.1, mult); // Never go below 10%
}

//+------------------------------------------------------------------+
//| MODULE 4: EQUITY CURVE SCALING                                  |
//+------------------------------------------------------------------+
double DQ_GetEquityScaleMultiplier() {
    if (!DQ_UseEquityScaling) return 1.0;
    
    double equity = AccountEquity();
    if (equity > DQ_g_peakEquity) DQ_g_peakEquity = equity;
    if (DQ_g_peakEquity <= 0) return 1.0;
    
    double ddPct = (DQ_g_peakEquity - equity) / DQ_g_peakEquity;
    
    if (ddPct <= DQ_EquityDDStart) return 1.0;
    if (ddPct >= DQ_EquityDDMax) return DQ_EquityScaleMin;
    
    // Linear interpolation
    double ratio = (ddPct - DQ_EquityDDStart) / (DQ_EquityDDMax - DQ_EquityDDStart);
    double scale = 1.0 - ratio * (1.0 - DQ_EquityScaleMin);
    
    return MathMax(DQ_EquityScaleMin, scale);
}

//+------------------------------------------------------------------+
//| MODULE 5: SESSION-AWARE SIZING                                  |
//+------------------------------------------------------------------+
double DQ_GetSessionMultiplier() {
    if (!DQ_UseSessionSizing) return 1.0;
    
    int hour = TimeHour(TimeCurrent());
    
    if (hour >= 0 && hour < 7)   return DQ_SessionAsian;      // Asian
    if (hour >= 7 && hour < 12)  return DQ_SessionLondonAM;    // London AM
    if (hour >= 12 && hour < 16) return DQ_SessionNYOverlap;   // NY overlap
    if (hour >= 16 && hour < 21) return DQ_SessionNYPM;        // NY PM
    
    return DQ_SessionDeadZone;                                   // Dead zone
}

//+------------------------------------------------------------------+
//| MODULE 6: ANTI-MARTINGALE SIZING                                |
//+------------------------------------------------------------------+
double DQ_GetAntiMartingaleMultiplier() {
    if (!DQ_UseAntiMartingale) return 1.0;
    
    if (DQ_g_consecutiveWins >= 3) return DQ_AM_WinStreak3;
    if (DQ_g_consecutiveWins >= 2) return DQ_AM_WinStreak2;
    if (DQ_g_consecutiveLosses >= 3) return DQ_AM_LossStreak3;
    if (DQ_g_consecutiveLosses >= 2) return DQ_AM_LossStreak2;
    
    return 1.0;
}

//+------------------------------------------------------------------+
//| STREAK TRACKING — Call after each trade closes                   |
//| Pass true for win, false for loss                                |
//+------------------------------------------------------------------+
void DQ_RecordTradeResult(bool isWin) {
    if (isWin) {
        DQ_g_consecutiveWins++;
        DQ_g_consecutiveLosses = 0;
    } else {
        DQ_g_consecutiveLosses++;
        DQ_g_consecutiveWins = 0;
    }
}

//+------------------------------------------------------------------+
//| RESET EQUITY PEAK — Call at start of each backtest month        |
//| (Optional: prevents old peak from suppressing current sizing)    |
//+------------------------------------------------------------------+
void DQ_ResetEquityPeak() {
    DQ_g_peakEquity = AccountEquity();
}

#endif // DQ_EXIT_MANAGEMENT_MQH
