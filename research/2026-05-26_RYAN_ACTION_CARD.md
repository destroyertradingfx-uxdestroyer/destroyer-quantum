# RYAN ACTION CARD: Cycle 5 — Priority 0 Integrations
## Date: 2026-05-26
## Time Required: 15-30 minutes
## Expected Impact: +$23K-$46K (closing the gap to $170K)

---

## STEP 1: Enable Vortex + RegimeShift (2 minutes, $5K-$13K)

**File:** `code/DESTROYER_QUANTUM_V28_06_TITAN.mq4`

Find and change these two lines:
```mql4
// FIND:
extern bool    InpVortex_Enabled         = false;
// CHANGE TO:
extern bool    InpVortex_Enabled         = true;       // TITAN: ENABLED for $170K target

// FIND:
extern bool    InpRegimeShift_Enabled    = false;
// CHANGE TO:
extern bool    InpRegimeShift_Enabled    = true;       // TITAN: ENABLED for $170K target
```

---

## STEP 2: MaxOpenTrades 16→24 (1 minute, $3K-$8K)

**File:** `code/DESTROYER_QUANTUM_V28_06_TITAN.mq4`

```mql4
// FIND:
extern int     InpMaxOpenTrades      = 16;
// CHANGE TO:
extern int     InpMaxOpenTrades      = 24;          // TITAN: Reaper alone uses 16 slots
```

---

## STEP 3: Integrate Equity Curve Multiplier (10 minutes, $15K-$25K)

**Source:** `code/V29_00_EQUITY_CURVE.mq4` (already written, copy-paste ready)

**Step 3a:** Copy the entire `CalculateEquityCurveMultiplier()` function into TITAN.
Paste it after `GetKellyLotSize()` (after line ~5094).

**Step 3b:** In `MoneyManagement_Quantum()` at line ~12927, add before the final lot calculation:
```mql4
   // V29: EQUITY CURVE AMPLIFICATION — portfolio-level anti-martingale
   double equityMult = CalculateEquityCurveMultiplier();
   combinedMultiplier *= equityMult;
```

**What it does:**
- 0.5x size when equity is in deep drawdown (protection)
- 1.0x-1.3x size when equity is growing (amplification)
- Up to 2.5x when all strategies are winning + at equity high

---

## STEP 4: Add Time Stop to ManageOpenTradesV13_ELITE (10 minutes, $8K-$15K)

**File:** `code/DESTROYER_QUANTUM_V28_06_TITAN.mq4`

**Add these externs** near other extern declarations (~line 1150):
```mql4
extern int    InpTimeStop_MaxBars    = 8;     // Max H4 bars to hold (32 hours)
extern double InpTimeStop_MinProfitR = 0.3;   // Close if profitR < this after MaxBars
```

**Add this code** in `ManageOpenTradesV13_ELITE()`, BEFORE the R-multiple calculations (~line 8559):
```mql4
   // V29: TIME-BASED EXIT — Close zombie trades
   double holdTimeBars = (TimeCurrent() - OrderOpenTime()) / PeriodSeconds();
   if(holdTimeBars >= InpTimeStop_MaxBars && profitR < InpTimeStop_MinProfitR)
   {
      bool closed = OrderClose(ticket, OrderClosePrice(), OrderClosePrice(), 5, clrRed);
      if(closed)
      {
         LogError(ERROR_INFO, "TIME-STOP: Ticket " + IntegerToString(ticket) + 
                  " closed after " + IntegerToString((int)holdTimeBars) + 
                  " bars, profitR=" + DoubleToString(profitR, 2), 
                  "ManageOpenTradesV13_ELITE");
      }
      continue;
   }
```

---

## AFTER THESE 4 CHANGES: BACKTEST

Run a full 2020.01.01 - 2025.06.01 backtest on EURUSD H4.
Expected: $140K-$170K+ profit, DD 25-32%, 800-950 trades.

If still below $170K, proceed to Priority 1 (Dynamic Kelly, Directional Concentration).

---

## NEW RESEARCH AVAILABLE

Full Cycle 5 research with 6 novel angles: `research/2026-05-26_CYCLE5_NOVEL_ANGLES.md`

Key new techniques with exact MQL4 code:
1. **Directional Concentration Risk** — prevents all-same-direction blowups
2. **MAE-Based Optimal Stops** — per-strategy optimal stop distances  
3. **Conviction-Weighted Sizing** — size proportional to signal strength
4. **Dynamic Kelly Fraction** — continuous DD-adaptive Kelly (0.10-0.45)
5. **Anti-Correlation Filter** — portfolio skew protection
6. **Session Strength Amplification** — amplify during active sessions

Combined conservative estimate: **$216K** (27% above $170K target).

---

*The bottleneck is implementation, not research. Let's go.* 🔷
