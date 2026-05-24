# V28.11 DESIGN: DEBATE LAYER
## Inspired by TradingAgents (TauricResearch/TradingAgents — 79K ★)

**Base:** V28.06 ($49,489, PF 1.78, DD 19.13%, 853 trades)
**Addition:** Signal debate + weighted voting + 3-way risk panel
**Philosophy:** Don't touch proven V28.06 logic. Bolt on top.

---

## THE PROBLEM

V28.06 has 12 strategies executing independently. They don't talk to each other.
- Phantom says BUY, Mean Reversion says SELL — both execute, cancel each other out
- Reaper opens 376 grid trades regardless of what other strategies think
- No "intelligence" in the aggregation — it's just "run everything, hope the winners beat the losers"

TradingAgents solved this with **debate before execution**. We adapt it for MQL4.

---

## ARCHITECTURE

```
CURRENT V28.06:
  OnNewBar() → Strategy1() → Strategy2() → ... → Strategy12()
  (each executes independently, no coordination)

PROPOSED V28.11:
  OnNewBar() → 
    1. COLLECT: Each strategy outputs signal + conviction (no execution)
    2. DEBATE: Aggregation layer weighs signals, detects divergence
    3. RISK PANEL: 3 perspectives evaluate the aggregated signal
    4. EXECUTE: Only trades that pass debate + risk panel execute
```

---

## COMPONENT 1: SIGNAL COLLECTION

Each strategy already has entry logic. Instead of calling OrderSend() directly,
we make each strategy output a SIGNAL STRUCT:

```mql4
struct StrategySignal {
    int    magic;           // Strategy magic number
    int    direction;       // OP_BUY, OP_SELL, or -1 (no signal)
    double conviction;      // 0.0 to 1.0 (how strong the signal is)
    string reason;          // Why this signal fired
    double suggestedLots;   // What the strategy would normally trade
    double suggestedSL;     // Suggested stop loss (price)
    double suggestedTP;     // Suggested take profit (price)
};
```

