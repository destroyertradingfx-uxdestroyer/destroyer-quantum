# CARA v6.3.mq4 — Correlation EA Analysis

**Source:** [jblanked/MQL4-Currency-Pair-Correlation-Expert-Advisor](https://github.com/jblanked/MQL4-Currency-Pair-Correlation-Expert-Advisor)
**File:** `CARA v6.3.mq4` (181 lines)
**Author:** JBlanked / Hyena Hut

---

## 1. Architecture Overview

CARA v6.3 is a **correlation-based order detection EA** that monitors multiple currency pairs and opens correlated trades when manual orders are detected on "primary" pairs. The core logic is **not in this file** — it delegates to two external libraries:

- `CustomFunctionsFix.mqh` — utility functions (lot calc, order checking)
- `CARAComponents.mqh` — the actual correlation detection and order execution logic

This file is the **orchestrator** that defines which pairs to monitor and how to size correlation orders.

---

## 2. How Correlation Detection Works

### Two Detection Functions

| Function | Purpose | Used For |
|---|---|---|
| `DetectOrders4()` | Detects orders on a primary pair and opens correlated trades on up to **8 other pairs** (with inverse/direct correlation) | US30, NAS100, XAUUSD, USDCAD, AUDJPY, NZDJPY, GBPJPY, CADJPY |
| `DetectOrdersSameTrend5()` | Detects orders on a primary pair and opens trades in the **same direction** on 5 correlated pairs | ETHUSD, BTCUSD, EURJPY |

### Signal Flow

```
Manual trade on primary pair (e.g., EURUSD)
        ↓
EA detects open order via DetectOrders4/DetectOrdersSameTrend5
        ↓
Correlation orders opened on related pairs using magic number pairs (buy magic + sell magic)
```

### Correlation Mappings (from OnTick)

**US30** correlates with: USDJPY, USDCAD, USDCHF, USDMXN, AUDUSD, EURUSD, GBPUSD, NZDUSD
**NAS100** correlates with: same 8 USD pairs
**XAUUSD** correlates with: same 8 USD pairs
**USDCAD** correlates with: AUDUSD, EURUSD, GBPUSD, NZDUSD, USDJPY (with conditional gate — only opens if no US30/NAS100/XAUUSD orders are active)
**ETHUSD** same-trend with: BTCUSD, LTCUSD, BNBUSD, DOGEUSD, XRPUSD
**BTCUSD** same-trend with: ETHUSD, LTCUSD, BNBUSD, DOGEUSD, XRPUSD
**AUDJPY** correlates with: EURAUD, GBPAUD, AUDUSD, AUDCHF, AUDCAD, AUDNZD
**NZDJPY** correlates with: AUDNZD, EURNZD, GBPNZD, NZDCAD, NZDCHF, NZDUSD
**EURJPY** same-trend with: EURAUD, EURCAD, EURCHF, EURGBP, EURNZD
**GBPJPY** correlates with: EURGBP, GBPAUD, GBPCAD, GBPCHF, GBPNZD
**CADJPY** correlates with: AUDCAD, EURCAD, GBPCAD, NZDCAD, CADCHF

### Correlation Logic

The `DetectOrders4()` function takes 8 correlated pair names as parameters. Positions 5-8 use `"x"` as a sentinel to skip unused slots. The actual correlation direction (same vs. inverse) and signal calculation are inside `CARAComponents.mqh` — not visible in this file. However, from the function naming:

- `DetectOrders4` — likely opens **inverse** correlated orders (when primary goes long, correlated pairs go short, or vice versa based on correlation sign)
- `DetectOrdersSameTrend5` — opens **same-direction** orders on all correlated pairs (used for crypto and EUR cross pairs where positive correlation is assumed)

---

## 3. Entry/Exit Signals

### Entry
- **Trigger:** A manual (or EA-placed) order is detected on a primary pair
- **Detection method:** `CheckIfOpenOrdersByMagicNB()` checks if orders exist with specific magic numbers
- **Condition gates:** USDCAD correlation trades only open if NO orders exist on US30/NAS100/XAUUSD (lines 136-139, 162-165) — prevents doubling up when USD is trending

### Exit
- `CloseOrdersNew()` is called on every tick for all 11 primary pairs (lines 111-121)
- Takes the primary pair's current correlation value as parameter — likely closes correlated orders when correlation breaks down or primary order closes
- Each pair has two magic numbers (buy-side and sell-side)

---

## 4. Lot Sizing Approach

Two mutually exclusive modes controlled by `uselotsize` vs `usepercentrisk`:

### Mode 1: Fixed Lot Size (`uselotsize = true`)
- Uses the `lotSize` input directly (default 0.01)
- All correlation orders use the same fixed lot size

### Mode 2: Percentage Risk Split (`usepercentrisk = true`)
- **Divides the primary order's lot size** among correlated pairs:
  - **USDCAD:** `OrderLots() / 8` (splits across 8 USD pairs in the detection set)
  - **ETH/BTC crypto:** `OrderLots() / 5` (splits across 5 crypto pairs)
  - **AUDJPY, NZDJPY:** `OrderLots() / 6` (splits across ~6 cross pairs)
  - **EURJPY, GBPJPY, CADJPY:** `OrderLots() / 5` (splits across 5 cross pairs)
- **Limitation noted in code:** "won't work for Nas, U30, or Gold" — these use the raw `lotSize` parameter even in percent-risk mode (lines 159-161 don't divide)
- This means the EA assumes equal risk distribution across correlated pairs

---

## 5. Magic Number System

Uses a **base + offset** system with 21 unique magic numbers per primary pair:

| Offset Range | Pair |
|---|---|
| +0, +1 | US30 |
| +2, +3 | NAS100 |
| +4, +5 | XAUUSD |
| +6, +7 | USDCAD |
| +8, +9 | ETHUSD |
| +10, +11 | BTCUSD |
| +12, +13 | AUDJPY |
| +14, +15 | NZDJPY |
| +16, +17 | EURJPY |
| +18, +19 | GBPJPY |
| +20, +21 | CADJPY |

Each pair gets two magic numbers (likely one for buy-side correlation, one for sell-side).

---

## 6. Key Observations & Limitations

1. **Most logic is hidden in `CARAComponents.mqh`** — this file is just the wiring. The actual correlation calculation, signal generation, and order execution are in the included library which is not publicly available in this repo.

2. **No stop-loss or take-profit visible** — exit logic is entirely in `CloseOrdersNew()` from the library. Likely closes when the primary order closes or correlation breaks.

3. **Anti-duplication gate** — USDCAD correlations are suppressed when US30/NAS100/XAUUSD trades are active, preventing over-exposure to USD moves.

4. **"x" sentinel pattern** — unused correlation slots are passed as `"x"` string, suggesting `DetectOrders4` checks for this and skips those pairs.

5. **VIP/licensed EA** — `JBlankedInitVIP()` and expiry date suggest this is a commercial EA with license validation.

6. **No timeframe dependency** — the EA runs on every tick with no indicator-based signals visible at this level. All signal logic is in the component libraries.

---

## 7. Relevance to Our Project

### What We Can Borrow
- **Correlation grouping concept** — organizing pairs by their correlation cluster (USD pairs, JPY crosses, crypto)
- **Conditional gate pattern** — suppressing correlated trades when a higher-priority cluster is already active
- **Lot-splitting approach** — dividing risk across correlated positions proportionally

### What We'd Improve
- **Inline the correlation calculation** — don't hide it in a library; use a proper Pearson or rolling-window correlation
- **Dynamic correlation** — this EA appears to use static/fixed correlation groupings rather than calculating real-time correlation coefficients
- **Add proper SL/TP** — independent stop-losses per correlated position rather than relying solely on primary order closure
- **Add correlation threshold** — only trade when correlation exceeds a minimum value (e.g., |r| > 0.7)