**Conviction scoring** (per strategy):
- Based on how many entry conditions are met (not just binary pass/fail)
- Example: Mean Reversion checks BB deviation + RSI + Hurst + ADX
  - All 4 met → conviction 1.0
  - 3 of 4 → conviction 0.75
  - 2 of 4 → conviction 0.5
  - 1 of 4 → conviction 0.25 (won't generate signal)
- V23 empirical probability multiplies conviction (higher prob = higher conviction)

**Implementation:** Modify each Execute* function to FIRST calculate the signal,
then call a new function `SubmitSignal()` instead of `OrderSend()` directly.
The actual `OrderSend()` moves to the debate layer.

---

## COMPONENT 2: SIGNAL DEBATE (Weighted Voting)

After all strategies have submitted signals, the debate layer evaluates:

### 2a. Direction Consensus
```mql4
double buyConviction = 0, sellConviction = 0;
double totalWeight = 0;

for each signal:
    weight = GetStrategyWeight(signal.magic);  // Based on rolling PF
    if signal.direction == OP_BUY:
        buyConviction += signal.conviction * weight;
    else if signal.direction == OP_SELL:
        sellConviction += signal.conviction * weight;
    totalWeight += weight;

double consensusRatio = MathAbs(buyConviction - sellConviction) / totalWeight;
// 0.0 = complete disagreement, 1.0 = complete agreement
```

### 2b. Strategy Weights (Credibility)
Based on rolling Profit Factor — higher PF = more voice in the debate:

```mql4
double GetStrategyWeight(int magic) {
    // V28.06 already tracks per-strategy PF via g_stratRollingPF
    int idx = GetStrategyIndexByMagic(magic);
    if (idx < 0) return 1.0;
    
    double pf = g_stratRollingPF[idx];
    if (pf < 1.0) return 0.5;   // Losing strategies get half weight
    if (pf < 1.5) return 1.0;   // Marginal strategies get normal weight
    if (pf < 2.0) return 1.5;   // Good strategies get 1.5x weight
    if (pf < 3.0) return 2.0;   // Great strategies get 2x weight
    return 3.0;                  // Elite strategies (PF 3+) get 3x weight
}
```

**V28.06 weights (based on backtest PF):**
- Phantom (PF 1.71) → 1.5x weight
- Nexus (PF 4.31) → 3.0x weight  
- NoiseBreakout (PF 1.77) → 1.5x weight
- SessionMomentum (PF 999*) → 2.0x (capped, only 2 trades)
- Reaper (PF 1.45) → 1.0x weight
- Mean Reversion (PF 999*) → 1.0x (capped, only 1 trade)

*PF 999 = too few trades to be reliable, cap weight

### 2c. Divergence Detection
When strategies disagree strongly, it's a WARNING signal:

```mql4
bool isDivergent = (buyConviction > 0.5 && sellConviction > 0.5);
if (isDivergent) {
    // Reduce position size by 50% — strategies are fighting
    sizeMultiplier *= 0.5;
    LogError("DEBATE: Divergent signals detected. Size reduced 50%.");
}
```

### 2d. Minimum Conviction Threshold
For a trade to pass the debate:
```mql4
double minConvictionThreshold = 0.3;  // At least 30% weighted conviction
bool debateApproved = (winningSide conviction > minConvictionThreshold);
```

---

## COMPONENT 3: RISK PANEL (3-Way Debate)

After the signal debate approves a trade, the Risk Panel evaluates.
Three "personas" with different risk appetites:

### Aggressive Risk Analyst
```mql4
bool AggressiveApprove(StrategySignal signal) {
    // Only blocks EXTREME risk
    if (ATR > 3x average ATR) return false;        // Extreme volatility
    if (g_ddProtectionActive) return false;          // Already in DD
    if (CountOpenTrades() >= InpMaxOpenTrades) return false;  // Full
    return true;  // Approves almost everything else
}
```

### Conservative Risk Analyst
```mql4
bool ConservativeApprove(StrategySignal signal) {
    // Requires multiple confirmations
    if (signal.conviction < 0.5) return false;       // Weak signal
    if (!IsTrendAligned(signal.direction)) return false;  // Against trend
    if (IsNearMajorLevel()) return false;             // Near S/R (choppy)
    if (signal.suggestedSL > 200 pips) return false;  // SL too wide
    if (consecutiveLosses > 3) return false;          // On a losing streak
    return true;
}
```

### Neutral Risk Analyst
```mql4
bool NeutralApprove(StrategySignal signal) {
    // Portfolio-level checks
    double currentExposure = GetTotalExposure();
    if (currentExposure > 80% of max) return false;   // Too exposed
    
    // Check if we already have a position in this direction
    if (HasOpenPosition(signal.direction, signal.magic)) return false;
    
    // Check correlation — if we already have 3 BUY trades open,
    // adding another BUY is concentrated risk
    int sameDirectionCount = CountTradesByDirection(signal.direction);
    if (sameDirectionCount >= 5) return false;
    
    return true;
}
```

### Voting Logic
```mql4
int approvals = 0;
if (AggressiveApprove(signal))  approvals++;
if (ConservativeApprove(signal)) approvals++;
if (NeutralApprove(signal))     approvals++;

bool riskApproved = (approvals >= 2);  // 2 of 3 must approve

if (!riskApproved) {
    LogError("RISK PANEL: Rejected by " + (3-approvals) + " of 3 analysts");
    return;  // No trade
}
```

---

## COMPONENT 4: POSITION SIZING (5-Tier Rating)

Map the debate consensus + risk approval to a 5-tier position size:

```mql4
double GetDebateSizeMultiplier(double conviction, int approvals) {
    // conviction: 0.0-1.0 from debate
    // approvals: 0-3 from risk panel
    
    double baseMultiplier = 1.0;
    
    // Tier 1: STRONG BUY (high conviction + all 3 risk approve)
    if (conviction >= 0.8 && approvals == 3)
        return 1.5;  // 150% of normal size
    
    // Tier 2: BUY (good conviction + 2+ risk approve)
    if (conviction >= 0.5 && approvals >= 2)
        return 1.0;  // Normal size
    
    // Tier 3: CAUTIOUS BUY (moderate conviction + 2 risk approve)
    if (conviction >= 0.3 && approvals >= 2)
        return 0.7;  // 70% size
    
    // Tier 4: HOLD (low conviction OR only 1 risk approve)
    if (conviction < 0.3 || approvals < 2)
        return 0.0;  // No trade
    
    // Tier 5: REJECT (no conviction or risk panel blocked)
    return 0.0;
}
```

---

## COMPONENT 5: TRADE LOGGING (Deferred Reflection)

Every trade logs WHY it was taken. After close, compute if the thesis held.

```mql4
struct TradeLog {
    datetime entryTime;
    int      direction;
    double   entryPrice;
    double   conviction;
    int      riskApprovals;
    string   strategies_agreed;   // "Phantom,Nexus" 
    string   strategies_disagreed; // "Reaper"
    double   atr_at_entry;
    double   hurst_at_entry;
    double   adx_at_entry;
    // Filled on close:
    double   exitPrice;
    double   pnl;
    double   holdDuration;
    bool     thesis_correct;      // Did direction match?
};
```

**Post-close analysis:**
```mql4
void AnalyzeClosedTrade(TradeLog log) {
    // Was the conviction justified?
    if (log.thesis_correct && log.conviction > 0.7) {
        // High conviction + correct → boost these strategies' weight
        BoostStrategyWeight(log.strategies_agreed);
    }
    if (!log.thesis_correct && log.conviction > 0.7) {
        // High conviction + wrong → penalize these strategies' weight
        PenalizeStrategyWeight(log.strategies_agreed);
    }
}
```

This creates a **feedback loop**: strategies that are right more often
get more weight in future debates. Strategies that are wrong lose weight.

---

## WHAT DOESN'T CHANGE IN V28.06

**CRITICAL: These remain untouched:**
- All strategy logic (entry conditions, SL/TP calculations)
- Kelly/Heat sizing system (still runs, debate multiplier ON TOP)
- V23 empirical probability engine
- All magic numbers and strategy registration
- OnTick flow and bar alignment
- Reaper grid management
- All existing filters (Hurst, Valkyrie, ADX, etc.)

**What changes:**
- `OrderSend()` calls move from Execute* functions to debate layer
- Each Execute* function returns a StrategySignal instead of trading
- New functions: SubmitSignal(), RunDebate(), RiskPanel(), GetDebateSizeMultiplier()
- New logging: TradeLog struct for deferred reflection

---

## EXECUTION FLOW (V28.11)

```
OnNewBar()
  │
  ├── [V28.06 unchanged] Event Shield, Time Filter, DD Protection
  │
  ├── PHASE 1: SIGNAL COLLECTION
  │   ├── Phantom → signal (direction, conviction, SL/TP)
  │   ├── Mean Reversion → signal
  │   ├── NoiseBreakout → signal
  │   ├── Reaper → signal (grid first entry only, not grid levels)
  │   ├── SessionMomentum → signal
  │   ├── Nexus → signal
  │   ├── Vortex → signal
  │   ├── RegimeShift → signal
  │   ├── DivergenceMR → signal
  │   ├── StructuralRetest → signal
  │   ├── Apex → signal
  │   └── Phantom → signal
  │
  ├── PHASE 2: SIGNAL DEBATE
  │   ├── Weight each signal by strategy PF
  │   ├── Calculate buy/sell conviction
  │   ├── Detect divergence
  │   └── Output: direction + consensus conviction + divergence flag
  │
  ├── PHASE 3: RISK PANEL
  │   ├── Aggressive → approve/reject
  │   ├── Conservative → approve/reject
  │   ├── Neutral → approve/reject
  │   └── Output: 2/3 or 3/3 approval
  │
  ├── PHASE 4: EXECUTION
  │   ├── Calculate debate size multiplier (5-tier)
  │   ├── Apply on top of existing Kelly/Heat sizing
  │   ├── OrderSend() with debate-adjusted size
  │   └── Log trade for deferred reflection
  │
  └── [V28.06 unchanged] Reaper grid management, existing exits
```

---

## EXPECTED IMPACT

**Trade count:** May decrease slightly (debate filters out conflicting signals)
**Win rate:** Should increase (only trades with consensus execute)
**Profit Factor:** Expected improvement (better quality trades)
**Drawdown:** Expected decrease (risk panel catches concentrated risk)

**Estimated:** 
- Trades: 853 → 600-700 (fewer but higher quality)
- PF: 1.78 → 2.0-2.3 (consensus filtering)
- DD: 19.13% → 14-16% (risk panel protection)
- Profit: $49K → $50-55K (fewer trades but bigger winners)

---

## IMPLEMENTATION ORDER

1. **Signal struct + SubmitSignal()** — Define the interface
2. **Modify one strategy** (Phantom) to output signal instead of trading
3. **Run debate on Phantom signals only** — validate the concept
4. **If positive, convert remaining strategies one at a time**
5. **Add Risk Panel** (3 personas)
6. **Add deferred reflection** (trade logging)
7. **Backtest V28.11** vs V28.06

**Rule: One change at a time. Test after each step.**

---

## RISKS

- **Over-filtering:** Debate might block too many trades. Monitor trade count.
- **Latency:** Multiple evaluation passes per bar. H4 has time, but keep it efficient.
- **Complexity:** More moving parts = more potential bugs. Comment everything.
- **Reaper:** Grid strategies don't fit the debate model well. First entry goes through debate, grid levels manage independently.

---

*Designed: May 2026*
*Inspired by: TauricResearch/TradingAgents*
*Base: V28.06 (VENI VIDI VICI)*
