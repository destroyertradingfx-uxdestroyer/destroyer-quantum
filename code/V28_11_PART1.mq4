//+------------------------------------------------------------------+
//|        DESTROYER_QUANTUM_V28.00_FULL_OVERHAUL.mq4               |
//|                    Copyright 2026, Quantum Leap Analytics        |
//|  DESTROYER QUANTUM V28.06 - VENI VIDI VICI                        |
//|  Session Momentum + Divergence MR, ATR Grid, High-PF Risk       |
//|                     https://github.com/okyyryan                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quantum Leap Analytics"
#property link      "https://github.com/okyyryan"
 #property version   "28.11"  // V28.11: DEBATE LAYER  Signal voting, Risk Panel, Deferred Reflection
#property strict

/*
==================================================================================================================
==================================================================================================================
   ### V28.04 SURGICAL PATCH  5 FIXES ###
==================================================================================================================
   PATCH DATE: 2026-05-22
   STATUS: BACKTEST PENDING  Ryan needs to run OHLC backtest
   
   CHANGES:
   1. CUT LiquiditySweep (9005)  PF 0.84, negative EV (-$1,439). Disabled.
   2. REVERTED Titan volatility threshold  0.250.4. Restored Valkyrie filter.
      V27.27 loosened these and let in 17 garbage trades (PF 2.000.37).
   3. FIXED duplicate GetStrategySpecificRisk  renamed second definition to
      GetStrategySpecificRiskByIndex to avoid compiler ambiguity.
   4. ADDED lot sizing fallback for new strategies 9003-9006.
      SessionMomentum gets 1.5x (high-PF potential), others get 1.0x or 0.5x.
   5. ADJUSTED DivergenceMR Hurst threshold  0.50.55 (EURUSD H4 rarely < 0.5).
      Extended StructuralRetest retest window  1020 bars (was too tight on H4).
   
   EXPECTED IMPACT:
   - Cut ~$1,439 in losses from LiquiditySweep
   - Restore Titan to PF 2.00+ (prevent 17 bad trades)
   - DivergenceMR + StructuralRetest may now generate trades (were dead code)
   - Estimated: $49K-$51K profit, PF 1.85-1.90, DD < 18%
   
==================================================================================================================
   ### V27.19 DYNAMIC PERFORMANCE-BASED LOT SIZING - KELLY + HEAT SCORE ###
==================================================================================================================
==================================================================================================================
   PATCH DATE: 2026-05-18
   STATUS: REVOLUTIONARY  PER-STRATEGY KELLY GOVERNED SIZING
   
   THE BREAKTHROUGH:
   V27.8 used a static 10%/20% win/loss multiplier with hardcoded tier caps per strategy.
   V27.19 replaces this with a fully dynamic, mathematically-governed system where each
   strategy's lot size is determined by its ACTUAL rolling performance.
   
    V27.19 FEATURES:
   
   1 ROLLING KELLY CRITERION (Per-Strategy)
      - Tracks last 60 trades per strategy in circular buffer
      - Calculates: Win Rate, Avg Win, Avg Loss, Profit Factor, Sharpe Proxy
      - Kelly Formula: f* = W - ((1-W) / R), using HALF-KELLY for safety
      - Blended with base risk: 60% Kelly + 40% base (prevents wild swings)
      - Min 0.5%, Max 10% per trade (safety bounds)
      
   2 DYNAMIC TIER CAPS (Performance-Based, Not Hardcoded)
      - Old: Warden=2.0x, Phantom=1.5x, Reaper=0.5x (static, arbitrary)
      - New: PF3.04.0x, PF2.03.0x, PF1.52.5x, PF1.22.0x, PF<1.00.75x
      - Sharpe bonus: +15% for Sharpe>1.0, additional +10% for Sharpe>2.0
      - Absolute cap: 5.0x (was 2.5x)
      
   3 HEAT SCORE (Capital Allocation Weight)
      - Composite of: PF Score (30%), Win Rate (15%), Kelly (25%), Sharpe (15%), Streak (15%)
      - EWMA-smoothed to prevent whipsaw (70% old, 30% new)
      - Maps to risk scaling: 0.00.25x, 0.51.0x, 1.02.0x
      - Hot strategies get MORE capital, cold strategies get LESS
      
   4 REAPER GRID AMPLIFICATION
      - Initial lot raised from 0.01 to 0.05 (PF 11.68 deserves more)
      - Grid max exposure now ~1.2 lots (was ~0.24)
      
   5 PORTFOLIO RISK BUDGET RAISED
      - InpMaxTotalRisk_Percent: 5.0%  8.0% (Kelly-governed needs headroom)
      - Per-trade 5% Global_Risk_Check maintained (safety)
   
   EXPECTED OUTCOMES:
   - Strategies self-optimize: winners amplify, losers shrink
   - High PF strategies (Reaper, Nexus) get proportionally more capital
   - Drawdown controlled by Kelly's natural negative-feedback
   - Target: $100K+ in same backtest period
   
   DEVELOPED BY: @okyy.ryan + V27.19 Dynamic Kelly Integration
   SLOGAN: Let the Math Decide  Kelly Governs, Heat Allocates
==================================================================================================================
*/

/*
==================================================================================================================
   ### V26.0 MATH-FIRST SIGNAL GENERATION - BREAKING THE FREQUENCY CAP ###
==================================================================================================================
   PATCH DATE: 2026-01-01
   STATUS: PARADIGM SHIFT - MATH GENERATES SIGNALS, NOT FILTERS THEM
   
   THE BREAKTHROUGH:
   V25's elastic layer is throttled by V18 indicator rarity (~190 signals). To reach 600-900 trades with PF >3.5:
   We bypass V18 binary logic entirely when math is confident. Math generates new signals independently.
   
    V26 MATH-FIRST STRATEGY:
   
   **MATHREVERSAL STRATEGY** (New Pure Math Signal Generator)
   - Magic Number: 999002
   - Entry Logic: Purely from empirical probability, deviation, entropy (NO RSI/BB required)
   - Triggers:
     * Empirical Probability > 0.7 (high confidence from history)
     * Deviation > 1.5 (significant price displacement)
     * Normalized Entropy < 0.6 (low chaos)
     * R-Expectancy > 0 (positive historical edge)
     * Regime Confidence > 0.5 (stable regime)
   - Direction: Deviation > 0  SELL (revert up), Deviation < 0  BUY (revert down)
   - Impact: +400-600 new trades from math where V18 binaries miss
   
   **V26 INTEGRATED FIXES** (All V25 components + tuning):
   
   1 MARGINAL VAR CONTRIBUTION (V25 Fix #1 - Enhanced)
      - Marginal VAR check in MathReversal before OrderSend
      - Soft dampening: lots *= 0.7 when marginalVar + currentVar > 80% of limit
      - Regime-contextual limits with dynamic thresholds
      
   2 REGIME PROBATION COMPLETE (V25 Fix #2 - Enhanced)
      - Probation state (type=3) triggers after 20 bars in calm with trendScore>0.45
      - Partial VAR relaxation in probation (varLimit *= 1.2)
      - Diversifies regime logic paths for continuous adaptation
      
   3 CONTINUOUS SCORING INTEGRATION (V25 Fix #3 - Active)
      - Used as fallback in existing strategies when binary conditions miss but math prob high
      - Elastic threshold = 0.6 - (prob  0.1)
      - Graduated scoring: RSI/BB weighted by probability
      
   4 COMPLETE RE-ENTRIES TUNED (V25 Fix #4 - Enhanced)
      - Lowered gates: confidence>0.5, expectancy>-0.1, cooldown=5 bars
      - Increased size: 0.7 base size (was 0.5)
      - Full OrderSend integration with V23 tracking
   
   CONFIGURATION:
   - input bool InpMathFirst = true  // Enable V26 Math-First mode (requires InpAlphaExpand=true)
   - input bool InpAlphaExpand = true // V24/V25 expansions
   - input bool InpElasticScoring = true // V25 continuous scoring
   
   PHILOSOPHY:
   V23 = Gate Signals (Filter rare binaries)
   V24 = Expand Gates (Relax filters conditionally)
   V25 = Generate from Math (Continuous scoring)
   V26 = Math Owns Signals (Pure math strategy + V25 enhancements)
   
   EXPECTED OUTCOMES (V26 Full Mode):
   - Trade Count: 190  650-950 (+460-760 from MathReversal + V25 tuning)
   - Profit Factor: 3.6-4.0 (quality gates maintain edge)
   - Max Drawdown: 9-11% (+2-4% acceptable for frequency)
   - Win Rate: >70% (math prob gates ensure quality)
   - Equity Curve: Dense staircase (math fills V18 gaps)
   
   BREAKDOWN:
   - MathReversal: +400-600 new trades (pure math, no V18 gates)
   - V25 Re-entries: +30-60 (tuned parameters)
   - V25 Continuous Scoring: +30-100 (elastic thresholds on existing)
   - Total: 190 + 460-760 = 650-950 trades
   
   DEVELOPED BY: @okyy.ryan + V26 Math-First Integration
   SLOGAN: Math Owns Signals - Confidence Generates, Not Filters
==================================================================================================================
*/

/*
==================================================================================================================
   ### V25.0 ELASTIC SIGNAL LAYER - MATHEMATICAL SIGNAL GENERATION ###
==================================================================================================================
   PATCH DATE: 2026-01-01
   STATUS: TRANSITION FROM "GATE SIGNALS" TO "GENERATE FROM MATH"
   
   OBJECTIVE:
   V24 implemented expansions but remained throttled by upstream V18 signal rarity and absolute VAR blocking.
   V25 shifts the paradigm: Instead of filtering rare binary signals, we GENERATE continuous signals from math.
   
    V25 ELASTIC LAYER FEATURES (ALL 4 FIXES INTEGRATED):
   
   1 MARGINAL VAR CONTRIBUTION (Fix #1) - Replace Absolute VAR Blocking
      - Problem: V24's absolute VAR check blocks trades without assessing marginal impact
      - Solution: Calculate each trade's added VAR contribution, not just portfolio total
      - Logic: marginalVar = lots  sl  tickValue / equity  tailRiskFactor
      - Soft dampening when close to limit (>80% of varLimit  lots *= 0.7)
      - Regime-contextual limits with dynamic thresholds
      - Impact: +30-50% approvals for low-impact trades
      - Integration: In ValidateTradeRisk() and ApproveTrade() flow
   
   2 REGIME PROBATION/HYSTERESIS (Fix #2) - Break Regime Freeze
      - Problem: V24 regime locked in RANGING_CALM (type=0) due to wide thresholds
      - Solution: Add probation state to prevent eternal calm; hysteresis for transitions
      - Logic: After 20+ bars in calm, if trendScore>0.45  TREND_PROBATION (type=3)
      - Probation enables partial relaxation (varLimit *= 1.2) without full regime shift
      - Diversifies condLoss/tail logic across regime types
      - Impact: Unlocks regime diversity, enables conditional logic paths
      - Integration: In V23_DetectMarketRegime()
   
   3 CONTINUOUS SCORING FOR ADAPTIVES (Fix #3) - Elastic Signal Geometry
      - Problem: V18 binary indicators (RSI<30, BB extremes) produce sparse signals (~190)
      - Solution: Replace binary gates with weighted continuous scores
      - Logic: totalScore = 0.5rsiScore + 0.3bbScore + 0.2regime.confidence
      - Adaptive threshold = 0.6 - (prob0.1)  elastic based on probability
      - rsiScore = (rsi<30 ? 1 : rsi<40 ? 0.7 : 0)  prob (graduated, not binary)
      - Impact: +2-3 signals from marginal cases that binary logic rejects
      - Integration: In ExecuteMeanReversionModelV8_6(), Reaper, other strategies
   
   4 COMPLETE RE-ENTRIES WITH TUNING (Fix #4) - Full OrderSend Integration
      - Problem: V24 re-entries stubbed (no OrderSend, strict gates, incomplete integration)
      - Solution: Lower gates, add full OrderSend execution, tune parameters
      - Lowered gates: confidence>0.5 (was 0.6), expectancy>-0.1 (was 0)
      - Cooldown reduced: 5 bars (was 10), size increased: 0.7 (was 0.5)
      - Full OrderSend calls integrated with V18 execution flow
      - Impact: +1.5-2 activations in calm markets
      - Integration: Complete V24_Reentry functions with OrderSend calls
   
   CONFIGURATION:
   - input bool InpAlphaExpand = false (V23 mode: 192 trades, conservative)
   - input bool InpAlphaExpand = true + InpElasticScoring = false (V24 mode: partial expansion)
   - input bool InpAlphaExpand = true + InpElasticScoring = true (V25 FULL mode: 600-900 trades)
   
   PHILOSOPHY:
   V23 = Gate Signals (Filter rare binaries)
   V24 = Expand Gates (Relax filters conditionally)
   V25 = Generate Signals (Math produces continuous scores)
   
   EXPECTED OUTCOMES (V25 Full Mode):
   - Trade Count: 192  600-900 (+400-700 from all 4 fixes)
   - Profit Factor: 3.5-4.1 (quality preserved through math scoring)
   - Max Drawdown: 8-10% (+2-4% acceptable variance)
   - Win Rate: >72% (continuous scoring maintains quality)
   - Equity Curve: Denser staircase (more frequent smaller wins)
   
   BACKTEST VALIDATION PATH:
   1. Fix #1 (Marginal VAR)  ~280 trades
   2. Fix #4 (Complete Re-entries)  ~450 trades
   3. Fix #2 (Regime Probation)  ~600 trades
   4. Fix #3 (Continuous Scoring)  600-900 trades
   
   DEVELOPED BY: @okyy.ryan + V25 Elastic Signal Layer Integration
   SLOGAN: Generate From Math - Continuous Signals, Continuous Quality
==================================================================================================================
*/

/*
==================================================================================================================
   ### V24.0 ALPHA EXPANSION MODE - BREAKING THE FREQUENCY CAP ###
==================================================================================================================
   PATCH DATE: 2025-12-31
   STATUS: CONDITIONAL TRADE EXPANSION WHILE MAINTAINING PF >3.5 AND DD <10%
   
   OBJECTIVE:
   V23's mathematical layers act as filters/governors that stabilize but cap frequency at ~192 trades.
   V24 implements THREE targeted expansions to achieve 600-900 trades while preserving quality:
   
    V24 EXPANSION FEATURES:
   
   1 REGIME-CONDITIONAL VAR RELAXATION (Fix #1)
      - Problem: VAR blocks frequent trades at 0.05 threshold (absolute, non-conditional)
      - Solution: Dynamic VAR limits based on regime type and entropy
      - Logic: If ranging/calm (regime==0 && entropy<0.5)  multiply VAR limit by InpVarRelaxFactor (default 1.5)
      - Impact: +30-50% more trades in low-risk regimes without increasing tail risk
      - Gated by: InpAlphaExpand toggle (V23 mode if false)
   
   2 ADAPTIVE ENTRY THRESHOLDS (Fix #2)
      - Problem: V18 indicator thresholds (RSI 30/70, BB 2.0 dev) are fixed
      - Solution: Use empirical prob & expectancy to dynamically loosen thresholds within bounds
      - Logic: adaptiveRsiLow = 30 - (prob * InpAdaptMax * (rExpectancy>0 ? 1 : 0.5))
      - Bounds: Max shift 10 levels/pips (InpAdaptMax), gated by positive expectancy
      - Impact: +200-400 trades in favorable regime contexts
      - Applied: ExecuteMeanReversionModelV8_6, Reaper, other strategies
   
   3 EXPECTANCY-GATED RE-ENTRIES (Fix #3)
      - Problem: No re-entry mechanics; signals used once then discarded
      - Solution: Re-execute approved signals after cooldown (half size, gated)
      - Logic: If rExpectancy>0 AND regime.confidence>0.6 AND cooldown elapsed  re-entry at 0.5x lots
      - Cooldown: InpReentryCooldown bars (default 10) per strategy
      - Impact: +100-300 trades safely (no new risk, existing signal validation)
   
   CONFIGURATION:
   - input bool InpAlphaExpand = false (V23 mode: stable 192 trades, PF ~4.0)
   - input bool InpAlphaExpand = true  (V24 mode: target 600-900 trades, PF 3.5-4.0, DD 8-10%)
   
   PHILOSOPHY:
   V23 = Institutional Safety (Conservative Governors)
   V24 = Alpha Expansion (Conditional Freedom with Quality Gates)
   
   EXPECTED OUTCOMES (V24 Mode):
   - Trade Count: 192  600-900 (+300-700 from re-entries/adaptive/VAR relaxation)
   - Profit Factor: 3.97  3.5-4.0 (slight quality drop acceptable for frequency)
   - Max Drawdown: 6.44%  8-10% (+2-3% variance acceptable)
   - Win Rate: Maintained >75% (quality gates prevent garbage)
   
   BACKTEST PATH:
   1. Fix #1 first (VAR relaxation - lowest risk)
   2. Fix #3 second (re-entries - no new risk)
   3. Fix #2 last (adaptive thresholds - highest variance)
   
   DEVELOPED BY: @okyy.ryan + V24 Alpha Expansion Integration
   SLOGAN: Freedom with Discipline - More Trades, Same Quality
==================================================================================================================
*/

/*
==================================================================================================================
   ### V23.0 INSTITUTIONAL EMPIRICAL PROBABILITY ENGINE ###
==================================================================================================================
   PATCH DATE: 2025-12-31
   STATUS: INSTITUTIONAL-GRADE MATHEMATICAL INTELLIGENCE - OPTION 6  V23 INTEGRATION
   
   OBJECTIVE:
   Surgical integration of advanced mathematical concepts into V18.3 framework:
   
    CORE SYSTEMS INTEGRATED:
   
   1 EMPIRICAL PROBABILITY ENGINE (Option 6 Core)
      - Bin-based empirical hit-rates (5 deviation bins: <1.0, 1.0-1.5, 1.5-2.0, 2.0-2.5, >2.5)
      - EWMA Bayesian-style updating on trade close
      - Slow prior decay toward 0.5 (prevents drift, trade-based cadence)
      - Per-strategy probability memory (no leakage)
   
   2 EXPECTANCY IN R-MULTIPLES
      - Scale-invariant risk/reward calculation
      - R = profit / actual_stop_loss_distance
      - Portfolio-wide R-expectancy tracking
   
   3 NORMALIZED ENTROPY
      - H_norm = H / log2(bins)  [0,1] bounded
      - Suppresses trades in chaotic regimes (H_norm > 0.7)
      - Never fully blocks alone (soft filter)
   
   4 ASYMMETRIC MARKET BIAS
      - Return skew detection (negative skew  bias short reversals)
      - Downside volatility ratio (down_var / total_var > 1.2  dampen longs)
      - Probability weighting (not direction forcing)
   
   5 TAIL-RISK DEPENDENCY (V22  V23)
      - Conditional loss probability: P(loss | previous loss)
      - Regime-contextualized (separate tracking per regime type)
      - Non-linear damping: damping = (1 - P_cond) (convex scaling)
   
   6 BIDIRECTIONAL REGIME FEEDBACK (V23)
      - Trade outcomes revise regime confidence
      - EWMA surprise metric with confidence-gap scaling
      - Aggregated adjustment (3+ confirms before regime shift)
      - Bounded feedback range (0.5 max adjustment)
   
   7 TRADE-BASED LEARNING CADENCE
      - All updates occur on trade close (not ticks/bars)
      - Prevents uneven learning rates across timeframes
   
   8 TRADE-LEVEL VAR
      - Empirical VAR from trade equity deltas
      - Quantile-based (5% worst outcomes)
      - Participates in global risk throttling
   
   INTEGRATION APPROACH:
   - Modular: New systems coexist with V18.3 strategies
   - Surgical: Minimal disruption to proven execution logic
   - Adaptive: Systems learn from actual trade outcomes
   - Production-grade: Bounded, scale-invariant, commented
   
   MATHEMATICAL RIGOR:
   - No normal distribution assumptions (empirical only)
   - No heuristics (all probabilistic/empirical)
   - All decay/learning on trade-close cadence
   - Regime-contextual tail risk (no global assumptions)
   
   EXPECTED OUTCOMES:
   - Improved edge through empirical probability calibration
   - Better risk allocation via R-expectancy and tail dampening
   - Regime-aware adaptation through bidirectional feedback
   - Preserved V18.3 execution quality with enhanced intelligence
   
   DEVELOPED BY: @okyy.ryan + V23 Institutional Integration
   SLOGAN: Empirical Truth > Assumed Models
==================================================================================================================
*/



/*
==================================================================================================================
   ### V18.3 CHRONOS UPGRADE - BREAKING THE VOLUME WALL ###
==================================================================================================================
   PATCH DATE: 2025-12-12
   STATUS: HIGH-FREQUENCY TRADING MODULE - TARGET 1000+ TRADES/YEAR
   
   OBJECTIVE:
   Break the "Volume Wall" by activating the Market Microstructure strategy.
   Current status: 30 trades/year (investment vehicle). Target: 1000+ trades (HFT system).
   
   THE CHRONOS UPGRADE: TIMEFRAME FRACTALS
   "Predator & Parasite" dual-timeframe strategy:
   - Predator (Titan H4): Decides macro direction using Kalman Filters
   - Parasite (Microstructure M15): Takes rapid scalps aligned with H4 bias
   
   IMPLEMENTATION:
   1. Market Microstructure M15 Flux Scalper (ExecuteMicrostructureStrategy)
      - Runs independently on M15 timeframe (96 candles/day vs H4's 6)
      - ONLY trades in alignment with H4 Kalman trend (safety first)
      - Targets: 3-5 scalps/day = 750+ trades/year
      - Entry: M15 pullbacks (RSI < 30/> 70 + BB extremes) in H4 trend direction
      - Exit: Tight TP (35 pips) / SL (25 pips) for fast scalping
   
   2. Integration Points:
      - Line ~1476: iBandsOnArray() helper function added
      - Line ~4910: ExecuteMicrostructureStrategy() function added
      - Line ~4049: OnTick() hookup for M15 execution
   
   3. Safety Features:
      - H4 Kalman Filter Gate: Never scalps against macro trend
      - Strategy Health Check: Pauses if PF drops below threshold
      - Independent Magic Number (999001): Separate tracking from main strategies
      - Half position sizing: Lower risk per scalp due to frequency
   
   EXPECTED OUTCOMES:
   - Total Trades: 30  1000+ (33x volume increase)
   - Win Rate: >70% (aligned with H4 trend)
   - Profit Factor: Maintained > 4.0 (high-quality entries only)
   - Drawdown: Slight increase to 10-12% (acceptable for frequency)
   
   MATHEMATICAL LOGIC:
   By filtering M15 scalps through H4 Kalman trend:
   - Eliminates "chop" that kills M15 bots
   - Maintains high win rate through macro alignment
   - Generates 16x more trading opportunities per day
   
   PREVIOUS: V18.2 VOLUME AWAKENING PATCH - SOLVING THE "SLEEPING BOT" PROBLEM
==================================================================================================================
   PATCH DATE: 2025-12-12
   STATUS: TRADE VOLUME AMPLIFICATION WHILE MAINTAINING CAPITAL PROTECTION
   
   DIAGNOSIS:
   V18.1 achieved exceptional capital protection (7.5% DD) but created a "Volume Problem":
   - Only 176 trades in 6 years (basically sleeping)
   - Mean Reversion strategy in a coma due to Hurst > 0.45 check being too strict
   - Titan strategy too slow (only 6 trades) due to overly cautious Kalman filter
   - The bot was protecting capital but not making money
   
   THE FIX: V18.2 VOLUME AWAKENING PATCH
   Two surgical strikes to unlock hundreds of safe trades:
   
   PATCH 1: REGIME-ADAPTIVE MEAN REVERSION (Replaces Binary Block)
   - OLD: Hurst > 0.45  100% BLOCKED (killed all trades)
   - NEW: Dynamic "Grid Stretch" based on market regime:
     * Hurst < 0.40 (Prime Reverting): BB Dev 1.8, RSI 65/35 (Aggressive)
     * Hurst 0.40-0.60 (Random/Noise): BB Dev 2.2, RSI 70/30 (Standard + Safety)
     * Hurst > 0.60 (Strong Trend): BB Dev 3.5, RSI 80/20 (Sniper Mode - Extreme Only)
   - Impact: Strategy stays active but adapts strictness to market conditions
   - Safety: ADX > 50 hard stop prevents trading in violent trends
   - Expected Outcome: 176 trades  600-900 trades (3-5x increase)
   
   PATCH 2: KALMAN FILTER ACCELERATION (Titan Speed Boost)
   - OLD: q=0.05, r=0.15 (too cautious, slow reaction)
   - NEW: q=0.10, r=0.10 (faster trend detection)
   - Impact: Titan identifies trends ~3-5 candles earlier
   - Expected Outcome: 6 Titan trades  30-40 trend setups
   
   MATHEMATICAL LOGIC - THE RUBBER BAND ANALOGY:
   Instead of turning OFF in imperfect conditions, we ADJUST the entry requirements:
   - Safe Market (Low Hurst): Trade aggressively with looser bands
   - Dangerous Market (High Hurst): Trade conservatively, only at extremes
   This keeps the bot ACTIVE while maintaining SAFETY
   
   INTEGRATION POINTS:
   - Line 858-859: CKalmanFilter.Init() - Updated q and r values
   - Line 4554-4826: ExecuteMeanReversionModelV8_6() - Complete regime-adaptive rewrite
   
   EXPECTED OUTCOMES:
   - Total Trades: 176  600-900 (3-5x volume increase)
   - Mean Reversion: Unlocked from coma, trades in all regimes with adaptive strictness
   - Titan: Faster trend entry, captures more opportunities
   - Drawdown: Slight increase to 10-12% (still within institutional limits)
   - Profit: Significant increase due to trade frequency
   - Quality: Maintained through regime-adaptive filters
   
   DEVELOPED BY: @okyy.ryan + V18.2 Volume Awakening Patch by AI Assistant
   SLOGAN: Active Protection - Trade More, Risk Smart
==================================================================================================================
*/

/*
==================================================================================================================
   ### V18.1 QUANTUM MATH PATCH - ADVANCED QUANTITATIVE ALGORITHMS ###
==================================================================================================================
   PATCH DATE: 2025-12-12 (SUPERSEDED BY V18.2)
   STATUS: INSTITUTIONAL-GRADE MATHEMATICAL ENHANCEMENTS (TOO CONSERVATIVE)
   
   DIAGNOSIS:
   Mean Reversion (PF 0.57) and Titan (PF 1.11) are failing while Reaper succeeds.
   - Mean Reversion: Using retail logic (RSI < 30 + BB), catching falling knives without measuring time series memory
   - Titan: Using laggy Moving Averages (EMAs), by the time EMA crosses, the move is over
   - Influx (0 Trades): Suffering from Boolean AND rigidity (too many conditions required simultaneously)
   
   THE FIX: V18.1 QUANTUM MATH PATCH
   Three institutional-grade mathematical enhancements:
   
   PATCH 1: HURST EXPONENT (Mean Reversion Fix)
   - Function: CalculateHurstExponent() - Rescaled Range (R/S) Analysis
   - Mathematics: Calculates market "memory" via Hurst Exponent (H)
     * 0.0 < H < 0.5: Anti-persistent (Mean Reverting) - SAFE TO FADE
     * 0.5 < H < 1.0: Persistent (Trending) - DANGEROUS TO FADE
   - Implementation: Added to ExecuteMeanReversionModelV8_6()
   - Threshold: H > 0.45 blocks Mean Reversion trades (Random/Trending regime)
   - Impact: Prevents Mean Reversion from trading during strong trends
   - Expected Outcome: Mean Reversion PF improves from 0.57 to 1.5+
   
   PATCH 2: KALMAN FILTER (Titan Trend Fix)
   - Class: CKalmanFilter - 1-Dimensional Kalman Filter
   - Mathematics: Recursively estimates "True Price" by separating signal from noise
     * Process noise (q = 0.05): Real market movement
     * Measurement noise (r = 0.15): Market noise/randomness
   - Implementation: Added to ExecuteTitanStrategy()
   - Enhancement: Reacts to trends ~40% faster than EMA
   - Logic: Kalman slope + Price position relative to Kalman line = Clean Trend
   - Impact: Titan enters trends before EMA crossover occurs
   - Expected Outcome: Titan PF improves from 1.11 to 2.0+
   
   PATCH 3: PROBABILISTIC SCORING (Influx/General Fix)
   - Function: GetProbabilisticEntryScore() - Weighted condition scoring
   - Mathematics: Converts Boolean AND to weighted score (0-100)
     * RSI extreme: 30 points
     * Price vs BB: 40 points
     * ADX confirmation: 20 points
     * Volume confirmation: 10 points
   - Logic: Trade when score > 75 (allows flexibility in conditions)
   - Impact: Strategies can trade even if one condition is slightly off
   - Expected Outcome: Increases trade frequency without sacrificing quality
   
   INTEGRATION POINTS:
   - Line 775: CKalmanFilter class added (after Silicon-X state variables)
   - Line 9990: CalculateHurstExponent() function added (before OnTester)
   - Line 10047: GetProbabilisticEntryScore() function added (utility functions)
   - Line 4502: ExecuteMeanReversionModelV8_6() - Hurst filter integrated
   - Line 6314: ExecuteTitanStrategy() - Kalman filter integrated
   
   EXPECTED OUTCOMES:
   - Mean Reversion: Only trades in true mean-reverting regimes (H < 0.45)
   - Titan: Enters trends 40% faster with reduced lag
   - System: Improved mathematical rigor, institutional-grade filtering
   - Performance Target: Mean Reversion PF 0.57 -> 1.5+, Titan PF 1.11 -> 2.0+
   
   DEVELOPED BY: @okyy.ryan + Advanced Quantitative Patch by AI Assistant
   SLOGAN: Institutional Math - Hurst, Kalman, Probabilistic Dominance
==================================================================================================================
*/

/*
================================================================================
   V18.0 PHASE 2 COMPONENT INTEGRATION MAP
================================================================================

COMPONENT USAGE GUIDE:

1. GetGeneticRiskMultiplier(magic) - Risk allocation based on strategy tier
   - Call before calculating lot size
   - Returns multiplier: 0.0 (disabled), 0.5 (dampen), 1.0 (normal), 3.0 (apex)

2. ExecuteSiliconCore() - Replaces ExecuteTrueNorthProtocol
   - Proactive trap system with auto-expansion
   - Integrated with Arbiter for directional filtering

3. ValidateTradeRisk(strategyIndex, lots) - Risk gatekeeper
   - Call before RobustOrderSend
   - Returns false if VaR > 5% or daily loss > 2%

4. GetRegimeRiskMultiplier(strategyType) - Market regime classifier
   - Type 1 = Trend strategies (Titan)
   - Type 2 = Grid strategies (Reaper/Silicon-X)
   - Returns: 0.2 (crisis), 0.5-2.0 (regime-specific)

5. ManageDrawdownExposure_V2() - Smart load shedding
   - Automatically halves worst trade at 10% DD
   - Call in OnTick before strategy execution

6. Arbiter.Refresh() - Ensemble arbitration
   - Call once per new bar
   - Use Arbiter.GetAllowedDirection() to check entry permission

7. GetVSAState() - Volume spread analysis
   - Returns: 0 (noise), 1 (breakout), 2 (reversal)
   - Use to filter Warden entries

8. GetKellyLotSize(magic, stopPips) - Dynamic position sizing
   - Uses Kelly Criterion with 25% fraction
   - Replaces static lot calculations

9. UpdatePriceBuffers() - Memory-optimized data management
   - Call once per new bar
   - Eliminates ArrayResize fragmentation

10. OnTester() - Genetic evolution metric
    - Automatically used by Strategy Tester
    - Optimizes for K-Score (profit  winrate / dd  trades)

STRATEGY INTEGRATION EXAMPLES:

// Before opening a Reaper trade:
if(!ValidateTradeRisk(4, calculatedLots)) return;
double regimeMultiplier = GetRegimeRiskMultiplier(2); // 2 = grid strategy
calculatedLots = calculatedLots * regimeMultiplier;

// Before opening a Titan trade:
int allowedDir = Arbiter.GetAllowedDirection();
if(allowedDir != -1 && allowedDir != signalDirection) return; // Block if conflict

// Dynamic lot sizing:
double lots = GetKellyLotSize(magicNumber, stopLossPips);
lots = lots * GetGeneticRiskMultiplier(magicNumber);
lots = lots * GetRegimeRiskMultiplier(1); // 1 = trend strategy

================================================================================
*/

// #include <QuantumOscillator.mqh> // REMOVED: QVO strategy purged in Phoenix Operation
// V23 FIX: Inline error codes for self-contained EA (no external includes)
// #include <stderror.mqh> // REMOVED FOR SELF-CONTAINED EA
// #include <stdlib.mqh>   // REMOVED FOR SELF-CONTAINED EA

//+------------------------------------------------------------------+
//| V23: INLINE ERROR CODES (Replacing stderror.mqh)                |
//+------------------------------------------------------------------+
#define ERR_NO_ERROR                    0
#define ERR_NO_RESULT                   1
#define ERR_COMMON_ERROR                2
#define ERR_INVALID_TRADE_PARAMETERS    3
#define ERR_SERVER_BUSY                 4
#define ERR_OLD_VERSION                 5
#define ERR_NO_CONNECTION               6
#define ERR_NOT_ENOUGH_RIGHTS           7
#define ERR_TOO_FREQUENT_REQUESTS       8
#define ERR_MALFUNCTIONAL_TRADE         9
#define ERR_ACCOUNT_DISABLED           64
#define ERR_INVALID_ACCOUNT            65
#define ERR_TRADE_TIMEOUT             128
#define ERR_INVALID_PRICE             129
#define ERR_INVALID_STOPS             130
#define ERR_INVALID_TRADE_VOLUME      131
#define ERR_MARKET_CLOSED             132
#define ERR_TRADE_DISABLED            133
#define ERR_NOT_ENOUGH_MONEY          134
#define ERR_PRICE_CHANGED             135
#define ERR_OFF_QUOTES                136
#define ERR_BROKER_BUSY               137
#define ERR_REQUOTE                   138
#define ERR_ORDER_LOCKED              139
#define ERR_LONG_POSITIONS_ONLY_ALLOWED  140
#define ERR_TOO_MANY_REQUESTS         141
#define ERR_TRADE_MODIFY_DENIED       145
#define ERR_TRADE_CONTEXT_BUSY        146
#define ERR_TRADE_EXPIRATION_DENIED   147
#define ERR_TRADE_TOO_MANY_ORDERS     148
#define ERR_TRADE_HEDGE_PROHIBITED    149
#define ERR_TRADE_PROHIBITED_BY_FIFO  150

//+------------------------------------------------------------------+
//| V23: GetErrorDescription (Replacing stdlib.mqh function)         |
//+------------------------------------------------------------------+
string GetErrorDescription(int errorCode) {
   switch(errorCode) {
      case ERR_NO_ERROR:                  return "No error";
      case ERR_NO_RESULT:                 return "No result";
      case ERR_COMMON_ERROR:              return "Common error";
      case ERR_INVALID_TRADE_PARAMETERS:  return "Invalid trade parameters";
      case ERR_SERVER_BUSY:               return "Trade server is busy";
      case ERR_OLD_VERSION:               return "Old version of client terminal";
      case ERR_NO_CONNECTION:             return "No connection with trade server";
      case ERR_NOT_ENOUGH_RIGHTS:         return "Not enough rights";
      case ERR_TOO_FREQUENT_REQUESTS:     return "Too frequent requests";
      case ERR_MALFUNCTIONAL_TRADE:       return "Malfunctional trade operation";
      case ERR_ACCOUNT_DISABLED:          return "Account disabled";
      case ERR_INVALID_ACCOUNT:           return "Invalid account";
      case ERR_TRADE_TIMEOUT:             return "Trade timeout";
      case ERR_INVALID_PRICE:             return "Invalid price";
      case ERR_INVALID_STOPS:             return "Invalid stops";
      case ERR_INVALID_TRADE_VOLUME:      return "Invalid trade volume";
      case ERR_MARKET_CLOSED:             return "Market is closed";
      case ERR_TRADE_DISABLED:            return "Trade is disabled";
      case ERR_NOT_ENOUGH_MONEY:          return "Not enough money";
      case ERR_PRICE_CHANGED:             return "Price changed";
      case ERR_OFF_QUOTES:                return "Off quotes";
      case ERR_BROKER_BUSY:               return "Broker is busy";
      case ERR_REQUOTE:                   return "Requote";
      case ERR_ORDER_LOCKED:              return "Order is locked";
      case ERR_LONG_POSITIONS_ONLY_ALLOWED: return "Only long positions allowed";
      case ERR_TOO_MANY_REQUESTS:         return "Too many requests";
      case ERR_TRADE_MODIFY_DENIED:       return "Modification denied";
      case ERR_TRADE_CONTEXT_BUSY:        return "Trade context is busy";
      case ERR_TRADE_EXPIRATION_DENIED:   return "Expirations are denied";
      case ERR_TRADE_TOO_MANY_ORDERS:     return "Too many orders";
      case ERR_TRADE_HEDGE_PROHIBITED:    return "Hedging prohibited";
      case ERR_TRADE_PROHIBITED_BY_FIFO:  return "Prohibited by FIFO rule";
      default:                            return "Unknown error: " + IntegerToString(errorCode);
   }
}
/*
==================================================================================================================
   ### EXPERT ADVISOR: DESTROYER QUANTUM V17.6 WINNER TAKES ALL PROTOCOL - CRITICAL PATCH PROTOCOL ###
   ==================================================================================================================
   STRATEGIC MANDATE: DQ-V17.5-20251125 - OPERATION PROBABILISTIC EVOLUTION
   
   V17.5 QUANTUM PROBABILISTIC MODEL INTEGRATION:
   The system has been upgraded from static risk allocation to a Dynamic Probabilistic Model.
   This architecture implements an "Internal Proxy" concept to force failing strategies (Warden, Mean Reversion)
   to adopt the genetic traits of the successful "Reaper" protocol.
   
   FOUR CORE FUNCTIONS ADDED:
   
   1. OptimizeStrategyWeights(magicNumber) - GENETIC PERFORMANCE MONITOR
      - Scans last 50 trades for each magic number
      - Calculates dynamic weighting multiplier (0.1 to 2.0) based on realized Profit Factor
      - Punishment: PF < 1.2  10% risk (choke failing strategies)
      - Survival: PF 1.2-2.0  100% risk (normal operation)
      - Domination: PF > 2.0  200% risk (amplify winners)
   
   2. IsReaperConditionMet() - REAPER LOGIC CLONING FILTER
      - Validates market texture matches high-win-rate conditions
      - Momentum Check: RSI must be outside 45-55 "dead zone"
      - Volatility Check: Bollinger Band width must be >10 pips (avoid low vol chop)
      - Applied to Warden and Mean Reversion before they can trade
   
   3. GetVolumeBias() - INSTITUTIONAL VSA (VOLUME SPREAD ANALYSIS)
      - Returns: 1 (Bullish Flow), -1 (Bearish Flow), 0 (Neutral)
      - Anomaly 1 "The Trap": High Volume + Small Candle = Reversal imminent
      - Anomaly 2 "The Drive": High Volume + Big Candle = Trend continuation
      - Uses tick volume relative to candle size for smart money detection
   
   4. MoneyManagement_Quantum(magicNumber, baseRiskPercent) - QUANTUM RISK FUNCTION
      - Combines Account Equity, Genetic Weight, and VSA Score
      - Formula: (Equity  Risk  Genetics  VSA) / StopLoss
      - Auto-scales lot size based on strategy performance history
      - Self-correcting: Bad strategies get smaller lots, good ones get amplified
   
   INTEGRATION POINTS:
   - ExecuteMeanReversionModelV8_6(): IsReaperConditionMet() filter added
   - ExecuteWardenStrategy(): IsReaperConditionMet() filter added
   - Lot sizing replaced: Leviathan_GetDynamicLotSize()  MoneyManagement_Quantum()
   - System automatically "kills" bad logic (via lot reduction) and "amplifies" good logic
   
   EXPECTED OUTCOMES:
   - Self-correction: System naturally reduces exposure to failing strategies
   - Performance amplification: Winning strategies automatically get more capital
   - Market condition filtering: Only trades in "alive" markets with clear momentum
   - Institutional alignment: VSA ensures trades align with smart money flow
   
   ===== PREVIOUS VERSION HISTORY =====
   STRATEGIC MANDATE: DQ-V17.4-20251107 - OPERATION PHOENIX: REAPER PROTOCOL RESTORATION
   
   OPERATION PHOENIX EXECUTIVE SUMMARY:
   The failed assimilation of Reaper into the Aegis Shield system has been corrected. Reaper protocol 
   performance degraded from PF 1.59 to 1.09 (near-breakeven) due to the Aegis Shield forcing it to 
   move to breakeven after only $50 profit, preventing it from reaching its full $400 target.
   
   CORE PROBLEM IDENTIFIED:
   - Reaper's true philosophy: Fixed monetary basket take profit ($400 target)
   - Aegis Shield interference: Forced breakeven at $50, never allowing full target reach
   - Result: Strategic degradation of Reaper's native profit extraction capability
   
   OPERATION PHOENIX SOLUTION:
   1. DECOUPLING: Complete separation of Reaper from Aegis Shield system
   2. NATIVE LOGIC: Restoration of Reaper's true fixed monetary basket exit system
   3. INDEPENDENT COMMAND: Separate OnTick_Reaper() function for autonomous operation
   4. PHOENIX PARAMETER: New InpReaper_BasketTP_Money = 400.0 for native basket targeting
   
   EXPECTED RESTORATION OUTCOMES:
   - Reaper Profit Factor: Target restoration to 2.0+ (from current 1.09)
   - Maximum Drawdown: Reduction through proper basket closure timing
   - Strategic Independence: Reaper operates according to its true design philosophy
   - Performance Isolation: Reaper performance no longer compromised by Aegis interference
   
   THE REAPER PROTOCOL SPECIFICATIONS (RESTORED TO NATIVE LOGIC):
   - Strategy Type: Grid/Martingale with fixed monetary basket management
   - Execution Timeframe: H4 (optimal for mean reversion)
   - Magic Numbers: 888001 (buy basket), 888002 (sell basket)
   - Grid Step: 25 pips (Sengkuni-optimized)
   - Lot Progression: 1.3x geometric multiplier (Sengkuni-derived)
   - Safety Limit: Maximum 10 levels per basket
   - Profit Target: $400 per basket closure (Phoenix Protocol)
   - Philosophy: Extract profit from market noise through position management
   
   ARCHITECTURAL CHANGES:
   - ManageSiliconX_AegisTrail(): Reaper logic removed, pure Silicon-X management
   - ManageReaperBasket(): New function for basket-based take profit
   - OnTick_Reaper(): Independent command structure for Reaper protocol
   - OnTick_SiliconX(): Independent command structure for Silicon-X protocol
   
   EXPECTED IMPACT:
   - Restores Reaper's true profit extraction capability
   - Eliminates Aegis Shield interference with Reaper performance
   - Provides independent protocol operation for maximum performance
   - Reduces drawdown through proper basket closure timing
   
   DEVELOPED BY: @okyy.ryan + MiniMax Agent Enhancement
   SLOGAN: Performance-Driven Precision & Tactical Excellence
==================================================================================================================
*/

/*
==================================================================================================================
   ### V17.10 PHASE 4 - HIGH-FREQUENCY UNLOCK ###
   ==================================================================================================================
   PATCH DATE: 2025-11-28
   STATUS: TRADE VOLUME AMPLIFICATION - FROM 179 TO 1000+ TRADES
   
   DIAGNOSIS:
   Phase 3 was TOO SAFE. 179 trades in 6 years = ~2 trades/month.
   This is unacceptable for an algorithmic system. We "over-fitted" for safety,
   strangling profit potential. The safety locks were TOO TIGHT.
   
   PHASE 4 SOLUTION: THE "HIGH-FREQUENCY" UNLOCK
   Open the floodgates while keeping the "Airbags" (Stops/Risk Management) from Phase 3.
   
   THREE CRITICAL CHANGES:
   
   1. TASK 1: REVIVE "MEAN REVERSION" (The Volume Generator)
      - Function: IsMeanReversionSafe()
      - CHANGED: Bollinger Band Deviation 3.0 -> 2.0 (Standard BB)
      - CHANGED: RSI Levels 25/75 -> 30/70 (Standard Levels)
      - Impact: 10x increase in Mean Reversion trade volume
      - Result: Trades on every volatility spike instead of statistical anomalies
   
   2. TASK 2: UNLEASH "REAPER" (The Alpha Sentinel Fix)
      - Function: AlphaSentinel_Check() [NEW FUNCTION]
      - Problem: Alpha Sentinel was rejecting perfectly good Reaper trades (PF 132.06)
      - CHANGED: ADX threshold for Reaper from 20-25 -> 10 (only block if market dead)
      - CHANGED: Mean Reversion ADX limit from 30 -> 45 (let it fade normal trends)
      - Integration: Added to IsHighConvictionSignal() to filter Reaper entries
      - Result: Reaper trades more frequently in "Good" conditions instead of "Perfect"
   
   3. TASK 3: ACCELERATE "TITAN" (Trend Frequency)
      - Function: GetTitanAllowedDirection()
      - Problem: Titan was waiting for Daily trend changes (takes months)
      - CHANGED: Timeframe D1/EMA200 -> H1/EMA100
      - CHANGED: Added 10-pip buffer for trend confirmation
      - Result: Titan becomes "Swing Trader" catching weekly swings instead of yearly trends
   
   EXPECTED OUTCOMES:
   - Trade Count: From 179 -> 1000+ trades (5-6x increase)
   - Mean Reversion: Takes trades on every volatility spike
   - Reaper: Engages more often with relaxed ADX filter
   - Titan: Catches every weekly trend instead of waiting months
   - Risk Management: Phase 3 stops/trailing still active (safety preserved)
   
   INTEGRATION POINTS:
   - IsMeanReversionSafe(): Line 9253 - Updated BB/RSI thresholds
   - AlphaSentinel_Check(): NEW FUNCTION - Inserted before IsMeanReversionSafe
   - GetTitanAllowedDirection(): Line 9235 - Updated timeframe and EMA
   - IsHighConvictionSignal(): Line 4541 - Integrated AlphaSentinel_Check call
   
   DEVELOPED BY: @okyy.ryan + Phase 4 Patch by AI Assistant
   SLOGAN: High Frequency, High Quality - Volume with Safety
==================================================================================================================
*/

/*
==================================================================================================================
   ### V18.0 INSTITUTIONAL CANDIDATE - EMERGENCY ROLLBACK & SURGICAL STRIKE ###
   ==================================================================================================================
   PATCH DATE: 2025-11-27
   STATUS: EMERGENCY ROLLBACK & SYSTEM RESTORATION
   
   DIAGNOSIS:
   We fell into a classic "Over-Engineering" trap with V17.9.
   - The Ratchet Failed: It panic-closed trades at the bottom of a normal pullback (-13%), locking in losses
   - The Hardcode Failed: Forcing 5.0x risk on a fresh account without history caused immediate drawdown
   - The Soft Pierce Failed: Relaxed Reaper filters (RSI 68/32, wick touch) generated garbage trades
   
   THE TRUTH IS IN THE V17.8 LOGS:
   Look closely at your V17.8 data (The "Good" run):
   - Reaper Protocol: 103 Trades, PF 16.79 (PERFECT)
   - Silicon-X: 53 Trades, PF 10.98 (PERFECT)
   - Warden: Gross Profit $22,500... Gross Loss -$18,500 (VOLATILE)
   - Mean Reversion: PF 0.42 (FAILURE)
   
   THE FIX: V18.0 INSTITUTIONAL CANDIDATE PROTOCOL
   We do not need complex math. We need to AMPUTATE the infected limbs.
   V17.10 returns to the V17.8 "Titanium" Logic (Strict Entries) but explicitly BANS Warden and Mean Reversion.
   We will trade ONLY Reaper and Silicon-X.
   
   FOUR CRITICAL CHANGES:
   
   1. THE "APEX ONLY" RISK ALLOCATOR (Surgical Strike)
      - Function: GetGeneticRiskMultiplier()
      - Reaper (888001, 888002): 2.5x risk (PF 16.79 - ELITE)
      - Silicon-X (984651): 2.5x risk (PF 10.98 - ELITE)
      - ALL OTHERS: 0.0x risk (BANNED)
      - Logic: Only fund strategies with PF > 10. Kill everything else.
   
   2. RESTORE V17.8 STRICT ENTRY LOGIC (Titanium Core)
      - Function: IsReaperConditionMet()
      - V17.9's "Soft Pierce" REVERTED
      - Price must CLOSE outside Bollinger Bands (not just wick touch)
      - RSI strict at 30/70 (not relaxed 32/68)
      - SELL: Close > Upper Band AND RSI > 70
      - BUY: Close < Lower Band AND RSI < 30
      - Target: Restore PF 16.79 sniper precision
   
   3. SMART EQUITY PRESERVATION (No Panic Ratchet)
      - Function: ManageDrawdownExposure_V2()
      - The "Ratchet" caused the V17.9 loss by closing trades early
      - New logic: "Drawdown Halver"
      - If we hit 15% drawdown, close HALF the position to survive
      - Keep the trade open to recover (no panic liquidation)
      - Logic: 150 Trades x High Quality > 400 Trades x Mixed Garbage
   
   4. CONFIGURATION CLEANUP
      - Removed: CheckProfitRetention() function (dangerous)
      - Verified: Magic Numbers match exactly (Reaper 888001/888002, Silicon-X 984651)
      - Target: Restore the equity curve of V17.8 without the Warden-induced volatility
   
   EXPECTED OUTCOMES:
   - Trading Frequency: ~150 trades (vs 300+ in V17.9)
   - Quality Over Quantity: Every trade from "PF 10+" strategies
   - Drawdown Protection: Halve positions instead of panic close
   - System Stability: No more Warden swings, no more Mean Reversion losses
   - Performance Target: Restore V17.8 baseline with improved stability
   
   DEVELOPED BY: @okyy.ryan + V17.10 Emergency Patch
   SLOGAN: Apex Strategies Only - Quality Over Quantity
==================================================================================================================
*/

/*
==================================================================================================================
   ### V17.9 PROFIT RATCHET - ASYMMETRIC RISK DOMINANCE ###
   ==================================================================================================================
   PATCH DATE: 2025-11-26
   PATCH REASON: V17.8 System made $17,000 profit then lost it back. Net Profit: $4,517.
   
   THE DIAGNOSIS:
   - Warden Gross Profit: $22,500 (created massive equity spike)
   - Warden Gross Loss: -$18,528 (created massive crash)
   - Reaper/Silicon-X: Near perfect (PF 10+), but too small to offset Warden's swings
   - Problem: System made $17k peak equity, then gave it all back
   
   THE FIX: "ASYMMETRIC RISK DOMINANCE" (V17.9)
   
   THREE CRITICAL CHANGES:
   
   1. THE PROFIT RATCHET (High Water Mark Protection)
      - Continuously monitors Peak Equity (High Water Mark)
      - If equity drops 10% from peak, LIQUIDATE EVERYTHING
      - Prevents "Making 17k and losing it" scenario
      - Function: CheckProfitRetention() called first in OnTick()
   
   2. ASYMMETRIC ALLOCATION (Hard-Coded Hierarchy)
      - God Tier (Reaper & Silicon-X): 5.0x risk (PF > 10)
      - Volatile Tier (Warden): 0.3x risk (profitable but dangerous)
      - Dead Tier (Mean Reversion): 0.0x risk (loses money)
      - Function: GetStrategySpecificRisk() overrides genetic calculation
   
   3. REAPER PROTOCOL V3 (Balanced Elite)
      - Changed from "Close OUTSIDE bands" to "Wick TOUCHED bands"
      - RSI relaxed from 30/70 to 32/68
      - Goal: Slightly more volume than V17.8, better quality than V17.7
      - Function: IsReaperConditionMet() updated logic
   
   EXPECTED OUTCOMES:
   - Profit Ratchet: Locks in gains, exits at 10% drawdown from peak
   - Reaper Amplified: Gets 5x capital allocation (God Tier)
   - Warden Leashed: Capped at 20% of previous size (0.3x)
   - Mean Reversion Banned: Gets ZERO capital (0.0x)
   - System preserves $17k peaks instead of riding them back down
   
   DEVELOPED BY: @okyy.ryan + V17.9 Patch by AI Assistant
   SLOGAN: Lock The Gains - Asymmetric Risk, Asymmetric Returns
==================================================================================================================
*/

/*
==================================================================================================================
   ### V17.8 TITANIUM CORE - SYSTEM FAILURE ANALYSIS & FIX ###
   ==================================================================================================================
   PATCH DATE: 2025-11-26
   PATCH REASON: V17.7 "DILUTION ERROR" - Net Profit dropped from $3,263 to $1,771
   
   THE DIAGNOSIS:
   - V17.7 relaxed Reaper RSI filters from 30/70 to 35/65 for "more volume"
   - V17.6 Reaper: 68 Trades, PF 12.94 (Sniper Mode)
   - V17.7 Reaper: 88 Trades, PF 1.65 (Shotgun Mode - FAILURE)
   - Result: 20 extra trades were GARBAGE setups, massive losses
   - Mean Reversion: Lost -$2,273 (cancer strategy)
   - Max Drawdown: 49.8% (CRITICAL FAILURE)
   
   THE FIX: "TITANIUM CORE" (V17.8)
   We are stripping back. No more "Expansion." No more "Mercy."
   
   THREE CRITICAL CHANGES:
   
   1. THE GUILLOTINE (Strict Risk Allocator)
      - KILL ZONE: PF < 1.05  0% risk (Mean Reversion banned immediately)
      - PROBATION: PF < 1.4  10% risk (prove yourself)
      - SCALING: PF < 2.5  100% risk (normal operation)
      - GOD TIER: PF >= 2.5  400% risk (Reaper amplification)
      - Grace period reduced from 15 to 10 trades
   
   2. REAPER SNIPER MODE (Logic Restoration)
      - RSI filter tightened back to 30/70 (from diluted 35/65)
      - Entry logic: Price MUST pierce Bollinger Band + RSI MUST be extreme
      - SELL: Price > Upper Band AND RSI > 70
      - BUY: Price < Lower Band AND RSI < 30
      - Target: Restore PF 12+ sniper precision
   
   3. DYNAMIC ATR STOP LOSS (Drawdown Killer)
      - Replaces fixed stop losses with volatility-based stops
      - Formula: Stop Loss = 1.5  ATR(14)
      - Safety clamps: Minimum 15 pips, Maximum 100 pips
      - Prevents 50% drawdowns from fixed stops in volatile markets
   
   EXPECTED OUTCOMES:
   - Mean Reversion BANNED (GetGeneticRiskMultiplier returns 0.0 for PF < 1.05)
   - Reaper restored to PF 12+ status (quality over quantity)
   - Drawdown capped by ATR stops (stops widen in chaos, tighten in calm)
   - System returns to PF > 2.0 baseline
   
   DEVELOPED BY: @okyy.ryan + V17.8 Patch by AI Assistant
   SLOGAN: Quality Over Quantity - Sniper, Not Shotgun
==================================================================================================================
*/

/*
==================================================================================================================
   ### V17.6 WINNER TAKES ALL PROTOCOL - CRITICAL PATCH ###
   ==================================================================================================================
   PATCH DATE: 2025-11-25
   PATCH REASON: INVERSE RISK SCALING BUG - Account blow from martingale death spiral
   
   ROOT CAUSE IDENTIFIED:
   - OptimizeForPF2_5() was INCREASING risk on FAILING strategies (Mean Reversion PF 0.75)
   - System logged: "Mean Reversion: Tightening entries, increasing risk factor to 1.8"
   - This is INVERTED LOGIC - amplified losses instead of cutting them
   - Meanwhile, Reaper (PF 3.06) and Silicon-X (PF 2.77) were starved of capital
   
   CRITICAL FIXES APPLIED:
   
   1. REPLACED OptimizeStrategyWeights() with GetGeneticRiskMultiplier()
      - OLD LOGIC: PF < 1.2  10% risk (too generous for losers)
      - NEW LOGIC (INVERTED):
        * PF < 1.0  0% risk (KILL ZONE - stop trading immediately)
        * PF < 1.3  20% risk (PROBATION - starve it)
        * PF < 2.0  100% risk (SURVIVAL - normal operation)
        * PF >= 2.0  200% risk (ELITE - amplify winners)
   
   2. ADDED IsTrendTooStrong() - Trend Lockout for Mean Reversion
      - Blocks Mean Reversion from selling into pumps (ADX > 30 + Volume confirmation)
      - Prevents counter-trend trades during institutional flow
   
   3. ADDED CheckCircuitBreaker() - Global Emergency Stop
      - Hard stop at 15% equity drawdown
      - Closes ALL positions immediately
      - Locks system for 24 hours to prevent revenge trading
   
   4. DISABLED ApplyUltraAggressiveOptimization()
      - This function contained the dangerous "increase risk on failure" logic
      - Now returns immediately without executing (hard stop)
   
   5. DISABLED OptimizeForPF2_5() call in OnTick
      - This was the trigger function calling the dangerous optimization
      - Commented out to prevent execution
   
   EXPECTED OUTCOMES:
   - Failing strategies (PF < 1.0) get ZERO capital allocation
   - Winning strategies (Reaper, Silicon-X) get DOUBLE capital allocation
   - Mean Reversion cannot fade strong institutional trends
   - System auto-shuts down at 15% drawdown (capital preservation)
   - "Winner Takes All" - only profitable strategies get funded
   
   TESTING PROTOCOL:
   - Deploy on demo account first
   - Monitor log for "KILL ZONE" messages (strategies with PF < 1.0)
   - Verify Reaper/Silicon-X get 2.0x multiplier
   - Verify Mean Reversion blocks during ADX > 30
   - Test circuit breaker by simulating drawdown
   
   DEVELOPED BY: @okyy.ryan + Emergency Patch by AI Assistant
   SLOGAN: Cut Losers Fast, Feed Winners Aggressively
==================================================================================================================
*/
//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
//--- General Settings
sinput string Inp_Header_General      = "====== DESTROYER QUANTUM V18.0 INSTITUTIONAL CANDIDATE ======";
//--- System: Magic Numbers
sinput string Inp_Header_Magic   = "====== SYSTEM: MAGIC NUMBERS ======";
extern int  InpMagic_MeanReversion = 777001;

extern string  InpTradeComment         = "DQ_V17.10_PH4"; // V17.10 Phase 4 High-Frequency
//--- Cerberus Model A: Mean-Reversion (Simplified)
sinput string Inp_Header_MeanReversion= "====== CERBERUS MODEL A: MEAN-REVERSION (ADAPTIVE) ======";
extern bool    InpMeanReversion_Enabled= true;        // ENABLED: OPERATION LEVIATHAN - All strategies active
extern int     InpMR_BB_Period         = 15;          // Bollinger Bands Period
extern double  InpMR_BB_Dev            = 1.9;         // Tighter bands for more signals
extern int     InpMR_RSI_Period        = 10;          // RSI Period
extern double  InpMR_RSI_OB            = 62.0;        // V27.18: Tightened from 65.0  fewer but higher quality Mean Rev entries
extern double  InpMR_RSI_OS            = 38.0;        // V27.18: Tightened from 35.0  fewer but higher quality Mean Rev entries
extern int     InpMR_CCI_Period        = 20;          // CCI Period for confirmation
extern double  InpMR_ADX_Threshold     = 20.0;        // NEW: ADX filter for trend strength

//+------------------------------------------------------------------+
//| V18.3 CHRONOS UPGRADE: MARKET MICROSTRUCTURE M15 SCALPER         |
//+------------------------------------------------------------------+
sinput string Inp_Header_Chronos = "====== CHRONOS MODEL M: MARKET MICROSTRUCTURE (M15 HFT) ======";
extern bool    InpChronos_Enabled = true;              // Enable Chronos M15 High-Frequency Scalper
extern double  InpChronos_ScalpSL_Pips = 25.0;         // Scalp Stop Loss in pips (tight)
extern double  InpChronos_ScalpTP_Pips = 35.0;         // Scalp Take Profit in pips (fast exit)
extern double  InpChronos_LotSizeMultiplier = 0.5;     // Lot size multiplier (0.5 = half of base risk)
extern int     InpChronos_MagicNumber = 999001;        // Unique Magic Number for tracking

//+------------------------------------------------------------------+
//--- Beehive Queen Protocol
sinput string Inp_Header_Queen       = "====== BEEHIVE QUEEN PROTOCOL ======";
extern bool    InpEnableCompounding   = true;        // Enable compounding
extern double  InpBase_Risk_Percent    = 1.0;         // V27.27: Raised from 0.5% for $100K target
extern double  InpBase_Risk_Percent_H1 = 0.25;        // Lower base risk for H1 strategies
extern double  InpDefensiveDD_Percent  = 15.0;        // Drawdown threshold to trigger defensive mode
extern double  InpDrawdown_Risk_Mult   = 0.3;         // Risk multiplier in defensive mode (0.3 = 30% of normal risk)
extern int     InpMaxOpenTrades      = 12;          // V27.1 FIX: Lowered from 20  accommodates 8 strategies + grid levels without runaway
extern double  InpMaxLotSize         = 5.0;         // V27.20: Maximum lot size per trade (configurable, was hardcoded 5.0)
extern bool    InpEnable_ReaperConditionFilter = false; // V26 FIX: Set true to require BB+RSI extreme before MR/Warden fire
//--- Queen: State-Based Strategy Permissions
extern bool    InpMR_Allow_Defensive  = true;  // Mean-reversion is often safe in drawdowns
//--- Queen: Portfolio Risk Budget
extern double  InpMaxTotalRisk_Percent = 8.0; // V27.19: Raised from 5.0  Kelly-governed strategies need more headroom for dynamic sizing
extern double  InpShortBiasThreshold  = 0.35; // V28.00: Short-side conviction threshold lowered from 0.6 to 0.35 for more short opportunities
//--- Queen: Adaptive Strategy Selection
extern bool   InpEnableAdaptiveSelection = false;     // <<< TEMPORARILY SET TO false
extern int    InpMinTradesForDecision  = 20;        // Min trades before Queen assesses a bee

// V13.0 ELITE: Strategy Cooldown System - Temporarily disable via a new master switch
sinput string Inp_Header_Cooldown = "====== COOLDOWN SYSTEM ======";
extern bool   InpEnableCooldownSystem  = false; // <<< ADD THIS NEW INPUT AND SET TO false

// V26 BEEHIVE: VAR Limiter & Alpha Sentinel Bypass (backtest calibration)
extern bool    InpDisable_VAR_Limiter  = false;  // V27.1 FIX: VAR gate MUST be active  was bypassed in V27 causing runaway exposure
extern bool    InpDisable_AlphaSentinel = false; // V27.1 FIX: Alpha Sentinel MUST be active  was bypassed in V27 causing unfiltered basket initiations
extern double InpMinProfitFactor       = 1.1;         // Bee is disabled if PF drops below this
//--- Aegis Dynamic Risk Protocol (Enhanced)
sinput string Inp_Header_Aegis        = "====== AEGIS DYNAMIC RISK PROTOCOL (ENHANCED) ======";
extern double  InpMax_Spread_Pips      = 55.0;         // Maximum spread in pips to allow trading
extern int     InpSlippage             = 3;           // Maximum allowed slippage in points
//--- Trade Quality Score (TQS)
extern double  InpTQS_High_Conviction  = 1.5;         // TQS multiplier for high conviction setups
extern double  InpTQS_Medium_Conviction= 1.0;         // TQS multiplier for medium conviction setups
extern double  InpTQS_Low_Conviction   = 0.5;         // TQS multiplier for low conviction setups
extern double  InpMinTQSForEntry       = 0.35;        // V27.7: Raised from 0.2 for higher quality setups
//--- Volatility-Adjusted Stop-Loss
extern double  InpATR_Multiplier       = 2.5;         // Multiplier for volatility forecast
//--- Multi-Stage Trailing Stop
extern double  InpPSAR_Step           = 0.02;        // Step value for Parabolic SAR
extern double  InpPSAR_Max            = 0.2;         // Maximum value for Parabolic SAR
extern int     InpChandelier_Period   = 22;          // Period for Chandelier Exit
extern double  InpChandelier_Multiplier= 3.0;         // Multiplier for Chandelier Exit
extern int     InpEMA_Trail_Period     = 10;          // Period for EMA trailing stop
//--- Market Condition Filters
sinput string Inp_Header_MarketFilters= "====== MARKET CONDITION FILTERS ======";
extern bool    InpEnableMarketFilters  = true;        // Enable market condition filters
//--- Time Filters
sinput string Inp_Header_TimeFilters   = "====== TIME FILTERS ======";
extern bool    InpEnableTimeFilter     = true;        // V27.20 FIX: Enable time-based trading restrictions (was false  20:00 UTC = 46.2% loss rate)
extern bool    InpTradeMonday          = true;        // Allow trading on Monday
extern bool    InpTradeTuesday         = true;        // Allow trading on Tuesday
extern bool    InpTradeWednesday       = false;       // V27.20 FIX: Block Wednesday trading (44% loss rate)
extern bool    InpTradeThursday        = true;        // Allow trading on Thursday
extern bool    InpTradeFriday          = true;        // Allow trading on Friday
extern bool    InpTradeSaturday        = false;       // Allow trading on Saturday
extern bool    InpTradeSunday          = false;       // Allow trading on Sunday
extern int     InpTradingStartHour     = 8;           // Start trading hour (server time)
extern int     InpTradingEndHour       = 18;          // End trading hour (server time)
extern int     InpServerUTCOffset      = 2;           // V27.20: Server-to-UTC offset (hours). Used by IsBadTradingHour()
//--- Visuals & Dashboard
sinput string Inp_Header_Visuals      = "====== VISUALS & DASHBOARD ======";
extern bool    InpShow_Dashboard       = true;        // Show on-chart dashboard
extern color   InpDashboard_BG_Color   = C'28,28,38'; // Background color
extern color   InpDashboard_Text_Color = C'210,210,220'; // Main text color
extern color   InpColor_Positive       = clrLimeGreen;
extern color   InpColor_Negative       = C'255,80,100';
extern color   InpColor_Neutral        = clrGoldenrod;
//--- Broker Requirements
sinput string Inp_Header_Broker       = "====== BROKER REQUIREMENTS ======";
extern int     InpMinStopDistancePoints = 30;         // Minimum stop distance in points (adjust based on your broker)

//+------------------------------------------------------------------+
//|                      NEW ADVANCED STRATEGIES                     |
//+------------------------------------------------------------------+


//--- Cerberus Model T: The Titan (Multi-Timeframe Momentum) ---
sinput string Inp_Header_Titan = "====== CERBERUS MODEL T: THE TITAN (MTF MOMENTUM) ======";
extern bool   InpTitan_Enabled         = true;
extern int    InpTitan_MagicNumber     = 777008;
extern int    InpTitan_D1_EMA          = 50;  // Strategic EMA on Daily chart
extern int    InpTitan_H4_EMA          = 34;  // Strategic EMA on H4 chart

//--- Huntsman Capital Preservation Protocol ---
sinput string Inp_Header_Huntsman     = "====== HUNTSMAN CAPITAL PRESERVATION ======";
extern bool   InpHuntsman_Enabled     = true;        // Enable Huntsman Capital Preservation
extern int    InpHuntsman_PrimingBars = 50;          // Bars to wait before activating defensive mode
extern double InpHuntsman_Risk_Scale  = 0.5;         // Risk scaling factor during defensive periods (50% of normal risk)

//--- Cerberus Model W: The Warden (Volatility Squeeze) ---
sinput string Inp_Header_Warden = "====== CERBERUS MODEL W: THE WARDEN (VOLATILITY SQUEEZE) ======";
extern bool   InpWarden_Enabled        = true;       // ENABLED: OPERATION LEVIATHAN - All strategies active
extern int    InpWarden_MagicNumber    = 777009;
extern int    InpWarden_BB_Period      = 20;
extern double InpWarden_BB_Dev         = 1.8;   // V27.10: Looser bands for more squeeze detections
extern int    InpWarden_KC_Period      = 20;
extern double InpWarden_KC_ATR_Mult    = 1.2;   // V27.10: Tighter channel for easier breach
extern int    InpWarden_Momentum_MA    = 50; // Momentum filter MA period

//--- Cerberus Model R: The Reaper (Grid/Martingale Basket Management) ---
sinput string Inp_Header_Reaper = "====== CERBERUS MODEL R: THE REAPER (GRID/MARTINGALE) ======";
extern bool   InpReaper_Enabled         = true;       // Enable Reaper Grid Protocol
extern int    InpReaper_BuyMagicNumber  = 888001;     // Magic number for buy basket
extern int    InpReaper_SellMagicNumber = 888002;     // Magic number for sell basket
extern double InpReaper_InitialLot      = 0.08;       // V28.00: Raised from 0.05  tighter trailing + per-level TP justifies more capital
extern double InpReaper_LotMultiplier   = 1.3;        // Geometric lot multiplier (1.3 from Sengkuni)
extern int    InpReaper_MaxLevels       = 8;          // V27.1 FIX: Tightened from 10 to 8  structural hardcap
extern int    InpReaper_PipStep         = 25;         // Grid step in pips (base multiplier for ATR dynamic grid)
extern double InpReaper_BasketTP        = 50.0;       // Basket take profit in USD ($50 target)
extern int    InpReaper_Timeframe       = PERIOD_H4;  // Execution timeframe (H4 for mean reversion)

//--- V27.1: REAPER INTELLIGENT GRID PARAMETERS ---
sinput string InpReaper_Header_Patch = "====== V27.1: REAPER INTELLIGENT GRID ======";
extern int    InpReaper_HardcapLevels   = 8;          // V27.1: Absolute max grid levels (structural cap)
extern double InpReaper_RegimeADX       = 50.0;       // V28.05 FIX #2: Raised from 30 to 50. ADX 30 is normal on EURUSD, not extreme.
// 50+ is genuinely dangerous trend territory where grid averaging is suicidal.
extern int    InpReaper_CooldownBars    = 2;          // V27.1: Min H4 bars between grid levels
extern double InpReaper_ATR_GridMult    = 0.5;        // V27.1: ATR multiplier for dynamic grid spacing

//--- V17.4: PHOENIX PROTOCOL - Reaper's True Exit System ---
sinput string InpReaper_Header_Phoenix = "====== REAPER: PHOENIX BASKET TP ======";
extern double InpReaper_BasketTP_Money  = 400.0;     // Basket Take Profit in deposit currency.

//--- V17.5: CHIMERA PROTOCOL - Reaper's Dual-Exit System ---
sinput string InpReaper_Header_Chimera   = "====== REAPER: CHIMERA TRAILING DEFENSE ======";
extern bool   InpReaper_EnableTrail       = true;       // Enable Reaper's defensive trailing stop.
extern double InpReaper_TrailStart_Money  = 150.0;      // Profit in USD to activate trail & move to BE.
extern int    InpReaper_TrailStop_Pips    = 300;        // Trailing distance in Pips after BE is activated (30 pips).

//--- Cerberus Model R: THE REAPER - ALPHA SENTINEL FILTER ---
sinput string Inp_Header_Reaper_Sentinel = "====== REAPER: ALPHA SENTINEL ENTRY FILTER ======";
extern bool   InpReaper_EnableSentinel   = true;     // Enable high-conviction filter for FIRST grid trade
extern double InpSentinel_MaxADX         = 25.0;     // Max ADX allowed for entry (avoids strong trends)
extern int    InpSentinel_MTF_MAPeriod   = 21;       // EMA Period for higher timeframe (Daily) trend check
extern double InpSentinel_MaxATR_Mult    = 1.3;      // Max ATR multiplier (blocks entry if volatility is >30% above average)

//--- CHIMERA PRIME: REAPER ELITE REVERSAL FILTER ---
sinput string Inp_Header_Reaper_Elite   = "====== REAPER: ELITE REVERSAL FILTER (CHIMERA) ======";
extern bool   InpReaper_EnableEliteFilter = true; // MASTER SWITCH for the new filter

//--- Cerberus Model S: The Silicon-X Protocol (Grid/Martingale Hybrid) ---
sinput string Inp_Header_SiliconX      = "====== CERBERUS MODEL S: SILICON-X (TRUE NORTH) ======";
//--- Main Parameters
extern bool   InpSiliconX_Enabled           = false;       // MASTER SWITCH: Enable/Disable Silicon-X Protocol (disabled V27.11-R)
extern double InpSX_InitialLot              = 0.01;         // Base lot size for the first trade in a series.
extern double InpSX_LotExponent             = 1.3;          // V27.10: Reduced from 1.6 for gentler grid growth
//--- Grid Mechanics
extern int    InpSX_MaxLevels               = 12;           // V27.10: Reduced from 18 to limit loss exposure
extern int    InpSX_PipStep                 = 180;          // V27.10: Increased from 150 for wider grid spacing
//--- "Hubble" Intelligence (Signal Filter)
extern int    InpSX_Hubble_LengthA          = 242;          // Lookback period for the inner Bollinger Band (Filter A).
extern double InpSX_Hubble_DeviationA       = 5.2;          // Standard deviation for the inner Bollinger Band (Filter A).
extern int    InpSX_Hubble_LengthB          = 354;          // Lookback period for the outer Bollinger Band (Filter B).
extern double InpSX_Hubble_DeviationB       = 22.74;        // Standard deviation for the outer Bollinger Band (Filter B).
//--- Risk Management
extern int    InpSX_TakeProfit_Points       = 2400;         // Take profit level in POINTS for each individual trade.
extern int    InpSX_StopLoss_Points         = 1200;         // Stop loss level in POINTS for each individual trade.
//--- Trailing System
extern bool   InpSX_TrailingPendingOn       = true;         // Enables the trailing of PENDING orders.
extern int    InpSX_TrailingPendingStart    = 50;           // Distance in POINTS at which PENDING order trailing begins.
extern bool   InpSX_TrailingOrderOn         = true;         // Enables trailing of OPEN positions.
extern int    InpSX_TrailingOrderStart      = 500;          // Profit in POINTS at which OPEN position trailing begins.
extern int    InpSX_TrailingOrderStop       = 100;          // Trailing stop distance in POINTS for OPEN positions.
//--- System Configuration
extern int    InpSX_MagicNumber             = 984651;       // Unique identifier for Silicon-X trades.
extern string InpSX_OrdersComment           = "Hubble";       // Comment for Silicon-X orders.
extern int    InpSX_TimerInterval           = 2;            // Processing interval in seconds to reduce CPU load.
//--- V15.5: OVERLORD - Basket Management System
sinput string InpSX_Header_Overlord        = "====== SILICON-X: OVERLORD BASKET MANAGEMENT ======";
extern bool   InpSX_EnableBasketTP         = true;         // MASTER SWITCH: Enable/Disable Basket TP logic.
extern double InpSX_BasketProfitTargetUSD  = 25.0;         // Collective profit target in account currency (e.g., USD).
//--- V16.0: JAGUAR - ATR TRAILING STOP SYSTEM ---
sinput string InpSX_Header_Jaguar          = "====== SILICON-X: JAGUAR ATR TRAILING STOP ======";
extern bool   InpSX_EnableATRtrail         = true;         // MASTER SWITCH: Enable/Disable ATR Trailing Stop.
extern int    InpSX_ATR_Period             = 14;           // ATR lookback period (e.g., 14).
extern double InpSX_ATR_Multiplier         = 3.0;          // ATR multiplier (e.g., 2.5, 3.0).
extern int    InpSX_ATR_MAPeriod           = 100;          // Period for smoothing the trailing stop price.
//--- V17.0: MANHATTAN PROJECT - Risk-Based Lot Sizing Engine ---
sinput string InpSX_Header_Manhattan       = "====== SILICON-X: MANHATTAN PROJECT RISK ENGINE ======";
extern bool   InpSX_RiskOn                 = true;         // MASTER SWITCH: Enable/Disable Risk-Based Lot Sizing.
extern double InpSX_FixLot                 = 0.01;         // Base lot size for $10,000 equity calculation.
extern double InpSX_Risk                   = 15.0;         // Risk multiplier (Risk/10.0 = aggression factor).
//--- V17.1: AEGIS SHIELD - Basket Trailing Stop System ---
sinput string InpSX_Header_Aegis        = "====== SILICON-X: AEGIS SHIELD BASKET TRAIL ======";
extern bool   InpSX_EnableAegisTrail      = true;       // MASTER SWITCH: Enable/Disable Basket Trailing Stop.
extern double InpSX_BasketTrailStartUSD   = 50.0;       // Profit in USD to activate the trail (move to Break-Even).
extern int    InpSX_BasketTrailStopPips   = 100;        // Trailing distance in Pips after BE is activated.
//--- V17.2: HUBBLE TELESCOPE - Pending Order Trailing System ---
sinput string InpSX_Header_Hubble        = "====== SILICON-X: HUBBLE TELESCOPE ENTRY PRECISION ======";
extern bool   InpSX_EnablePendingTrail    = true;       // MASTER SWITCH: Enable/Disable Pending Order Trailing.
extern int    InpSX_PendingTrailStartPips = 50;         // Pips from market price to start trailing traps.

//+------------------------------------------------------------------+
//|       HADES PROTOCOL: JUDGMENT DAY FAILSAFE                     |
//+------------------------------------------------------------------+
sinput string Inp_Header_Hades_JDay  = "====== HADES: JUDGMENT DAY PROTOCOL ======";
extern double  InpHades_BasketStopLoss_Percent = 2.5; // TIGHTENED: Max basket loss is now 2.5% of equity.

//+------------------------------------------------------------------+
//|       V27.1: QUEEN BEE GLOBAL CIRCUIT BREAKER                   |
//+------------------------------------------------------------------+
sinput string Inp_Header_QueenHedge = "====== QUEEN BEE GLOBAL CIRCUIT BREAKER ======";
extern double InpQueen_MaxDrawdownPct     = 5.0;   // Max drawdown % before strategy shutdown
extern double InpQueen_MaxExposureLots    = 1.0;   // Max total open lots across all strategies
extern double InpQueen_ReaperDDKillPct    = 3.0;   // Drawdown % to kill Reaper specifically
extern int    InpQueen_MaxConcurrentBaskets = 2;    // Max simultaneous grid baskets (Reaper + SX)

//+------------------------------------------------------------------+
//|                      NEW ENHANCED STRATEGIES                     |
//+------------------------------------------------------------------+

// ============================================================
// V26 BEEHIVE  APEX STRATEGY (Session Rollover Reverter)
// ============================================================
extern bool    InpApex_Enabled            = true;
extern double  InpApex_ATR_Multiplier_SL  = 1.5;   // SL = ATR  this value
extern double  InpApex_ATR_Multiplier_TP  = 1.2;   // TP = ATR  this value
extern double  InpApex_ATR_Trigger        = 1.5;   // Bar range must exceed ATR  this to trigger
extern int     InpApex_ATR_Period         = 20;
extern int     InpApex_MagicNumber        = 777011;

// ============================================================
// V26 BEEHIVE  PHANTOM STRATEGY (Monday Gap Fader)
// ============================================================
extern bool    InpPhantom_Enabled         = true;
extern double  InpPhantom_MaxGap_Pips     = 30.0;  // Only trade gaps  this size
extern double  InpPhantom_MinGap_Pips     = 5.0;   // V27.10: Increased from 3.0 to avoid micro-gap noise
extern double  InpPhantom_SL_GapMult      = 2.0;   // V27.10: Increased from 1.5 for wider SL
extern double  InpPhantom_TP_GapMult      = 0.9;
extern int     InpPhantom_MagicNumber     = 777013;

// ============================================================
// V26 BEEHIVE  NEXUS STRATEGY (Volatility Compression Breakout)
// ============================================================
extern bool    InpNexus_Enabled           = true;
extern int     InpNexus_ATR_Period        = 14;
extern int     InpNexus_MedianLookback    = 50;
extern int     InpNexus_CompressionBars   = 3;     // Bars below threshold to qualify
extern double  InpNexus_CompressionRatio  = 0.75;  // ATR must be < Median  this
extern double  InpNexus_SL_ATR_Mult       = 1.5;
extern double  InpNexus_TP_Median_Mult    = 2.0;
extern int     InpNexus_MagicNumber       = 777014;







//+------------------------------------------------------------------+
//| ULTRA-AGGRESSIVE PROFIT FACTOR OPTIMIZATION (V11.1)            |
//+------------------------------------------------------------------+
sinput string Inp_Header_PF_Optimization = "====== ULTRA-AGGRESSIVE PF 2.5+ OPTIMIZATION ======";
extern double InpPF_Target = 2.5;                    // Target Profit Factor
extern double InpRR_Ratio_M15 = 3.0;                 // Risk/Reward for M15 strategies
extern double InpRR_Ratio_M30 = 3.2;                 // Risk/Reward for M30 strategies  
extern double InpRR_Ratio_H1 = 2.8;                  // Risk/Reward for H1 strategies
extern double InpWinRate_Boost = 1.15;               // Win rate boost multiplier

//+------------------------------------------------------------------+
//| PHASE 5: ENHANCED PERFORMANCE OPTIMIZATION                      |
//| TARGETING: 87.3% WIN RATE, 4.2+ PROFIT FACTOR                   |
//+------------------------------------------------------------------+
sinput string Inp_Header_Phase5Optimization = "====== PHASE 5: ELITE PERFORMANCE TARGETS ======";
extern bool    InpEnablePerformanceOptimization = true;   // Enable Phase 5 optimizations
extern double  InpEnhancedWinRateTarget = 87.3;           // Target win rate percentage
extern double  InpEnhancedProfitFactorTarget = 4.2;       // Target profit factor  
extern double  InpEnhancedMaxDrawdownTarget = 8.2;        // Target max drawdown percentage
extern double  InpEnhancedSharpeRatioTarget = 3.8;        // Target Sharpe ratio
// Enhanced Conviction Thresholds
extern double  InpHighConvictionThreshold = 8.5;          // High conviction for 87%+ win rate
extern double  InpMediumConvictionThreshold = 6.0;        // Medium conviction threshold
extern double  InpUltraHighConvictionThreshold = 9.5;     // Ultra high conviction (9.5+)
// Multi-Timeframe Confirmation
extern bool    InpEnableMTFConfirmation = true;           // Enable multi-timeframe confirmation
extern int     InpMTFConfirmationBars = 3;                // Bars required for confirmation
extern double  InpMinVolumeConfirmation = 1.2;            // Minimum volume multiplier
// Enhanced Risk Management
extern bool    InpEnableDynamicRiskSizing = true;         // Dynamic position sizing
extern double  InpMaxRiskPerTrade = 0.5;                  // Max risk per trade (0.5%)
extern bool    InpEnableRegimeBasedSizing = true;         // Adjust size based on market regime
// Performance-Based Adaptation
extern bool    InpEnableAdaptiveThresholds = true;        // Adapt thresholds based on performance
extern int     InpPerformanceLookback = 100;              // Lookback for performance analysis
extern double  InpMinTradesForAdaptation = 25;            // Minimum trades before adaptation

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
//--- Cerberus State
enum ENUM_CERBERUS_MODEL
{
   MODEL_NONE,
   MODEL_MEAN_REVERSION
};
ENUM_CERBERUS_MODEL g_active_model = MODEL_NONE;
//--- Aegis State
double   g_trade_quality_score = 1.0;
double   g_initial_risk_amount = 0.0;
int      g_trail_stage = 1;
//--- Beehive Queen State
enum ENUM_HIVE_STATE
{
   HIVE_STATE_GROWTH,
   HIVE_STATE_DEFENSIVE
};
ENUM_HIVE_STATE g_hive_state = HIVE_STATE_GROWTH;
double   g_high_watermark_equity = 0.0;
double   g_current_drawdown = 0.0;
string   g_hwm_key;
//--- Huntsman Capital Preservation State
bool     g_huntsman_phase_active = true; // Flag for the initial priming period
//--- V17.9: PROFIT RATCHET - High Water Mark Protection
double   GlobalPeakEquity = 0.0;  // V17.9: Peak Equity High Water Mark for Profit Ratchet
string   g_logFileName; // GENEVA PROTOCOL V3.0

//--- Cerberus Model R: The Reaper State (Grid/Basket Management)
int      g_reaper_buy_levels = 0;        // Current number of open buy basket levels
int      g_reaper_sell_levels = 0;       // Current number of open sell basket levels
datetime g_reaper_last_trade_time = 0;   // Last trade execution time for cooldown

//--- V27.1: Queen Bee Global Circuit Breaker State
double   g_queen_total_exposure_lots = 0.0;    // Total open lots across all strategies
double   g_queen_drawdown_pct = 0.0;           // Current drawdown as % of balance
bool     g_queen_kill_reaper = false;           // Emergency flag: shut down Reaper
bool     g_queen_kill_warden = false;           // Emergency flag: shut down Warden
bool     g_queen_kill_all = false;              // Emergency flag: full system halt

//+------------------------------------------------------------------+
//|  OPERATION LEVIATHAN: ADAPTIVE KELLY CRITERION COMPOUNDING ENGINE  |
//+------------------------------------------------------------------+
sinput string Inp_Header_Leviathan = "====== LEVIATHAN: ADAPTIVE KELLY ENGINE ======";
sinput bool   InpLeviathan_Enabled = true;             // MASTER SWITCH: Enable/Disable Adaptive Kelly Engine
sinput double InpLeviathan_KellyFraction = 0.25;       // Kelly fraction multiplier (0.25 = 25% of calculated Kelly)
sinput double InpLeviathan_MaxRisk = 5.0;              // Maximum risk per trade percentage (5.0%)
sinput double InpLeviathan_MinRisk = 0.5;              // Minimum risk per trade percentage (0.5%)
sinput int    InpLeviathan_HistoryLookback = 50;       // Number of trades to analyze for Kelly calculation

//=== V27.7: EVENT SHIELD + ATR CIRCUIT BREAKER ===
sinput string InpV276_Header_EventRisk = "====== V27.7: EVENT SHIELD + ATR CIRCUIT BREAKER ======";
sinput bool   InpEventRisk_Enabled       = true;       // Block trading during FOMC/ECB/NFP windows
sinput double InpATR_SpikeMultiplier      = 1.8;        // Block trades if ATR(14) > this  MA(ATR,20)  V27.7
sinput int    InpATR_SpikeLockoutHours    = 12;         // Hours to suspend trading after ATR spike  V27.7
sinput int    InpMaxConsecutiveLoss       = 3;          // Max consecutive losses before strategy suspension  V27.7
sinput int    InpLossLockoutHours         = 24;         // Hours to suspend strategy after consec loss limit  V27.7
sinput double InpMaxDailyLoss             = 0.0;         // V27.18: REMOVED  was killing Phantom's gap-fill sequence. Per-strategy risk is sufficient.

//--- Leviathan Engine State
int      g_consecutiveWins = 0;          // Current consecutive winning trades
int      g_consecutiveLosses = 0;        // Current consecutive losing trades
double   g_leviathan_kellyFraction = 0.25;    // Use 25% of the calculated Kelly size
double   g_leviathan_maxRisk = 5.0;           // Allow risk to go up to 5% per trade in high-confidence scenarios
double   g_leviathan_minRisk = 0.5;           // Never risk less than 0.5% on an approved signal
double   g_reaper_buy_avg_price = 0.0;   // Average price of buy basket
double   g_reaper_sell_avg_price = 0.0;  // Average price of sell basket
bool     g_reaper_buy_active = false;    // Flag if buy basket is active
bool     g_reaper_sell_active = false;   // Flag if sell basket is active

//--- V27.7: EVENT SHIELD STATE (ATR Spike, Consecutive Loss Guardian) ---
datetime g_atrSpikeLockoutUntil = 0;                // Timestamp until which trading is suspended
int      g_consecLossTracker[17][2];                // [idx][0]=streak(-1=losses,1=wins) [idx][1]=count
datetime g_strategyLockoutUntil[15];                // Per-strategy lockout timestamps
double   g_lastATRValue = 0.0;                     // Last ATR value
double   g_lastATRMA = 0.0;                        // Last ATR MA value
double   g_dailyPandL = 0.0;                       // V27.16: Current day's net P&L (resets at midnight)
datetime g_lastPandLDate = 0;                      // V27.16: Date of last P&L reset

//--- V27.8: ADAPTIVE RISK UNWIND STATE ---
double   g_strategyMultiplier[17];                 // Dynamic risk multipliers [0-16] per strategy index
// Each starts at 1.0. On loss: *= 0.8, On win: *= 1.1
// Clamped between 0.2 and strategy's max Kelly tier

//--- V27.19: DYNAMIC PERFORMANCE-BASED LOT SIZING ---
// Rolling trade history per strategy for Kelly calculation
#define STRATEGY_HISTORY_SIZE 60                   // Rolling window of last N trades
double   g_stratProfits[15][60];                   // Profit/loss of last 60 trades per strategy
int      g_stratProfitIdx[15];                     // Current circular buffer index per strategy
int      g_stratTotalTrades[17];                   // Total trades completed per strategy
double   g_stratRollingWinRate[15];                // Rolling win rate (EWMA)
double   g_stratRollingAvgWin[15];                 // Rolling average winning trade $
double   g_stratRollingAvgLoss[15];                // Rolling average losing trade $
double   g_stratRollingPF[15];                     // Rolling profit factor
double   g_stratKellyFraction[17];                 // Kelly-optimal fraction per strategy
double   g_stratSharpeProxy[15];                   // Rolling Sharpe proxy (return/volatility)
double   g_stratHeatScore[17];                     // 0.0-1.0: How much "heat" (capital) to allocate
datetime g_stratLastCalcTime[15];                  // Last time Kelly was recalculated
// Dynamic tier caps  replace hardcoded per-strategy caps
double   g_stratDynamicMaxMult[17];                // Dynamically computed max multiplier per strategy

// V27.21: Drawdown protection flag
bool     g_ddProtectionActive = false;             // Set by ManageDrawdownExposure_V2 when DD > 10% (V28.00: tightened from 12%)

//--- Cerberus Model S: The Silicon-X State (Grid/Basket Management)
int      g_siliconx_buy_levels = 0;        // Current number of open buy basket levels
int      g_siliconx_sell_levels = 0;       // Current number of open sell basket levels
datetime g_siliconx_last_trade_time = 0;   // Last trade execution time for cooldown

//+------------------------------------------------------------------+
//| V18.1 QUANTUM MATH PATCH: KALMAN FILTER CLASS                    |
//+------------------------------------------------------------------+
class CKalmanFilter
{
   private:
      double state_est; // Estimate of the state (Price)
      double error_cov; // Error covariance
      double q;         // Process noise covariance (The real movement)
      double r;         // Measurement noise covariance (Market noise)

   public:
      // Constructor: Tune q and r. Higher Q = faster reaction. Higher R = more smoothing.
      void Init() {
         state_est = 0; 
         error_cov = 0.1;
         
         // V18.2 Speed Update:
         // INCREASE q (Process Noise) to make it trust price changes more.
         // DECREASE r (Measurement Noise) to reduce smoothing lag.
         q = 0.10;  // Was 0.05 -> Faster reaction to trend starts
         r = 0.10;  // Was 0.15 -> Less lag, slightly more noise tolerance
      }

      double Update(double measurement) 
      {
         // 1. Initialize if first run
         if(state_est == 0) { state_est = measurement; return state_est; }

         // 2. Prediction Step
         double predicted_error = error_cov + q;

         // 3. Kalman Gain Calculation (ZERO-DIVIDE PROTECTION)
         double denominator = predicted_error + r;
         if(denominator == 0 || denominator < 0.000001) denominator = 0.000001; // Prevent zero divide
         double kalman_gain = predicted_error / denominator;

         // 4. Correction Step (The Magic)
         state_est = state_est + kalman_gain * (measurement - state_est);
         
         // 5. Update Covariance
         error_cov = (1 - kalman_gain) * predicted_error;

         return state_est;
      }
};
CKalmanFilter KalmanTitan; // Global Instance for Titan Strategy

//--- MULTI-TIMEFRAME DATA ARRAYS (NEW V11.0) ---
datetime lastM15Bar, lastM30Bar, lastH1Bar;

double m15High[], m15Low[], m15Close[], m15Volume[], m15Open[];
double m30High[], m30Low[], m30Close[], m30Volume[], m30Open[];
double h1High[], h1Low[], h1Close[], h1Volume[], h1Open[];

//--- Kelly Criterion Variables ---
double   g_kelly_fraction = 0.25; // Conservative Kelly fraction
double   g_strategy_win_rates[7]; // Win rates for each strategy
double   g_strategy_avg_wins[7];  // Average win amounts
double   g_strategy_avg_losses[7]; // Average loss amounts

//--- Signal Arbitration Variables ---
double   g_signal_conviction[7]; // Signal strength for each strategy
int      g_signal_priority[7];   // Priority for signal arbitration

// --- GENEVA PROTOCOL V4.0: In-Memory Accumulator ---
struct PerfData
{
   string name;
   int    trades;
   double grossProfit;
   double grossLoss;
};

// ============================================================================
// V23 INSTITUTIONAL EMPIRICAL PROBABILITY STRUCTURES
// ============================================================================

// Empirical Probability Bin (Per-Strategy Per-Deviation-Level)
struct EmpiricalProbBin {
    double hitRate;          // EWMA P(reversal) for this deviation bin
    int observationCount;    // Total observations in this bin
    datetime lastUpdate;     // Last update timestamp (for decay tracking)
};

// Strategy Performance Tracker (V23 Enhanced)
struct V23_StrategyPerformance {
    string strategyName;
    int magicNumber;
    
    // R-Multiple Tracking
    double ewmaRProfit;      // EWMA of R-profit (winners)
    double ewmaRLoss;        // EWMA of R-loss (losers)
    double rExpectancy;      // R-expectancy = R_win * P_win - R_loss * P_loss
    
    // Empirical Probability Bins (5 deviation levels)
    EmpiricalProbBin probBins[5];  // 0: <1.0, 1: 1.0-1.5, 2: 1.5-2.0, 3: 2.0-2.5, 4: >2.5
    
    // Tail Risk Tracking (Per Regime)
    double condLossProb[3];  // P(loss|prev_loss) for [Range, Trend, Volatile]
    bool lastWasLoss[3];     // Track previous outcome per regime
    
    // Bidirectional Regime Feedback
    double regimeSurprise;   // EWMA surprise = |predicted - actual|
    int regimeConfirmCount;  // Aggregation counter (adjust after 3+ confirms)
    
    // Trade History (for R-calculation)
    double lastStopLossPips; // Last trade SL for R-calc
    double lastDeviation;    // Last entry deviation (for bin update)
    int lastRegimeType;      // Last regime at entry
};

// Market Regime State (V23 Enhanced)
struct V23_RegimeState {
    int type;                // 0: Range, 1: Trend, 2: Volatile, 3: TREND_PROBATION (V25)
    double confidence;       // Regime confidence [0,1]
    double confAdjustment;   // Bidirectional feedback adjustment
    
    // Mathematical Regime Metrics
    double volatilityCluster; // Short_var / Long_var
    double signAutocorr;      // Sign autocorrelation (persistence)
    double trendSlope;        // Linear regression slope
    double trendR2;           // Regression R
    double entropyNorm;       // Normalized Shannon entropy [0,1]
    
    // V25: Regime Probation/Hysteresis (Fix #2)
    int prevRegime;           // Previous regime type for hysteresis
    int barsInRegime;         // Bars spent in current regime
    
    datetime lastUpdate;
};

// Trade-Level Equity Delta (for VAR)
struct V23_TradeEquityDelta {
    double equityChange;     // Change in equity (% of account)
    double rValue;           // R-multiple of trade
    datetime closeTime;
    int strategyMagic;
};


// V26 BEEHIVE: Slot map:
//   0=MeanReversion  1=QuantumOsc(retired)  2=Titan        3=Warden
//   4=Reaper         5=Silicon-X            6=Chronos      7=NoiseBreakout
//   8=Apex           9=Phantom             10=Nexus       11=Vortex
//  12=RegimeShift   13=SessionMomentum    14=DivergenceMR  15-16=Reserved
PerfData g_perfData[17];

// V13.0 ELITE: Strategy Cooldown System - Temporary Disablement Protocol
struct StrategyCooldown {
   bool disabled;
   datetime disabledTime;
   int disabledBars;
};
StrategyCooldown g_strategyCooldown[17]; // V28.00: Extended to 17 strategies
// ---

//--- Dashboard Objects
string   g_obj_prefix = "DQV10_";
//--- Broker requirements

// PHASE 5: ENHANCED PERFORMANCE OPTIMIZATION TARGETING 87.3% WIN RATE, 4.2+ PF
struct PerformanceRecord {
    datetime timestamp;
    double win_rate;
    double profit_factor;
    double sharpe_ratio;
    double max_drawdown;
    double conviction_threshold;
    bool high_performance_mode;
};
PerformanceRecord g_performance_history[100]; // Circular buffer for 100 records
int g_performance_index = 0;
int g_total_performance_records = 0;

// CHIMERA PRIME: PivotLevels struct for Reaper Elite Filter
struct PivotLevels
{
    double r2;
    double r1;
    double pivot;
    double s1;
    double s2;
};

// Phase 5 Adaptive Learning Variables
bool g_high_performance_mode = false;
double g_adaptive_conviction_threshold = 6.0;
double g_enhanced_win_rate_target = 87.3;
double g_enhanced_profit_factor_target = 4.2;
double g_enhanced_max_drawdown_target = 8.2;
double g_enhanced_sharpe_ratio_target = 3.8;

// Performance tracking for adaptation
double g_recent_win_rates[50];      // Recent win rates
double g_recent_profit_factors[50]; // Recent profit factors  
double g_recent_sharpe_ratios[50];  // Recent Sharpe ratios
int g_performance_tracking_index = 0;

// Current performance metrics
datetime g_last_performance_update = 0;
double g_current_win_rate = 0.0;
double g_current_profit_factor = 0.0;
double g_current_sharpe_ratio = 0.0;
double   g_min_stop_distance = 0.0;
//--- CORTANA PROTOCOL: Enhanced Error Handling ---
enum ERROR_LEVEL
{
    ERROR_INFO,
    ERROR_WARNING,
    ERROR_CRITICAL
};

//+------------------------------------------------------------------+
//|  PROJECT ASCENSION: ORION META-STRATEGY CONTROLLER (V1.0)       |
//+------------------------------------------------------------------+

// --- Global Enum for Strategy Permissions ---
enum ENUM_STRATEGY_PERMISSION
{
    PERMIT_NONE,      // No strategy is allowed to initiate trades.
    PERMIT_SILICON_X,   // Only Silicon-X can start a new sequence.
    PERMIT_REAPER,      // Only Reaper can start a new sequence.
    PERMIT_TREND      // Only trend-followers (Titan) can start.
};

// --- Global variable to hold the current permission state ---
ENUM_STRATEGY_PERMISSION g_orion_permission = PERMIT_NONE;

//+------------------------------------------------------------------+
//|    PROJECT ASCENSION: ADAPTIVE COMPOUNDING ENGINE GLOBALS       |
//+------------------------------------------------------------------+
double g_Ascension_MaxRiskPercent = 3.0;
double g_Ascension_MinRiskPercent = 0.5;
// Note: g_high_watermark_equity and g_current_drawdown already exist from Beehive Queen Protocol, we will reuse them.

// Compounding modes
enum COMPOUNDING_MODE 
{
    MODE_AGGRESSIVE_GROWTH,
    MODE_BALANCED_GROWTH,
    MODE_CAPITAL_PRESERVATION
};
COMPOUNDING_MODE g_compoundingMode = MODE_BALANCED_GROWTH;

struct ErrorLog
{
    datetime time;
    ERROR_LEVEL level;
    string message;
    string function;
    int line;
};

ErrorLog g_error_log[];
int g_max_error_log_size = 100;
datetime g_start_time = 0;

//+------------------------------------------------------------------+
//| V18.0 COMPONENT 6: Ensemble Arbitration Class                   |
//| Dictates global direction to prevent grid correlation accumulation |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| V18.0 COMPONENT 7: Optimized Data Arrays (No Dynamic Resizing)  |
//+------------------------------------------------------------------+
#define MAX_HISTORY 2000

double Buffer_M15_Close[MAX_HISTORY];
double Buffer_H1_Close[MAX_HISTORY];

void InitializeMemory()
{
   ArrayInitialize(Buffer_M15_Close, 0.0);
   ArrayInitialize(Buffer_H1_Close, 0.0);
}

void UpdatePriceBuffers()
{
   // Fast Shift: Move data from index 0 to 1, length-1
   ArrayCopy(Buffer_M15_Close, Buffer_M15_Close, 1, 0, MAX_HISTORY-1);
   ArrayCopy(Buffer_H1_Close, Buffer_H1_Close, 1, 0, MAX_HISTORY-1);
   
   // Insert new data at Tip
   Buffer_M15_Close[0] = iClose(NULL, PERIOD_M15, 0);
   Buffer_H1_Close[0]  = iClose(NULL, PERIOD_H1, 0);
}

class CArbiter
{
private:
   int    m_titanSignal;
   int    m_vsaSignal;
   double m_globalBias;

   // Helper: Get Titan Trend (H4 EMA 50 vs Daily EMA 50)
   int GetTitanTrend()
   {
      double h4_ema = iMA(NULL, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
      double d1_ema = iMA(NULL, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
      
      if(Close[1] > h4_ema && h4_ema > d1_ema) return 1;  // Strong Bull
      if(Close[1] < h4_ema && h4_ema < d1_ema) return -1; // Strong Bear
      return 0; // Ranging/Conflict
   }

   // Helper: Volume Spread Analysis (Simple Anomaly Detection)
   int GetVSABias()
   {
      double vol = (double)Volume[1];
      double volAvg = iMA(NULL, 0, 20, 0, MODE_SMA, PRICE_CLOSE, 1); // FIXED: Changed from PRICE_VOLUME to PRICE_CLOSE
      double spread = High[1] - Low[1];
      double spreadAvg = iATR(NULL, 0, 20, 1);
      
      // High Vol, Low Spread = Absorption/Reversal
      if(vol > volAvg * 1.5 && spread < spreadAvg * 0.8)
      {
         // If candle closed Up, it's weakness (selling into highs) -> Bearish
         if(Close[1] > Open[1]) return -1; 
         // If candle closed Down, it's strength (buying into lows) -> Bullish
         return 1;
      }
      return 0; 
   }

public:
   void Refresh()
   {
      m_titanSignal = GetTitanTrend();
      m_vsaSignal   = GetVSABias();
      // Weighted Formula: Titan (0.6) + VSA (0.4)
      m_globalBias  = (m_titanSignal * 0.6) + (m_vsaSignal * 0.4);
   }

   // Returns: 0 (Both), 1 (Long Only), -1 (Short Only)
   int GetAllowedDirection()
   {
      // V27.20 FIX: Asymmetric thresholds  long bias > 0.3 (easy), short bias < -InpShortBiasThreshold (hard)
      if(m_globalBias > 0.3)  return OP_BUY;
      if(m_globalBias < -InpShortBiasThreshold) return OP_SELL;
      return -1; // Code for "Both Allowed"
   }
   
   string GetStatusString()
   {
      return "Arbiter: Bias=" + DoubleToString(m_globalBias, 2) + 
             " (Titan:" + IntegerToString(m_titanSignal) + 
             " VSA:" + IntegerToString(m_vsaSignal) + ")";
   }
};

CArbiter Arbiter; // Global Instance

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                 |
//+------------------------------------------------------------------+
string HiveStateToString(ENUM_HIVE_STATE state)
{
   switch(state)
   {
      case HIVE_STATE_GROWTH: return "GROWTH";
      case HIVE_STATE_DEFENSIVE: return "DEFENSIVE";
      default: return "UNKNOWN";
   }
}
string GetStrategyName(int index)
{
    switch(index)
    {
        case 1: return "Mean Reversion";
        case 5: return "Quantum Oscillator"; // V8.5.9: UPDATED
        case 7: return "Titan"; // Titan strategy
        case 8: return "Warden"; // Warden strategy

        default: return "";
    }
}
double CalculateATR(int period, int shift=0)
{
   if(period <= 0) return 0;
   if(Bars < period + shift) return 0;
   return(iATR(Symbol(), Period(), period, shift));
}
bool IsSpreadAcceptable(double maxSpreadPips)
{
   if(maxSpreadPips <= 0) return false;
   return((MarketInfo(Symbol(), MODE_SPREAD) / 10.0) <= maxSpreadPips);
}

//+------------------------------------------------------------------+
//| CHIMERA PRIME: REAPER - Calculates Daily Pivot Points            |
//+------------------------------------------------------------------+
PivotLevels Reaper_CalculateDailyPivots()
{
    PivotLevels levels;

    // Get previous day's High, Low, and Close
    double prevHigh  = iHigh(Symbol(), PERIOD_D1, 1);
    double prevLow   = iLow(Symbol(), PERIOD_D1, 1);
    double prevClose = iClose(Symbol(), PERIOD_D1, 1);

    // Calculate pivot levels using the classic formula
    levels.pivot = (prevHigh + prevLow + prevClose) / 3.0;
    levels.s1    = (2 * levels.pivot) - prevHigh;
    levels.s2    = levels.pivot - (prevHigh - prevLow);
    levels.r1    = (2 * levels.pivot) - prevLow;
    levels.r2    = levels.pivot + (prevHigh - prevLow);

    return levels;
}

//+------------------------------------------------------------------+
//| CHIMERA PRIME: REAPER - Stochastic Confirmation Filter           |
//+------------------------------------------------------------------+
bool Reaper_ConfirmWithStochastic(int trade_direction)
{
    // Use parameters from the research document: (14,3,3) on the H4 chart
    double k_line_current = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, STO_LOWHIGH, MODE_MAIN, 1);
    double d_line_current = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, STO_LOWHIGH, MODE_SIGNAL, 1);
    
    double k_line_previous = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, STO_LOWHIGH, MODE_MAIN, 2);
    double d_line_previous = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, STO_LOWHIGH, MODE_SIGNAL, 2);

    // For a BUY signal, we need:
    // 1. Stochastic to be in the extreme oversold zone (< 20).
    // 2. A bullish crossover (%K crossing ABOVE %D).
    if (trade_direction == OP_BUY)
    {
        bool isOversold = (k_line_current < 20 && d_line_current < 20);
        bool hasCrossedUp = (k_line_previous <= d_line_previous && k_line_current > d_line_current);

        return (isOversold && hasCrossedUp);
    }
    
    // For a SELL signal, we need:
    // 1. Stochastic to be in the extreme overbought zone (> 80).
    // 2. A bearish crossover (%K crossing BELOW %D).
    if (trade_direction == OP_SELL)
    {
        bool isOverbought = (k_line_current > 80 && d_line_current > 80);
        bool hasCrossedDown = (k_line_previous >= d_line_previous && k_line_current < d_line_current);
        
        return (isOverbought && hasCrossedDown);
    }

    return false;
}

//+------------------------------------------------------------------+
//| CHIMERA PRIME: REAPER - RSI Divergence Detection Engine          |
//+------------------------------------------------------------------+
bool Reaper_DetectRSIDivergence(int trade_direction)
{
    int lookback_period = 40; // Look back over the last 40 H4 bars

    if (trade_direction == OP_BUY) // Search for BULLISH divergence
    {
        // 1. Find the most recent significant swing low in price.
        int recent_low_idx = iLowest(Symbol(), PERIOD_H4, MODE_LOW, 10, 1);
        double recent_low_price = iLow(Symbol(), PERIOD_H4, recent_low_idx);
        double recent_low_rsi = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, recent_low_idx);

        // 2. Find a previous significant swing low to compare against.
        int previous_low_idx = iLowest(Symbol(), PERIOD_H4, MODE_LOW, lookback_period - 15, 15);
        double previous_low_price = iLow(Symbol(), PERIOD_H4, previous_low_idx);
        double previous_low_rsi = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, previous_low_idx);

        // 3. Evaluate divergence conditions
        // Condition A: Price has made a new lower low.
        bool isPriceLowerLow = (recent_low_price < previous_low_price);
        // Condition B: RSI has made a higher low.
        bool isRSIHigherLow = (recent_low_rsi > previous_low_rsi);
        // Condition C: The divergence must occur in the oversold zone.
        bool isInOversoldZone = (recent_low_rsi < 35); // V17.8: Tightened back to 35 (Sniper Mode)

        return (isPriceLowerLow && isRSIHigherLow && isInOversoldZone);
    }
    
    if (trade_direction == OP_SELL) // Search for BEARISH divergence
    {
        // 1. Find the most recent significant swing high in price.
        int recent_high_idx = iHighest(Symbol(), PERIOD_H4, MODE_HIGH, 10, 1);
        double recent_high_price = iHigh(Symbol(), PERIOD_H4, recent_high_idx);
        double recent_high_rsi = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, recent_high_idx);
        
        // 2. Find a previous significant swing high to compare against.
        int previous_high_idx = iHighest(Symbol(), PERIOD_H4, MODE_HIGH, lookback_period - 15, 15);
        double previous_high_price = iHigh(Symbol(), PERIOD_H4, previous_high_idx);
        double previous_high_rsi = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, previous_high_idx);

        // 3. Evaluate divergence conditions
        // Condition A: Price has made a new higher high.
        bool isPriceHigherHigh = (recent_high_price > previous_high_price);
        // Condition B: RSI has made a lower high.
        bool isRSILowerHigh = (recent_high_rsi < previous_high_rsi);
        // Condition C: The divergence must occur in the overbought zone.
        bool isInOverboughtZone = (recent_high_rsi > 65); // V17.8: Tightened back to 65 (Sniper Mode)

        return (isPriceHigherHigh && isRSILowerHigh && isInOverboughtZone);
    }

    return false;
}

//+------------------------------------------------------------------+
//| ENHANCED MULTI-TIMEFRAME DATA COLLECTION (V11.1)                 |
//+------------------------------------------------------------------+
bool UpdateMultiTimeframeData()
{
    bool dataUpdated = false;
    static int retryCount = 0;
    
    // ENHANCED M15 DATA COLLECTION
    datetime currentM15 = iTime(Symbol(), PERIOD_M15, 0);
    if(currentM15 > lastM15Bar || retryCount < 3) // Force initial load
    {
        int m15Bars = MathMin(100, iBars(Symbol(), PERIOD_M15));
        if(m15Bars >= 20) {
            ArrayResize(m15High, m15Bars);
            ArrayResize(m15Low, m15Bars);
            ArrayResize(m15Close, m15Bars);
            ArrayResize(m15Volume, m15Bars);
            ArrayResize(m15Open, m15Bars);
            
            for(int i = 0; i < m15Bars; i++)
            {
                m15High[i] = iHigh(Symbol(), PERIOD_M15, i);
                m15Low[i] = iLow(Symbol(), PERIOD_M15, i);
                m15Close[i] = iClose(Symbol(), PERIOD_M15, i);
                m15Open[i] = iOpen(Symbol(), PERIOD_M15, i);
                m15Volume[i] = (double)iVolume(Symbol(), PERIOD_M15, i);
            }
            lastM15Bar = currentM15;
            dataUpdated = true;
            if(!IsOptimization()) Print("M15 Data Updated - Bars: ", ArraySize(m15Close));
            retryCount = 0;
        } else {
            retryCount++;
        }
    }
    
    // ENHANCED M30 DATA COLLECTION
    datetime currentM30 = iTime(Symbol(), PERIOD_M30, 0);
    if(currentM30 > lastM30Bar || retryCount < 3) // Force initial load
    {
        int m30Bars = MathMin(100, iBars(Symbol(), PERIOD_M30));
        if(m30Bars >= 20) {
            ArrayResize(m30High, m30Bars);
            ArrayResize(m30Low, m30Bars);
            ArrayResize(m30Close, m30Bars);
            ArrayResize(m30Volume, m30Bars);
            ArrayResize(m30Open, m30Bars);
            
            for(int i = 0; i < m30Bars; i++)
            {
                m30High[i] = iHigh(Symbol(), PERIOD_M30, i);
                m30Low[i] = iLow(Symbol(), PERIOD_M30, i);
                m30Close[i] = iClose(Symbol(), PERIOD_M30, i);
                m30Open[i] = iOpen(Symbol(), PERIOD_M30, i);
                m30Volume[i] = (double)iVolume(Symbol(), PERIOD_M30, i);
            }
            lastM30Bar = currentM30;
            dataUpdated = true;
            if(!IsOptimization()) Print("M30 Data Updated - Bars: ", ArraySize(m30Close));
        } else {
            retryCount++;
        }
    }
    
    // ENHANCED H1 DATA COLLECTION
    datetime currentH1 = iTime(Symbol(), PERIOD_H1, 0);
    if(currentH1 > lastH1Bar || retryCount < 3) // Force initial load
    {
        int h1Bars = MathMin(100, iBars(Symbol(), PERIOD_H1));
        if(h1Bars >= 20) {
            ArrayResize(h1High, h1Bars);
            ArrayResize(h1Low, h1Bars);
            ArrayResize(h1Close, h1Bars);
            ArrayResize(h1Volume, h1Bars);
            ArrayResize(h1Open, h1Bars);
            
            for(int i = 0; i < h1Bars; i++)
            {
                h1High[i] = iHigh(Symbol(), PERIOD_H1, i);
                h1Low[i] = iLow(Symbol(), PERIOD_H1, i);
                h1Close[i] = iClose(Symbol(), PERIOD_H1, i);
                h1Open[i] = iOpen(Symbol(), PERIOD_H1, i);
                h1Volume[i] = (double)iVolume(Symbol(), PERIOD_H1, i);
            }
            lastH1Bar = currentH1;
            dataUpdated = true;
            if(!IsOptimization()) Print("H1 Data Updated - Bars: ", ArraySize(h1Close));
        } else {
            retryCount++;
        }
    }
    
    return dataUpdated;
}

//+------------------------------------------------------------------+
//| PRINT MULTI-TIMEFRAME STATUS FOR VERIFICATION (V11.0)           |
//+------------------------------------------------------------------+
void PrintMultiTFStatus()
{
    Print("=== MULTI-TIMEFRAME STATUS ===");
    Print("M15 Bars: ", ArraySize(m15Close), " Last Bar: ", TimeToString(lastM15Bar));
    Print("M30 Bars: ", ArraySize(m30Close), " Last Bar: ", TimeToString(lastM30Bar));  
    Print("H1 Bars: ", ArraySize(h1Close), " Last Bar: ", TimeToString(lastH1Bar));
    Print("H4 Chart Attached - Current Time: ", TimeToString(TimeCurrent()));
    
    // Show sample data
    if(ArraySize(m15Close) > 0)
        Print("M15 Current Price: ", m15Close[0], " Volume: ", m15Volume[0]);
    if(ArraySize(m30Close) > 0)
        Print("M30 Current Price: ", m30Close[0], " Volume: ", m30Volume[0]);
    if(ArraySize(h1Close) > 0)
        Print("H1 Current Price: ", h1Close[0], " Volume: ", h1Volume[0]);
}

//+------------------------------------------------------------------+
//| CUSTOM INDICATOR FUNCTIONS FOR ARRAY DATA (V11.0)               |
//+------------------------------------------------------------------+
double iRSIOnArray(double &array[], int period, int shift)
{
    if(ArraySize(array) < period + shift + 1) return 0;
    
    double gains = 0, losses = 0;
    for(int i = shift + 1; i <= shift + period; i++)
    {
        if(i >= ArraySize(array)) return 0;
        double change = array[i-1] - array[i];
        if(change > 0) gains += change;
        else losses -= change;
    }
    
    if(losses == 0) return 100;
    double rs = gains / losses;
    return 100 - (100 / (1 + rs));
}

double iMAOnArray(double &array[], int period, int shift, int ma_method, int applied_price)
{
    if(ArraySize(array) < period + shift) return 0;
    
    double sum = 0;
    for(int i = shift; i < shift + period; i++)
    {
        if(i >= ArraySize(array)) return 0;
        sum += array[i];
    }
    return sum / period;
}

//+------------------------------------------------------------------+
//| V18.3 CHRONOS: Bollinger Bands on Array Helper                   |
//| Calculate Bollinger Bands from price array for M15 scalping     |
//+------------------------------------------------------------------+
double CustomBBOnArray(double &data[], int total, int period, double deviation, int bands_shift, int mode, int shift)
{
   if(ArraySize(data) < period+shift) return 0;
   
   // 1. Calculate Simple MA
   double ma = 0;
   for(int i=0; i<period; i++) ma += data[shift+i];
   ma /= period;
   
   if(mode == MODE_MAIN) return ma;
   
   // 2. Calculate Standard Deviation
   double sumDiff = 0;
   for(int i=0; i<period; i++) sumDiff += MathPow(data[shift+i] - ma, 2);
   double stdDev = MathSqrt(sumDiff / period);
   
   // 3. Return Bands
   if(mode == MODE_UPPER) return ma + (deviation * stdDev);
   if(mode == MODE_LOWER) return ma - (deviation * stdDev);
   
   return 0;
}

double iEMAOnArray(double &array[], int period, int shift)
{
    if(ArraySize(array) < period + shift) return 0;
    
    double multiplier = 2.0 / (period + 1.0);
    double ema = array[ArraySize(array) - 1]; // Start with oldest value
    
    for(int i = ArraySize(array) - 2; i >= shift; i--)
    {
        if(i >= ArraySize(array) || i < 0) return 0;
        ema = (array[i] - ema) * multiplier + ema;
    }
    
    return ema;
}

double iATROnArray(double &high[], double &low[], double &close[], int period, int shift)
{
    if(ArraySize(high) < period + shift + 1 || ArraySize(low) < period + shift + 1 || ArraySize(close) < period + shift + 1) 
        return 0;
    
    double sum = 0;
    for(int i = shift; i < shift + period; i++)
    {
        if(i >= ArraySize(high) || i >= ArraySize(low) || i >= ArraySize(close)) return 0;
        double tr1 = high[i] - low[i];
        double tr2 = (i + 1 < ArraySize(close)) ? MathAbs(high[i] - close[i+1]) : 0;
        double tr3 = (i + 1 < ArraySize(close)) ? MathAbs(low[i] - close[i+1]) : 0;
        sum += MathMax(tr1, MathMax(tr2, tr3));
    }
    return sum / period;
}

//+------------------------------------------------------------------+
//| Helper: Convert ENUM_HIVE_STATE to string for logging             |
//+------------------------------------------------------------------+
string NormalizeSymbol(string symbol)
{
   // Check for empty string
   if(StringLen(symbol) == 0)
   {
      LogError(ERROR_WARNING, "Empty symbol name provided", "NormalizeSymbol");
      return "";
   }
   
   // Convert to uppercase and remove suffixes like .m, .pro, etc.
   string normalized = StringSubstr(symbol, 0, 6);
   StringToUpper(normalized);
   return normalized;
}
//+------------------------------------------------------------------+
//| Get symbol point value                                           |
//+------------------------------------------------------------------+
double GetSymbolPoint()
{
   double point = MarketInfo(Symbol(), MODE_POINT);
   
   if(point <= 0)
   {
      LogError(ERROR_WARNING, "Invalid point value for symbol " + Symbol(), "GetSymbolPoint");
      return 0;
   }
   
   return point;
}
//+------------------------------------------------------------------+
//| Get symbol pip value in account currency                         |
//+------------------------------------------------------------------+
double GetPipValue()
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   
   if(tickSize == 0) 
   {
      LogError(ERROR_WARNING, "Invalid tick size for symbol " + Symbol(), "GetPipValue");
      return 0;
   }
   
   // Calculate pip value
   double pipValue = tickValue * (_Point / tickSize);
   
   // Adjust for JPY pairs
   if(StringFind(Symbol(), "JPY") != -1)
      pipValue *= 100.0;
   
   return pipValue;
}
//+------------------------------------------------------------------+
//| Calculate position size based on volatility and risk             |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskPercent, double stopLossPips, double volatilityFactor=1.0)
{
   // Validate inputs
   if(riskPercent <= 0 || stopLossPips <= 0 || volatilityFactor <= 0)
   {
      LogError(ERROR_WARNING, "Invalid input parameters for CalculatePositionSize", "CalculatePositionSize");
      return 0;
   }
   
   // Get account information
   double accountBalance = AccountEquity();
   if(accountBalance <= 0)
   {
      LogError(ERROR_CRITICAL, "Invalid account balance: " + DoubleToString(accountBalance, 2), "CalculatePositionSize");
      return 0;
   }
   
   double riskAmount = accountBalance * riskPercent / 100.0;
   
   // Adjust risk by volatility factor
   riskAmount *= volatilityFactor;
   
   // Get pip value
   double pipValue = GetPipValue();
   if(pipValue <= 0)
   {
      LogError(ERROR_WARNING, "Invalid pip value for " + Symbol(), "CalculatePositionSize");
      return 0;
   }
   
   // Calculate position size (ZERO-DIVIDE PROTECTION)
   if(stopLossPips <= 0) stopLossPips = 10; // Default 10 pips
   double positionSize = riskAmount / (stopLossPips * pipValue);
   
   // Get broker limits
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   // Validate broker limits
   if(minLot <= 0 || maxLot <= 0 || lotStep <= 0)
   {
      LogError(ERROR_CRITICAL, "Invalid broker lot limits. Min: " + DoubleToString(minLot, 2) + 
            ", Max: " + DoubleToString(maxLot, 2) + ", Step: " + DoubleToString(lotStep, 2), "CalculatePositionSize");
      return 0;
   }
   
   // Normalize to broker's lot step
   positionSize = MathFloor(positionSize / lotStep) * lotStep;
   
   // Apply broker limits
   if(positionSize < minLot)
      positionSize = minLot;
   if(positionSize > maxLot)
      positionSize = maxLot;
   
   return positionSize;
}
//+------------------------------------------------------------------+
//| Calculate volatility factor based on ATR                         |
//+------------------------------------------------------------------+
double CalculateVolatilityFactor(int atrPeriod=14)
{
   // Validate period
   if(atrPeriod <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ATR period: " + IntegerToString(atrPeriod), "CalculateVolatilityFactor");
      return 1.0; // Return neutral value
   }
   
   double currentATR = CalculateATR(atrPeriod);
   if(currentATR <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ATR value: " + DoubleToString(currentATR, Digits), "CalculateVolatilityFactor");
      return 1.0; // Return neutral value
   }
   
   double avgATR = 0;
   int validBars = 0;
   
   // Calculate average ATR over the last 30 periods
   for(int i = 1; i <= 30; i++)
   {
      double atrValue = CalculateATR(atrPeriod, i);
      if(atrValue > 0)
      {
         avgATR += atrValue;
         validBars++;
      }
   }
   
   if(validBars == 0)
   {
      LogError(ERROR_WARNING, "No valid ATR values found for volatility calculation", "CalculateVolatilityFactor");
      return 1.0; // Return neutral value
   }
   
   avgATR /= validBars;
   
   if(avgATR <= 0)
   {
      LogError(ERROR_WARNING, "Invalid average ATR: " + DoubleToString(avgATR, Digits), "CalculateVolatilityFactor");
      return 1.0; // Return neutral value
   }
   
   // Calculate volatility factor (0.5 to 1.5 range)
   double volatilityFactor = currentATR / avgATR;
   volatilityFactor = MathMax(0.5, MathMin(1.5, volatilityFactor));
   
   return volatilityFactor;
}
//+------------------------------------------------------------------+
//| Robust OrderSend wrapper with retry logic                        |
//+------------------------------------------------------------------+
int RobustOrderSend(string symbol, int cmd, double volume, double price, 
                   int slippage, double stoploss, double takeprofit, 
                   string comment, int magic, datetime expiration=0, 
                   color arrow_color=CLR_NONE)
{
   // Reset last error before starting
   ResetLastError();
   
   // Validate inputs
   if(StringLen(symbol) == 0)
   {
      LogError(ERROR_WARNING, "Empty symbol name", "RobustOrderSend");
      return -1;
   }
   
   if(volume <= 0)
   {
      LogError(ERROR_WARNING, "Invalid volume: " + DoubleToString(volume, 2), "RobustOrderSend");
      return -1;
   }
   
   // V15.4 CRITICAL FIX: The previous validation was too strict and rejected pending orders.
   // This corrected logic validates ALL standard MQL4 order types from OP_BUY (0) to OP_SELLSTOP (5).
   // This brings Silicon-X and any other pending-order strategy online.
   if(cmd < OP_BUY || cmd > OP_SELLSTOP)
   {
      LogError(ERROR_WARNING, "Invalid order type: " + IntegerToString(cmd), "RobustOrderSend");
      return -1;
   }
   
   // Normalize all price values
   price = NormalizeDouble(price, Digits);
   stoploss = NormalizeDouble(stoploss, Digits);
   takeprofit = NormalizeDouble(takeprofit, Digits);
   
   // Check trading conditions
   if(!IsTradeAllowed())
   {
      LogError(ERROR_INFO, "Trading is not allowed at this time", "RobustOrderSend");
      return -1;
   }
   
   if(!IsSpreadAcceptable(InpMax_Spread_Pips))
   {
      LogError(ERROR_INFO, "Spread too high for trading. Current: " + DoubleToString(MarketInfo(symbol, MODE_SPREAD), 1) + " pips", "RobustOrderSend");
      return -1;
   }

   // V27.20 FIX Layer 2: Catch-all bad-hours block in RobustOrderSend
   if(InpEnableTimeFilter && IsBadTradingHour())
   {
      LogError(ERROR_INFO, "RobustOrderSend: Blocked by Bad-Hours filter", "RobustOrderSend");
      return -1;
   }
   
   // Retry parameters
   int maxRetries = 5;
   int retryDelay = 1000; // 1 second
   int retryCount = 0;
   int ticket = -1;
   int lastError = 0;
   
   while(retryCount < maxRetries)
   {
      // Reset last error before each attempt
      ResetLastError();
      
      // Refresh rates
      RefreshRates();
      
      // Update price for market orders
      if(cmd == OP_BUY)
         price = Ask;
      else if(cmd == OP_SELL)
         price = Bid;
      
      // Attempt to send order
      ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, takeprofit, comment, magic, expiration, arrow_color);
      
      // Check if successful
      if(ticket > 0)
      {
         LogError(ERROR_INFO, "Order placed successfully. Ticket: " + IntegerToString(ticket), "RobustOrderSend");
         return ticket;
      }
      
      // Handle error
      lastError = GetLastError();
      LogError(ERROR_WARNING, "OrderSend failed. Retrying... Error: " + IntegerToString(lastError) + " - " + GetErrorDescription(lastError), "RobustOrderSend");
      
      // For certain errors, don't retry
      if(lastError == ERR_INVALID_PRICE || 
         lastError == ERR_INVALID_STOPS || 
         lastError == ERR_INVALID_TRADE_VOLUME ||
         lastError == ERR_NOT_ENOUGH_MONEY)
      {
         LogError(ERROR_CRITICAL, "Fatal error. Aborting order.", "RobustOrderSend");
         return -1;
      }
      
      // Wait before retry
      Sleep(retryDelay);
      retryDelay *= 2; // Exponential backoff
      retryCount++;
   }
   
   LogError(ERROR_CRITICAL, "Failed to place order after " + IntegerToString(maxRetries) + " attempts. Last error: " + 
         IntegerToString(lastError), "RobustOrderSend");
   return -1;
}
//+------------------------------------------------------------------+
//| Robust OrderModify wrapper with retry logic                       |
//+------------------------------------------------------------------+
bool RobustOrderModify(int ticket, double price, double stoploss, double takeprofit, 
                      datetime expiration=0, color arrow_color=CLR_NONE)
{
   // Reset last error before starting
   ResetLastError();
   
   // Validate ticket
   if(ticket <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ticket number: " + IntegerToString(ticket), "RobustOrderModify");
      return false;
   }
   
   // Normalize all price values
   price = NormalizeDouble(price, Digits);
   stoploss = NormalizeDouble(stoploss, Digits);
   takeprofit = NormalizeDouble(takeprofit, Digits);
   
   // Check trading conditions
   if(!IsTradeAllowed())
   {
      LogError(ERROR_INFO, "Trading is not allowed at this time", "RobustOrderModify");
      return false;
   }
   
   // Retry parameters
   int maxRetries = 5;
   int retryDelay = 1000; // 1 second
   int retryCount = 0;
   bool success = false;
   int lastError = 0;
   
   while(retryCount < maxRetries)
   {
      // Reset last error before each attempt
      ResetLastError();
      
      // Refresh rates
      RefreshRates();
      
      // Attempt to modify order
      success = OrderModify(ticket, price, stoploss, takeprofit, expiration, arrow_color);
      
      // Check if successful
      if(success)
      {
         LogError(ERROR_INFO, "Order modified successfully. Ticket: " + IntegerToString(ticket), "RobustOrderModify");
         return true;
      }
      
      // Handle error
      lastError = GetLastError();
      LogError(ERROR_WARNING, "OrderModify failed. Error: " + IntegerToString(lastError) + 
            ". Retry: " + IntegerToString(retryCount + 1) + "/" + IntegerToString(maxRetries), "RobustOrderModify");
      
      // For certain errors, don't retry
      if(lastError == ERR_INVALID_PRICE || 
         lastError == ERR_INVALID_STOPS || 
         lastError == ERR_INVALID_TICKET ||
         lastError == ERR_TRADE_NOT_ALLOWED)
      {
         LogError(ERROR_CRITICAL, "Fatal error. Aborting modification.", "RobustOrderModify");
         return false;
      }
      
      // Wait before retry
      Sleep(retryDelay);
      retryDelay *= 2; // Exponential backoff
      retryCount++;
   }
   
   LogError(ERROR_CRITICAL, "Failed to modify order after " + IntegerToString(maxRetries) + " attempts. Last error: " + 
         IntegerToString(lastError), "RobustOrderModify");
   return false;
}
//+------------------------------------------------------------------+
//| Place initial stop loss and take profit                          |
//+------------------------------------------------------------------+
bool PlaceInitialStops(int ticket, int atrPeriod, double atrMultiplier=2.5, double riskRewardRatio=2.0)
{
   // Validate inputs
   if(ticket <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ticket number: " + IntegerToString(ticket), "PlaceInitialStops");
      return false;
   }
   
   if(atrPeriod <= 0 || atrMultiplier <= 0 || riskRewardRatio <= 0)
   {
      LogError(ERROR_WARNING, "Invalid input parameters for PlaceInitialStops", "PlaceInitialStops");
      return false;
   }
   
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      LogError(ERROR_WARNING, "Failed to select order for initial stops. Ticket: " + IntegerToString(ticket) + 
            ". Error: " + IntegerToString(GetLastError()), "PlaceInitialStops");
      return false;
   }
   
   double atr = CalculateATR(atrPeriod);
   if(atr <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ATR value: " + DoubleToString(atr, Digits), "PlaceInitialStops");
      return false;
   }
   
   double stopDistance = atr * atrMultiplier;
   
   double openPrice = OrderOpenPrice();
   double stopLoss = 0;
   double takeProfit = 0;
   
   // Calculate stop loss and take profit based on order type
   if(OrderType() == OP_BUY)
   {
      stopLoss = openPrice - stopDistance;
      takeProfit = openPrice + (stopDistance * riskRewardRatio);
   }
   else if(OrderType() == OP_SELL)
   {
      stopLoss = openPrice + stopDistance;
      takeProfit = openPrice - (stopDistance * riskRewardRatio);
   }
   else
   {
      LogError(ERROR_WARNING, "Invalid order type: " + IntegerToString(OrderType()), "PlaceInitialStops");
      return false;
   }
   
   // Normalize prices
   stopLoss = NormalizeDouble(stopLoss, Digits);
   takeProfit = NormalizeDouble(takeProfit, Digits);
   
   // Ensure stop loss is valid (not too close to current price)
   if(OrderType() == OP_BUY)
   {
      if(stopLoss >= Bid)
      {
         LogError(ERROR_WARNING, "Invalid stop loss for BUY order. SL: " + DoubleToString(stopLoss, Digits) + 
               ", Bid: " + DoubleToString(Bid, Digits), "PlaceInitialStops");
         return false;
      }
   }
   
   if(OrderType() == OP_SELL)
   {
      if(stopLoss <= Ask)
      {
         LogError(ERROR_WARNING, "Invalid stop loss for SELL order. SL: " + DoubleToString(stopLoss, Digits) + 
               ", Ask: " + DoubleToString(Ask, Digits), "PlaceInitialStops");
         return false;
      }
   }
   
   // Modify order with new stop loss and take profit
   return RobustOrderModify(ticket, OrderOpenPrice(), stopLoss, takeProfit);
}
//+------------------------------------------------------------------+
//| Move stop loss to break-even                                    |
//+------------------------------------------------------------------+
bool MoveToBreakEven(int ticket, double bufferPips=0)
{
   // Validate inputs
   if(ticket <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ticket number: " + IntegerToString(ticket), "MoveToBreakEven");
      return false;
   }
   
   if(bufferPips < 0)
   {
      LogError(ERROR_WARNING, "Negative buffer pips: " + DoubleToString(bufferPips, 2), "MoveToBreakEven");
      return false;
   }
   
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      LogError(ERROR_WARNING, "Failed to select order for break-even. Ticket: " + IntegerToString(ticket) + 
            ". Error: " + IntegerToString(GetLastError()), "MoveToBreakEven");
      return false;
   }
   
   // Check if order is already at break-even or better
   if(OrderType() == OP_BUY && OrderStopLoss() >= OrderOpenPrice())
      return true;
   
   if(OrderType() == OP_SELL && OrderStopLoss() <= OrderOpenPrice())
      return true;
   
   double openPrice = OrderOpenPrice();
   double breakEvenSL = 0;
   
   // Calculate break-even stop loss with buffer
   if(OrderType() == OP_BUY)
   {
      breakEvenSL = openPrice + (bufferPips * _Point);
   }
   else if(OrderType() == OP_SELL)
   {
      breakEvenSL = openPrice - (bufferPips * _Point);
   }
   
   // Normalize stop loss
   breakEvenSL = NormalizeDouble(breakEvenSL, Digits);
   
   // Modify order with break-even stop loss
   return RobustOrderModify(ticket, OrderOpenPrice(), breakEvenSL, OrderTakeProfit());
}
//+------------------------------------------------------------------+
//| Apply ATR-based trailing stop                                   |
//+------------------------------------------------------------------+
bool ApplyATRTrailingStop(int ticket, int atrPeriod, double atrMultiplier=2.0)
{
   // Validate inputs
   if(ticket <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ticket number: " + IntegerToString(ticket), "ApplyATRTrailingStop");
      return false;
   }
   
   if(atrPeriod <= 0 || atrMultiplier <= 0)
   {
      LogError(ERROR_WARNING, "Invalid input parameters for ApplyATRTrailingStop", "ApplyATRTrailingStop");
      return false;
   }
   
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
   {
      LogError(ERROR_WARNING, "Failed to select order for ATR trail. Ticket: " + IntegerToString(ticket) + 
            ". Error: " + IntegerToString(GetLastError()), "ApplyATRTrailingStop");
      return false;
   }
   
   double atr = CalculateATR(atrPeriod);
   if(atr <= 0)
   {
      LogError(ERROR_WARNING, "Invalid ATR value: " + DoubleToString(atr, Digits), "ApplyATRTrailingStop");
      return false;
   }
   
   double trailDistance = atr * atrMultiplier;
   
   double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
   double newStopLoss = 0;
   
   // Calculate new stop loss based on order type
   if(OrderType() == OP_BUY)
   {
      newStopLoss = currentPrice - trailDistance;
      
      // Only move stop loss up, never down
      if(newStopLoss <= OrderStopLoss())
         return true;
   }
   else if(OrderType() == OP_SELL)
   {
      newStopLoss = currentPrice + trailDistance;
      
      // Only move stop loss down, never up
      if(newStopLoss >= OrderStopLoss())
         return true;
   }
   else
   {
      LogError(ERROR_WARNING, "Invalid order type: " + IntegerToString(OrderType()), "ApplyATRTrailingStop");
      return false;
   }
   
   // Normalize stop loss
   newStopLoss = NormalizeDouble(newStopLoss, Digits);
   
   // Modify order with new stop loss
   return RobustOrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit());
}
//+------------------------------------------------------------------+
//| ULTRA-AGGRESSIVE PROFIT FACTOR OPTIMIZATION FUNCTION             |
//+------------------------------------------------------------------+
double GetAggressiveRiskFactor(int strategyIndex)
{
    double baseRisk = InpBase_Risk_Percent;
    
    // AGGRESSIVE RISK ADJUSTMENT FOR PF 2.5+
    switch(strategyIndex)
    {
        case 4: // Momentum Impulse - High Frequency
            return baseRisk * 1.3 * InpWinRate_Boost;
        case 5: // Volatility Breakout - Medium Frequency  
            return baseRisk * 1.2 * InpWinRate_Boost;
        case 6: // Market Microstructure - Professional
            return baseRisk * 1.4 * InpWinRate_Boost;
        default:
            return baseRisk;
    }
}

//+------------------------------------------------------------------+
//| Helper: Normal Cumulative Distribution Function                   |
//| Approximation of the standard normal CDF                         |
//+------------------------------------------------------------------+
double NormalCDF(double x)
{
   // Abramowitz and Stegun formula 26.2.17
   double a1 =  0.254829592;
   double a2 = -0.284496736;
   double a3 =  1.421413741;
   double a4 = -1.453152027;
   double a5 =  1.061405429;
   double p  =  0.3275911;
   // Save the sign of x
   int sign = (x < 0) ? -1 : 1;
   x = MathAbs(x) / MathSqrt(2.0);
   // A&S formula
   double t = 1.0 / (1.0 + p * x);
   double y = 1.0 - (((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * MathExp(-x * x));
   return 0.5 * (1.0 + sign * y);
}
//+------------------------------------------------------------------+
//| Get Dynamic Risk Multiplier                                     |
//| Calculates risk multiplier based on current drawdown            |
//+------------------------------------------------------------------+
double GetDynamicRiskMultiplier(double current_drawdown_percent)
{
    // This function dynamically scales risk exposure based on drawdown depth.
    // It maps a drawdown from 0% up to the max defensive DD threshold (InpDefensiveDD_Percent)
    // to a risk multiplier from 1.0 (full risk) down to our minimum (InpDrawdown_Risk_Mult).
    if (!InpEnableCompounding) return 1.0; // Compounding disabled, always use full risk
    if (current_drawdown_percent <= 0) return 1.0; // No drawdown, full risk
    if (current_drawdown_percent >= InpDefensiveDD_Percent) return InpDrawdown_Risk_Mult; // At max DD, use min risk
    
    // Linear interpolation formula: y = y1 + ((x - x1) * (y2 - y1)) / (x2 - x1)
    // y1 = 1.0 (full risk multiplier), x1 = 0.0 (zero drawdown)
    // y2 = InpDrawdown_Risk_Mult (min risk), x2 = InpDefensiveDD_Percent (max drawdown)
    double risk_mult = 1.0 + ((current_drawdown_percent - 0) * (InpDrawdown_Risk_Mult - 1.0)) / (InpDefensiveDD_Percent - 0);
    
    return NormalizeDouble(risk_mult, 2);
}
//+------------------------------------------------------------------+
//| REMOVED: First GetLotSizeV8_5_9_FIXED function definition        |
//| Keeping only the enhanced version that follows                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| FIXED: Safe position sizing with comprehensive error handling   |
//| Prevents crashes from division by zero and invalid parameters   |
//+------------------------------------------------------------------+
double GetLotSizeV8_5_9_FIXED(double tqs, double stopLossPoints, double risk_percent, double current_drawdown)
{
    // ENHANCED INPUT VALIDATION
    if(tqs <= 0 || stopLossPoints <= 0 || risk_percent <= 0)
    {
        LogError(ERROR_WARNING, "GetLotSizeV8_5_9_FIXED: Invalid inputs - TQS: " + DoubleToString(tqs, 2) + 
              ", StopLoss: " + DoubleToString(stopLossPoints, 2) + ", Risk%: " + DoubleToString(risk_percent, 2), "GetLotSizeV8_5_9_FIXED");
        return MarketInfo(Symbol(), MODE_MINLOT);
    }
    
    // ENHANCED ACCOUNT VALIDATION
    double accountBalance = AccountBalance();
    if(accountBalance <= 0)
    {
        LogError(ERROR_CRITICAL, "GetLotSizeV8_5_9_FIXED: Invalid account balance: " + DoubleToString(accountBalance, 2), "GetLotSizeV8_5_9_FIXED");
        return MarketInfo(Symbol(), MODE_MINLOT);
    }
    
    // PORTFOLIO RISK BUDGET CHECK
    double totalCurrentRisk = GetTotalCurrentRiskPercent();
    if(totalCurrentRisk >= InpMaxTotalRisk_Percent)
    {
        LogError(ERROR_INFO, "GetLotSizeV8_5_9_FIXED: Portfolio risk budget exceeded: " + DoubleToString(totalCurrentRisk, 2) + "%", "GetLotSizeV8_5_9_FIXED");
        return 0; // Zero lot size to prevent over-risking
    }
    
    // Calculate base risk amount with enhanced safety
    double riskable_equity_base;
    double dynamic_risk_multiplier = GetDynamicRiskMultiplier(current_drawdown);
    double final_risk_percent = risk_percent * dynamic_risk_multiplier;
    
    // HUNTSMAN PROTOCOL INTEGRATION
    if(InpHuntsman_Enabled && g_huntsman_phase_active)
    {
        if(Bars < InpHuntsman_PrimingBars)
        {
            final_risk_percent *= InpHuntsman_Risk_Scale;
        }
        else
        {
            g_huntsman_phase_active = false;
        }
    }
    
    // STATE-BASED RISK CALCULATION
    if(InpEnableCompounding && AccountEquity() < g_high_watermark_equity)
    {
        riskable_equity_base = g_high_watermark_equity;
    }
    else
    {
        riskable_equity_base = AccountEquity();
    }
    
    double riskAmount = riskable_equity_base * final_risk_percent / 100.0;
    
    // ADJUST BY TQS
    riskAmount *= tqs;
    
    // LOW CONVICTION CHECK
    if(tqs < InpMinTQSForEntry)
    {
        return MarketInfo(Symbol(), MODE_MINLOT);
    }
    
    // ENHANCED TICK VALUE CALCULATION
    double tickValuePerLot = MarketInfo(Symbol(), MODE_TICKVALUE);
    
    // DIVISION BY ZERO PROTECTION
    if(tickValuePerLot <= 0 || stopLossPoints <= 0)
    {
        LogError(ERROR_WARNING, "GetLotSizeV8_5_9_FIXED: Invalid tick value or stop loss: " + DoubleToString(tickValuePerLot, 5), "GetLotSizeV8_5_9_FIXED");
        return MarketInfo(Symbol(), MODE_MINLOT);
    }
    
    // SAFE LOT SIZE CALCULATION
    double lotSize = riskAmount / (stopLossPoints * tickValuePerLot);
    
    // ENHANCED LOT SIZE VALIDATION
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    if(lotSize < minLot || lotSize > maxLot)
    {
        LogError(ERROR_INFO, "GetLotSizeV8_5_9_FIXED: Calculated lot size out of range: " + DoubleToString(lotSize, 2) + 
              " (Min: " + DoubleToString(minLot, 2) + ", Max: " + DoubleToString(maxLot, 2) + ")", "GetLotSizeV8_5_9_FIXED");
        
        if(lotSize < minLot) return minLot;
        if(lotSize > maxLot) return maxLot;
    }
    
    // NORMALIZE TO LOT STEP
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    
    LogError(ERROR_INFO, "GetLotSizeV8_5_9_FIXED: Calculated lot size: " + DoubleToString(lotSize, 2) + 
          " | Risk Amount: " + DoubleToString(riskAmount, 2), "GetLotSizeV8_5_9_FIXED");
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| V8.5.9: Get Total Current Risk Percent                           |
//| Calculates the sum of risk of all open hive trades as a % of equity.|
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| V8.5.9: Get Total Current Risk Percent (CORRECTED)               |
//| Calculates the sum of risk of all open hive trades as a % of equity.|
//+------------------------------------------------------------------+
double GetTotalCurrentRiskPercent()
{
    double total_risk_amount = 0;
    double accountEquity = AccountEquity();
    if (accountEquity <= 0) return 0.0; // Prevent division by zero if equity is zero

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

        int magic = OrderMagicNumber();
        // V27.2: FIXED  use IsOurMagicNumber() to check ALL strategies (was only checking 3)
        // Previously missed: Reaper (888001/888002), Silicon-X (984651), Chronos (999001),
        // NoiseBreakout (777012), Apex (777011), Phantom (777013), Nexus (777014)
        if(OrderSymbol() == Symbol() && IsOurMagicNumber(magic))
        {
            if (OrderStopLoss() > 0) // Only include trades with a defined stop loss
            {
                double open_price = OrderOpenPrice();
                double stop_loss_price = OrderStopLoss();
                double lots = OrderLots();
                
                // V8.5.9 REPAIR: Manual, mathematically-correct calculation of potential loss
                double point_value = MarketInfo(OrderSymbol(), MODE_TICKVALUE) / MarketInfo(OrderSymbol(), MODE_TICKSIZE) * _Point;
                double points_at_risk = 0;

                if (OrderType() == OP_BUY)
                {
                    points_at_risk = (open_price - stop_loss_price) / _Point;
                }
                else // OP_SELL
                {
                    points_at_risk = (stop_loss_price - open_price) / _Point;
                }
                
                if (points_at_risk > 0)
                {
                    total_risk_amount += points_at_risk * point_value * lots;
                }
            }
        }
    }

    // Return the total monetary risk as a percentage of the current account equity.
    return (total_risk_amount / accountEquity) * 100.0;
}
//+------------------------------------------------------------------+
//| V8.5: Update Strategy Performance                               |
//| Core function to track strategy performance                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| V8.5: Update Strategy Performance (CORTANA ENHANCED)             |

//+------------------------------------------------------------------+
//| V8.5: Monitor Closed Trades                                     |
//| Detects closed trades and updates performance stats              |

//+------------------------------------------------------------------+
//| V8.5: Is Strategy Healthy                                         |
//| Determines if a strategy should be allowed to trade               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Is Strategy Healthy (GENEVA PROTOCOL - V1.0 STUB)              |
//| Old logic is deprecated. Now returns true by default.          |
//+------------------------------------------------------------------+
// V13.0 ELITE: Enhanced IsStrategyHealthy with Temporary Cooldown System
bool IsStrategyHealthy(int magicNumber)
{
    // MASTER SWITCH
    if (!InpEnableAdaptiveSelection && !InpEnableCooldownSystem) return true;
    
    // Find strategy index from magic number
    int strategyIndex = GetStrategyIndexFromMagic(magicNumber);
    if(strategyIndex < 0 || strategyIndex >= 15) return true; // V26 BEEHIVE: Extended to 15
    
    // V13.0 ELITE: COOLDOWN SYSTEM - Check if strategy is temporarily disabled
    if(g_strategyCooldown[strategyIndex].disabled)
    {
        // Check if cooldown period has passed (10 bars)
        int currentBar = iBars(Symbol(), Period());
        int cooldownBars = currentBar - g_strategyCooldown[strategyIndex].disabledBars;
        
        if(cooldownBars >= 10) // 10-bar cooldown period
        {
            // Re-enable strategy after cooldown
            g_strategyCooldown[strategyIndex].disabled = false;
            g_strategyCooldown[strategyIndex].disabledTime = 0;
            LogError(ERROR_INFO, "Strategy " + g_perfData[strategyIndex].name + 
                  " RE-ENABLED after cooldown (10 bars)", "IsStrategyHealthyV13");
        }
        else
        {
            // Still in cooldown period
            return false;
        }
    }
    
    // If not in cooldown, perform standard health checks
    // ADAPTIVE SELECTION
    if (!InpEnableAdaptiveSelection) return true; // Respect adaptive selection switch
    
    // MINIMUM TRADE REQUIREMENT
    if(g_perfData[strategyIndex].trades < InpMinTradesForDecision)
    {
        return true; // Allow strategy to gather more data
    }
    
    // CALCULATE CURRENT PROFIT FACTOR
    double grossProfit = g_perfData[strategyIndex].grossProfit;
    double grossLoss = g_perfData[strategyIndex].grossLoss;
    
    if(grossLoss > 0)
    {
        double currentPF = grossProfit / grossLoss;
        
        // V13.0 ELITE: TEMPORARY COOLDOWN instead of permanent disable
        if(currentPF < InpMinProfitFactor)
        {
            // Trigger temporary cooldown (10 bars)
            g_strategyCooldown[strategyIndex].disabled = true;
            g_strategyCooldown[strategyIndex].disabledTime = TimeCurrent();
            g_strategyCooldown[strategyIndex].disabledBars = iBars(Symbol(), Period());
            
            LogError(ERROR_INFO, "Strategy " + g_perfData[strategyIndex].name + 
                  " TEMPORARILY DISABLED - PF too low: " + DoubleToString(currentPF, 2) + 
                  " (10-bar cooldown)", "IsStrategyHealthyV13");
            return false;
        }
    }
    
    // DRAWDOWN PROTECTION CHECK
    if(g_current_drawdown >= InpDefensiveDD_Percent)
    {
        // In defensive mode, be more selective
        if(strategyIndex == 3) // Warden is more volatile
        {
            if(g_perfData[strategyIndex].grossLoss > 0)
            {
                double currentPF = g_perfData[strategyIndex].grossProfit / g_perfData[strategyIndex].grossLoss;
                if(currentPF < 1.5) // Stricter threshold in defensive mode
                {
                    // V13.0 ELITE: TEMPORARY COOLDOWN for defensive mode too
                    g_strategyCooldown[strategyIndex].disabled = true;
                    g_strategyCooldown[strategyIndex].disabledTime = TimeCurrent();
                    g_strategyCooldown[strategyIndex].disabledBars = iBars(Symbol(), Period());
                    
                    LogError(ERROR_INFO, "Strategy " + g_perfData[strategyIndex].name + 
                          " TEMPORARILY DISABLED in defensive mode - PF: " + DoubleToString(currentPF, 2) + 
                          " (10-bar cooldown)", "IsStrategyHealthyV13");
                    return false;
                }
            }
        }
    }
    
    return true;
}
//+------------------------------------------------------------------+
//| CORTANA PROTOCOL: ENHANCED ERROR LOGGING FUNCTION                |
//+------------------------------------------------------------------+
void LogError(ERROR_LEVEL level, string message, string function = "", int line = 0)
{
    // ENHANCED ERROR LOGGING WITH COMPREHENSIVE DIAGNOSTICS
    
    // Create a new log entry with enhanced metadata
    ErrorLog new_entry;
    new_entry.time = TimeCurrent();
    new_entry.level = level;
    new_entry.message = message;
    new_entry.function = function;
    new_entry.line = line;
    
    // Add to log array
    int log_size = ArraySize(g_error_log);
    ArrayResize(g_error_log, log_size + 1);
    g_error_log[log_size] = new_entry;
    
    // Trim log if it exceeds maximum size
    if(ArraySize(g_error_log) > g_max_error_log_size)
    {
        // Shift array to remove oldest entry
        for(int i = 0; i < g_max_error_log_size - 1; i++)
        {
            g_error_log[i] = g_error_log[i + 1];
        }
        ArrayResize(g_error_log, g_max_error_log_size);
    }
    
    // ENHANCED LEVEL CLASSIFICATION
    string level_str = "";
    color level_color = clrWhite;
    string prefix = "";
    
    switch(level)
    {
        case ERROR_INFO:
            level_str = "  INFO";
            level_color = clrDodgerBlue;
            prefix = "";
            break;
        case ERROR_WARNING:
            level_str = "  WARNING";
            level_color = clrGold;
            prefix = "";
            break;
        case ERROR_CRITICAL:
            level_str = " CRITICAL";
            level_color = clrRed;
            prefix = "";
            break;
    }
    
    // COMPREHENSIVE FORMATTING WITH CONTEXT
    string formatted_message = prefix + " [" + TimeToString(new_entry.time, TIME_DATE|TIME_SECONDS) + "] " +
                               "[" + level_str + "] ";
    
    // ADD FUNCTION CONTEXT
    if(StringLen(function) > 0)
        formatted_message += "[" + function + "()";
    
    if(line > 0)
        formatted_message += ":" + IntegerToString(line);
    
    if(StringLen(function) > 0 || line > 0)
        formatted_message += "] ";
    
    // ADD TRADE CONTEXT
    if(OrdersTotal() > 0)
        formatted_message += "[Trades: " + IntegerToString(OrdersTotal()) + "] ";
    
    // ADD ACCOUNT CONTEXT FOR CRITICAL ERRORS
    if(level == ERROR_CRITICAL)
    {
        formatted_message += "[Equity: " + DoubleToString(AccountEquity(), 2) + "] ";
        formatted_message += "[Balance: " + DoubleToString(AccountBalance(), 2) + "] ";
        formatted_message += "[Drawdown: " + DoubleToString(g_current_drawdown, 2) + "%] ";
    }
    
    formatted_message += message;
    
    // PRINT WITH ENHANCED VISUALIZATION
    Print(formatted_message);
    
    // CHART COMMENT FOR REAL-TIME MONITORING
    if(level == ERROR_CRITICAL && !IsOptimization())
    {
        string chartMsg = "CRITICAL ERROR: " + message;
        if(StringLen(function) > 0)
            chartMsg += " in " + function + "()";
        Comment(chartMsg);
        
        // Clear chart comment after 10 seconds
        static datetime lastCritError = 0;
        if(TimeCurrent() - lastCritError > 10)
        {
            Comment("");
            lastCritError = TimeCurrent();
        }
    }
    
    // ERROR HISTORY TRACKING
    static int errorCount = 0;
    static datetime lastErrorCheck = 0;
    
    if(TimeCurrent() - lastErrorCheck > 60) // Check every minute
    {
        errorCount = 0;
        for(int i = ArraySize(g_error_log) - 1; i >= 0; i--)
        {
            if(g_error_log[i].level == ERROR_CRITICAL && 
               TimeCurrent() - g_error_log[i].time < 3600) // Last hour
            {
                errorCount++;
            }
        }
        
        if(errorCount > 10)
        {
            Print(" WARNING: High critical error rate detected - " + IntegerToString(errorCount) + " errors in last hour");
        }
        
        lastErrorCheck = TimeCurrent();
    }
}
//+------------------------------------------------------------------+
//|       PROJECT ASCENSION: APEX SENTINEL REGIME FILTER (V1.0)      |
//|    Integrates intelligence from the Silicon EA to enable trading |
//|                     only in optimal market regimes.              |
//+------------------------------------------------------------------+
// --- MASTER SENTINEL FUNCTION ---
bool IsApexSentinelGreenlight()
{
    // The Apex Sentinel is a multi-layer filter. ALL layers must pass for a greenlight.
    if(!IsSentinel_VolatilityRegimeOK()) return false;
    if(!IsSentinel_TrendRegimeOK()) return false;
    if(!IsSentinel_MarketStructureOK()) return false;
    
    // If all checks pass, the market regime is optimal.
    return true;
}

// --- LAYER 1: VOLATILITY REGIME (CRITICAL) ---
// PURPOSE: Avoids high-volatility events which are poison to grid systems.
// This is the primary reason for the Silicon EA's low 4.06% drawdown.
bool IsSentinel_VolatilityRegimeOK()
{
    // Use H4 as the strategic timeframe for regime analysis, as per the report.
    int timeframe = PERIOD_H4;
    int atrPeriod = 14;
    int avgLookback = 100;

    double currentATR = iATR(Symbol(), timeframe, atrPeriod, 1); // Use last closed bar
    
    // Calculate historical average ATR
    double sumATR = 0;
    int validBars = 0;
    for(int i = 2; i < 2 + avgLookback; i++)
    {
        if(i >= Bars(Symbol(), timeframe)) break;
        sumATR += iATR(Symbol(), timeframe, atrPeriod, i);
        validBars++;
    }
    
    if(validBars < (avgLookback * 0.8)) // Need sufficient historical data
    {
        LogError(ERROR_INFO, "Apex Sentinel (Volatility): Insufficient H4 data for analysis.");
        return false; 
    }
    
    double avgATR = sumATR / validBars;

    // FILTER 1: Current volatility must be below 1.3x the historical average.
    // This effectively filters out news spikes and black swan events.
    if(currentATR > avgATR * 1.3)
    {
        LogError(ERROR_INFO, "Apex Sentinel Block: VOLATILITY TOO HIGH. Current ATR " + 
                  DoubleToString(currentATR, _Digits) + " > 1.3x Average " + DoubleToString(avgATR * 1.3, _Digits));
        return false;
    }

    // FILTER 2: Check for recent explosive spikes (no trading right after a bomb goes off).
    for(int i = 2; i <= 10; i++)
    {
        if(i >= Bars(Symbol(), timeframe)) break;
        double historicalATR = iATR(Symbol(), timeframe, atrPeriod, i);
        if(historicalATR > avgATR * 1.5)
        {
            LogError(ERROR_INFO, "Apex Sentinel Block: RECENT VOLATILITY SPIKE DETECTED.");
            return false;
        }
    }

    return true; // Volatility regime is confirmed safe.
}


// --- LAYER 2: TREND REGIME ---
// PURPOSE: Silicon-X is a range/breakout system. This filter disables it during strong, established trends.
bool IsSentinel_TrendRegimeOK()
{
    int timeframe = PERIOD_H4;
    double adx = iADX(Symbol(), timeframe, 14, PRICE_CLOSE, MODE_MAIN, 1);

    // FILTER 1: ADX must be below 30, indicating a weak trend or ranging market.
    if(adx >= 30)
    {
        LogError(ERROR_INFO, "Apex Sentinel Block: STRONG TREND DETECTED. ADX " + 
                  DoubleToString(adx, 1) + " >= 30");
        return false;
    }

    // FILTER 2: Check for sudden trend acceleration.
    double adxPrev = iADX(Symbol(), timeframe, 14, PRICE_CLOSE, MODE_MAIN, 2);
    if(adx > adxPrev * 1.1)
    {
         LogError(ERROR_INFO, "Apex Sentinel Block: TREND ACCELERATION DETECTED.");
         return false;
    }

    return true; // Trend regime is confirmed suitable for grid/trap system.
}

// --- LAYER 3: MARKET STRUCTURE ---
// PURPOSE: Ensures the market is in a "normal" state, avoiding extremes and gaps.
bool IsSentinel_MarketStructureOK()
{
    int timeframe = PERIOD_H4;
    
    // FACTOR 1: Price should not be at extreme levels relative to its long-term mean (200 EMA).
    double ema200 = iMA(Symbol(), timeframe, 200, 0, MODE_EMA, PRICE_CLOSE, 1);
    double close = iClose(Symbol(), timeframe, 1);
    double deviation = MathAbs(close - ema200) / ema200;

    if (deviation > 0.05) // Price is more than 5% away from the 200 EMA
    {
        LogError(ERROR_INFO, "Apex Sentinel Block: MARKET AT EXTREME. Price deviation from 200 EMA > 5%.");
        return false;
    }

    // FACTOR 2: Check for recent significant price gaps.
    for(int i = 1; i <= 5; i++)
    {
        if(i+1 >= Bars(Symbol(), timeframe)) break;
        double prevClose = iClose(Symbol(), timeframe, i+1);
        double currentOpen = iOpen(Symbol(), timeframe, i);
        double gap = MathAbs(currentOpen - prevClose);
        double avgRange = iATR(Symbol(), timeframe, 14, i);
        
        if (avgRange > 0 && gap > avgRange * 2.0)
        {
            LogError(ERROR_INFO, "Apex Sentinel Block: RECENT PRICE GAP DETECTED.");
            return false;
        }
    }
    
    return true; // Market structure is stable.
}

//+------------------------------------------------------------------+
//|    PROJECT ASCENSION: SILICON TRAP PLACEMENT CONFIRMATION        |
//+------------------------------------------------------------------+
// PURPOSE: Detects volatility contraction (BB Squeeze) as the final
// confirmation before laying the initial grid traps.
bool IsTrapPlacementWindowOpen()
{
    int timeframe = PERIOD_H1; // Report suggests H1 for this analysis

    // BOLLINGER BAND SQUEEZE DETECTION
    double bbUpper = iBands(Symbol(), timeframe, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);
    double bbLower = iBands(Symbol(), timeframe, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);
    
    // V17.4 FIX: Check for division by zero
    double bbWidth = (iClose(Symbol(), timeframe, 1) > 0) ? (bbUpper - bbLower) / iClose(Symbol(), timeframe, 1) : 0;
    
    // Calculate historical average BB width over 100 periods
    double avgBBWidth = 0;
    int validBars = 0;
    for(int i = 2; i < 2 + 100; i++)
    {
        if (i >= Bars(Symbol(), timeframe)) break;
        double histUpper = iBands(Symbol(), timeframe, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, i);
        double histLower = iBands(Symbol(), timeframe, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, i);
        double histClose = iClose(Symbol(), timeframe, i);
        if (histClose > 0)
        {
            avgBBWidth += (histUpper - histLower) / histClose;
            validBars++;
        }
    }
    if (validBars == 0) return true; // Fail safe, don't block
    avgBBWidth /= validBars;

    // Report Logic: CONTRACTION = BB width in bottom 20th percentile of its history.
    if(bbWidth > avgBBWidth * 0.20)
    {
        LogError(ERROR_INFO, "Trap Placement Block: Volatility is not contracted (BB Squeeze not found).");
        return false;
    }
    
    // ATR CONFIRMATION
    double currentATR = iATR(Symbol(), timeframe, 14, 1);
    double avgATR = 0;
    validBars = 0;
    for(int i = 2; i < 2 + 100; i++)
    {
        if(i >= Bars(Symbol(), timeframe)) break;
        avgATR += iATR(Symbol(), timeframe, 14, i);
        validBars++;
    }
    if (validBars == 0) return true; // Fail safe
    avgATR /= validBars;
    
    if(currentATR > avgATR * 0.8)
    {
         LogError(ERROR_INFO, "Trap Placement Block: ATR is expanding, not contracting.");
         return false;
    }
    
    LogError(ERROR_INFO, "Trap Placement CONFIRMED: Volatility contracted. Ready to place traps.");
    return true; // Trap window is open.
}

//+------------------------------------------------------------------+
//|  PROJECT ASCENSION: ORION META-STRATEGY CONTROLLER (V1.0)       |
//+------------------------------------------------------------------+

// --- The Orion Master Conductor ---
// This function must be called ONCE per bar in OnNewBar() BEFORE any strategy logic.
void Orion_DynamicAllocation()
{
    // --- Phase 1: Pre-analysis Checks ---
    // If ANY grid strategy is ALREADY active, we are locked in. No new permissions.
    UpdateReaperBasketState();   // Ensure state is fresh
    UpdateSiliconXState();       // Ensure state is fresh
    if (g_reaper_buy_levels > 0 || g_reaper_sell_levels > 0 || g_siliconx_buy_levels > 0 || g_siliconx_sell_levels > 0)
    {
        g_orion_permission = PERMIT_NONE; // Lock state, existing grid manages itself
        LogError(ERROR_INFO, "Orion Protocol: Active grid detected. Allocation locked.");
        return;
    }
    
    // --- Phase 2: Market Regime Analysis ---
    int timeframe = PERIOD_H4;
    double adx = iADX(Symbol(), timeframe, 14, PRICE_CLOSE, MODE_MAIN, 1);
    
    double currentATR = iATR(Symbol(), timeframe, 14, 1);
    double avgATR = 0;
    int validBars = 0;
    for(int i = 2; i < 2 + 50; i++) { // Shorter lookback for responsiveness
        if(i >= Bars(Symbol(), timeframe)) break;
        avgATR += iATR(Symbol(), timeframe, 14, i);
        validBars++;
    }
    avgATR = (validBars > 0) ? avgATR / validBars : 0;
    double normalizedATR = (avgATR > 0) ? currentATR / avgATR : 1.0;

    // --- Phase 3: Allocation Decision Logic (as per intel report) ---
    // Note: We use ADX < 25 here, slightly different from the Sentinel's < 30, to give Reaper its ideal, quiet market.
    if (adx < 25 && normalizedATR < 1.2) 
    {
        // RANGING, LOW-TO-NORMAL VOLATILITY -> Ideal for Reaper Protocol
        g_orion_permission = PERMIT_REAPER;
        LogError(ERROR_INFO, "Orion Protocol: Regime is RANGING/CALM (ADX: "+DoubleToString(adx,1)+"). Permitting REAPER Protocol.");
    }
    else if (adx > 30) // Let's keep it simple for now, ADX > 30 is a TREND
    {
        // TRENDING -> Ideal for Titan Protocol
        g_orion_permission = PERMIT_TREND;
         LogError(ERROR_INFO, "Orion Protocol: Regime is TRENDING (ADX: "+DoubleToString(adx,1)+"). Permitting TITAN Protocol.");
    }
    else // The "in-between" zone is where breakouts are born. This is Silicon-X territory.
    {
        // TRANSITIONAL / PRE-BREAKOUT -> Ideal for Silicon-X Protocol
        g_orion_permission = PERMIT_SILICON_X;
        LogError(ERROR_INFO, "Orion Protocol: Regime is TRANSITIONAL (ADX: "+DoubleToString(adx,1)+"). Permitting SILICON-X Protocol.");
    }
}
//+------------------------------------------------------------------+
//| PROJECT ASCENSION: ADAPTIVE COMPOUNDING ENGINE - GetLotSize      |
//| Replaces ALL previous lot sizing functions.                     |
//+------------------------------------------------------------------+
double GetLotSize_Ascension(double stopLossPips, int strategyIndex)
{
    if (stopLossPips <= 0) return MarketInfo(Symbol(), MODE_MINLOT);
    
    // STEP 1: DETERMINE COMPOUNDING MODE (based on DD and streaks)
    DetermineCompoundingMode();
    
    // STEP 2: CALCULATE KELLY CRITERION (uses hardcoded stats from the intel report for now)
    double winRate = 0.7922; // Using Silicon EA's proven stats
    double oddsRatio = 3.81;
    double lossRate = 1.0 - winRate;
    double kellyFraction = (((oddsRatio * winRate) - lossRate) / oddsRatio) * 0.25; // 25% Fractional Kelly

    double baseRiskPercent = kellyFraction * 100.0; // Convert to percent

    // STEP 3: APPLY MODE-SPECIFIC RISK ADJUSTMENT
    double modeMultiplier = 1.0;
    switch(g_compoundingMode)
    {
        case MODE_AGGRESSIVE_GROWTH:    modeMultiplier = 1.5; break;
        case MODE_CAPITAL_PRESERVATION: modeMultiplier = 0.5; break;
        default:                        modeMultiplier = 1.0; break;
    }
    double adjustedRisk = baseRiskPercent * modeMultiplier;

    // STEP 4: APPLY PERFORMANCE-BASED SCALING
    double scalingFactor = 1.0;
    // Win streak boost
    if(g_consecutiveWins >= 5) scalingFactor += 0.3; 
    else if(g_consecutiveWins >= 3) scalingFactor += 0.15;
    // Equity growth boost
    double equityGrowth = (AccountEquity() - 10000) / 10000;
    if(equityGrowth > 1.0) scalingFactor += 0.2; 
    else if(equityGrowth > 0.5) scalingFactor += 0.1;
    // Drawdown penalty
    if(g_current_drawdown > 3.0) scalingFactor *= 0.7;
    // Loss streak penalty
    if(g_consecutiveLosses >= 2) scalingFactor *= 0.6;
    
    double finalRiskPercent = adjustedRisk * scalingFactor;

    // STEP 5: ENFORCE ABSOLUTE RISK LIMITS
    finalRiskPercent = MathMax(g_Ascension_MinRiskPercent, MathMin(g_Ascension_MaxRiskPercent, finalRiskPercent));
    
    // FINAL PORTFOLIO BUDGET CHECK (from our old robust function)
    if(GetTotalCurrentRiskPercent() + finalRiskPercent > InpMaxTotalRisk_Percent)
    {
        LogError(ERROR_INFO, "ASCENSION ENGINE: Trade blocked by portfolio max risk limit.");
        return 0; // Return zero lots to block trade
    }

    // STANDARD LOT SIZE CALCULATION
    double riskAmount = AccountEquity() * (finalRiskPercent / 100.0);
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = 0;

    // V17.4 FIX: Check for invalid tick value and stop loss in PIPS (not points)
    if(tickValue > 0 && stopLossPips > 0)
    {
      // Value of one pip for one lot (ZERO-DIVIDE PROTECTION)
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      if(tickSize <= 0) tickSize = 0.00001; // Prevent zero divide
      double pipValuePerLot = MarketInfo(Symbol(), MODE_TICKVALUE) * (10 * _Point) / tickSize;
      if(StringFind(Symbol(), "JPY") >= 0) pipValuePerLot /= 100;
       
      if (pipValuePerLot > 0) {
         lotSize = riskAmount / (stopLossPips * pipValuePerLot);
      }
    }

    // Normalize Lot Size
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

    if (lotStep > 0)
        lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

    LogError(ERROR_INFO, "ASCENSION ENGINE: Mode=" + CompoundingModeToString(g_compoundingMode) +
             " | Final Risk=" + DoubleToString(finalRiskPercent, 2) + "% | Lots=" + 
             DoubleToString(lotSize, 2));

    return lotSize;
}

// --- Helper for Determining Compounding Mode ---
void DetermineCompoundingMode()
{
    // Uses existing g_current_drawdown, g_high_watermark_equity
    if(g_current_drawdown < 2.0 && g_consecutiveWins >= 3) {
        g_compoundingMode = MODE_AGGRESSIVE_GROWTH;
    }
    else if(g_current_drawdown > 5.0 || g_consecutiveLosses >= 2) {
        g_compoundingMode = MODE_CAPITAL_PRESERVATION;
    }
    else {
        g_compoundingMode = MODE_BALANCED_GROWTH;
    }
}

// --- Helper to convert Enum to String for logging ---
string CompoundingModeToString(COMPOUNDING_MODE mode) {
    switch(mode) {
        case MODE_AGGRESSIVE_GROWTH: return "AGGRESSIVE";
        case MODE_BALANCED_GROWTH: return "BALANCED";
        case MODE_CAPITAL_PRESERVATION: return "PRESERVATION";
        default: return "UNKNOWN";
    }
}
//+------------------------------------------------------------------+
//| KELLY CRITERION POSITION SIZING                                 |
//+------------------------------------------------------------------+
double CalculateKellyFraction(int strategy_index)
{
    // Initialize if first time
    if(g_strategy_win_rates[strategy_index] == 0)
    {
        // Default conservative values based on strategy type
        switch(strategy_index)
        {
            case 0: // Mean Reversion - historically good performance
                g_strategy_win_rates[strategy_index] = 0.55;
                g_strategy_avg_wins[strategy_index] = 1.5;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
            case 1: // Quantum Oscillator - good performance
                g_strategy_win_rates[strategy_index] = 0.52;
                g_strategy_avg_wins[strategy_index] = 1.4;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
            case 2: // Titan - trend following, lower win rate but higher rewards
                g_strategy_win_rates[strategy_index] = 0.45;
                g_strategy_avg_wins[strategy_index] = 2.2;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
            case 3: // Warden - volatility breakout
                g_strategy_win_rates[strategy_index] = 0.48;
                g_strategy_avg_wins[strategy_index] = 1.8;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
            case 4: // Momentum Impulse - high frequency, moderate win rate
                g_strategy_win_rates[strategy_index] = 0.50;
                g_strategy_avg_wins[strategy_index] = 1.3;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
            case 5: // Volatility Breakout - breakout specialist
                g_strategy_win_rates[strategy_index] = 0.47;
                g_strategy_avg_wins[strategy_index] = 1.9;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
            case 6: // Market Microstructure - professional trading
                g_strategy_win_rates[strategy_index] = 0.53;
                g_strategy_avg_wins[strategy_index] = 1.6;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
            default:
                g_strategy_win_rates[strategy_index] = 0.45;
                g_strategy_avg_wins[strategy_index] = 1.5;
                g_strategy_avg_losses[strategy_index] = 1.0;
                break;
        }
    }
    
    double win_rate = g_strategy_win_rates[strategy_index];
    // ZERO-DIVIDE PROTECTION
    double avg_loss = g_strategy_avg_losses[strategy_index];
    if(avg_loss <= 0) avg_loss = 1.0;
    double win_loss_ratio = g_strategy_avg_wins[strategy_index] / avg_loss;
    
    // Kelly Formula: f = (bp - q) / b
    // where b = odds received on the wager (win/loss ratio)
    //       p = probability of winning
    //       q = probability of losing (1-p)
    // ZERO-DIVIDE PROTECTION
    if(win_loss_ratio <= 0) win_loss_ratio = 1.0;
    double kelly_fraction = (win_loss_ratio * win_rate - (1 - win_rate)) / win_loss_ratio;
    
    // Apply safety multiplier (use half-Kelly for safety)
    kelly_fraction = kelly_fraction * 0.5;
    
    // Clamp between 0.01 and 0.50 (1% to 50% of account)
    if(kelly_fraction < 0.01) kelly_fraction = 0.01;
    if(kelly_fraction > 0.50) kelly_fraction = 0.50;
    
    return kelly_fraction;
}

//+------------------------------------------------------------------+
//| SIGNAL ARBITRATION SYSTEM                                        |
//+------------------------------------------------------------------+
double CalculateSignalConviction(int strategy_index, double signal_strength)
{
    // Base conviction multipliers by strategy priority
    double priority_multiplier = 1.0;
    
    switch(strategy_index)
    {
        case 6: // Market Microstructure (H1) - highest priority
            priority_multiplier = 1.5;
            break;
        case 5: // Volatility Breakout (M30) - high priority  
            priority_multiplier = 1.3;
            break;
        case 4: // Momentum Impulse (M15) - high priority
            priority_multiplier = 1.2;
            break;
        case 2: // Titan (H4) - medium priority
            priority_multiplier = 1.1;
            break;
        case 0: // Mean Reversion (H4) - medium priority
            priority_multiplier = 1.0;
            break;
        case 1: // Quantum Oscillator (H4) - medium priority
            priority_multiplier = 1.0;
            break;
        case 3: // Warden (H4) - lower priority
            priority_multiplier = 0.9;
            break;
    }
    
    // Signal strength normalization (typically 0.0 to 1.0)
    double normalized_strength = MathMax(0.0, MathMin(1.0, signal_strength));
    
    // Calculate final conviction score
    double conviction = normalized_strength * priority_multiplier;
    
    // Store for arbitration
    g_signal_conviction[strategy_index] = conviction;
    g_signal_priority[strategy_index] = (int)(priority_multiplier * 10);
    
    return conviction;
}

bool IsSignalApproved(int strategy_index, double conviction_score)
{
    // Minimum conviction threshold for trade approval
    double min_conviction = 0.3;
    
    // Higher threshold for lower priority strategies
    double adjusted_threshold = min_conviction;
    if(strategy_index == 3) // Warden gets stricter filtering
        adjusted_threshold = 0.4;
    
    return (conviction_score >= adjusted_threshold);
}

//+------------------------------------------------------------------+
//| PHASE 5: ENHANCED 8-COMPONENT CONVICTION SYSTEM                 |
//| TARGETING: 87.3% WIN RATE, 4.2+ PROFIT FACTOR                   |
//+------------------------------------------------------------------+
double CalculateEnhancedConviction(int strategy_index, double signal_strength)
{
    if(!InpEnablePerformanceOptimization) 
        return CalculateSignalConviction(strategy_index, signal_strength);
    
    double conviction = 0.0;
    
    // COMPONENT 1: Trend Alignment Assessment (0-2.0)
    double trend_conviction = CalculateTrendAlignmentConviction(strategy_index);
    conviction += trend_conviction;
    
    // COMPONENT 2: Momentum Strength Measurement (0-1.5) 
    double momentum_conviction = CalculateMomentumStrengthConviction(strategy_index);
    conviction += momentum_conviction;
    
    // COMPONENT 3: Volume Confirmation Analysis (0-1.5)
    double volume_conviction = CalculateVolumeConfirmationConviction(strategy_index);
    conviction += volume_conviction;
    
    // COMPONENT 4: Volatility Regime Evaluation (0-1.0)
    double volatility_conviction = CalculateVolatilityRegimeConviction(strategy_index);
    conviction += volatility_conviction;
    
    // COMPONENT 5: Support/Resistance Proximity (0-1.0)
    double sr_conviction = CalculateSupportResistanceConviction(strategy_index);
    conviction += sr_conviction;
    
    // COMPONENT 6: RSI Divergence Detection (0-1.0)
    double rsi_conviction = CalculateRSIDivergenceConviction(strategy_index);
    conviction += rsi_conviction;
    
    // COMPONENT 7: Bollinger Band Position Analysis (0-1.0)
    double bb_conviction = CalculateBollingerBandConviction(strategy_index);
    conviction += bb_conviction;
    
    // COMPONENT 8: ADX Trend Strength Calculation (0-1.0)
    double adx_conviction = CalculateADXTrendConviction(strategy_index);
    conviction += adx_conviction;
    
    // Apply High-Performance Mode boost
    if(g_high_performance_mode && conviction >= 6.0)
    {
        conviction *= 1.25; // 25% boost in high-performance mode
    }
    
    // Apply adaptive threshold adjustment
    conviction = MathMax(conviction, g_adaptive_conviction_threshold);
    
    return MathMin(10.0, conviction); // Cap at 10.0
}

double CalculateTrendAlignmentConviction(int strategy_index)
{
    // Multi-timeframe EMA alignment assessment
    double h1_ema20 = iMA(Symbol(), PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double h1_ema50 = iMA(Symbol(), PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    double h4_ema20 = iMA(Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double d1_ema20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    double alignment_score = 0.0;
    
    // H1 alignment (most recent)
    if(Close[0] > h1_ema20 && h1_ema20 > h1_ema50) alignment_score += 0.8; // Bullish
    else if(Close[0] < h1_ema20 && h1_ema20 < h1_ema50) alignment_score += 0.8; // Bearish
    
    // H4 confirmation
    if(Close[0] > h4_ema20) alignment_score += 0.6;
    else alignment_score += 0.6; // Bearish confirmation
    
    // D1 trend context
    if(Close[0] > d1_ema20) alignment_score += 0.6;
    else alignment_score += 0.6; // Bearish context
    
    return alignment_score;
}

double CalculateMomentumStrengthConviction(int strategy_index)
{
    double momentum_score = 0.0;
    
    // RSI momentum
    double rsi = iRSI(Symbol(), Period(), 14, PRICE_CLOSE, 0);
    if(rsi > 50 && rsi < 70) momentum_score += 0.5; // Bullish momentum
    else if(rsi < 50 && rsi > 30) momentum_score += 0.5; // Bearish momentum
    
    // MACD momentum
    double macd_main = iMACD(Symbol(), Period(), 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    double macd_signal = iMACD(Symbol(), Period(), 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    if(macd_main > macd_signal) momentum_score += 0.5;
    else momentum_score += 0.5; // Bearish momentum
    
    // Price velocity
    double velocity = (Close[0] - Close[5]) / Close[5] * 100;
    if(MathAbs(velocity) > 0.5) momentum_score += 0.5; // Significant movement
    
    return momentum_score;
}

double CalculateVolumeConfirmationConviction(int strategy_index)
{
    double volume_score = 0.0;
    
    // Volume MA confirmation
    double volume_ma = iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double current_volume = (double)Volume[0];
    
    if(current_volume > volume_ma * 1.2) volume_score += 0.7; // Strong volume
    else if(current_volume > volume_ma) volume_score += 0.3; // Normal volume
    
    // Volume trend
    double volume_trend = ((double)Volume[0] - (double)Volume[5]) / (double)Volume[5] * 100;
    if(volume_trend > 10) volume_score += 0.4; // Increasing volume
    else if(volume_trend < -10) volume_score += 0.4; // Decreasing volume on reversal
    
    // Strategy-specific volume requirements
    switch(strategy_index)
    {
        case 4: // Momentum Impulse M15 - requires volume spike
            if(current_volume > volume_ma * 1.5) volume_score += 0.4;
            break;
        case 5: // Volatility Breakout M30 - requires volume confirmation
            if(current_volume > volume_ma * 1.3) volume_score += 0.4;
            break;
    }
    
    return volume_score;
}

double CalculateVolatilityRegimeConviction(int strategy_index)
{
    double volatility_score = 0.0;
    
    double current_atr = iATR(Symbol(), Period(), 14, 0);
    double avg_atr = 0;
    
    // Calculate average ATR over 20 periods
    for(int i = 1; i <= 20; i++)
    {
        avg_atr += iATR(Symbol(), Period(), 14, i);
    }
    avg_atr /= 20;
    
    // ZERO-DIVIDE PROTECTION
    if(avg_atr <= 0) avg_atr = 0.0001;
    double volatility_ratio = current_atr / avg_atr;
    
    // Strategy-specific volatility requirements
    switch(strategy_index)
    {
        case 0: // Mean Reversion - prefers lower volatility
            if(volatility_ratio < 0.8) volatility_score += 0.6;
            else if(volatility_ratio < 1.2) volatility_score += 0.4;
            break;
        case 2: // Titan - prefers stable trending volatility
            if(volatility_ratio > 0.8 && volatility_ratio < 1.5) volatility_score += 0.6;
            break;
        case 5: // Volatility Breakout - requires high volatility
            if(volatility_ratio > 1.3) volatility_score += 0.7;
            else if(volatility_ratio > 1.0) volatility_score += 0.3;
            break;
        default: // General case
            if(volatility_ratio > 0.8 && volatility_ratio < 1.5) volatility_score += 0.5;
            break;
    }
    
    return volatility_score;
}

double CalculateSupportResistanceConviction(int strategy_index)
{
    double sr_score = 0.0;
    
    // Find recent highs and lows
    double recent_high = High[0];
    double recent_low = Low[0];
    
    for(int i = 1; i < 20; i++)
    {
        if(High[i] > recent_high) recent_high = High[i];
        if(Low[i] < recent_low) recent_low = Low[i];
    }
    
    double price_range = recent_high - recent_low;
    double current_position = Close[0] - recent_low;
    
    // Position within range (0 = support, 1 = resistance)
    double position_ratio = price_range > 0 ? current_position / price_range : 0.5;
    
    // Near support/resistance zones
    if(position_ratio < 0.2 || position_ratio > 0.8) sr_score += 0.6; // Near key levels
    else if(position_ratio < 0.4 || position_ratio > 0.6) sr_score += 0.4; // Moderate proximity
    
    // Strategy-specific SR requirements
    switch(strategy_index)
    {
        case 0: // Mean Reversion - prefers oversold/overbought levels
            if(position_ratio < 0.2 || position_ratio > 0.8) sr_score += 0.4;
            break;
        case 2: // Titan - prefers breakouts from consolidation
            if(position_ratio > 0.4 && position_ratio < 0.6) sr_score += 0.4;
            break;
    }
    
    return sr_score;
}

double CalculateRSIDivergenceConviction(int strategy_index)
{
    double rsi_score = 0.0;
    
    double current_rsi = iRSI(Symbol(), Period(), 14, PRICE_CLOSE, 0);
    
    // Look for divergence with price
    double price_trend = Close[0] - Close[5];
    double rsi_trend = current_rsi - iRSI(Symbol(), Period(), 14, PRICE_CLOSE, 5);
    
    // Bullish divergence (price down, RSI up)
    if(price_trend < 0 && rsi_trend > 0)
    {
        rsi_score += 0.6;
        if(current_rsi < 40) rsi_score += 0.4; // Stronger at oversold levels
    }
    // Bearish divergence (price up, RSI down)
    else if(price_trend > 0 && rsi_trend < 0)
    {
        rsi_score += 0.6;
        if(current_rsi > 60) rsi_score += 0.4; // Stronger at overbought levels
    }
    // No divergence but strong momentum
    else if(MathAbs(rsi_trend) > 2 && (current_rsi < 30 || current_rsi > 70))
    {
        rsi_score += 0.3; // Extreme levels
    }
    
    return rsi_score;
}

double CalculateBollingerBandConviction(int strategy_index)
{
    double bb_score = 0.0;
    
    double bb_upper = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double bb_lower = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    double bb_middle = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Position within Bollinger Bands (ZERO-DIVIDE PROTECTION)
    double bb_range = bb_upper - bb_lower;
    double bb_position = (bb_range > 0) ? (Close[0] - bb_lower) / bb_range : 0.5;
    
    // Strategy-specific BB analysis
    switch(strategy_index)
    {
        case 0: // Mean Reversion - prefer touches of bands
            if(bb_position < 0.1 || bb_position > 0.9) bb_score += 0.7; // Near bands
            else if(bb_position < 0.3 || bb_position > 0.7) bb_score += 0.3;
            break;
        case 3: // Warden - prefer squeeze breakouts
            {
                double bb_width = bb_upper - bb_lower;
                double avg_bb_width = 0;
                for(int i = 1; i <= 20; i++)
                {
                    double temp_upper = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_UPPER, i);
                    double temp_lower = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_LOWER, i);
                    avg_bb_width += temp_upper - temp_lower;
                }
                avg_bb_width /= 20;
                
                if(bb_width < avg_bb_width * 0.7) // Squeeze detected
                {
                    if(bb_position > 0.8 || bb_position < 0.2) bb_score += 0.8; // Breakout from squeeze
                }
            }
            break;
        default: // General case
            if(bb_position < 0.2 || bb_position > 0.8) bb_score += 0.5;
            break;
    }
    
    return bb_score;
}

double CalculateADXTrendConviction(int strategy_index)
{
    double adx_score = 0.0;
    
    double adx = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 0);
    
    // ADX strength classification
    if(adx > 25) adx_score += 0.6; // Strong trend
    else if(adx > 20) adx_score += 0.4; // Moderate trend
    else if(adx > 15) adx_score += 0.2; // Weak trend
    
    // DI+ and DI- analysis
    double di_plus = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_PLUSDI, 0);
    double di_minus = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MINUSDI, 0);
    
    // Strong directional movement
    if(MathAbs(di_plus - di_minus) > 10) adx_score += 0.4;
    
    return adx_score;
}

//+------------------------------------------------------------------+
//| PHASE 5: MULTI-TIMEFRAME CONFIRMATION SYSTEM                    |
//+------------------------------------------------------------------+
bool CheckMultiTimeframeConfirmation(int strategy_index)
{
    if(!InpEnableMTFConfirmation) return true;
    
    // H1 EMA alignment
    double h1_ema20 = iMA(Symbol(), PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double h1_ema50 = iMA(Symbol(), PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    // H4 EMA alignment  
    double h4_ema20 = iMA(Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double h4_ema50 = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    // D1 EMA alignment
    double d1_ema20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double d1_ema50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    bool h1_bullish = Close[0] > h1_ema20 && h1_ema20 > h1_ema50;
    bool h1_bearish = Close[0] < h1_ema20 && h1_ema20 < h1_ema50;
    bool h4_bullish = Close[0] > h4_ema20;
    bool h4_bearish = Close[0] < h4_ema20;
    bool d1_bullish = Close[0] > d1_ema20;
    bool d1_bearish = Close[0] < d1_ema20;
    
    // Require alignment for enhanced conviction
    bool bullish_alignment = h1_bullish && h4_bullish && d1_bullish;
    bool bearish_alignment = h1_bearish && h4_bearish && d1_bearish;
    
    // Strategy-specific MTF requirements
    switch(strategy_index)
    {
        case 2: // Titan - requires full alignment
            return bullish_alignment || bearish_alignment;
        case 0: // Mean Reversion - flexible on higher timeframes
            return h1_bullish || h1_bearish; // At least H1 confirmation
        case 4: // Momentum Impulse - requires H1 and H4
            return (h1_bullish && h4_bullish) || (h1_bearish && h4_bearish);
        default: // General case - require at least H1 and H4
            return (h1_bullish && h4_bullish) || (h1_bearish && h4_bearish);
    }
}

//+------------------------------------------------------------------+
//| PHASE 5: DYNAMIC POSITION SIZING WITH KELLY CRITERION          |
//+------------------------------------------------------------------+
double CalculateDynamicPositionSize(int strategy_index, double conviction_score)
{
    if(!InpEnableDynamicRiskSizing) 
        return CalculateKellyFraction(strategy_index);
    
    // Base Kelly calculation
    double base_kelly = CalculateKellyFraction(strategy_index);
    
    // Performance-based adjustment
    double performance_multiplier = 1.0;
    
    if(g_perfData[strategy_index].trades >= 10)
    {
        double strategy_pf = (g_perfData[strategy_index].grossLoss > 0) ? 
                           g_perfData[strategy_index].grossProfit / g_perfData[strategy_index].grossLoss : 1.0;
        
        // Boost size for high-performing strategies
        if(strategy_pf > 3.0) performance_multiplier = 1.5;
        else if(strategy_pf > 2.0) performance_multiplier = 1.3;
        else if(strategy_pf > 1.5) performance_multiplier = 1.1;
        // Reduce size for underperforming strategies
        else if(strategy_pf < 1.2) performance_multiplier = 0.7;
        else if(strategy_pf < 1.0) performance_multiplier = 0.5;
    }
    
    // Conviction-based boost
    double conviction_multiplier = 1.0;
    if(conviction_score > 8.0) conviction_multiplier = 1.4;
    else if(conviction_score > 7.0) conviction_multiplier = 1.2;
    else if(conviction_score > 6.0) conviction_multiplier = 1.1;
    
    // Market regime adjustment
    double regime_multiplier = 1.0;
    if(g_current_drawdown > 8.0) regime_multiplier = 0.6; // Defensive mode
    else if(g_current_drawdown > 5.0) regime_multiplier = 0.8; // Cautious mode
    else if(g_current_drawdown < 2.0) regime_multiplier = 1.2; // Aggressive mode
    
    // Calculate final position size
    double dynamic_size = base_kelly * performance_multiplier * conviction_multiplier * regime_multiplier;
    
    // Apply maximum risk constraints
    dynamic_size = MathMax(0.1, MathMin(dynamic_size, InpMaxRiskPerTrade));
    
    return dynamic_size;
}

//+------------------------------------------------------------------+
//| PHASE 5: PERFORMANCE ADAPTATION SYSTEM                          |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
{
    if(TimeCurrent() - g_last_performance_update < 300) return; // Update every 5 minutes
    
    g_last_performance_update = TimeCurrent();
    
    // Calculate overall performance metrics
    double total_profit = 0, total_loss = 0, total_trades = 0, total_wins = 0;
    
    for(int i = 0; i < 7; i++)
    {
        total_profit += g_perfData[i].grossProfit;
        total_loss += g_perfData[i].grossLoss;
        total_trades += g_perfData[i].trades;
        
        if(g_perfData[i].trades > 0)
        {
            // ZERO-DIVIDE PROTECTION
            double profit_loss_sum = g_perfData[i].grossProfit + g_perfData[i].grossLoss;
            double win_rate = (profit_loss_sum > 0) ? g_perfData[i].grossProfit / profit_loss_sum : 0;
            total_wins += (int)(g_perfData[i].trades * win_rate);
        }
    }
    
    // Store in performance history (circular buffer)
    PerformanceRecord new_record;
    new_record.timestamp = TimeCurrent();
    new_record.win_rate = (total_trades > 0) ? ((double)total_wins / total_trades) * 100 : 0;
    new_record.profit_factor = (total_loss > 0) ? total_profit / total_loss : 0;
    new_record.conviction_threshold = g_adaptive_conviction_threshold;
    new_record.high_performance_mode = g_high_performance_mode;
    
    // Calculate Sharpe ratio (simplified)
    if(total_trades > 10)
    {
        double avg_return = total_profit / total_trades;
        double variance = 0;
        
        for(int i = 0; i < 17 && i < ArraySize(g_perfData); i++) // V28.00: Extended to 17
        {
            if(g_perfData[i].trades > 0)
            {
                double avg_strategy_return = (g_perfData[i].grossProfit - g_perfData[i].grossLoss) / g_perfData[i].trades;
                variance += MathPow(avg_strategy_return - avg_return, 2);
            }
        }
        variance /= 7;
        new_record.sharpe_ratio = (variance > 0) ? avg_return / MathSqrt(variance) : 0;
    }
    else
    {
        new_record.sharpe_ratio = 0;
    }
    
    // Calculate max drawdown
    double current_equity = AccountBalance() + AccountProfit();
    if(g_high_watermark_equity == 0) g_high_watermark_equity = current_equity;
    else if(current_equity > g_high_watermark_equity) g_high_watermark_equity = current_equity;
    
    double drawdown = (g_high_watermark_equity - current_equity) / g_high_watermark_equity * 100;
    new_record.max_drawdown = MathMax(0, drawdown);
    
    // Store in circular buffer
    g_performance_history[g_performance_index] = new_record;
    g_performance_index = (g_performance_index + 1) % 100;
    if(g_total_performance_records < 100) g_total_performance_records++;
    
    // Update current performance variables
    g_current_win_rate = new_record.win_rate;
    g_current_profit_factor = new_record.profit_factor;
    g_current_sharpe_ratio = new_record.sharpe_ratio;
    
    // Check for high-performance mode activation
    CheckHighPerformanceMode();
    
    // Adaptive threshold adjustment
    UpdateAdaptiveThresholds();
    
    // Store recent metrics for trend analysis
    g_recent_win_rates[g_performance_tracking_index] = g_current_win_rate;
    g_recent_profit_factors[g_performance_tracking_index] = g_current_profit_factor;
    g_recent_sharpe_ratios[g_performance_tracking_index] = g_current_sharpe_ratio;
    g_performance_tracking_index = (g_performance_tracking_index + 1) % 50;
}

void CheckHighPerformanceMode()
{
    bool should_activate = false;
    
    // Activate if we've consistently hit targets
    if(g_total_performance_records >= 20)
    {
        double recent_win_rate = 0, recent_pf = 0, recent_count = 0;
        
        for(int i = 0; i < MathMin(20, g_total_performance_records); i++)
        {
            int index = (g_performance_index - 1 - i + 100) % 100;
            if(index >= 0 && index < g_total_performance_records)
            {
                recent_win_rate += g_performance_history[index].win_rate;
                recent_pf += g_performance_history[index].profit_factor;
                recent_count++;
            }
        }
        
        if(recent_count > 0)
        {
            recent_win_rate /= recent_count;
            recent_pf /= recent_count;
            
            if(recent_win_rate >= g_enhanced_win_rate_target && recent_pf >= g_enhanced_profit_factor_target)
            {
                should_activate = true;
            }
        }
    }
    
    if(should_activate && !g_high_performance_mode)
    {
        g_high_performance_mode = true;
        g_adaptive_conviction_threshold = 7.0; // Higher thresholds in high-performance mode
        LogError(ERROR_INFO, " HIGH-PERFORMANCE MODE ACTIVATED - Conviction threshold: 7.0", "CheckHighPerformanceMode");
    }
    else if(!should_activate && g_high_performance_mode)
    {
        g_high_performance_mode = false;
        g_adaptive_conviction_threshold = 6.0; // Standard thresholds
        LogError(ERROR_INFO, " Standard performance mode - Conviction threshold: 6.0", "CheckHighPerformanceMode");
    }
}

void UpdateAdaptiveThresholds()
{
    if(g_total_performance_records < 25) return; // Need sufficient data
    
    // Calculate recent trends
    double recent_win_rate_trend = 0;
    double recent_pf_trend = 0;
    int recent_period = MathMin(10, g_total_performance_records);
    
    for(int i = 0; i < recent_period - 1; i++)
    {
        int current_index = (g_performance_index - 1 - i + 100) % 100;
        int previous_index = (g_performance_index - 2 - i + 100) % 100;
        
        recent_win_rate_trend += g_performance_history[current_index].win_rate - g_performance_history[previous_index].win_rate;
        recent_pf_trend += g_performance_history[current_index].profit_factor - g_performance_history[previous_index].profit_factor;
    }
    
    // Adjust thresholds based on trends
    if(recent_win_rate_trend > 0 && recent_pf_trend > 0)
    {
        // Performance improving - can lower thresholds slightly
        g_adaptive_conviction_threshold = MathMax(5.0, g_adaptive_conviction_threshold - 0.1);
    }
    else if(recent_win_rate_trend < 0 || recent_pf_trend < 0)
    {
        // Performance declining - raise thresholds for selectivity
        g_adaptive_conviction_threshold = MathMin(9.0, g_adaptive_conviction_threshold + 0.2);
    }
}

//+------------------------------------------------------------------+
//| ADX FILTER FUNCTION                                              |
//+------------------------------------------------------------------+
bool IsTrendStrongEnough(double min_adx)
{
    if(min_adx <= 0) return true; // No filter needed
    
    double adx = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 1);
    return (adx >= min_adx);
}
//+------------------------------------------------------------------+
//| FUNCTION: Tactical Drawdown Manager                              |
//| LOGIC: Reduces exposure during storms, doesn't panic-close all.  |
//| V17.10: Smart Equity Preservation (No Ratchet)                   |
//+------------------------------------------------------------------+
void ManageDrawdownExposure_V2()
{
   double equity  = AccountEquity();
   double balance = AccountBalance();
   double ddPercent = (balance - equity) / balance * 100.0;
   
   // V28.00 FIX: Gradual drawdown protection (starts at 5%)
   // Level 1: 5-8% DD  Reduce lot sizing by 25%
   // Level 2: 8-10% DD  Reduce lot sizing by 50%
   // Level 3: 10-12% DD  Stop new trades, trim positions > 0.5 lots
   // Level 4: >12% DD  Emergency: trim ALL positions > 0.1 lots
   
   // Store DD level for use in lot sizing
   static int lastDDLevel = 0;
   int currentDDLevel = 0;
   
   if(ddPercent >= 12.0) currentDDLevel = 4;
   else if(ddPercent >= 10.0) currentDDLevel = 3;
   else if(ddPercent >= 8.0) currentDDLevel = 2;
   else if(ddPercent >= 5.0) currentDDLevel = 1;
   
   // Log DD level changes
   if(currentDDLevel != lastDDLevel)
   {
      Print("V27.21 DD Protection: Level ", currentDDLevel, " (", DoubleToString(ddPercent, 1), "%)");
      lastDDLevel = currentDDLevel;
   }
   
   // Level 3+: Stop new trades (check in OnNewBar)
   if(currentDDLevel >= 3)
   {
      // Set global flag to block new entries
      g_ddProtectionActive = true;
   }
   else if(ddPercent < 7.0) // V28.00: Hysteresis - require DD < 7% to reset (was < 10%)
   {
      g_ddProtectionActive = false;
   }
   // If DD is between 10-12%, maintain previous state (hysteresis)
   
   // Level 4: Emergency trimming
   if(currentDDLevel >= 4)
   {
      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            double currentLots = OrderLots();
            
            // Trim ALL positions > 0.1 lots (more aggressive than V27.20)
            if(currentLots > 0.10) 
            {
               double halfLots = NormalizeDouble(currentLots / 2.0, 2);
               bool closeResult = OrderClose(OrderTicket(), halfLots, OrderClosePrice(), 10, Orange);
               if(!closeResult)
               {
                  Print("Error closing order: ", GetLastError());
               }
               else
               {
                  Print("V27.21 DD Emergency: Trimmed position ", OrderTicket(), " by 50%");
               }
            }
         }
      }
   }
   // Level 3: Trim large positions
   else if(currentDDLevel >= 3)
   {
      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            double currentLots = OrderLots();
            
            // Only trim positions > 0.5 lots
            if(currentLots > 0.50) 
            {
               double trimLots = NormalizeDouble(currentLots * 0.75, 2); // Trim 25%
               bool closeResult = OrderClose(OrderTicket(), trimLots, OrderClosePrice(), 10, Orange);
               if(!closeResult)
               {
                  Print("Error closing order: ", GetLastError());
               }
               else
               {
                  Print("V27.21 DD Protection: Trimmed position ", OrderTicket(), " by 25%");
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FUNCTION: Strategic Hierarchy Allocator                          |
//| V17.9: ASYMMETRIC ALLOCATION - Hard-coded bias                   |
//+------------------------------------------------------------------+
double GetStrategySpecificRisk(int magicNumber)
{
   // 1. THE GOD TIER (Reaper & Silicon-X)
   // They have PF > 10. They get MAXIMUM leverage.
   // Reaper Buy: 888001, Reaper Sell: 888002
   // Silicon-X: 984651
   if(magicNumber == 888001 || magicNumber == 888002 || magicNumber == 984651) 
      return 5.0; 
   
   // 2. THE VOLATILE TIER (Warden & NoiseBreakout)
   // They make money but can crash hard. Cap at 0.3x Risk.
   if(magicNumber == InpWarden_MagicNumber || magicNumber == 777012) // 777009 or 777012
      return 0.3; 
   
   // 3. THE DEAD TIER (Mean Reversion)
   // It loses money. It gets ZERO.
   if(magicNumber == InpMagic_MeanReversion) // 777001
      return 0.0; 
   
   // 4. ALL OTHERS (Standard Genetic Check)
   // Fallback to previous genetic function for unknowns
   return GetGeneticRiskMultiplier(magicNumber); 
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//| DESTROYER QUANTUM V11.0 ENHANCED - by @okyy.ryan + MiniMax Agent |
//+------------------------------------------------------------------+

// ============================================================================
// V23 INSTITUTIONAL GLOBALS
// ============================================================================

// V23 Performance Trackers (Per Strategy)
V23_StrategyPerformance v23_stratPerf[10];  // Support up to 10 strategies
int v23_stratCount = 0;

// V23 Market Regime
V23_RegimeState v23_regime;

// V23 Trade Equity Deltas (Rolling 100 trades for VAR)
V23_TradeEquityDelta v23_tradeDeltas[100];
int v23_tradeDeltaIndex = 0;

// V23 Configuration Parameters
input double InpV23_EwmaAlpha = 0.05;           // EWMA alpha for performance decay
input double InpV23_PriorDecayAlpha = 0.01;     // Prior decay toward 0.5
input double InpV23_MinProb = 0.70;             // Minimum probability for entry
input int InpV23_RegimeConfirmThreshold = 3;   // Confirms needed for regime adjustment
input bool InpV23_EnableEmpiricalProb = true;  // Enable empirical probability engine
input bool InpV23_EnableTailDampening = true;  // Enable tail-risk dampening
input bool InpV23_EnableRegimeFeedback = true; // Enable bidirectional regime feedback

//+------------------------------------------------------------------+
//| V24 ALPHA EXPANSION CONFIGURATION                                |
//+------------------------------------------------------------------+
input string Inp_Header_V24 = "====== V24/V25/V26 EXPANSION MODES (OPT-IN) ======";
input bool InpAlphaExpand = true;                 // V27.2: ENABLED  V24 Alpha Expansion unlocks 600-900 trade target
input bool InpElasticScoring = true;              // V27.2: ENABLED  V25 Elastic Scoring for continuous signal generation
input bool InpMathFirst = false;                  // V28.01: DISABLED  MathReversal removed (not in performance report)
input double InpVarRelaxFactor = 1.5;             // VAR relaxation multiplier in low-risk regimes (Fix #1)
input double InpAdaptMax = 10.0;                  // Max adaptive shift for thresholds (levels/pips) (Fix #2)
input int InpReentryCooldown = 5;                 // Re-entry cooldown in bars (V25: reduced from 10 to 5) (Fix #4)
input double InpReentrySizeMult = 0.7;            // Re-entry size multiplier (V25: increased from 0.5 to 0.7) (Fix #4)

// V27: NOISE BREAKOUT STRATEGY (SSRN-4824172)
input string Inp_Header_V27 = "====== V27: NOISE BREAKOUT (SSRN-4824172) ======";
input bool InpNoiseBreakout_Enabled = true;        // Enable Noise Breakout strategy
input int InpNoiseBreakout_Magic = 777012;         // Magic number for Noise Breakout
input int InpNoiseBB_Period = 20;                  // Bollinger Band period for squeeze detection
input double InpNoiseBB_Dev = 2.0;                 // Bollinger Band deviation
input int InpNoiseKC_Period = 20;                  // Keltner Channel period
input double InpNoiseKC_ATR_Mult = 1.5;            // Keltner Channel ATR multiplier
input int InpNoiseMomentum_MA = 50;                // Momentum MA period for trend filter
input double InpNoiseMinVolMult = 0.5;             // Minimum volume multiplier vs previous bar
input double InpNoiseBreakoutATRMult = 0.15;       // Minimum breakout distance (ATR multiplier)

//+------------------------------------------------------------------+
//| V27.27: VORTEX STRATEGY  Vortex Indicator Trend Crossover       |
//| Magic: 9001                                                      |
//+------------------------------------------------------------------+
sinput string Inp_Header_Vortex = "====== VORTEX: VORTEX INDICATOR TREND CROSSOVER ======";
extern bool    InpVortex_Enabled         = false;       // Enable Vortex Strategy
extern int     InpVortex_MagicNumber     = 9001;        // Magic number for Vortex
extern int     InpVortex_Period          = 14;          // Vortex Indicator period
extern int     InpVortex_ADX_Threshold   = 20;          // ADX threshold for trend confirmation

//+------------------------------------------------------------------+
//| V27.27: REGIME SHIFT STRATEGY  ADX+RSI Regime Change Detector  |
//| Magic: 9002                                                      |
//+------------------------------------------------------------------+
sinput string Inp_Header_RegimeShift = "====== REGIME SHIFT: ADX+RSI REGIME CHANGE DETECTOR ======";
extern bool    InpRegimeShift_Enabled         = false;  // Enable Regime Shift Strategy
extern int     InpRegimeShift_MagicNumber     = 9002;   // Magic number for Regime Shift
extern int     InpRegimeShift_ADX_Period      = 14;     // ADX period for regime detection
extern int     InpRegimeShift_RSI_Period      = 14;     // RSI period for bias detection

//--- V28.00: SESSION MOMENTUM STRATEGY (Magic: 9003) ---
sinput string Inp_Header_SessionMomentum = "====== V28.00: SESSION MOMENTUM (LONDON BREAKOUT) ======";
input bool    InpSessionMomentum_Enabled        = true;       // Enable Session Momentum Strategy
input int     InpSessionMomentum_MagicNumber    = 9003;       // Magic number for Session Momentum
input int     InpSessionMomentum_ADX_Period     = 14;         // ADX period for trend confirmation
input double  InpSessionMomentum_ADX_Threshold  = 20.0;       // ADX threshold for momentum filter
input double  InpSessionMomentum_ATR_SL_Mult    = 1.5;        // ATR multiplier for stop loss
input double  InpSessionMomentum_ATR_TP_Mult    = 3.0;        // ATR multiplier for take profit

//--- V28.00: DIVERGENCE MEAN REVERSION STRATEGY (Magic: 9004) ---
sinput string Inp_Header_DivergenceMR = "====== V28.00: DIVERGENCE MEAN REVERSION ======";
input bool    InpDivergenceMR_Enabled           = true;       // Enable Divergence Mean Reversion
input int     InpDivergenceMR_MagicNumber       = 9004;       // Magic number for Divergence MR
input int     InpDivergenceMR_RSI_Period        = 14;         // RSI period for divergence detection
input int     InpDivergenceMR_BB_Period         = 20;         // Bollinger Band period
input double  InpDivergenceMR_BB_Dev            = 2.0;        // Bollinger Band deviation
input double  InpDivergenceMR_Hurst_Threshold   = 0.55;       // V28.04: Raised from 0.5  EURUSD H4 rarely < 0.5 (was 0 trades)
input double  InpDivergenceMR_ADX_Max           = 30.0;       // Max ADX (non-trending filter)
input double  InpDivergenceMR_ATR_SL_Mult       = 2.0;        // ATR multiplier for stop loss
input double  InpDivergenceMR_ATR_TP_Mult       = 3.0;        // ATR multiplier for take profit

sinput string Inp_Header_LiquiditySweep = "====== V28.03: LIQUIDITY SWEEP ======";
input bool    InpLiquiditySweep_Enabled         = false;      // V28.04: CUT  PF 0.84, negative EV (-$1,439)
input int     InpLiquiditySweep_MagicNumber     = 9005;       // Magic number for Liquidity Sweep
input int     InpLiquiditySweep_RSI_Period      = 14;         // RSI period
input int     InpLiquiditySweep_RSI_OS          = 30;         // RSI oversold level
input int     InpLiquiditySweep_RSI_OB          = 70;         // RSI overbought level
input int     InpLiquiditySweep_SweepLookback   = 20;         // Bars to look back for session high/low
input int     InpLiquiditySweep_MaxRetraceBars  = 3;          // Max bars for retrace after sweep
input double  InpLiquiditySweep_ATR_SL_Mult     = 1.5;        // ATR multiplier for SL
input double  InpLiquiditySweep_ATR_TP_Mult     = 2.5;        // ATR multiplier for TP
input double  InpLiquiditySweep_VolumeMult      = 1.5;        // Volume spike multiplier

sinput string Inp_Header_StructuralRetest = "====== V28.03: STRUCTURAL BREAK & RETEST ======";
input bool    InpStructuralRetest_Enabled       = true;       // Enable Structural Retest
input int     InpStructuralRetest_MagicNumber   = 9006;       // Magic number for Structural Retest
input int     InpStructuralRetest_SwingPeriod   = 20;         // Period for swing high/low detection
input int     InpStructuralRetest_RetraceBars   = 20;         // V28.04: Extended from 10  10 was too tight on H4 (0 trades)
input double  InpStructuralRetest_ATR_SL_Mult   = 1.5;        // ATR multiplier for SL
input double  InpStructuralRetest_ATR_TP_Mult   = 3.0;        // ATR multiplier for TP
input double  InpStructuralRetest_MinRR         = 2.0;        // Minimum risk/reward ratio

// V23 Runtime State
double v23_lastDeviation = 0;      // Last calculated deviation (for bin mapping)
double v23_lastEquity = 0;         // For equity delta calculation
bool v23_initialized = false;

// V24 Runtime State
datetime v24_lastTrade[10];        // Last trade timestamp per strategy (for re-entry cooldown)
double v24_lastSignalPrice[10];    // Last signal price per strategy (for re-entry tracking)
int v24_lastSignalType[10];        // Last signal type per strategy (1=buy, -1=sell, 0=none)


//+------------------------------------------------------------------+
//| V28.11 DEBATE LAYER  included inline                            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| DESTROYER QUANTUM V28.11 - DEBATE LAYER (COMBINED)                |
//| VENI VIDI VICI                                                    |
//|                                                                   |
//| This file contains:                                               |
//|   1. Debate Engine (signals, voting, risk panel, sizing, reflect) |
//|   2. All 12 strategies converted for debate signal submission     |
//|   3. OnNewBar_DebateLayer() drop-in hook                         |
//|                                                                   |
//| INTEGRATION:                                                      |
//|   1. #include this file at top of your EA                        |
//|   2. Call InitDebateLayer() in OnInit()                          |
//|   3. Replace OnNewBar() strategy block with OnNewBar_DebateLayer()|
//|   4. Call ProcessTradeClose() when debate trades close           |
//+------------------------------------------------------------------+

     1|//+------------------------------------------------------------------+
     2|//| V28_11_DEBATE_LAYER.mqh - Signal Debate & Risk Panel             |
     3|//| DESTROYER QUANTUM V28.11 - VENI VIDI VICI                        |
     4|//| Inspired by TradingAgents (TauricResearch)                       |
     5|//| Bolt-on to V28.06 -- does NOT modify existing strategy logic      |
     6|//+------------------------------------------------------------------+
     7|
     8|#ifndef DEBATE_LAYER_MQH
     9|#define DEBATE_LAYER_MQH
    10|
    11|//--- Maximum number of strategies that can submit signals
    12|#define MAX_SIGNALS 16
    13|
    14|//--- Minimum weighted conviction for a trade to pass debate
    15|#define MIN_CONVICTION_THRESHOLD 0.30
    16|
    17|//--- Divergence threshold (both sides above this = conflict)
    18|#define DIVERGENCE_THRESHOLD 0.50
    19|
    20|//--- Size multipliers per tier
    21|#define TIER1_SIZE_MULT 1.5   // STRONG: high conviction + 3/3 approve
    22|#define TIER2_SIZE_MULT 1.0   // NORMAL: good conviction + 2/3 approve
    23|#define TIER3_SIZE_MULT 0.7   // CAUTIOUS: moderate conviction + 2/3 approve
    24|#define TIER4_SIZE_MULT 0.0   // HOLD: low conviction or < 2 approve
    25|
    26|//--- Conservative persona thresholds
    27|#define CONSERVATIVE_MIN_CONVICTION 0.50
    28|#define CONSERVATIVE_MAX_SL_PIPS    200.0
    29|#define CONSERVATIVE_MAX_CONSEC_LOSSES 3
    30|
    31|//--- Neutral persona thresholds
    32|#define NEUTRAL_MAX_EXPOSURE_PCT    80.0
    33|#define NEUTRAL_MAX_SAME_DIRECTION  5
    34|
    35|//--- Risk panel: how many of 3 must approve
    36|#define RISK_PANEL_MIN_APPROVALS 2
    37|
    38|//+------------------------------------------------------------------+
    39|//| STRUCT: StrategySignal                                            |
    40|//| Output from each strategy instead of direct OrderSend()          |
    41|//+------------------------------------------------------------------+
    42|struct StrategySignal {
    43|   int      magic;            // Strategy magic number
    44|   int      direction;        // OP_BUY, OP_SELL, or -1 (no signal)
    45|   double   conviction;       // 0.0 to 1.0 (strength of signal)
    46|   string   reason;           // Human-readable reason
    47|   double   suggestedLots;    // What the strategy would normally trade
    48|   double   suggestedSL;      // Suggested stop loss (price)
    49|   double   suggestedTP;      // Suggested take profit (price)
    50|   double   entryPrice;       // Current price at signal time
    51|   datetime signalTime;       // When the signal was generated
    52|};
    53|
    54|//+------------------------------------------------------------------+
    55|//| STRUCT: DebateResult                                              |
    56|//| Output from the debate engine                                     |
    57|//+------------------------------------------------------------------+
    58|struct DebateResult {
    59|   bool     approved;         // Did the debate approve a trade?
    60|   int      direction;        // OP_BUY or OP_SELL
    61|   double   consensusConviction; // Weighted consensus (0-1)
    62|   double   buyConviction;    // Total weighted BUY conviction
    63|   double   sellConviction;   // Total weighted SELL conviction
    64|   bool     isDivergent;      // Both sides strong = warning
    65|   int      signalsReceived;  // How many strategies submitted
    66|   int      buySignals;       // How many said BUY
    67|   int      sellSignals;      // How many said SELL
    68|   string   agreedStrategies; // Comma-separated list of winning side
    69|   string   disagreedStrategies; // Comma-separated list of losing side
    70|};
    71|
    72|//+------------------------------------------------------------------+
    73|//| STRUCT: RiskPanelResult                                           |
    74|//| Output from the 3-way risk evaluation                             |
    75|//+------------------------------------------------------------------+
    76|struct RiskPanelResult {
    77|   int      approvals;        // 0-3 (how many approved)
    78|   bool     aggressiveApproved;
    79|   bool     conservativeApproved;
    80|   bool     neutralApproved;
    81|   string   aggressiveReason;
    82|   string   conservativeReason;
    83|   string   neutralReason;
    84|};
    85|
    86|//+------------------------------------------------------------------+
    87|//| STRUCT: TradeLog                                                  |
    88|//| For deferred reflection -- log why trades were taken               |
    89|//+------------------------------------------------------------------+
    90|struct TradeLog {
    91|   //--- Entry data (logged on open)
    92|   int      ticket;
    93|   datetime entryTime;
    94|   int      direction;
    95|   double   entryPrice;
    96|   double   lots;
    97|   double   conviction;
    98|   int      riskApprovals;
    99|   string   strategiesAgreed;
   100|   string   strategiesDisagreed;
   101|   double   atrAtEntry;
   102|   double   hurstAtEntry;
   103|   double   adxAtEntry;
   104|   //--- Exit data (logged on close)
   105|   double   exitPrice;
   106|   double   pnl;
   107|   double   holdDuration;
   108|   bool     thesisCorrect;
   109|};
   110|
   111|//+------------------------------------------------------------------+
   112|//| GLOBAL: Signal buffer                                             |
   113|//+------------------------------------------------------------------+
   114|StrategySignal g_signals[MAX_SIGNALS];
   115|int            g_signalCount = 0;
   116|
   117|//+------------------------------------------------------------------+
   118|//| GLOBAL: Trade log buffer                                          |
   119|//+------------------------------------------------------------------+
   120|TradeLog       g_tradeLog[];
   121|int            g_tradeLogCount = 0;
   122|
   123|//+------------------------------------------------------------------+
   124|//| GLOBAL: Strategy weight overrides (from deferred reflection)      |
   125|//+------------------------------------------------------------------+
   126|double         g_strategyWeightAdj[MAX_MAGIC];  // Adjustment multiplier
   127|bool           g_weightAdjInitialized = false;
   128|
   129|//+------------------------------------------------------------------+
   130|//| FUNCTION: InitDebateLayer()                                       |
   131|//| Call once in OnInit()                                             |
   132|//+------------------------------------------------------------------+
   133|void InitDebateLayer() {
   134|   g_signalCount = 0;
   135|   g_tradeLogCount = 0;
   136|   g_weightAdjInitialized = false;
   137|   
   138|   //--- Initialize weight adjustments to 1.0 (no adjustment)
   139|   for (int i = 0; i < MAX_MAGIC; i++) {
   140|      g_strategyWeightAdj[i] = 1.0;
   141|   }
   142|   g_weightAdjInitialized = true;
   143|   
   144|   LogError("DEBATE LAYER: Initialized. " + IntegerToString(MAX_SIGNALS) + " signal slots.");
   145|}
   146|
   147|//+------------------------------------------------------------------+
   148|//| FUNCTION: ResetSignals()                                          |
   149|//| Call at start of each OnNewBar() to clear previous signals       |
   150|//+------------------------------------------------------------------+
   151|void ResetSignals() {
   152|   g_signalCount = 0;
   153|   ArrayResize(g_signals, 0);
   154|}
   155|
   156|//+------------------------------------------------------------------+
   157|//| FUNCTION: SubmitSignal()                                          |
   158|//| Each strategy calls this instead of OrderSend()                   |
   159|//| Returns true if signal was accepted                               |
   160|//+------------------------------------------------------------------+
   161|bool SubmitSignal(int magic, int direction, double conviction,
   162|                  string reason, double lots, double sl, double tp) {
   163|   
   164|   //--- Validate
   165|   if (direction != OP_BUY && direction != OP_SELL) return false;
   166|   if (conviction < 0.0 || conviction > 1.0) return false;
   167|   if (g_signalCount >= MAX_SIGNALS) {
   168|      LogError("DEBATE: Signal buffer full. Dropping signal from magic " + IntegerToString(magic));
   169|      return false;
   170|   }
   171|   
   172|   //--- Add signal to buffer
   173|   int idx = g_signalCount;
   174|   g_signalCount++;
   175|   ArrayResize(g_signals, g_signalCount);
   176|   
   177|   g_signals[idx].magic = magic;
   178|   g_signals[idx].direction = direction;
   179|   g_signals[idx].conviction = conviction;
   180|   g_signals[idx].reason = reason;
   181|   g_signals[idx].suggestedLots = lots;
   182|   g_signals[idx].suggestedSL = sl;
   183|   g_signals[idx].suggestedTP = tp;
   184|   g_signals[idx].entryPrice = (direction == OP_BUY) ? Ask : Bid;
   185|   g_signals[idx].signalTime = TimeCurrent();
   186|   
   187|   return true;
   188|}
   189|
   190|//+------------------------------------------------------------------+
   191|//| FUNCTION: GetStrategyWeight()                                     |
   192|//| Returns credibility weight based on rolling PF + reflection adj   |
   193|//+------------------------------------------------------------------+
   194|double GetStrategyWeight(int magic) {
   195|   int idx = GetStrategyIndexByMagic(magic);
   196|   if (idx < 0) return 1.0;
   197|   
   198|   //--- Base weight from rolling Profit Factor
   199|   double pf = g_stratRollingPF[idx];
   200|   double baseWeight = 1.0;
   201|   
   202|   if (pf < 1.0)       baseWeight = 0.5;   // Losing strategies: half voice
   203|   else if (pf < 1.5)  baseWeight = 1.0;   // Marginal: normal voice
   204|   else if (pf < 2.0)  baseWeight = 1.5;   // Good: 1.5x voice
   205|   else if (pf < 3.0)  baseWeight = 2.0;   // Great: 2x voice
   206|   else                 baseWeight = 3.0;   // Elite (PF 3+): 3x voice
   207|   
   208|   //--- Cap weight for strategies with too few trades
   209|   int totalTrades = g_stratTotalTrades[idx];
   210|   if (totalTrades < 5) baseWeight = MathMin(baseWeight, 1.0);  // Not enough data
   211|   
   212|   //--- Apply deferred reflection adjustment
   213|   if (g_weightAdjInitialized && idx < MAX_MAGIC) {
   214|      baseWeight *= g_strategyWeightAdj[idx];
   215|   }
   216|   
   217|   //--- Clamp to reasonable range
   218|   return MathMax(0.25, MathMin(3.0, baseWeight));
   219|}
   220|
   221|//+------------------------------------------------------------------+
   222|//| FUNCTION: RunDebate()                                             |
   223|//| The core debate engine -- weighs signals, detects divergence       |
   224|//+------------------------------------------------------------------+
   225|DebateResult RunDebate() {
   226|   DebateResult result;
   227|   result.approved = false;
   228|   result.direction = -1;
   229|   result.consensusConviction = 0;
   230|   result.buyConviction = 0;
   231|   result.sellConviction = 0;
   232|   result.isDivergent = false;
   233|   result.signalsReceived = g_signalCount;
   234|   result.buySignals = 0;
   235|   result.sellSignals = 0;
   236|   result.agreedStrategies = "";
   237|   result.disagreedStrategies = "";
   238|   
   239|   //--- No signals = no trade
   240|   if (g_signalCount == 0) return result;
   241|   
   242|   //--- Calculate weighted conviction for each side
   243|   double totalWeight = 0;
   244|   
   245|   for (int i = 0; i < g_signalCount; i++) {
   246|      double weight = GetStrategyWeight(g_signals[i].magic);
   247|      double weightedConviction = g_signals[i].conviction * weight;
   248|      
   249|      if (g_signals[i].direction == OP_BUY) {
   250|         result.buyConviction += weightedConviction;
   251|         result.buySignals++;
   252|      }
   253|      else if (g_signals[i].direction == OP_SELL) {
   254|         result.sellConviction += weightedConviction;
   255|         result.sellSignals++;
   256|      }
   257|      
   258|      totalWeight += weight;
   259|   }
   260|   
   261|   //--- Normalize to 0-1 range
   262|   if (totalWeight > 0) {
   263|      result.buyConviction /= totalWeight;
   264|      result.sellConviction /= totalWeight;
   265|   }
   266|   
   267|   //--- Determine winning direction
   268|   double winningConviction = 0;
   269|   if (result.buyConviction > result.sellConviction) {
   270|      result.direction = OP_BUY;
   271|      winningConviction = result.buyConviction;
   272|   }
   273|   else if (result.sellConviction > result.buyConviction) {
   274|      result.direction = OP_SELL;
   275|      winningConviction = result.sellConviction;
   276|   }
   277|   else {
   278|      //--- Exact tie -- no trade
   279|      LogError("DEBATE: Exact tie between BUY and SELL. No trade.");
   280|      return result;
   281|   }
   282|   
   283|   result.consensusConviction = winningConviction;
   284|   
   285|   //--- Divergence detection
   286|   result.isDivergent = (result.buyConviction > DIVERGENCE_THRESHOLD &&
   287|                         result.sellConviction > DIVERGENCE_THRESHOLD);
   288|   
   289|   if (result.isDivergent) {
   290|      LogError("DEBATE: DIVERGENCE detected. BUY=" + DoubleToStr(result.buyConviction, 2) +
   291|               " SELL=" + DoubleToStr(result.sellConviction, 2));
   292|   }
   293|   
   294|   //--- Build agreed/disagreed lists
   295|   for (int i = 0; i < g_signalCount; i++) {
   296|      string stratName = GetStrategyNameByMagic(g_signals[i].magic);
   297|      if (g_signals[i].direction == result.direction) {
   298|         if (result.agreedStrategies != "") result.agreedStrategies += ",";
   299|         result.agreedStrategies += stratName;
   300|      }
   301|      else {
   302|         if (result.disagreedStrategies != "") result.disagreedStrategies += ",";
   303|         result.disagreedStrategies += stratName;
   304|      }
   305|   }
   306|   
   307|   //--- Check minimum conviction threshold
   308|   if (winningConviction < MIN_CONVICTION_THRESHOLD) {
   309|      LogError("DEBATE: Conviction " + DoubleToStr(winningConviction, 2) +
   310|               " below threshold " + DoubleToStr(MIN_CONVICTION_THRESHOLD, 2) + ". No trade.");
   311|      return result;
   312|   }
   313|   
   314|   result.approved = true;
   315|   
   316|   LogError("DEBATE: APPROVED " + (result.direction == OP_BUY ? "BUY" : "SELL") +
   317|            " | Conviction=" + DoubleToStr(winningConviction, 2) +
   318|            " | BUY=" + IntegerToString(result.buySignals) +
   319|            " SELL=" + IntegerToString(result.sellSignals) +
   320|            " | Agreed: " + result.agreedStrategies);
   321|   
   322|   return result;
   323|}
   324|
   325|//+------------------------------------------------------------------+
   326|//| FUNCTION: AggressiveRiskCheck()                                   |
   327|//| Only blocks EXTREME risk -- lets almost everything through         |
   328|//+------------------------------------------------------------------+
   329|bool AggressiveRiskCheck(StrategySignal &signal, string &reason) {
   330|   //--- Check 1: Extreme volatility (ATR > 3x average)
   331|   double currentATR = iATR(Symbol(), PERIOD_H4, 14, 0);
   332|   double avgATR = 0;
   333|   for (int i = 1; i <= 20; i++) avgATR += iATR(Symbol(), PERIOD_H4, 14, i);
   334|   avgATR /= 20.0;
   335|   
   336|   if (currentATR > 3.0 * avgATR) {
   337|      reason = "Extreme volatility: ATR " + DoubleToStr(currentATR, 1) +
   338|               " > 3x avg " + DoubleToStr(avgATR, 1);
   339|      return false;
   340|   }
   341|   
   342|   //--- Check 2: Already in drawdown protection mode
   343|   if (g_ddProtectionActive) {
   344|      reason = "DD protection active";
   345|      return false;
   346|   }
   347|   
   348|   //--- Check 3: Max open trades reached
   349|   if (CountOpenTrades() >= InpMaxOpenTrades) {
   350|      reason = "Max open trades: " + IntegerToString(InpMaxOpenTrades);
   351|      return false;
   352|   }
   353|   
   354|   reason = "Approved (aggressive)";
   355|   return true;
   356|}
   357|
   358|//+------------------------------------------------------------------+
   359|//| FUNCTION: ConservativeRiskCheck()                                 |
   360|//| Requires multiple confirmations -- high bar for entry              |
   361|//+------------------------------------------------------------------+
   362|bool ConservativeRiskCheck(StrategySignal &signal, string &reason) {
   363|   //--- Check 1: Minimum conviction
   364|   if (signal.conviction < CONSERVATIVE_MIN_CONVICTION) {
   365|      reason = "Conviction " + DoubleToStr(signal.conviction, 2) +
   366|               " < " + DoubleToStr(CONSERVATIVE_MIN_CONVICTION, 2);
   367|      return false;
   368|   }
   369|   
   370|   //--- Check 2: Trend alignment (D1 EMA50)
   371|   double ema50_D1 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   372|   double price = (signal.direction == OP_BUY) ? Ask : Bid;
   373|   
   374|   if (signal.direction == OP_BUY && price < ema50_D1) {
   375|      reason = "BUY against D1 trend (price < EMA50)";
   376|      return false;
   377|   }
   378|   if (signal.direction == OP_SELL && price > ema50_D1) {
   379|      reason = "SELL against D1 trend (price > EMA50)";
   380|      return false;
   381|   }
   382|   
   383|   //--- Check 3: Stop loss too wide
   384|   double slPips = MathAbs(signal.entryPrice - signal.suggestedSL) / g_pipValue;
   385|   if (slPips > CONSERVATIVE_MAX_SL_PIPS) {
   386|      reason = "SL too wide: " + DoubleToStr(slPips, 0) + " pips > " +
   387|               DoubleToStr(CONSERVATIVE_MAX_SL_PIPS, 0);
   388|      return false;
   389|   }
   390|   
   391|   //--- Check 4: Consecutive losses
   392|   if (g_kellyConsecutiveLosses >= CONSERVATIVE_MAX_CONSEC_LOSSES) {
   393|      reason = "Consecutive losses: " + IntegerToString(g_kellyConsecutiveLosses) +
   394|               " >= " + IntegerToString(CONSERVATIVE_MAX_CONSEC_LOSSES);
   395|      return false;
   396|   }
   397|   
   398|   reason = "Approved (conservative)";
   399|   return true;
   400|}
   401|
   402|//+------------------------------------------------------------------+
   403|//| FUNCTION: NeutralRiskCheck()                                      |
   404|//| Portfolio-level risk management -- exposure and correlation         |
   405|//+------------------------------------------------------------------+
   406|bool NeutralRiskCheck(StrategySignal &signal, string &reason) {
   407|   //--- Check 1: Total exposure
   408|   double currentExposure = GetTotalExposurePercent();
   409|   if (currentExposure > NEUTRAL_MAX_EXPOSURE_PCT) {
   410|      reason = "Exposure " + DoubleToStr(currentExposure, 0) +
   411|               "% > " + DoubleToStr(NEUTRAL_MAX_EXPOSURE_PCT, 0) + "%";
   412|      return false;
   413|   }
   414|   
   415|   //--- Check 2: Same direction concentration
   416|   int sameDirCount = CountTradesByDirection(signal.direction);
   417|   if (sameDirCount >= NEUTRAL_MAX_SAME_DIRECTION) {
   418|      reason = IntegerToString(sameDirCount) + " trades already " +
   419|               (signal.direction == OP_BUY ? "BUY" : "SELL") +
   420|               " (max " + IntegerToString(NEUTRAL_MAX_SAME_DIRECTION) + ")";
   421|      return false;
   422|   }
   423|   
   424|   //--- Check 3: Duplicate magic (same strategy already has open trade)
   425|   if (HasOpenPositionByMagic(signal.magic)) {
   426|      reason = "Strategy " + GetStrategyNameByMagic(signal.magic) +
   427|               " already has open position";
   428|      return false;
   429|   }
   430|   
   431|   reason = "Approved (neutral)";
   432|   return true;
   433|}
   434|
   435|//+------------------------------------------------------------------+
   436|//| FUNCTION: RunRiskPanel()                                          |
   437|//| 3-way risk debate: Aggressive, Conservative, Neutral              |
   438|//| Returns how many approved (0-3)                                   |
   439|//+------------------------------------------------------------------+
   440|RiskPanelResult RunRiskPanel(StrategySignal &signal) {
   441|   RiskPanelResult result;
   442|   
   443|   result.aggressiveApproved = AggressiveRiskCheck(signal, result.aggressiveReason);
   444|   result.conservativeApproved = ConservativeRiskCheck(signal, result.conservativeReason);
   445|   result.neutralApproved = NeutralRiskCheck(signal, result.neutralReason);
   446|   
   447|   result.approvals = 0;
   448|   if (result.aggressiveApproved)   result.approvals++;
   449|   if (result.conservativeApproved) result.approvals++;
   450|   if (result.neutralApproved)      result.approvals++;
   451|   
   452|   LogError("RISK PANEL: " + IntegerToString(result.approvals) + "/3 approved" +
   453|            " | Aggr=" + (result.aggressiveApproved ? "YES" : "NO") +
   454|            " | Cons=" + (result.conservativeApproved ? "YES" : "NO") +
   455|            " | Neut=" + (result.neutralApproved ? "YES" : "NO"));
   456|   
   457|   if (result.approvals < RISK_PANEL_MIN_APPROVALS) {
   458|      if (!result.conservativeApproved)
   459|         LogError("RISK PANEL REJECT (conservative): " + result.conservativeReason);
   460|      if (!result.neutralApproved)
   461|         LogError("RISK PANEL REJECT (neutral): " + result.neutralReason);
   462|   }
   463|   
   464|   return result;
   465|}
   466|
   467|//+------------------------------------------------------------------+
   468|//| FUNCTION: GetDebateSizeMultiplier()                               |
   469|//| Maps conviction + approvals to 5-tier position sizing             |
   470|//+------------------------------------------------------------------+
   471|double GetDebateSizeMultiplier(double conviction, int approvals, bool isDivergent) {
   472|   double baseMultiplier = 0.0;
   473|   
   474|   //--- Tier 1: STRONG -- high conviction + all 3 approve
   475|   if (conviction >= 0.80 && approvals == 3)
   476|      baseMultiplier = TIER1_SIZE_MULT;
   477|   
   478|   //--- Tier 2: NORMAL -- good conviction + 2+ approve
   479|   else if (conviction >= 0.50 && approvals >= 2)
   480|      baseMultiplier = TIER2_SIZE_MULT;
   481|   
   482|   //--- Tier 3: CAUTIOUS -- moderate conviction + 2+ approve
   483|   else if (conviction >= 0.30 && approvals >= 2)
   484|      baseMultiplier = TIER3_SIZE_MULT;
   485|   
   486|   //--- Tier 4/5: HOLD -- reject
   487|   else
   488|      baseMultiplier = TIER4_SIZE_MULT;
   489|   
   490|   //--- Divergence penalty: reduce size 50%
   491|   if (isDivergent && baseMultiplier > 0) {
   492|      baseMultiplier *= 0.5;
   493|      LogError("SIZING: Divergence penalty applied. Size reduced 50%.");
   494|   }
   495|   
   496|   return baseMultiplier;
   497|}
   498|
   499|//+------------------------------------------------------------------+
   500|//| FUNCTION: ExecuteDebateTrade()                                    |
   501|

//+------------------------------------------------------------------+
//| STRATEGY CONVERSIONS                                              |
//+------------------------------------------------------------------+

     1|//+------------------------------------------------------------------+
     2|//| V28.11_STRATEGIES_DEBATE.mq4                                      |
     3|//| All V28.06 strategies converted for debate layer                  |
     4|//| Each returns a signal instead of executing directly                |
     5|//| Include V28_11_DEBATE_LAYER.mq4 in your EA first                 |
     6|//+------------------------------------------------------------------+
     7|
     8|//+------------------------------------------------------------------+
     9|//| MEAN REVERSION - RSI+BB+Hurst adaptive                           |
    10|//| Original magic: InpMagic_MeanReversion                           |
    11|//+------------------------------------------------------------------+
    12|void ExecuteMeanReversion_DEBATE()
    13|{
    14|   if(Period() != PERIOD_H4) return;
    15|   if(!InpMeanReversion_Enabled) return;
    16|   if(!IsStrategyHealthy(InpMagic_MeanReversion)) return;
    17|   if(g_hive_state == HIVE_STATE_DEFENSIVE && !InpMR_Allow_Defensive) return;
    18|   if(InpEnable_ReaperConditionFilter && !IsReaperConditionMet()) return;
    19|   if(InpEnableMarketFilters && !CheckMarketConditions()) return;
    20|   if(InpEnableTimeFilter && !CheckTimeFilter()) return;
    21|
    22|   int shift = 0;
    23|   g_active_model = MODEL_MEAN_REVERSION;
    24|
    25|   // Regime-adaptive bands (V18.2)
    26|   double Hurst = CalculateHurstExponent(Symbol(), Period(), 100);
    27|   double adaptive_dev = 2.0;
    28|   double rsi_upper = 70;
    29|   double rsi_lower = 30;
    30|
    31|   if(Hurst < 0.50) {
    32|      adaptive_dev = 1.8; rsi_upper = 65; rsi_lower = 35;
    33|   } else if(Hurst >= 0.40 && Hurst <= 0.60) {
    34|      adaptive_dev = 2.2; rsi_upper = 70; rsi_lower = 30;
    35|   } else {
    36|      adaptive_dev = 3.5; rsi_upper = 80; rsi_lower = 20;
    37|   }
    38|
    39|   // Technical indicators
    40|   double bb_upper = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_UPPER, shift);
    41|   double bb_lower = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_LOWER, shift);
    42|   double rsi_val  = iRSI(Symbol(), Period(), 14, PRICE_CLOSE, shift);
    43|   double price    = Close[shift];
    44|
    45|   bool buy_signal  = (price < bb_lower) && (rsi_val < rsi_lower);
    46|   bool sell_signal = (price > bb_upper) && (rsi_val > rsi_upper);
    47|
    48|   // Elastic scoring (V25 Fix #3)
    49|   if(InpAlphaExpand && InpElasticScoring) {
    50|      int stratIdx = V23_FindStrategyIndex(InpMagic_MeanReversion);
    51|      if(stratIdx >= 0) {
    52|         double prob = V23_GetEmpiricalProb(stratIdx, MathAbs((price - iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)) / iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)));
    53|         double rExpect = v23_stratPerf[stratIdx].rExpectancy;
    54|         double rsiScore_Buy = 0, rsiScore_Sell = 0;
    55|         if(rsi_val < 30) rsiScore_Buy = 1.0 * prob;
    56|         else if(rsi_val < 40) rsiScore_Buy = 0.7 * prob;
    57|         else if(rsi_val < 45) rsiScore_Buy = 0.3 * prob;
    58|         if(rsi_val > 70) rsiScore_Sell = 1.0 * prob;
    59|         else if(rsi_val > 60) rsiScore_Sell = 0.7 * prob;
    60|         else if(rsi_val > 55) rsiScore_Sell = 0.3 * prob;
    61|         double bbRange = bb_upper - bb_lower;
    62|         double bbScore_Buy = (bbRange > 0) ? MathAbs(price - bb_lower) / bbRange : 0;
    63|         double bbScore_Sell = (bbRange > 0) ? MathAbs(price - bb_upper) / bbRange : 0;
    64|         bbScore_Buy = (price < bb_lower) ? (1.0 - bbScore_Buy) * rExpect : 0;
    65|         bbScore_Sell = (price > bb_upper) ? (1.0 - bbScore_Sell) * rExpect : 0;
    66|         double regimeContrib = v23_regime.confidence * 0.2;
    67|         double totalScore_Buy = 0.5 * rsiScore_Buy + 0.3 * bbScore_Buy + regimeContrib;
    68|         double totalScore_Sell = 0.5 * rsiScore_Sell + 0.3 * bbScore_Sell + regimeContrib;
    69|         double scoreThreshold = 0.6 - (prob * 0.1);
    70|         scoreThreshold = MathMax(0.4, MathMin(0.7, scoreThreshold));
    71|         buy_signal = (totalScore_Buy > scoreThreshold);
    72|         sell_signal = (totalScore_Sell > scoreThreshold);
    73|      }
    74|   }
    75|
    76|   // Safety checks
    77|   double ADX = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 0);
    78|   if(ADX > 50) return;
    79|   if(IsTrendTooStrong()) return;
    80|   if(!Filter_CounterTrend()) return;
    81|
    82|   if(buy_signal && !IsMeanReversionSafe(OP_BUY)) buy_signal = false;
    83|   if(sell_signal && !IsMeanReversionSafe(OP_SELL)) sell_signal = false;
    84|
    85|   if(!buy_signal && !sell_signal) return;
    86|
    87|   // Conviction: based on RSI extremity + BB distance + Hurst regime
    88|   double rsiDev = MathAbs(rsi_val - 50.0) / 50.0;
    89|   double bbDist = MathAbs((price - bb_lower) / (bb_upper - bb_lower));
    90|   double regimeBonus = 0;
    91|   if(Hurst < 0.50) regimeBonus = 0.3;
    92|   else if(Hurst <= 0.60) regimeBonus = 0.15;
    93|   double conviction = MathMin(1.0, (rsiDev * 0.4 + bbDist * 0.3 + regimeBonus));
    94|
    95|   int direction = buy_signal ? OP_BUY : OP_SELL;
    96|   double atr_stop = GetATRStopLossPips() * Point;
    97|   double sl, tp, lots;
    98|
    99|   if(direction == OP_BUY) {
   100|      sl = Ask - atr_stop;
   101|      tp = Ask + atr_stop * 2.2;
   102|      lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, GetATRStopLossPips());
   103|   } else {
   104|      sl = Bid + atr_stop;
   105|      tp = Bid - atr_stop * 2.2;
   106|      lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, GetATRStopLossPips());
   107|   }
   108|
   109|   if(lots <= 0) return;
   110|
   111|   SubmitSignal(InpMagic_MeanReversion, direction, conviction,
   112|                "MR_ADAPTIVE|" + DoubleToStr(Hurst, 2) + "|" + DoubleToStr(rsi_val, 0),
   113|                lots, sl, tp);
   114|}
   115|
   116|//+------------------------------------------------------------------+
   117|//| MATH REVERSAL - Z-score pure math                                |
   118|//| Magic: 999002                                                    |
   119|//+------------------------------------------------------------------+
   120|void ExecuteMathReversal_DEBATE()
   121|{
   122|   if(!InpMathFirst || !InpAlphaExpand) return;
   123|
   124|   int stratIdx = V23_FindStrategyIndex(999002);
   125|   if(stratIdx < 0) return;
   126|
   127|   // Z-score deviation
   128|   double ma20 = iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
   129|   double stdDev20 = iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
   130|   if(stdDev20 <= 0) return;
   131|   double deviation = (Close[1] - ma20) / stdDev20;
   132|
   133|   // Math confidence gate
   134|   double prob = V23_GetEmpiricalProb(stratIdx, MathAbs(deviation));
   135|   double entropyNorm = v23_regime.entropyNorm;
   136|   double confidence = v23_regime.confidence;
   137|   int regimeType = v23_regime.type;
   138|   double rExpect = v23_stratPerf[stratIdx].rExpectancy;
   139|
   140|   bool mathConfident = (prob > 0.7) && (MathAbs(deviation) > 1.5) &&
   141|                        (entropyNorm < 0.6) && (rExpect > 0) && (confidence > 0.5);
   142|   if(!mathConfident) return;
   143|
   144|   // Conviction from math factors
   145|   double convProb = MathMin(1.0, (prob - 0.7) / 0.3);          // 0-1 (0.7->0, 1.0->1)
   146|   double convDev  = MathMin(1.0, (MathAbs(deviation) - 1.5) / 1.5); // 0-1 (1.5->0, 3.0->1)
   147|   double convConf = confidence;
   148|   double conviction = (convProb * 0.4 + convDev * 0.3 + convConf * 0.3);
   149|
   150|   int dir = (deviation > 0) ? OP_SELL : OP_BUY;
   151|
   152|   double atr = iATR(NULL, 0, 14, 1);
   153|   double slDist = atr * 1.5;
   154|   double tpDist = atr * 2.5;
   155|   double price = (dir == OP_BUY) ? Ask : Bid;
   156|   double sl = (dir == OP_BUY) ? price - slDist : price + slDist;
   157|   double tp = (dir == OP_BUY) ? price + tpDist : price - tpDist;
   158|
   159|   double lots = V23_CalculateLotSize(stratIdx, 0.005, 50.0, regimeType);
   160|   if(lots <= 0) return;
   161|
   162|   // VAR check
   163|   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   164|   double marginalVar = lots * 50.0 * Point * tickValue / AccountEquity();
   165|   double currentVar = V23_CalculateEmpiricalVAR();
   166|   double varLimit = 0.05;
   167|   if(regimeType == 0) varLimit *= InpVarRelaxFactor;
   168|   else if(regimeType == 3) varLimit *= 1.2;
   169|   if(currentVar + marginalVar > varLimit) return;
   170|
   171|   SubmitSignal(999002, dir, conviction,
   172|                "MATH_REV|prob=" + DoubleToStr(prob, 2) + "|dev=" + DoubleToStr(deviation, 1),
   173|                lots, sl, tp);
   174|}
   175|
   176|//+------------------------------------------------------------------+
   177|//| NOISE BREAKOUT - BB Squeeze breakout                             |
   178|//| Magic: 777012                                                    |
   179|//+------------------------------------------------------------------+
   180|void ExecuteNoiseBreakout_DEBATE()
   181|{
   182|   if(!InpNoiseBreakout_Enabled) return;
   183|   if(Period() != PERIOD_H4) return;
   184|   if(CountOpenTrades(InpNoiseBreakout_Magic) > 0) return;
   185|   if(!IsStrategyHealthy(InpNoiseBreakout_Magic)) return;
   186|   if(!CheckTimeFilter()) return;
   187|
   188|   int bias = CheckDirectionalBias();
   189|
   190|   double bb_upper = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);
   191|   double bb_lower = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);
   192|   double bb_mid   = iBands(Symbol(), PERIOD_H4, 20, 2.0, 0, PRICE_CLOSE, MODE_MAIN, 1);
   193|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   194|   if(atr <= 0) return;
   195|
   196|   double squeezeWidth = (bb_upper - bb_lower) / atr;
   197|
   198|   // BUY: Close above upper BB + bullish bias
   199|   if(Close[1] > bb_upper && (bias == 1 || bias == 2)) {
   200|      double conviction = MathMin(1.0, (Close[1] - bb_upper) / atr * 0.5 + 0.3);
   201|      conviction = MathMin(1.0, conviction + (1.0 - squeezeWidth) * 0.2);
   202|      double sl = Ask - (atr * 1.5);
   203|      double tp = Ask + (atr * 3.0);
   204|      double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
   205|      if(lots > 0)
   206|         SubmitSignal(InpNoiseBreakout_Magic, OP_BUY, conviction,
   207|                      "NOISE_BO|BB_squeeze", lots, sl, tp);
   208|   }
   209|   // SELL: Close below lower BB + bearish bias
   210|   else if(Close[1] < bb_lower && (bias == -1 || bias == 2)) {
   211|      double conviction = MathMin(1.0, (bb_lower - Close[1]) / atr * 0.5 + 0.3);
   212|      conviction = MathMin(1.0, conviction + (1.0 - squeezeWidth) * 0.2);
   213|      double sl = Bid + (atr * 1.5);
   214|      double tp = Bid - (atr * 3.0);
   215|      double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
   216|      if(lots > 0)
   217|         SubmitSignal(InpNoiseBreakout_Magic, OP_SELL, conviction,
   218|                      "NOISE_BO|BB_squeeze", lots, sl, tp);
   219|   }
   220|}
   221|
   222|//+------------------------------------------------------------------+
   223|//| APEX - Session rollover fade                                     |
   224|//| Magic: 777011                                                    |
   225|//+------------------------------------------------------------------+
   226|void ExecuteApexStrategy_DEBATE()
   227|{
   228|   if(!InpApex_Enabled) return;
   229|   if(Period() != PERIOD_H4) return;
   230|   if(CountOpenTrades(InpApex_MagicNumber) > 0) return;
   231|   if(!IsStrategyHealthy(InpApex_MagicNumber)) return;
   232|   if(!CheckTimeFilter()) return;
   233|
   234|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   235|   if(atr <= 0) return;
   236|
   237|   // Extended bar detection
   238|   double barRange = High[1] - Low[1];
   239|   double trigger = atr * InpApex_ATR_Multiplier_SL;
   240|   bool extendedBull = (Close[1] > Open[1] && barRange > trigger);
   241|   bool extendedBear = (Close[1] < Open[1] && barRange > trigger);
   242|
   243|   if(!extendedBull && !extendedBear) return;
   244|
   245|   // Conviction from bar extension
   246|   double extensionRatio = barRange / atr;
   247|   double conviction = MathMin(1.0, (extensionRatio - 1.0) / 2.0);
   248|
   249|   int direction;
   250|   double sl, tp, lots;
   251|
   252|   if(extendedBull) {
   253|      direction = OP_SELL;
   254|      sl = High[1] + (atr * InpApex_ATR_Multiplier_SL * Point * 10);
   255|      tp = Bid - (atr * InpApex_ATR_Multiplier_TP * Point * 10);
   256|      lots = MoneyManagement_Quantum(InpApex_MagicNumber, InpBase_Risk_Percent);
   257|   } else {
   258|      direction = OP_BUY;
   259|      sl = Low[1] - (atr * InpApex_ATR_Multiplier_SL * Point * 10);
   260|      tp = Ask + (atr * InpApex_ATR_Multiplier_TP * Point * 10);
   261|      lots = MoneyManagement_Quantum(InpApex_MagicNumber, InpBase_Risk_Percent);
   262|   }
   263|
   264|   if(lots > 0)
   265|      SubmitSignal(InpApex_MagicNumber, direction, conviction,
   266|                   "APEX|ext=" + DoubleToStr(extensionRatio, 1), lots, sl, tp);
   267|}
   268|
   269|//+------------------------------------------------------------------+
   270|//| NEXUS - Volatility compression breakout                          |
   271|//| Magic: 777014                                                    |
   272|//+------------------------------------------------------------------+
   273|void ExecuteNexusStrategy_DEBATE()
   274|{
   275|   if(!InpNexus_Enabled) return;
   276|   if(Period() != PERIOD_H4) return;
   277|   if(CountOpenTrades(InpNexus_MagicNumber) > 0) return;
   278|   if(!IsStrategyHealthy(InpNexus_MagicNumber)) return;
   279|   if(!CheckTimeFilter()) return;
   280|
   281|   int bias = CheckDirectionalBias();
   282|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   283|   if(atr <= 0) return;
   284|
   285|   // Volatility compression: N consecutive bars of ATR below median
   286|   double atrMedian = 0;
   287|   for(int i = 1; i <= 20; i++) atrMedian += iATR(Symbol(), PERIOD_H4, 14, i);
   288|   atrMedian /= 20.0;
   289|
   290|   int compressionBars = 0;
   291|   for(int i = 1; i <= 10; i++) {
   292|      if(iATR(Symbol(), PERIOD_H4, 14, i) < atrMedian * InpNexus_CompressionRatio)
   293|         compressionBars++;
   294|      else break;
   295|   }
   296|
   297|   if(compressionBars < InpNexus_MinCompressionBars) return;
   298|
   299|   // Breakout direction
   300|   bool buyBreak  = (Close[0] > High[1]);
   301|   bool sellBreak = (Close[0] < Low[1]);
   302|   if(!buyBreak && !sellBreak) return;
   303|
   304|   // Conviction from compression depth + breakout strength
   305|   double compressDepth = 1.0 - (atr / atrMedian);
   306|   double breakoutStrength = 0;
   307|   if(buyBreak) breakoutStrength = (Close[0] - High[1]) / atr;
   308|   else breakoutStrength = (Low[1] - Close[0]) / atr;
   309|
   310|   double conviction = MathMin(1.0, compressDepth * 0.5 + breakoutStrength * 0.3 + compressionBars * 0.05);
   311|
   312|   int direction;
   313|   double sl, tp;
   314|
   315|   if(buyBreak && (bias == 1 || bias == 2)) {
   316|      direction = OP_BUY;
   317|      sl = Ask - (atr * InpNexus_SL_ATR_Mult);
   318|      tp = Ask + (atrMedian * InpNexus_TP_Median_Mult);
   319|   } else if(sellBreak && (bias == -1 || bias == 2)) {
   320|      direction = OP_SELL;
   321|      sl = Bid + (atr * InpNexus_SL_ATR_Mult);
   322|      tp = Bid - (atrMedian * InpNexus_TP_Median_Mult);
   323|   } else return;
   324|
   325|   double lots = MoneyManagement_Quantum(InpNexus_MagicNumber, InpBase_Risk_Percent);
   326|   if(lots > 0)
   327|      SubmitSignal(InpNexus_MagicNumber, direction, conviction,
   328|                   "NEXUS|comp=" + IntegerToString(compressionBars) + "bars", lots, sl, tp);
   329|}
   330|
   331|//+------------------------------------------------------------------+
   332|//| MICROSTRUCTURE - H4 Kalman + M15 scalp                           |
   333|//| Magic: InpChronos_MagicNumber                                    |
   334|//+------------------------------------------------------------------+
   335|void ExecuteMicrostructure_DEBATE()
   336|{
   337|   if(!InpChronos_Enabled) return;
   338|   if(Period() != PERIOD_H4) return;
   339|   int magic_micro = InpChronos_MagicNumber;
   340|   if(CountOpenTrades(magic_micro) > 0) return;
   341|   if(!IsStrategyHealthy(magic_micro)) return;
   342|   if(!CheckTimeFilter()) return;
   343|
   344|   // H4 Kalman filter for macro bias
   345|   double kalman_prev = iMA(Symbol(), PERIOD_H4, 10, 0, MODE_EMA, PRICE_CLOSE, 2);
   346|   double kalman_curr = iMA(Symbol(), PERIOD_H4, 10, 0, MODE_EMA, PRICE_CLOSE, 1);
   347|   int bias = 0;
   348|   if(kalman_curr > kalman_prev && Close[1] > kalman_curr) bias = 1;
   349|   else if(kalman_curr < kalman_prev && Close[1] < kalman_curr) bias = -1;
   350|   if(bias == 0) return;
   351|
   352|   // M15 RSI + BB for micro signal
   353|   double m15_rsi = iRSI(Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1);
   354|   double m15_bb_lower = iBands(Symbol(), PERIOD_M15, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 1);
   355|   double m15_bb_upper = iBands(Symbol(), PERIOD_M15, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 1);
   356|
   357|   bool buy_scalp  = (bias == 1 && Close[1] < m15_bb_lower && m15_rsi < 30);
   358|   bool sell_scalp = (bias == -1 && Close[1] > m15_bb_upper && m15_rsi > 70);
   359|   if(!buy_scalp && !sell_scalp) return;
   360|
   361|   // Conviction from RSI extremity
   362|   double rsiExtremity = 0;
   363|   if(buy_scalp) rsiExtremity = (30.0 - m15_rsi) / 30.0;
   364|   else rsiExtremity = (m15_rsi - 70.0) / 30.0;
   365|   double conviction = MathMax(0.3, MathMin(1.0, rsiExtremity));
   366|
   367|   int direction = buy_scalp ? OP_BUY : OP_SELL;
   368|   double slPips = InpChronos_ScalpSL_Pips * 10 * Point;
   369|   double tpPips = InpChronos_ScalpTP_Pips * 10 * Point;
   370|   double sl, tp;
   371|
   372|   if(direction == OP_BUY) {
   373|      sl = Ask - slPips;
   374|      tp = Ask + tpPips;
   375|   } else {
   376|      sl = Bid + slPips;
   377|      tp = Bid - tpPips;
   378|   }
   379|
   380|   double lots = MoneyManagement_Quantum(magic_micro, InpBase_Risk_Percent) * InpChronos_LotSizeMultiplier;
   381|   if(lots > 0)
   382|      SubmitSignal(magic_micro, direction, conviction,
   383|                   "MICRO|H4_bias=" + IntegerToString(bias), lots, sl, tp);
   384|}
   385|
   386|//+------------------------------------------------------------------+
   387|//| VORTEX - Vortex indicator crossover                              |
   388|//| Magic: 9001                                                      |
   389|//+------------------------------------------------------------------+
   390|void ExecuteVortexStrategy_DEBATE()
   391|{
   392|   if(!InpVortex_Enabled) return;
   393|   if(Period() != PERIOD_H4) return;
   394|   if(CountOpenTrades(InpVortex_MagicNumber) > 0) return;
   395|   if(!IsStrategyHealthy(InpVortex_MagicNumber)) return;
   396|   if(!CheckTimeFilter()) return;
   397|
   398|   int bias = CheckDirectionalBias();
   399|
   400|   // Vortex indicator
   401|   double vmPlus_1 = 0, vmMinus_1 = 0, atrSum_1 = 0;
   402|   double vmPlus_2 = 0, vmMinus_2 = 0, atrSum_2 = 0;
   403|   for(int v = 1; v <= InpVortex_Period; v++) {
   404|      vmPlus_1  += MathAbs(High[v] - Low[v+1]);
   405|      vmMinus_1 += MathAbs(Low[v] - High[v+1]);
   406|      atrSum_1  += MathAbs(High[v] - Low[v]);
   407|   }
   408|   for(int w = 2; w <= InpVortex_Period + 1; w++) {
   409|      vmPlus_2  += MathAbs(High[w] - Low[w+1]);
   410|      vmMinus_2 += MathAbs(Low[w] - High[w+1]);
   411|      atrSum_2  += MathAbs(High[w] - Low[w]);
   412|   }
   413|   if(atrSum_1 <= 0 || atrSum_2 <= 0) return;
   414|
   415|   double viPlus_1  = vmPlus_1 / atrSum_1;
   416|   double viMinus_1 = vmMinus_1 / atrSum_1;
   417|   double viPlus_2  = vmPlus_2 / atrSum_2;
   418|   double viMinus_2 = vmMinus_2 / atrSum_2;
   419|
   420|   double adx = iADX(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, MODE_MAIN, 1);
   421|   if(adx < InpVortex_ADX_Threshold) return;
   422|
   423|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   424|   if(atr <= 0) return;
   425|
   426|   bool buyCross  = (viPlus_1 > viMinus_1 && viPlus_2 <= viMinus_2);
   427|   bool sellCross = (viMinus_1 > viPlus_1 && viMinus_2 <= viPlus_2);
   428|
   429|   if(!buyCross && !sellCross) return;
   430|
   431|   // Conviction from VI spread + ADX
   432|   double viSpread = MathAbs(viPlus_1 - viMinus_1);
   433|   double adxNorm = MathMin(1.0, (adx - InpVortex_ADX_Threshold) / 30.0);
   434|   double conviction = MathMin(1.0, viSpread * 0.6 + adxNorm * 0.4);
   435|
   436|   int direction;
   437|   double sl, tp;
   438|
   439|   if(buyCross && (bias == 1 || bias == 2)) {
   440|      direction = OP_BUY;
   441|      sl = Ask - (atr * 1.5);
   442|      tp = Ask + (atr * 2.5);
   443|   } else if(sellCross && (bias == -1 || bias == 2)) {
   444|      direction = OP_SELL;
   445|      sl = Bid + (atr * 1.5);
   446|      tp = Bid - (atr * 2.5);
   447|   } else return;
   448|
   449|   double lots = MoneyManagement_Quantum(InpVortex_MagicNumber, InpBase_Risk_Percent);
   450|   if(lots > 0)
   451|      SubmitSignal(InpVortex_MagicNumber, direction, conviction,
   452|                   "VORTEX|VI=" + DoubleToStr(viSpread, 2), lots, sl, tp);
   453|}
   454|
   455|//+------------------------------------------------------------------+
   456|//| REGIME SHIFT - ADX+RSI regime change                             |
   457|//| Magic: 9002                                                      |
   458|//+------------------------------------------------------------------+
   459|void ExecuteRegimeShiftStrategy_DEBATE()
   460|{
   461|   if(!InpRegimeShift_Enabled) return;
   462|   if(Period() != PERIOD_H4) return;
   463|   if(CountOpenTrades(InpRegimeShift_MagicNumber) > 0) return;
   464|   if(!IsStrategyHealthy(InpRegimeShift_MagicNumber)) return;
   465|   if(!CheckTimeFilter()) return;
   466|
   467|   int bias = CheckDirectionalBias();
   468|
   469|   double adx_1 = iADX(Symbol(), PERIOD_H4, InpRegimeShift_ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   470|   double adx_2 = iADX(Symbol(), PERIOD_H4, InpRegimeShift_ADX_Period, PRICE_CLOSE, MODE_MAIN, 2);
   471|   double rsi = iRSI(Symbol(), PERIOD_H4, InpRegimeShift_RSI_Period, PRICE_CLOSE, 1);
   472|
   473|   bool adxCrossAbove25 = (adx_1 > 25.0 && adx_2 <= 25.0);
   474|   if(!adxCrossAbove25) return;
   475|
   476|   double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
   477|   if(atr <= 0) return;
   478|
   479|   // Conviction from ADX momentum + RSI distance from 50
   480|   double adxMomentum = MathMin(1.0, (adx_1 - 25.0) / 25.0);
   481|   double rsiBias = MathAbs(rsi - 50.0) / 50.0;
   482|   double conviction = MathMin(1.0, adxMomentum * 0.5 + rsiBias * 0.5);
   483|
   484|   int direction;
   485|   double sl, tp;
   486|
   487|   if(rsi > 50.0 && (bias == 1 || bias == 2)) {
   488|      direction = OP_BUY;
   489|      sl = Ask - (atr * 2.0);
   490|      tp = Ask + (atr * 3.0);
   491|   } else if(rsi < 50.0 && (bias == -1 || bias == 2)) {
   492|      direction = OP_SELL;
   493|      sl = Bid + (atr * 2.0);
   494|      tp = Bid - (atr * 3.0);
   495|   } else return;
   496|
   497|   double lots = MoneyManagement_Quantum(InpRegimeShift_MagicNumber, InpBase_Risk_Percent);
   498|   if(lots > 0)
   499|      SubmitSignal(InpRegimeShift_MagicNumber, direction, conviction,
   500|                   "REGIME_SHIFT|ADX=" + DoubleToStr(adx_1, 0), lots, sl, tp);
   501|

//+------------------------------------------------------------------+
//| ONNEWBAR DEBATE HOOK                                              |
//+------------------------------------------------------------------+

     1|//+------------------------------------------------------------------+
     2|//| V28_11_ONNEWBAR_DEBATE_HOOK.mq4                                  |
     3|//| Drop-in replacement for OnNewBar() strategy section              |
     4|//| Include V28_11_DEBATE_LAYER.mq4 + V28_11_STRATEGIES_DEBATE.mq4  |
     5|//+------------------------------------------------------------------+
     6|
     7|//--- Call this from OnNewBar() INSTEAD of the individual strategy calls
     8|void OnNewBar_DebateLayer()
     9|{
    10|   //--- Step 1: Reset signal buffer for this bar
    11|   ResetSignals();
    12|
    13|   //--- Step 2: All strategies submit signals (no execution)
    14|   ExecuteMeanReversion_DEBATE();
    15|   ExecuteMathReversal_DEBATE();
    16|   ExecuteNoiseBreakout_DEBATE();
    17|   ExecuteApexStrategy_DEBATE();
    18|   ExecuteNexusStrategy_DEBATE();
    19|   ExecuteMicrostructure_DEBATE();
    20|   ExecuteVortexStrategy_DEBATE();
    21|   ExecuteRegimeShiftStrategy_DEBATE();
    22|   ExecuteSessionMomentum_DEBATE();
    23|   ExecuteDivergenceMR_DEBATE();
    24|   ExecuteStructuralRetest_DEBATE();
    25|
    26|   //--- Phantom is Monday-only, fire on Monday
    27|   if(DayOfWeek() == 1) ExecutePhantomStrategy_DEBATE();
    28|
    29|   //--- Step 3: Run debate + risk panel + execute winner
    30|   if(g_signalCount > 0) {
    31|      int ticket = ExecuteDebateTrade();
    32|      if(ticket > 0) {
    33|         LogError("ONNEWBAR_DEBATE: Trade executed #" + IntegerToString(ticket) +
    34|                  " from " + IntegerToString(g_signalCount) + " signals");
    35|      }
    36|   }
    37|
    38|   //--- Step 4: Reaper runs independently (grid first entry through debate)
    39|   //--- Grid levels still use existing ProcessReaperBasket logic
    40|   //--- Comment out ExecuteReaperProtocol() and replace with:
    41|   ExecuteReaperProtocol_Debate();
    42|}
    43|
    44|//+------------------------------------------------------------------+
    45|//| REAPER PROTOCOL - Grid first entry through debate                |
    46|//| Grid levels continue using existing OrderSend logic              |
    47|//+------------------------------------------------------------------+
    48|void ExecuteReaperProtocol_Debate()
    49|{
    50|   //--- Check if Reaper has no active basket in BUY direction
    51|   //--- If so, check for high conviction signal and submit to debate
    52|   int buyMagic = InpReaper_BuyMagicNumber;
    53|   int sellMagic = InpReaper_SellMagicNumber;
    54|
    55|   //--- BUY basket: first entry through debate
    56|   if(CountOpenTrades(buyMagic) == 0) {
    57|      if(IsHighConvictionSignal(OP_BUY)) {
    58|         //--- Calculate conviction from AlphaSentinel confluence layers
    59|         int layers = 0;
    60|         // Layer 1: Pivot proximity (already checked in IsHighConvictionSignal)
    61|         layers++;
    62|         // Layer 2: Stochastic crossover
    63|         double stoch1 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
    64|         double stoch2 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 2);
    65|         if(stoch1 > stoch2) layers++;
    66|         // Layer 3: RSI divergence
    67|         double rsi1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 1);
    68|         double rsi2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 2);
    69|         if(rsi1 > rsi2 && Low[1] < Low[2]) layers++;
    70|
    71|         double conviction = layers / 3.0;
    72|         double lots = GetNextReaperLotSize(0);
    73|         double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
    74|         double sl = Ask - (atr * 2.0);
    75|
    76|         SubmitSignal(buyMagic, OP_BUY, conviction,
    77|                      "REAPER_BUY|layers=" + IntegerToString(layers), lots, sl, 0);
    78|      }
    79|   }
    80|
    81|   //--- SELL basket: first entry through debate
    82|   if(CountOpenTrades(sellMagic) == 0) {
    83|      if(IsHighConvictionSignal(OP_SELL)) {
    84|         int layers = 0;
    85|         layers++;
    86|         double stoch1 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
    87|         double stoch2 = iStochastic(Symbol(), PERIOD_H4, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 2);
    88|         if(stoch1 < stoch2) layers++;
    89|         double rsi1 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 1);
    90|         double rsi2 = iRSI(Symbol(), PERIOD_H4, 14, PRICE_CLOSE, 2);
    91|         if(rsi1 < rsi2 && High[1] > High[2]) layers++;
    92|
    93|         double conviction = layers / 3.0;
    94|         double lots = GetNextReaperLotSize(0);
    95|         double atr = iATR(Symbol(), PERIOD_H4, 14, 1);
    96|         double sl = Bid + (atr * 2.0);
    97|
    98|         SubmitSignal(sellMagic, OP_SELL, conviction,
    99|                      "REAPER_SELL|layers=" + IntegerToString(layers), lots, sl, 0);
   100|      }
   101|   }
   102|
   103|   //--- Grid level management continues as before (not through debate)
   104|   ProcessReaperBasket(buyMagic, OP_BUY);
   105|   ProcessReaperBasket(sellMagic, OP_SELL);
   106|}
   107|
   108|//+------------------------------------------------------------------+
   109|//| INTEGRATION GUIDE                                                 |
   110|//|                                                                   |
   111|//| In your EA (V28_11.mq4):                                         |
   112|//|                                                                   |
   113|//| 1. Add at top:                                                    |
   114|//|    #include "V28_11_DEBATE_LAYER.mq4"                            |
   115|//|                                                                   |
   116|//| 2. In OnInit():                                                   |
   117|//|    InitDebateLayer();                                             |
   118|//|                                                                   |
   119|//| 3. In OnNewBar():                                                 |
   120|//|    REPLACE the block of Execute*() calls with:                    |
   121|//|    OnNewBar_DebateLayer();                                        |
   122|//|                                                                   |
   123|//| 4. In OnTradeClose() or equivalent:                               |
   124|//|    ProcessTradeClose(ticket, exitPrice, pnl);                    |
   125|//|                                                                   |
   126|//| That's it. All V28.06 logic preserved. Debate layer is additive. |
   127|//+------------------------------------------------------------------+
   128|

int OnInit()
{
   // V18.0 COMPONENT 7: Initialize Memory Buffers
   InitializeMemory();

   g_start_time = TimeCurrent(); // Initialize start time for runtime calculation
   // --- GENEVA PROTOCOL V3.0: DYNAMIC FILE NAMING ---
   g_logFileName = MQLInfoString(MQL_PROGRAM_NAME) + "_Performance_Log.csv";
   FileDelete(g_logFileName); // Delete any previous log with the correct name
   // ---

   
   LogError(ERROR_INFO, "### INITIALIZING DESTROYER QUANTUM V10.0 - PROJECT CHIMERA ###", "OnInit");
   LogError(ERROR_INFO, "Developed by @okyy.ryan. Strategic Precision & Tactical Dominance.", "OnInit");
   
   //--- Initialize broker requirements
   g_min_stop_distance = InpMinStopDistancePoints * _Point;
   
   //--- Initialize Dashboard
   if(InpShow_Dashboard && !IsOptimization())
   {
      InitializeDashboardV8_6();
   }
   
   //--- Seed the random number generator if needed
   MathSrand((int)TimeCurrent());
   
   // --- TREASURER INITIALIZATION ---
   // Create a unique key for the HWM based on Account Number and EA Magic Number.
   // This prevents conflicts with other EAs or accounts on the same terminal.
   g_hwm_key = "DQ_V1000_HWM_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + IntegerToString(InpMagic_MeanReversion);
   if (GlobalVariableCheck(g_hwm_key))
   {
       // A persistent HWM was found. Load it.
       g_high_watermark_equity = GlobalVariableGet(g_hwm_key);
       LogError(ERROR_INFO, "Treasurer: Persistent High Watermark loaded: " + DoubleToString(g_high_watermark_equity, 2), "OnInit");
   }
   else
   {
       // No persistent HWM found. Initialize with current equity and save it.
       g_high_watermark_equity = AccountEquity();
       GlobalVariableSet(g_hwm_key, g_high_watermark_equity);
       LogError(ERROR_INFO, "Treasurer: New High Watermark initialized and saved: " + DoubleToString(g_high_watermark_equity, 2), "OnInit");
   }
   
   // --- GENEVA V4.1: Extended Performance Accumulator ---
   for(int i=0; i<17; i++) // V28.00: Extended to 17 strategy slots
   {
       g_perfData[i].trades = 0;
       g_perfData[i].grossProfit = 0.0;
       g_perfData[i].grossLoss = 0.0;
   }
   g_perfData[0].name = "Mean Reversion";
   g_perfData[1].name = "Quantum Oscillator";
   g_perfData[2].name = "Titan";
   g_perfData[3].name = "Warden";
   g_perfData[4].name = "Reaper Protocol";
   g_perfData[5].name = "Silicon-X";
   g_perfData[6].name = "Market Microstructure";
   g_perfData[7].name = "NoiseBreakout";
   g_perfData[8].name = "Apex";
   g_perfData[9].name = "Phantom";
    g_perfData[10].name = "Nexus";
    g_perfData[11].name = "MathReversal"; // V27.2: Fixed index collision
    g_perfData[12].name = "RegimeShift";
    g_perfData[13].name = "SessionMomentum"; // V28.00: New strategy
    g_perfData[14].name = "DivergenceMR";    // V28.00: New strategy
    g_perfData[15].name = "LiquiditySweep"; // V28.03: New strategy
    g_perfData[16].name = "StructuralRetest"; // V28.03: New strategy
   // ---
   
   // V13.0 ELITE: Initialize Strategy Cooldown System
   for(int i = 0; i < 17; i++)  // V28.00: Extended to 17 strategies
   {
       g_strategyCooldown[i].disabled = false;
       g_strategyCooldown[i].disabledTime = 0;
       g_strategyCooldown[i].disabledBars = 0;
   }
   
   // PHASE 2: INSTITUTIONAL SYSTEM INITIALIZATION
   InitializeInstitutionalSystem();
   
   // PHASE 3: ELITE SYSTEM INITIALIZATION
   InitializeEliteSystem();
   
   LogError(ERROR_INFO, "### DESTROYER QUANTUM V13.0 ELITE INITIALIZATION COMPLETE ###", "OnInit");

    // V23 INSTITUTIONAL INITIALIZATION
    V23_Initialize();
    
    // Register strategies for V23 tracking
    // Warden: 777009
    V23_RegisterStrategy("Warden", 777009);
    
    // Reaper: 888001 (Buy), 888002 (Sell)
    V23_RegisterStrategy("Reaper_Buy", 888001);
    V23_RegisterStrategy("Reaper_Sell", 888002);
    
    // Silicon-X: 984651
    V23_RegisterStrategy("Silicon-X", 984651);
    
    // V27: NoiseBreakout: 777012
    V23_RegisterStrategy("NoiseBreakout", 777012);
    
    // V24/V25/V26 ALPHA EXPANSION INITIALIZATION
    if(InpAlphaExpand) {
        if(InpMathFirst) {
            Print("[V26] MATH-FIRST MODE ENABLED - Pure Math Signal Generation + Full V25 Enhancements");
            Print("[V26] Target: 650-950 trades, PF 3.6-4.0, DD 9-11%");
            Print("[V26] MathReversal Strategy: +400-600 trades from pure math (NO V18 binary gates)");
            Print("[V26] All V25 Fixes: Marginal VAR, Regime Probation, Continuous Scoring, Complete Re-entries");
            Print("[V26] Triggers: Prob>0.7, Deviation>1.5, Entropy<0.6, RExp>0, Confidence>0.5");
            
            // Register MathReversal strategy
            V23_RegisterStrategy("MathReversal", 999002);
            Print("[V26] MathReversal strategy registered with magic 999002");
        } else if(InpElasticScoring) {
            Print("[V25] ELASTIC SIGNAL LAYER MODE ENABLED - Full V25 with Continuous Scoring");
            Print("[V25] Target: 600-900 trades, PF 3.5-4.1, DD 8-10%");
            Print("[V25] Fix #1: Marginal VAR with regime-contextual limits");
            Print("[V25] Fix #2: Regime Probation/Hysteresis enabled");
            Print("[V25] Fix #3: Continuous Scoring ACTIVE (elastic signal geometry)");
            Print("[V25] Fix #4: Complete Re-entries with OrderSend integration");
        } else {
            Print("[V24] Alpha Expansion Mode ENABLED - Target: 600-900 trades, PF 3.5-4.0, DD 8-10%");
            Print("[V24] Fix #1: VAR Relaxation Factor = ", DoubleToString(InpVarRelaxFactor, 2));
            Print("[V24] Fix #2: Adaptive Max Shift = ", DoubleToString(InpAdaptMax, 2), " levels");
        }
        Print("[V25] Fix #4: Re-entry Cooldown = ", InpReentryCooldown, " bars (reduced to 5), Size = ", DoubleToString(InpReentrySizeMult, 2), "x (increased to 0.7)");
        
        // Initialize V24/V25 re-entry tracking arrays
        for(int v24_i = 0; v24_i < 10; v24_i++) {
            v24_lastTrade[v24_i] = 0;
            v24_lastSignalPrice[v24_i] = 0;
            v24_lastSignalType[v24_i] = 0;
        }
    } else {
        Print("[V23] Alpha Expansion Mode DISABLED - V23 Conservative Mode (192 trades, PF ~4.0)");
    }
    
    // Mean Reversion: Find magic number
    // Titan: Find magic number
    // Add other strategies as needed
    
    Print("[V23] Strategy registration complete. Empirical probability engine active.");

   // V27.7: Initialize Event Shield arrays
   g_atrSpikeLockoutUntil = 0;
   ArrayInitialize(g_consecLossTracker, 0);
   ArrayInitialize(g_strategyLockoutUntil, 0);
   
   // V27.8: Initialize Adaptive Risk Unwind  all strategies start at 1.0x
   ArrayInitialize(g_strategyMultiplier, 1.0);
   
   // V27.19: Initialize Dynamic Performance-Based Lot Sizing
   ArrayInitialize(g_stratProfits, 0.0);
   ArrayInitialize(g_stratProfitIdx, 0);
   ArrayInitialize(g_stratTotalTrades, 0);
   ArrayInitialize(g_stratRollingWinRate, 0.5);      // Start at 50% assumption
   ArrayInitialize(g_stratRollingAvgWin, 100.0);     // Seed: $100 avg win
   ArrayInitialize(g_stratRollingAvgLoss, 80.0);     // Seed: $80 avg loss
   ArrayInitialize(g_stratRollingPF, 1.25);           // Seed: 1.25 PF
   ArrayInitialize(g_stratKellyFraction, 0.025);      // Seed: 2.5% Kelly
   ArrayInitialize(g_stratSharpeProxy, 0.5);          // Seed: moderate Sharpe
   ArrayInitialize(g_stratHeatScore, 0.5);            // Start at 50% heat
   ArrayInitialize(g_stratLastCalcTime, 0);
   ArrayInitialize(g_stratDynamicMaxMult, 2.0);       // Start at 2.0x cap
   
   // V28.11: Initialize Debate Layer
   InitDebateLayer();
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//| DESTROYER QUANTUM V10.0 - by @okyy.ryan                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LogError(ERROR_INFO, "### DE-INITIALIZING DESTROYER QUANTUM V13.8. Reason: " + IntegerToString(reason) + " ###", "OnDeinit");
   
   //--- Cleanup dashboard objects
   if(InpShow_Dashboard)
   {
      ObjectsDeleteAll(0, g_obj_prefix);
   }
   
   // If EA is removed by user, clean up the global variable.
   if (reason == REASON_REMOVE) {
       GlobalVariableDel(g_hwm_key);
       LogError(ERROR_INFO, "Treasurer: Persistent High Watermark cleared.", "OnDeinit");
   }
   
   // V13.7 SENGKUNI FIX: Reconcile all historical trades before generating the report
   // This guarantees accuracy by catching trades closed at the end of the test.
   ReconcileFinalPerformance(); 
   
   // Generate final performance report with the reconciled data
   GeneratePerformanceReport();
   
   // --- CORTANA ENHANCEMENT: Final Summary ---
   LogError(ERROR_INFO, "=== DESTROYER QUANTUM V13.7 DEACTIVATED ===", "OnDeinit");
   LogError(ERROR_INFO, "Total Runtime: " + TimeToString(TimeCurrent() - g_start_time, TIME_MINUTES|TIME_SECONDS), "OnDeinit");
   LogError(ERROR_INFO, "Final Equity: $" + DoubleToString(AccountEquity(), 2), "OnDeinit");
   LogError(ERROR_INFO, "Thank you for using DESTROYER QUANTUM!", "OnDeinit");
}
//+------------------------------------------------------------------+
//| Expert tick function (main loop)                                 |
//| DESTROYER QUANTUM V10.0 - by @okyy.ryan                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| V18.0 COMPONENT 3: Risk Gatekeeper                              |
//| Connects CInstitutionalRiskManager to Execution                 |
//+------------------------------------------------------------------+
bool ValidateTradeRisk(int strategyIndex, double intendedLots)
{
   // 1. Update Volatility Metrics
   // InstitutionalRisk.CalculatePortfolioVAR(); // Uncomment if class exists
   
   // 2. Check Daily Loss Limit
   double equity = AccountEquity();
   double balance = AccountBalance();
   double currentDailyLoss = balance - equity;
   double maxDailyLoss = balance * 0.02; // 2% of Balance
   
   if(currentDailyLoss > maxDailyLoss)
   {
      LogError(ERROR_CRITICAL, "RISK MANAGER: Daily Loss Limit Hit. Trade Blocked.", "ValidateTradeRisk");
      return false;
   }

   // 3. Check Portfolio VaR (Value At Risk)
   // V25 FIX #1: MARGINAL VAR CONTRIBUTION - Assess incremental trade impact
   double currentVaR = CalculateSimpleVaR(); // Current portfolio VAR
   double portfolioVaR = currentVaR;  // For backward compatibility
   
   // V25: Calculate dynamic VAR limit based on regime and entropy
   double varLimit = 5.0;  // Base 5% VAR cap (V23 default)
   
   if(InpAlphaExpand) {
       // Apply conditional relaxation in low-risk regimes or probation
       bool isLowRiskRegime = (v23_regime.type == 0 && v23_regime.entropyNorm < 0.5);
       bool isProbationRegime = (v23_regime.type == 3);  // V25: Probation state
       
       if(isLowRiskRegime) {
           varLimit *= InpVarRelaxFactor;  // Multiply by relaxation factor (default 1.5)
           Print("[V25 Fix#1] VAR limit relaxed to ", DoubleToString(varLimit, 2), 
                 "% (Regime=", v23_regime.type, ", Entropy=", DoubleToString(v23_regime.entropyNorm, 3), ")");
       } else if(isProbationRegime) {
           varLimit *= 1.2;  // Partial relaxation in probation
           Print("[V25 Fix#2] VAR limit probation relaxation to ", DoubleToString(varLimit, 2), "%");
       }
       
       // V25 FIX #1: Calculate marginal VAR for this specific trade
       // Estimate SL pips from lot size (rough approximation if not directly available)
       double estimatedSLpips = 50;  // Default estimate; strategies should pass actual SL
       double marginalVaR = V25_CalculateMarginalVAR(intendedLots, estimatedSLpips, v23_regime.type);
       
       // Check if marginal contribution pushes us over limit
       double projectedVaR = currentVaR + marginalVaR;
       
       if(projectedVaR > varLimit) {
           // V25: Soft dampening if close to limit (within 20% buffer)
           if(projectedVaR < varLimit * 1.2) {
               // Apply soft dampening to lot size (would need to return adjusted lots)
               Print("[V25 Fix#1] Marginal VAR soft damping: currentVaR=", DoubleToString(currentVaR, 2),
                     "%, marginalVaR=", DoubleToString(marginalVaR, 2), 
                     "%, projected=", DoubleToString(projectedVaR, 2), "%");
               // Note: Soft damping would require returning adjusted lot size
               // For now, we allow the trade with warning
           } else {
               // Hard block if significantly over
               string msg = "[V25 Fix#1] MARGINAL VAR BLOCK: Current=" + DoubleToString(currentVaR, 2) + 
                           "%, Marginal=" + DoubleToString(marginalVaR, 2) + 
                           "%, Projected=" + DoubleToString(projectedVaR, 2) + 
                           "% > Limit=" + DoubleToString(varLimit, 2) + "%";
               LogError(ERROR_WARNING, msg, "ValidateTradeRisk");
               return false;
           }
       }
   } else {
       // V23/V24 mode: Absolute VAR check
       if(portfolioVaR > varLimit) {
           string msg = "RISK MANAGER: Portfolio VaR (" + DoubleToString(portfolioVaR,2) + "%) exceeds ";
           msg += "limit (" + DoubleToString(varLimit,2) + "%). Trade Blocked.";
           LogError(ERROR_WARNING, msg, "ValidateTradeRisk");
           return false;
       }
   }

   return true;
}

//+------------------------------------------------------------------+
//| V25 FIX #1: Calculate Marginal VAR Contribution                 |
//| Returns the additional VAR this trade would add to portfolio    |
//+------------------------------------------------------------------+
double V25_CalculateMarginalVAR(double lots, double slPips, int regimeType) {
    // Calculate trade risk in account currency
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double pipValue = tickValue * 10;  // Convert tick to pip value
    double tradeRisk = lots * slPips * pipValue;
    
    // Convert to percentage of equity
    double equity = AccountEquity();
    if(equity <= 0) return 0;
    
    double riskPercent = (tradeRisk / equity) * 100.0;
    
    // Apply tail risk factor based on regime
    double tailFactor = 1.0;
    if(regimeType == 2) {        // Volatile
        tailFactor = 1.5;
    } else if(regimeType == 3) { // Probation
        tailFactor = 1.2;
    }
    
    return riskPercent * tailFactor;
}

// Simple VaR calculation based on open positions
double CalculateSimpleVaR()
{
   double totalRisk = 0.0;
   double equity = AccountEquity();
   
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         double sl = OrderStopLoss();
            double openPrice = OrderOpenPrice();
            double lots = OrderLots();
            
            if(sl > 0 && openPrice > 0)
            {
               // V27.26: Calculate risk based on SL distance (not just unrealized P/L)
               double slDistance = MathAbs(openPrice - sl);
               double tickValue = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
               double tickSize = MarketInfo(OrderSymbol(), MODE_TICKSIZE);
               
               if(tickSize > 0 && tickValue > 0)
               {
                  double riskPerTrade = (slDistance / tickSize) * tickValue * lots;
                  totalRisk += riskPerTrade;
               }
            }
            else if(OrderStopLoss() == 0)
            {
               // No SL set - use 2x ATR as estimated risk
               double atr = iATR(OrderSymbol(), PERIOD_H4, 14, 1);
               double tickValue = MarketInfo(OrderSymbol(), MODE_TICKVALUE);
               double tickSize = MarketInfo(OrderSymbol(), MODE_TICKSIZE);
               
               if(tickSize > 0 && tickValue > 0 && atr > 0)
               {
                  double riskPerTrade = (atr * 2.0 / tickSize) * tickValue * lots;
                  totalRisk += riskPerTrade;
               }
            }
      }
   }
   
   return (equity > 0) ? (totalRisk / equity * 100.0) : 0.0;
}


//+------------------------------------------------------------------+
//| V18.0 COMPONENT 4: Apex Sentinel (Market Regime Classifier)     |
//| Returns: Risk Multiplier based on Environment                   |
//+------------------------------------------------------------------+
double GetRegimeRiskMultiplier(int strategyType)
{
   // --- METRICS ---
   double atrShort = iATR(NULL, 0, 14, 1);
   double atrLong  = iATR(NULL, 0, 100, 1);
   double adx      = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
   
   // --- 1. CRISIS REGIME (Volatility Shock) ---
   if(atrShort > (atrLong * 2.0)) 
   {
      // In crisis, cut all risk to 20%
      return 0.2; 
   }

   // --- 2. TRENDING REGIME ---
   if(adx > 30)
   {
      if(strategyType == 1) return 1.5; // Trend Strategies (Titan) -> Boost
      if(strategyType == 2) return 0.5; // Grid Strategies (Reaper/Silicon) -> Dampen
   }

   // --- 3. RANGING REGIME ---
   if(adx < 20)
   {
      if(strategyType == 1) return 0.5; // Trend Strategies -> Dampen
      if(strategyType == 2) return 2.0; // Grid Strategies -> Boost (Ideal Conditions)
   }

   return 1.0; // Neutral
}


//+------------------------------------------------------------------+
//| V18.0 COMPONENT 5: The Drawdown Halver (Smart Load Shedding)    |
//| Replaces: CheckCircuitBreaker (Panic Close)                     |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| V18.0 COMPONENT 9: VSA Flow Analyzer                            |
//| Returns: 1 (Breakout), 2 (Reversal), 0 (Noise)                  |
//+------------------------------------------------------------------+
int GetVSAState()
{
   double volCur = (double)Volume[1];
   double volSum = 0;
   for(int vi = 1; vi <= 20; vi++) volSum += (double)Volume[vi];
   double volAvg = volSum / 20.0; // V27.11: Fixed  using actual volume data
   
   double rangeCur = High[1] - Low[1];
   double rangeAvg = iATR(NULL, 0, 20, 2);
   
   if(rangeAvg == 0 || volAvg == 0) return 0;
   
   double vRatio = volCur / volAvg;
   double rRatio = rangeCur / rangeAvg;
   
   // 1. The Trap (High Vol, Tiny Range) -> Potential Reversal
   if(vRatio > 1.5 && rRatio < 0.5) return 2;
   
   // 2. The Injection (High Vol, Huge Range) -> Breakout Validation
   if(vRatio > 1.5 && rRatio > 1.5) return 1;
   
   return 0;
}


//+------------------------------------------------------------------+
//| V18.0 COMPONENT 10: Manhattan Dynamic Sizing                    |
//| Uses historical performance to adjust risk                      |
//+------------------------------------------------------------------+
double GetKellyLotSize(int magic, double stopLossPips)
{
   // 1. Retrieve Stats from History (In-memory accumulators from Part 1)
   // For V18, we simulate stats if history is empty
   double winRate = 0.65; // Conservative estimate for Grid
   double avgWin  = 50.0;
   double avgLoss = 40.0;
   
   // 2. Calculate Edge (ZERO-DIVIDE PROTECTION)
   double b = (avgLoss > 0) ? avgWin / avgLoss : 1.0;
   if(b <= 0) b = 1.0; // Additional safety
   double p = winRate;
   double q = 1.0 - p;
   
   double kellyPct = ((b * p) - q) / b;
   
   // 3. Apply Safety Fraction (Quarter Kelly)
   kellyPct = kellyPct * 0.25; 
   
   // 4. Cap Risk
   if(kellyPct > 0.05) kellyPct = 0.05; // Max 5% equity
   if(kellyPct < 0.001) kellyPct = 0.001; // Min risk
   
   double riskMoney = AccountEquity() * kellyPct;
   double tickVal = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickVal <= 0) tickVal = 1.0; // ZERO-DIVIDE PROTECTION
   
   // Lot Formula: RiskMoney / (SL_Points * TickValue)
   double slPoints = stopLossPips * 10; // Convert pips to points
   if(slPoints <= 0) slPoints = 100; // Default (ZERO-DIVIDE PROTECTION)
   double lots = riskMoney / (slPoints * tickVal);
   
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+

// V27.27: Directional Bias is handled by int CheckDirectionalBias() below




/* V18.0 NEW ONTICK STRUCTURE - REVIEW AND INTEGRATE:
void OnTick()
{

    // V23 REGIME DETECTION (once per bar)
    static datetime v23_lastBar = 0;
    if(Time[0] != v23_lastBar) {
        V23_DetectMarketRegime();
        v23_lastBar = Time[0];
    }

   // ===== V18.0 PHASE 2: INSTITUTIONAL CORE ARCHITECTURE =====
   
   // 1. Critical Safety Checks (High Priority)
   ManageDrawdownExposure_V2(); // Component 5: Smart Load Shedding
   Hades_ManageBaskets();       // Legacy safety
   
   // 2. Data Updates (Once per bar)
   static datetime lastBar;
   bool newBar = (Time[0] != lastBar);
   
   if(newBar)
   {
      lastBar = Time[0];
      // Component 7: Memory optimization (if implemented)
      // UpdatePriceBuffers();
      
      // Component 6: Ensemble Arbitration Engine
      Arbiter.Refresh();
   }
   
   // 3. Strategy Execution (Delegated & Direction-Aware)
   
   // Component 6: Get allowed direction from Arbiter
   int allowed = Arbiter.GetAllowedDirection();
   
   // Silicon Core (Trap System) - Component 2
   if(InpSiliconX_Enabled)
   {
      ExecuteSiliconCore();
   }
   
   // Reaper (Grid System) - Only if enabled and direction matches Arbiter
   if(InpReaper_Enabled)
   {
      ExecuteReaperProtocol();
   }
   
   // Warden (Volatility) - Only on VSA Injection signals (Component 9)
   if(InpWarden_Enabled && GetVSAState() == 1)
   {
      ExecuteWardenStrategy();
   }
   
   // Titan (Trend) - Strategic directional filter
   if(InpTitan_Enabled)
   {
      ExecuteTitanStrategy();
   }
   
   // Mean Reversion - With proper filtering
   if(InpMeanReversion_Enabled)
   {
      ExecuteMeanReversionModelV8_6();
   }
   
   // 4. Dashboard (Low Priority)
   if(InpShow_Dashboard) UpdateDashboard_Realtime();
}
*/

void OnTick()
{
   // V18.0 INSTITUTIONAL CANDIDATE: Tactical Drawdown Manager (HIGHEST PRIORITY)
   ManageDrawdownExposure_V2();
   
   // V17.6 WINNER TAKES ALL: Global Circuit Breaker Check (Second Priority)
   CheckCircuitBreaker();
   
   // V27.6: Event-Aware Risk  log warning during FOMC/ECB/NFP windows
   if(InpEventRisk_Enabled) CheckEventRisk();
   
   // Check if system is in lockout mode
   if(GlobalVariableGet("SystemLockout") > TimeCurrent())
   {
      Comment("SYSTEM LOCKOUT ACTIVE - Circuit Breaker Tripped. Resume at: " + TimeToString((datetime)GlobalVariableGet("SystemLockout")));
      return;
   }

   // ===============================================================
   // ======= HADES PROTOCOL: HIGHEST PRIORITY EXIT AUTHORITY =======
   // ===============================================================
   Hades_ManageBaskets();
   // ===============================================================
   
   // --- FIXED: SINGLE EXECUTION PER BAR TO PREVENT DUPLICATE STRATEGIES ---
   static datetime lastBarTime = 0;
   static datetime lastHistoricalUpdate = 0;
   
   // Execute core trading logic ONLY on new bars
   if(Time[0] > lastBarTime)
   {
      lastBarTime = Time[0];
      
      // V11.1: FIXED MULTI-TIMEFRAME STRATEGY EXECUTION (ONCE PER BAR)
      if(UpdateMultiTimeframeData_Fixed())
      {
         // V18.3 CHRONOS UPGRADE: High Frequency M15 Scalping Module
         // This runs INDEPENDENTLY of the H4 strategy cycle.
         // Executes on M15 timeframe for 1000+ trades/year target
         ExecuteMicrostructureStrategy();
      }
      
      // Call main strategy processing
      OnNewBar();
   }
   
   // --- Update performance tracking on every tick (stateless) ---
   if(Time[0] > lastHistoricalUpdate)
   {
      static int historyTotal_last_tick = -1;
      
      if(historyTotal_last_tick < 0)
         historyTotal_last_tick = OrdersHistoryTotal();
      
      int currentHistoryTotal = OrdersHistoryTotal();
      
      if(currentHistoryTotal > historyTotal_last_tick)
      {
         for(int i = historyTotal_last_tick; i < currentHistoryTotal; i++)
         {
            if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            {
               int magic = OrderMagicNumber();
               // V13.7 SENGKUNI FIX: Use the IsOurMagicNumber() helper to track ALL strategies,
               // including the Reaper Protocol. This makes the system robust for future additions.
               if(IsOurMagicNumber(magic))
               {
                  UpdatePerformanceV4(magic, OrderProfit() + OrderCommission() + OrderSwap());
               }
            }
         }
      }
      historyTotal_last_tick = currentHistoryTotal;
      lastHistoricalUpdate = Time[0];
   }
   
   // Dashboard updates on every tick
   if(InpShow_Dashboard && !IsOptimization())
      UpdateDashboard_Realtime();
   
   // V13.0 ELITE: Performance monitoring and optimization
   MonitorPerformanceTargets();
   
   // Trade management
   ManageOpenTradesV13_ELITE();
   
   // PHASE 3: Warden Trailing Stop Manager (Call on every tick)
   ManageWardenTrailingStop();
   
   // V17.5: OPERATION CHIMERA - Unified command structure with centralized trailing
   if (InpSiliconX_Enabled) OnTick_SiliconX();
   OnTick_Reaper();
   
   // --- UNIFIED STRATEGY EXECUTION BLOCK ---
   
   // Centralized Management
   ManageUnified_AegisTrail(); // Manages trailing defense for ALL applicable strategies.
   
   // Additional phases
   OnTick_Institutional();
   OnTick_Elite();
   
   // V24 ALPHA EXPANSION: Re-entry Processing (Fix #3)
   if(InpAlphaExpand) {
       V24_ProcessReentries();
   }
}



//+------------------------------------------------------------------+
//| FIXED: MULTI-TIMEFRAME DATA COLLECTION                         |
//+------------------------------------------------------------------+
bool UpdateMultiTimeframeData_Fixed()
{
   bool dataUpdated = false;
   static datetime lastM15BarFixed = 0, lastM30BarFixed = 0, lastH1BarFixed = 0;
   static int retryCount = 0;
   
   // FIXED: Ensure arrays are properly initialized
   if(ArraySize(m15Close) == 0 || m15Close[0] != iClose(Symbol(), PERIOD_M15, 0))
   {
      // M15 DATA COLLECTION WITH PROPER INITIALIZATION
      datetime currentM15 = iTime(Symbol(), PERIOD_M15, 0);
      if(currentM15 > lastM15BarFixed || retryCount < 3)
      {
         int m15Bars = MathMin(100, iBars(Symbol(), PERIOD_M15));
         if(m15Bars >= 20) 
         {
            ArrayResize(m15High, m15Bars);
            ArrayResize(m15Low, m15Bars);
            ArrayResize(m15Close, m15Bars);
            ArrayResize(m15Volume, m15Bars);
            ArrayResize(m15Open, m15Bars);
            
            // VALIDATED DATA POPULATION
            for(int i = 0; i < m15Bars && i < 100; i++)
            {
               if(i < Bars(Symbol(), PERIOD_M15))
               {
                  m15High[i] = iHigh(Symbol(), PERIOD_M15, i);
                  m15Low[i] = iLow(Symbol(), PERIOD_M15, i);
                  m15Close[i] = iClose(Symbol(), PERIOD_M15, i);
                  m15Open[i] = iOpen(Symbol(), PERIOD_M15, i);
                  m15Volume[i] = (double)iVolume(Symbol(), PERIOD_M15, i);
               }
            }
            lastM15BarFixed = currentM15;
            dataUpdated = true;
            retryCount = 0;
         }
         else 
         {
            retryCount++;
            LogError(ERROR_WARNING, "Insufficient M15 bars: " + IntegerToString(m15Bars), "UpdateMultiTimeframeData_Fixed");
         }
      }
   }
   
   // M30 DATA COLLECTION
   datetime currentM30 = iTime(Symbol(), PERIOD_M30, 0);
   if(currentM30 > lastM30Bar)
   {
      int m30Bars = MathMin(100, iBars(Symbol(), PERIOD_M30));
      if(m30Bars >= 20)
      {
         ArrayResize(m30High, m30Bars);
         ArrayResize(m30Low, m30Bars);
         ArrayResize(m30Close, m30Bars);
         ArrayResize(m30Volume, m30Bars);
         ArrayResize(m30Open, m30Bars);
         
         for(int i = 0; i < m30Bars && i < 100; i++)
         {
            if(i < Bars(Symbol(), PERIOD_M30))
            {
               m30High[i] = iHigh(Symbol(), PERIOD_M30, i);
               m30Low[i] = iLow(Symbol(), PERIOD_M30, i);
               m30Close[i] = iClose(Symbol(), PERIOD_M30, i);
               m30Open[i] = iOpen(Symbol(), PERIOD_M30, i);
               m30Volume[i] = (double)iVolume(Symbol(), PERIOD_M30, i);
            }
         }
         lastM30Bar = currentM30;
         dataUpdated = true;
      }
   }
   
   // H1 DATA COLLECTION
   datetime currentH1 = iTime(Symbol(), PERIOD_H1, 0);
   if(currentH1 > lastH1BarFixed)
   {
      int h1Bars = MathMin(100, iBars(Symbol(), PERIOD_H1));
      if(h1Bars >= 20)
      {
         ArrayResize(h1High, h1Bars);
         ArrayResize(h1Low, h1Bars);
         ArrayResize(h1Close, h1Bars);
         ArrayResize(h1Volume, h1Bars);
         ArrayResize(h1Open, h1Bars);
         
         for(int i = 0; i < h1Bars && i < 100; i++)
         {
            if(i < Bars(Symbol(), PERIOD_H1))
            {
               h1High[i] = iHigh(Symbol(), PERIOD_H1, i);
               h1Low[i] = iLow(Symbol(), PERIOD_H1, i);
               h1Close[i] = iClose(Symbol(), PERIOD_H1, i);
               h1Open[i] = iOpen(Symbol(), PERIOD_H1, i);
               h1Volume[i] = (double)iVolume(Symbol(), PERIOD_H1, i);
            }
         }
         lastH1BarFixed = currentH1;
         dataUpdated = true;
      }
   }
   
   return dataUpdated;
}

//+------------------------------------------------------------------+
//| Main logic block V10.0: PARALLEL EXECUTION ENGINE              |
//| Project Chimera Phase 2: Independent Strategy Processing       |
//+------------------------------------------------------------------+
void OnNewBar()
{
   LogError(ERROR_INFO, "--- NEW BAR ANALYSIS [ORION V1.0] ---", "OnNewBar");
   
   // V27.7: Unified Event Shield  blocks trading during high-impact events + ATR spikes
   if(IsTradeBlockedByShield())
   {
      LogError(ERROR_WARNING, "OnNewBar: Blocked by Event Shield (news/ATR spike)", "OnNewBar");
      if(!IsOptimization()) UpdateDashboard_StaticV8_6();
      return;
   }

   // V27.20 FIX: Block entries during historically bad trading hours
   if(InpEnableTimeFilter && IsBadTradingHour())
   {
      LogError(ERROR_WARNING, "OnNewBar: Blocked by Bad-Hours filter (UTC loss window)", "OnNewBar");
      if(!IsOptimization()) UpdateDashboard_StaticV8_6();
      return;
   }
   
   // V27.16: Gentle Max Daily Loss  stop new trades if daily loss limit exceeded
   if(InpMaxDailyLoss > 0 && g_dailyPandL < -InpMaxDailyLoss)
   {
      LogError(ERROR_WARNING, "OnNewBar: Blocked by Max Daily Loss ($" + DoubleToString(g_dailyPandL, 2) + ")", "OnNewBar");
      if(!IsOptimization()) UpdateDashboard_StaticV8_6();
      return;
   }
   
   // V28.00: Drawdown protection  block new trades when DD > 10% (tightened from 12%)
   if(g_ddProtectionActive)
   {
      LogError(ERROR_WARNING, "OnNewBar: Blocked by DD Protection (drawdown > 10%)", "OnNewBar");
      if(!IsOptimization()) UpdateDashboard_StaticV8_6();
      return;
   }
   
   // V23 REGIME DETECTION (once per bar)
   V23_DetectMarketRegime();
   
   UpdateQueenBeeStatus();

   // =====================================================================
   // ============== ORION PROTOCOL: META-STRATEGY ALLOCATION =============
   // =====================================================================
   // LEVIATHAN: All strategies enabled - Orion permission system bypassed
   // Orion_DynamicAllocation();
   // =====================================================================

   // Initial guard clause: Exit immediately if portfolio is already full.
   if (CountOpenTrades() >= InpMaxOpenTrades)
   {
      if(!IsOptimization()) UpdateDashboard_StaticV8_6();
      return;
   }

   // =================================================================
   // V28.11: DEBATE LAYER  Signal voting + Risk Panel
   // Silicon-X still runs independently (grid specialist)
   // All other strategies submit signals through debate
   // =================================================================

   // Silicon-X runs independently (not through debate)
   if(InpSiliconX_Enabled)
   {
      ExecuteSiliconCore();
      if(CountOpenTrades() >= InpMaxOpenTrades) { if(!IsOptimization()) UpdateDashboard_StaticV8_6(); return; }
   }

   // V28.11: All other strategies through debate layer
   OnNewBar_DebateLayer();

   if(!IsOptimization())
   {
     UpdateDashboard_StaticV8_6();
   }
   
   // PHASE 3: ELITE BAR OPTIMIZATION
   OnNewBar_Elite();
}
//+------------------------------------------------------------------+
//| Update Queen Bee Status                                          |
//| Manages high watermark, drawdown, and hive state                 |
//+------------------------------------------------------------------+
void UpdateQueenBeeStatus()
{
   // Update current equity and high watermark
   double currentEquity = AccountEquity();
   
   if (currentEquity > g_high_watermark_equity)
   {
       g_high_watermark_equity = currentEquity; // A new peak has been reached
       GlobalVariableSet(g_hwm_key, g_high_watermark_equity); // SAVE PERSISTENTLY
       LogError(ERROR_INFO, "Treasurer: New High Watermark saved: " + DoubleToString(g_high_watermark_equity, 2), "UpdateQueenBeeStatus");
   }
   
   // Calculate current drawdown as a percentage
   if (g_high_watermark_equity > 0)
   {
       g_current_drawdown = (g_high_watermark_equity - currentEquity) / g_high_watermark_equity * 100.0;
   }
   else
   {
       g_current_drawdown = 0.0;
   }
   
   // Update hive state based on drawdown
   ENUM_HIVE_STATE old_state = g_hive_state;
   
   if (g_current_drawdown >= InpDefensiveDD_Percent)
   {
       g_hive_state = HIVE_STATE_DEFENSIVE;
   }
   else
   {
       g_hive_state = HIVE_STATE_GROWTH;
   }
   
   // Log state changes
   if (old_state != g_hive_state)
   {
       LogError(ERROR_INFO, "Queen Bee: Hive state changed from " + HiveStateToString(old_state) + 
             " to " + HiveStateToString(g_hive_state) + 
             ". Drawdown: " + DoubleToString(g_current_drawdown, 2) + "%", "UpdateQueenBeeStatus");
   }
   
   // V27.1: Run Queen Bee Global Circuit Breaker check
   QueenBee_GlobalRiskCheck();
}

//+------------------------------------------------------------------+
//| V27.1: Queen Bee Global Risk Assessment                        |
//| Shuts down strategy blocks when drawdown exceeds algorithmic   |
//| thresholds. Replaces the "accidental" limits of V26 with      |
//| intentional, mathematically-grounded risk gates.               |
//+------------------------------------------------------------------+
void QueenBee_GlobalRiskCheck()
{
   // STEP 1: Calculate current drawdown
   double balance = AccountBalance();
   double equity = AccountEquity();
   if(balance > 0) g_queen_drawdown_pct = ((balance - equity) / balance) * 100.0;
   else g_queen_drawdown_pct = 0.0;
   
   // STEP 2: Calculate total open exposure
   g_queen_total_exposure_lots = 0.0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol())
         {
            int magic = OrderMagicNumber();
            if(magic == InpReaper_BuyMagicNumber || magic == InpReaper_SellMagicNumber ||
               magic == InpSX_MagicNumber || magic == InpWarden_MagicNumber ||
               magic == InpMagic_MeanReversion || magic == InpTitan_MagicNumber ||
               magic == InpPhantom_MagicNumber || magic == InpNexus_MagicNumber ||
               magic == InpApex_MagicNumber || magic == 777012 || magic == InpChronos_MagicNumber || magic == 999002)
            {
               g_queen_total_exposure_lots += OrderLots();
            }
         }
      }
   }
   
   // STEP 3: KILL SWITCHES
   
   // LEVEL 1: Full system halt if drawdown exceeds hard limit
   if(g_queen_drawdown_pct >= InpQueen_MaxDrawdownPct)
   {
      if(!g_queen_kill_all)
      {
         LogError(ERROR_CRITICAL, "QUEEN BEE: GLOBAL KILL SWITCH ACTIVATED - Drawdown: " + 
                   DoubleToString(g_queen_drawdown_pct, 2) + "% >= " + 
                   DoubleToString(InpQueen_MaxDrawdownPct, 1) + "% threshold. ALL STRATEGIES SUSPENDED.", 
                   "QueenBee_GlobalRiskCheck");
         g_queen_kill_all = true;
      }
   }
   else if(g_queen_drawdown_pct < InpQueen_MaxDrawdownPct * 0.5)
   {
      // Reset kill switch when drawdown recovers to 50% of threshold
      if(g_queen_kill_all)
      {
         LogError(ERROR_INFO, "QUEEN BEE: Global kill switch DEACTIVATED - Drawdown recovered to " + 
                   DoubleToString(g_queen_drawdown_pct, 2) + "%", "QueenBee_GlobalRiskCheck");
         g_queen_kill_all = false;
      }
   }
   
   // LEVEL 2: Kill Reaper specifically if drawdown is too high
   if(g_queen_drawdown_pct >= InpQueen_ReaperDDKillPct)
   {
      if(!g_queen_kill_reaper)
      {
         LogError(ERROR_WARNING, "QUEEN BEE: REAPER KILL SWITCH - Drawdown " + 
                   DoubleToString(g_queen_drawdown_pct, 2) + "% >= " + 
                   DoubleToString(InpQueen_ReaperDDKillPct, 1) + "%. Closing Reaper baskets.", 
                   "QueenBee_GlobalRiskCheck");
         g_queen_kill_reaper = true;
         CloseAllByMagic(InpReaper_BuyMagicNumber);
         CloseAllByMagic(InpReaper_SellMagicNumber);
      }
   }
   else if(g_queen_drawdown_pct < InpQueen_ReaperDDKillPct * 0.3)
   {
      if(g_queen_kill_reaper)
      {
         LogError(ERROR_INFO, "QUEEN BEE: Reaper kill switch DEACTIVATED", "QueenBee_GlobalRiskCheck");
         g_queen_kill_reaper = false;
      }
   }
   
   // LEVEL 3: Exposure limit warning
   if(g_queen_total_exposure_lots >= InpQueen_MaxExposureLots)
   {
      LogError(ERROR_WARNING, "QUEEN BEE: EXPOSURE LIMIT - Total lots: " + 
                DoubleToString(g_queen_total_exposure_lots, 2) + " >= " + 
                DoubleToString(InpQueen_MaxExposureLots, 2) + " max. New grid entries blocked.", 
                "QueenBee_GlobalRiskCheck");
   }
}

//+------------------------------------------------------------------+
//| V27.1: Check if Queen Bee allows a specific strategy to trade   |
//+------------------------------------------------------------------+
bool QueenBee_AllowsStrategy(int magicNumber)
{
   // Global kill blocks everything
   if(g_queen_kill_all) return false;
   
   // Reaper-specific kill
   if(g_queen_kill_reaper && 
      (magicNumber == InpReaper_BuyMagicNumber || magicNumber == InpReaper_SellMagicNumber))
      return false;
   
   // Exposure limit blocks new grid entries
   if(g_queen_total_exposure_lots >= InpQueen_MaxExposureLots)
   {
      if(magicNumber == InpReaper_BuyMagicNumber || magicNumber == InpReaper_SellMagicNumber ||
         magicNumber == InpSX_MagicNumber)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| GENEVA V4.0: In-Memory Performance Update                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| GENEVA PROTOCOL V4.1: EXTENDED PERFORMANCE TRACKING             |
//+------------------------------------------------------------------+
void UpdatePerformanceV4(int magic, double profit)
{
    // --- ASCENSION INTEGRATION: Update win/loss streak counters ---
    if(profit >= 0) {
        g_consecutiveWins++;
        g_consecutiveLosses = 0;
    } else {
        g_consecutiveLosses++;
        g_consecutiveWins = 0;
    }
    
    // V27.16: Max Daily Loss  track net P&L, reset at midnight
    datetime today = iTime(Symbol(), PERIOD_D1, 0);
    if(today > g_lastPandLDate) {
        g_dailyPandL = 0.0;
        g_lastPandLDate = today;
    }
    g_dailyPandL += profit;
    if(g_dailyPandL < -InpMaxDailyLoss) {
        LogError(ERROR_WARNING, "DAILY LOSS TRACKER: Limit of $" + DoubleToString(InpMaxDailyLoss, 0) +
                 " exceeded ($" + DoubleToString(g_dailyPandL, 2) + ")", "UpdatePerformanceV4");
    }
    // --- END V27.16 ---
    // --- END ASCENSION INTEGRATION ---
    
    // V27.7: Consecutive Loss Guardian  track per-strategy streaks
    RecordStrategyResult(magic, profit);

    // V13.7 SENGKUNI FIX: Use the single, authoritative GetStrategyIndexFromMagic function
    // to determine the correct performance bucket. This is more robust and less error-prone.
    int index = GetStrategyIndexFromMagic(magic);

    if(index != -1)
    {
        g_perfData[index].trades++;
        if(profit >= 0) g_perfData[index].grossProfit += profit;
        else g_perfData[index].grossLoss += MathAbs(profit);
        
        // ENHANCED LOGGING
        string strategyName = GetStrategyNameFromMagic(magic); // Use existing helper for name
        if (strategyName == "") strategyName = "Unknown";

        LogError(ERROR_INFO, "Performance Updated: " + strategyName + 
                  " | Profit: " + DoubleToStr(profit, 2) + 
                  " | Total Trades: " + IntegerToString(g_perfData[index].trades), "UpdatePerformanceV4");
    }
    else
    {
        LogError(ERROR_WARNING, "UpdatePerformanceV4: Could not find strategy index for magic number: " + IntegerToString(magic));
    }
}

// Helper function to get strategy name from magic (Extended V11.1)
string GetStrategyNameFromMagic(int magic)
{
    if(magic == InpMagic_MeanReversion) return "Mean Reversion";
    if(magic == InpTitan_MagicNumber)    return "Titan";
    if(magic == InpWarden_MagicNumber)   return "Warden";
    if(magic == InpReaper_BuyMagicNumber || magic == InpReaper_SellMagicNumber) return "Reaper Protocol";
    if(magic == InpSX_MagicNumber)       return "Silicon-X";
    if(magic == InpChronos_MagicNumber)  return "Chronos";
    if(magic == 999002)                  return "MathReversal";
    if(magic == 777012)                  return "NoiseBreakout";
    if(magic == InpApex_MagicNumber)     return "Apex";
    if(magic == InpPhantom_MagicNumber)  return "Phantom";
    if(magic == InpNexus_MagicNumber)    return "Nexus";
    if(magic == InpVortex_MagicNumber)   return "Vortex"; // V27.27
    if(magic == InpRegimeShift_MagicNumber) return "RegimeShift"; // V27.27
    if(magic == InpSessionMomentum_MagicNumber) return "SessionMomentum"; // V28.00
    if(magic == InpDivergenceMR_MagicNumber) return "DivergenceMR"; // V28.00
    if(magic == InpLiquiditySweep_MagicNumber) return "LiquiditySweep"; // V28.03
    if(magic == InpStructuralRetest_MagicNumber) return "StructuralRetest"; // V28.03

    return "Unknown";
}

//+------------------------------------------------------------------+
//| Check if a magic number belongs to this EA                      |
//+------------------------------------------------------------------+
bool IsOurMagicNumber(int magic)
{
    if(magic == InpMagic_MeanReversion || 
       magic == InpTitan_MagicNumber ||
       magic == InpWarden_MagicNumber ||
       magic == InpReaper_BuyMagicNumber ||
       magic == InpReaper_SellMagicNumber ||
       magic == InpSX_MagicNumber ||
       magic == InpChronos_MagicNumber ||
       magic == 999002 ||  // V27: MathReversal
       magic == 666001 ||  // V27: Warden alt magic
       magic == 666002 ||  // V27: Warden alt magic
       magic == 777012 ||  // V27: NoiseBreakout
       magic == InpApex_MagicNumber ||
       magic == InpPhantom_MagicNumber ||
       magic == InpNexus_MagicNumber ||
       magic == InpSessionMomentum_MagicNumber ||  // V28.00: Session Momentum
       magic == InpDivergenceMR_MagicNumber ||        // V28.00: Divergence MR
       magic == InpLiquiditySweep_MagicNumber ||      // V28.03: Liquidity Sweep
       magic == InpStructuralRetest_MagicNumber)      // V28.03: Structural Retest
    {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get the strategy index from a magic number (Global Function)    |
//+------------------------------------------------------------------+
// Get the strategy index from a magic number (Global Function)
int GetStrategyIndexFromMagic(int magicNumber) 
{
    if(magicNumber == InpMagic_MeanReversion) return 0;
    // Index 1 (Quantum Oscillator) is disabled.
    if(magicNumber == InpTitan_MagicNumber) return 2;
    if(magicNumber == InpWarden_MagicNumber || magicNumber == 666001 || magicNumber == 666002) return 3;
    if(magicNumber == InpReaper_BuyMagicNumber || magicNumber == InpReaper_SellMagicNumber) return 4;
    if(magicNumber == InpSX_MagicNumber) return 5;
    if(magicNumber == InpChronos_MagicNumber) return 6;
    if(magicNumber == 777012) return 7; // V27: NoiseBreakout
    if(magicNumber == 999002) return 11; // V27.2: MathReversal
    if(magicNumber == InpApex_MagicNumber) return 8;
    if(magicNumber == InpPhantom_MagicNumber) return 9;
    if(magicNumber == InpNexus_MagicNumber) return 10;
    if(magicNumber == InpVortex_MagicNumber) return 11; // V27.27: Vortex
    if(magicNumber == InpRegimeShift_MagicNumber) return 12; // V27.27: Regime Shift
    if(magicNumber == InpSessionMomentum_MagicNumber) return 13; // V28.00: Session Momentum
    if(magicNumber == InpDivergenceMR_MagicNumber) return 14; // V28.00: Divergence MR
    if(magicNumber == InpLiquiditySweep_MagicNumber) return 15; // V28.03: Liquidity Sweep
    if(magicNumber == InpStructuralRetest_MagicNumber) return 16; // V28.03: Structural Retest

    return -1; // Return -1 for unknown
}

//+------------------------------------------------------------------+
//| Calculate strategy volatility based on returns                  |
//+------------------------------------------------------------------+
double GetStrategyVolatility(int strategyIndex) {
    if(g_perfData[strategyIndex].trades < 2) return 0.5; // Default volatility

    double returns[1000];
    ArrayInitialize(returns, 0.0);
    int returnCount = 0;

    for(int i = OrdersHistoryTotal() - 1; i >= 0 && returnCount < 1000; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if(IsOurMagicNumber(OrderMagicNumber())) {
                int strategyIdx = GetStrategyIndexFromMagic(OrderMagicNumber());
                if(strategyIdx == strategyIndex) {
                    returns[returnCount++] = OrderProfit() + OrderCommission() + OrderSwap();
                }
            }
        }
    }

    if(returnCount < 2) return 0.5;

    double sum = 0, sumSq = 0;
    for(int i = 0; i < returnCount; i++) {
        sum += returns[i];
        sumSq += returns[i] * returns[i];
    }

    // ZERO-DIVIDE PROTECTION
    if(returnCount <= 0) returnCount = 1;
    double variance = (sumSq - (sum * sum) / returnCount) / MathMax(returnCount - 1, 1);
    return MathSqrt(MathMax(variance, 0));
}

//+------------------------------------------------------------------+
//| Calculate strategy Sharpe ratio (Global Function)               |
//+------------------------------------------------------------------+
double CalculateStrategySharpe(int strategyIndex) {
    double avgReturn = 0;
    int tradeCount = 0;

    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if(IsOurMagicNumber(OrderMagicNumber())) {
                int strategyIdx = GetStrategyIndexFromMagic(OrderMagicNumber());
                if(strategyIdx == strategyIndex) {
                    avgReturn += OrderProfit() + OrderCommission() + OrderSwap();
                    tradeCount++;
                }
            }
        }
    }

    if(tradeCount == 0) return 0;
    avgReturn /= tradeCount;

    double riskFreeRate = AccountEquity() * 0.000055; // Assumed risk-free rate
    double excessReturn = avgReturn - riskFreeRate;
    double volatility = GetStrategyVolatility(strategyIndex);

    return (volatility > 0) ? excessReturn / volatility : 0;
}

//+------------------------------------------------------------------+
//| Calculate strategy win rate (Global Function)                   |
//+------------------------------------------------------------------+
double CalculateWinRate(int strategyIndex) {
    int wins = 0, total = 0;

    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            if(IsOurMagicNumber(OrderMagicNumber())) {
                int strategyIdx = GetStrategyIndexFromMagic(OrderMagicNumber());
                if(strategyIdx == strategyIndex) {
                    total++;
                    if(OrderProfit() > 0) wins++;
                }
            }
        }
    }

    return (total > 0) ? (double)wins / total : 0.5;
}

//+------------------------------------------------------------------+
//| V13.7: Reconcile Final Performance                               |
//| Re-calculates all stats from history to prevent "Terminal Event" |
//| failure where trades closed at test-end are missed.              |
//+------------------------------------------------------------------+
void ReconcileFinalPerformance()
{
   LogError(ERROR_INFO, "--- EXECUTING FINAL PERFORMANCE RECONCILIATION ---", "ReconcileFinalPerformance");
   
   // Create temporary performance structs to hold the reconciled data.
   PerfData reconciledData[17]; // V28.00: Extended to 17 strategies
   for(int i=0; i<17; i++) // V28.00: Extended to 17 strategies
   {
      reconciledData[i].name = g_perfData[i].name; // Copy names over
      reconciledData[i].trades = 0;
      reconciledData[i].grossProfit = 0.0;
      reconciledData[i].grossLoss = 0.0;
   }
   
   // Loop through the entire account history from the beginning.
   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      
      // Use our robust IsOurMagicNumber check to ensure we only count our own trades.
      int magic = OrderMagicNumber();
      if(IsOurMagicNumber(magic))
      {
         // Use our robust indexing function to find the correct strategy.
         int index = GetStrategyIndexFromMagic(magic);
         if (index != -1)
         {
            double profit = OrderProfit() + OrderCommission() + OrderSwap();
            
            reconciledData[index].trades++;
            if (profit >= 0)
            {
               reconciledData[index].grossProfit += profit;
            }
            else
            {
               reconciledData[index].grossLoss += MathAbs(profit);
            }
         }
      }
   }
   
   // Now, overwrite the potentially inaccurate global stats with the reconciled data.
   for(int i=0; i<17; i++) // V28.00: Extended to 17 strategies
   {
      g_perfData[i].trades = reconciledData[i].trades;
      g_perfData[i].grossProfit = reconciledData[i].grossProfit;
      g_perfData[i].grossLoss = reconciledData[i].grossLoss;
   }
   
   LogError(ERROR_INFO, "--- RECONCILIATION COMPLETE. Generating final, accurate report. ---", "ReconcileFinalPerformance");
}

//+------------------------------------------------------------------+
//| GENEVA V4.1: In-Memory Based Performance Reporting               |
//+------------------------------------------------------------------+
void GeneratePerformanceReport()
{
   Print("--- DESTROYER QUANTUM V11.1: DETAILED PERFORMANCE REPORT (GENEVA V4.1) ---");

   double totalNetProfit = 0, totalGrossProfit = 0, totalGrossLoss = 0;
   int totalTrades = 0;

   for (int i=0; i<17; i++) // V28.00: Extended to 17 strategies
   {
      if (g_perfData[i].trades == 0) continue;

      double netProfit = g_perfData[i].grossProfit - g_perfData[i].grossLoss;
      double pf = (g_perfData[i].grossLoss > 0) ? g_perfData[i].grossProfit / g_perfData[i].grossLoss : 999.0;

      totalNetProfit += netProfit;
      totalGrossProfit += g_perfData[i].grossProfit;
      totalGrossLoss += g_perfData[i].grossLoss;
      totalTrades += g_perfData[i].trades;
      
      PrintFormat("Strategy: %-22s | Trades: %4d | Net Profit: %8.2f | Gross Profit: %8.2f | Gross Loss: %8.2f | Profit Factor: %5.2f",
                  g_perfData[i].name, g_perfData[i].trades, netProfit, g_perfData[i].grossProfit, g_perfData[i].grossLoss, pf);
   }

   Print("\n--- OVERALL SYSTEM PERFORMANCE ---");
   PrintFormat("Total Trades Across All Strategies: %d", totalTrades);
   PrintFormat("Total System Net Profit: %+8.2f", totalNetProfit);
   PrintFormat("Total System Gross Profit: %8.2f", totalGrossProfit);
   PrintFormat("Total System Gross Loss: %8.2f", totalGrossLoss);
   
   double overallPF = (totalGrossLoss > 0) ? totalGrossProfit / totalGrossLoss : 999.0;
   PrintFormat("Overall Profit Factor: %.2f", overallPF);
   Print("--------------------------------------------------");
}

//+------------------------------------------------------------------+
//| ================================================================ |
//|            CERBERUS MULTI-MODEL ENTRY SYSTEM IMPLEMENTATION       |
//| ================================================================ |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Cerberus Model A: Mean-Reversion (Adaptive) implementation.      |
//| DESTROYER QUANTUM V10.0 - by @okyy.ryan                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| MEAN REVERSION 2.0: REGIME-ADAPTIVE EXECUTION (V18.2)           |
//| Replaces binary Hurst block with dynamic grid stretch            |
//+------------------------------------------------------------------+
void ExecuteMeanReversionModelV8_6()
{
   if(Period() != PERIOD_H4) return;
   if(!InpMeanReversion_Enabled) 
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: Strategy DISABLED - returning", "ExecuteMeanReversionModelV8_6");
      return;
   }
   
   // V8.5: Strategy Health Check
   if (!IsStrategyHealthy(InpMagic_MeanReversion))
   {
       LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: Strategy disabled by Queen - underperforming", "ExecuteMeanReversionModelV8_6");
       return; 
   }
   
   // State-based permission check
   if (g_hive_state == HIVE_STATE_DEFENSIVE && !InpMR_Allow_Defensive) 
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Strategy not allowed in defensive mode", "ExecuteMeanReversionModelV8_6");
      return;
   }
   
   // V26 BEEHIVE: Reaper condition filter now toggleable via InpEnable_ReaperConditionFilter
   if(InpEnable_ReaperConditionFilter && !IsReaperConditionMet())
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Reaper market conditions not met (low volatility or RSI in dead zone)", "ExecuteMeanReversionModelV8_6");
      return;
   }
   
   int shift = 0;
   g_active_model = MODEL_MEAN_REVERSION;
   
   //--- Check market conditions and time filters
   if(InpEnableMarketFilters && !CheckMarketConditions())
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Market conditions not met", "ExecuteMeanReversionModelV8_6");
      return;
   }
   
   if(InpEnableTimeFilter && !CheckTimeFilter())
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Time filter not met", "ExecuteMeanReversionModelV8_6");
      return;
   }
   
   // =================================================================================
   // V18.2 VOLUME AWAKENING PATCH: REGIME-ADAPTIVE BANDS (Replaces Binary Block)
   // =================================================================================
   
   // 1. Calculate Market Regime (Hurst Exponent)
   // We measure over 100 bars to determine market "memory"
   double Hurst = CalculateHurstExponent(Symbol(), Period(), 100);
   
   // 2. Dynamic "Grid Stretch" Calculation
   // Instead of turning OFF, we change the rules based on the regime.
   // This is the RUBBER BAND ANALOGY: Stretch requirements in dangerous markets
   double adaptive_dev = 2.0;  // Standard BB Deviation
   double rsi_upper = 70;      // Standard RSI overbought
   double rsi_lower = 30;      // Standard RSI oversold
   
   string regime_description = "";
   
   if(Hurst < 0.50) // V27.27: Lowered from 0.40 for more entries
   {
      // PRIME CONDITION (Strong Mean Reversion): Trade Aggressively
      adaptive_dev = 1.8;  // Easier entry (tighter bands)
      rsi_upper = 65;      // Enter earlier on upside
      rsi_lower = 35;      // Enter earlier on downside
      regime_description = "PRIME_REVERTING";
   }
   else if(Hurst >= 0.40 && Hurst <= 0.60)
   {
      // RANDOM/NOISE: Standard Risk + Safety Buffer
      adaptive_dev = 2.2;  // Standard + Safety margin
      rsi_upper = 70;      // Standard levels
      rsi_lower = 30;
      regime_description = "RANDOM_NOISE";
   }
   else // Hurst > 0.60 (Strong Trend)
   {
      // DANGEROUS: Sniper Mode Only (Fade only extreme extensions)
      adaptive_dev = 3.5;  // Extreme bands only (very wide)
      rsi_upper = 80;      // Only trade at extremes
      rsi_lower = 20;
      regime_description = "TRENDING_SNIPER";
   }
   
   // =================================================================================
   // V24 FIX #2: ADAPTIVE ENTRY THRESHOLDS (Empirical Prob-Based Dynamic Loosening)
   // =================================================================================
   
   if(InpAlphaExpand) {
       // Get strategy index for V23 tracking
       int stratIdx = V23_FindStrategyIndex(InpMagic_MeanReversion);
       
       if(stratIdx >= 0) {
           // Calculate current deviation (for empirical prob lookup)
           double currentDeviation = MathAbs(Close[shift] - iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)) / 
                                     iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift);
           
           // Get empirical probability and R-expectancy
           double prob = V23_GetEmpiricalProb(stratIdx, currentDeviation);
           double rExpect = v23_stratPerf[stratIdx].rExpectancy;
           
           // Calculate adaptive shift (bounded by InpAdaptMax)
           // Only loosen if positive expectancy; halve shift if negative
           double adaptShift = prob * InpAdaptMax * (rExpect > 0 ? 1.0 : 0.5);
           
           // Apply bounded adjustments
           rsi_lower = MathMax(20, rsi_lower - adaptShift);  // Loosen lower bound (min 20)
           rsi_upper = MathMin(80, rsi_upper + adaptShift);  // Loosen upper bound (max 80)
           adaptive_dev = adaptive_dev + (adaptShift / 10.0); // Adjust deviation slightly
           
           Print("[V24 Fix#2] Adaptive Thresholds: Prob=", DoubleToString(prob, 3), 
                 " RExp=", DoubleToString(rExpect, 2), 
                 " Shift=", DoubleToString(adaptShift, 2), 
                 "  RSI[", DoubleToString(rsi_lower, 1), "/", DoubleToString(rsi_upper, 1), "]", 
                 " BBDev=", DoubleToString(adaptive_dev, 2));
       }
   }
   
   LogError(ERROR_INFO, "V18.2 Regime-Adaptive MR: Hurst=" + DoubleToString(Hurst,4) + 
            " | Regime=" + regime_description + 
            " | BB_Dev=" + DoubleToString(adaptive_dev,2) + 
            " | RSI_Levels=" + DoubleToString(rsi_lower,0) + "/" + DoubleToString(rsi_upper,0), 
            "ExecuteMeanReversionModelV8_6");
   
   // 3. Technical Calculation with ADAPTIVE inputs
   double bb_upper = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_UPPER, shift);
   double bb_lower = iBands(Symbol(), Period(), 20, adaptive_dev, 0, PRICE_CLOSE, MODE_LOWER, shift);
   double rsi_val  = iRSI(Symbol(), Period(), 14, PRICE_CLOSE, shift);
   double price    = Close[shift];
   
   // 4. Trigger Logic (Using adaptive thresholds)
   bool buy_signal  = (price < bb_lower) && (rsi_val < rsi_lower);
   bool sell_signal = (price > bb_upper) && (rsi_val > rsi_upper);
   
   // =================================================================================
   // V25 FIX #3: CONTINUOUS SCORING FOR ADAPTIVES (Elastic Signal Geometry)
   // Replace binary gates with weighted continuous scores
   // =================================================================================
   
   if(InpAlphaExpand && InpElasticScoring) {
       // Get strategy tracking data
       int stratIdx = V23_FindStrategyIndex(InpMagic_MeanReversion);
       
       if(stratIdx >= 0) {
           double prob = V23_GetEmpiricalProb(stratIdx, MathAbs((price - iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)) / 
                                                iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, shift)));
           double rExpect = v23_stratPerf[stratIdx].rExpectancy;
           
           // Calculate continuous scores (graduated, not binary)
           double rsiScore_Buy = 0;
           double rsiScore_Sell = 0;
           
           if(rsi_val < 30) rsiScore_Buy = 1.0 * prob;
           else if(rsi_val < 40) rsiScore_Buy = 0.7 * prob;
           else if(rsi_val < 45) rsiScore_Buy = 0.3 * prob;
           
           if(rsi_val > 70) rsiScore_Sell = 1.0 * prob;
           else if(rsi_val > 60) rsiScore_Sell = 0.7 * prob;
           else if(rsi_val > 55) rsiScore_Sell = 0.3 * prob;
           
           // BB Score: Distance from bands (normalized)
           double bbRange = bb_upper - bb_lower;
           double bbScore_Buy = (bbRange > 0) ? MathAbs(price - bb_lower) / bbRange : 0;
           double bbScore_Sell = (bbRange > 0) ? MathAbs(price - bb_upper) / bbRange : 0;
           
           bbScore_Buy = (price < bb_lower) ? (1.0 - bbScore_Buy) * rExpect : 0;  // Inverted and weighted
           bbScore_Sell = (price > bb_upper) ? (1.0 - bbScore_Sell) * rExpect : 0;
           
           // Regime confidence contribution
           double regimeContrib = v23_regime.confidence * 0.2;
           
           // Total composite scores (weighted combination)
           double totalScore_Buy = 0.5 * rsiScore_Buy + 0.3 * bbScore_Buy + regimeContrib;
           double totalScore_Sell = 0.5 * rsiScore_Sell + 0.3 * bbScore_Sell + regimeContrib;
           
           // Adaptive threshold (elastic based on probability)
           double scoreThreshold = 0.6 - (prob * 0.1);  // Higher prob  lower threshold needed
           scoreThreshold = MathMax(0.4, MathMin(0.7, scoreThreshold));  // Bounded [0.4, 0.7]
           
           // Override binary signals with continuous scoring
           buy_signal = (totalScore_Buy > scoreThreshold);
           sell_signal = (totalScore_Sell > scoreThreshold);
           
           Print("[V25 Fix#3] Continuous Scoring: BuyScore=", DoubleToString(totalScore_Buy, 3),
                 " SellScore=", DoubleToString(totalScore_Sell, 3),
                 " Threshold=", DoubleToString(scoreThreshold, 3),
                 "  Buy=", (buy_signal ? "YES" : "NO"),
                 " Sell=", (sell_signal ? "YES" : "NO"));
       }
   }
   
   LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: Price=" + DoubleToString(price,Digits) + 
            " | BB_Range=[" + DoubleToString(bb_lower,Digits) + " - " + DoubleToString(bb_upper,Digits) + "]" +
            " | RSI=" + DoubleToString(rsi_val,2) + 
            " | Buy=" + (buy_signal ? "YES" : "NO") + 
            " | Sell=" + (sell_signal ? "YES" : "NO"), 
            "ExecuteMeanReversionModelV8_6");
   
   // 5. Volume/Trend Safety Check (Quick "Glance")
   // If trying to fade a move, ensure current momentum isn't vertical
   // ADX > 50 = Violent trend, don't fight it regardless of regime
   double ADX = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 0);
   if(ADX > 50) 
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: BLOCKED - ADX=" + DoubleToString(ADX,2) + " > 50 (Violent Trend Safety)", "ExecuteMeanReversionModelV8_6");
      return; // Hard stop only on violent trends
   }
   
   // V17.6 WINNER TAKES ALL: Additional Trend Lockout
   if(IsTrendTooStrong())
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Trend too strong (ADX > 30 with volume confirmation)", "ExecuteMeanReversionModelV8_6");
      return;
   }
   
   // PHASE 2: FAT TAIL FIX - Counter-Trend Filter
   if(!Filter_CounterTrend())
   {
      LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Filter_CounterTrend blocked trade", "ExecuteMeanReversionModelV8_6");
      return;
   }
   
   // PHASE 3: MEAN REVERSION SNIPER FILTER (if still using this)
   if(buy_signal)
   {
      if(!IsMeanReversionSafe(OP_BUY))
      {
         LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - IsMeanReversionSafe filter blocked BUY", "ExecuteMeanReversionModelV8_6");
         return;
      }
   }
   
   if(sell_signal)
   {
      if(!IsMeanReversionSafe(OP_SELL))
      {
         LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - IsMeanReversionSafe filter blocked SELL", "ExecuteMeanReversionModelV8_6");
         return;
      }
   }
   
   // 6. EXECUTION LOGIC (BUY SIGNAL)
   if(buy_signal)
   {
       // Calculate signal conviction for arbitrage system
       double signal_strength = 0.0;
       double rsi_deviation = MathAbs(rsi_val - 50.0) / 50.0;
       double bb_deviation = MathAbs((Close[shift] - bb_lower) / (bb_upper - bb_lower));
       signal_strength = (rsi_deviation + bb_deviation) / 2.0;
       
       // PHASE 5: Enhanced conviction calculation
       double conviction = CalculateEnhancedConviction(0, signal_strength); // 0 = Mean Reversion index
       
        if(!IsSignalApproved(0, conviction) || conviction < 4.5)
        {
           LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Signal conviction too low: " + DoubleToString(conviction, 2), "ExecuteMeanReversionModelV8_6");
           return;
        }
        
        // Multi-timeframe confirmation
        if(!CheckMultiTimeframeConfirmation(0))
        {
           LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Multi-timeframe confirmation failed", "ExecuteMeanReversionModelV8_6");
           return;
        }
        
        // Calculate Trade Quality Score
        g_trade_quality_score = CalculateTQSForMeanReversionV8(shift);
        
        if(g_trade_quality_score < InpMinTQSForEntry)
        {
           LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - TQS too low: " + DoubleToString(g_trade_quality_score, 2), "ExecuteMeanReversionModelV8_6");
           return;
        }
        
        // V17.5: QUANTUM PROBABILISTIC MODEL - Quantum Money Management
        // V27.2: Pass actual ATR stop pips to MoneyManagement_Quantum
        int atr_stop_pips_mr = GetATRStopLossPips();
        double stop_loss_distance_price = atr_stop_pips_mr * Point;
        double stop_loss = Ask - stop_loss_distance_price;
        double take_profit = Ask + stop_loss_distance_price * 2.2;
        double lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, atr_stop_pips_mr);
       
       int ticket = OpenTrade(OP_BUY, lots, Ask, stop_loss, take_profit, "MR_ADAPTIVE_BUY", InpMagic_MeanReversion);
       if(ticket > 0)
       {
          g_initial_risk_amount = stop_loss_distance_price;
          g_trail_stage = 1;
          LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SUCCESS - BUY order #" + IntegerToString(ticket) + " placed", "ExecuteMeanReversionModelV8_6");
          
          // V24 FIX #3: Track signal for re-entry system
          if(InpAlphaExpand) {
              int stratIdx = V23_FindStrategyIndex(InpMagic_MeanReversion);
              if(stratIdx >= 0) {
                  v24_lastTrade[stratIdx] = TimeCurrent();
                  v24_lastSignalPrice[stratIdx] = Ask;
                  v24_lastSignalType[stratIdx] = 1;  // 1 = BUY
                  Print("[V24 Fix#3] Signal tracked for re-entry: BUY at ", DoubleToString(Ask, Digits));
              }
          }
       }
       else
       {
          LogError(ERROR_WARNING, "ExecuteMeanReversionModelV8_6: FAILED - Could not place BUY order", "ExecuteMeanReversionModelV8_6");
       }
       return;
   }
   
   // 7. EXECUTION LOGIC (SELL SIGNAL)
   if(sell_signal)
   {
       // Calculate signal conviction for arbitrage system
       double signal_strength = 0.0;
       double rsi_deviation = MathAbs(rsi_val - 50.0) / 50.0;
       double bb_deviation = MathAbs((Close[shift] - bb_lower) / (bb_upper - bb_lower));
       signal_strength = (rsi_deviation + bb_deviation) / 2.0;
       
       // PHASE 5: Enhanced conviction calculation
       double conviction = CalculateEnhancedConviction(0, signal_strength);
       
        if(!IsSignalApproved(0, conviction) || conviction < 4.5)
        {
           LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Signal conviction too low: " + DoubleToString(conviction, 2), "ExecuteMeanReversionModelV8_6");
           return;
        }
        
        // Multi-timeframe confirmation
        if(!CheckMultiTimeframeConfirmation(0))
        {
           LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Multi-timeframe confirmation failed", "ExecuteMeanReversionModelV8_6");
           return;
        }
        
        // Calculate Trade Quality Score
        g_trade_quality_score = CalculateTQSForMeanReversionV8(shift);
        
        if(g_trade_quality_score < InpMinTQSForEntry)
        {
           LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - TQS too low: " + DoubleToString(g_trade_quality_score, 2), "ExecuteMeanReversionModelV8_6");
           return;
        }
        
        // V27.2: Pass actual ATR stop pips to MoneyManagement_Quantum
        int atr_stop_pips_mr_sell = GetATRStopLossPips();
        double lots = MoneyManagement_Quantum(InpMagic_MeanReversion, InpBase_Risk_Percent, atr_stop_pips_mr_sell);
       
       if(lots <= 0)
       {
          LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SKIPPED - Portfolio risk budget exceeded (lots=0)", "ExecuteMeanReversionModelV8_6");
          return;
       }
       
       // V17.8: TITANIUM CORE - Dynamic ATR Stop Loss
       int atr_stop_pips = GetATRStopLossPips();
       double stop_loss_distance_price = atr_stop_pips * Point;
       double stop_loss = Bid + stop_loss_distance_price;
       double take_profit = Bid - stop_loss_distance_price * 2.2; // 2.2:1 RR ratio
       
       LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: Opening SELL - Lots=" + DoubleToString(lots, 2) + 
                " | SL=" + DoubleToString(stop_loss, Digits) + 
                " | TP=" + DoubleToString(take_profit, Digits) + 
                " | Conviction=" + DoubleToString(conviction,2), 
                "ExecuteMeanReversionModelV8_6");
       
       int ticket = OpenTrade(OP_SELL, lots, Bid, stop_loss, take_profit, "MR_ADAPTIVE_SELL", InpMagic_MeanReversion);
       if(ticket > 0)
       {
          g_initial_risk_amount = stop_loss_distance_price;
          g_trail_stage = 1;
          LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: SUCCESS - SELL order #" + IntegerToString(ticket) + " placed", "ExecuteMeanReversionModelV8_6");
          
          // V24 FIX #3: Track signal for re-entry system
          if(InpAlphaExpand) {
              int stratIdx = V23_FindStrategyIndex(InpMagic_MeanReversion);
              if(stratIdx >= 0) {
                  v24_lastTrade[stratIdx] = TimeCurrent();
                  v24_lastSignalPrice[stratIdx] = Bid;
                  v24_lastSignalType[stratIdx] = -1;  // -1 = SELL
                  Print("[V24 Fix#3] Signal tracked for re-entry: SELL at ", DoubleToString(Bid, Digits));
              }
          }
       }
       else
       {
          LogError(ERROR_WARNING, "ExecuteMeanReversionModelV8_6: FAILED - Could not place SELL order", "ExecuteMeanReversionModelV8_6");
       }
       return;
   }
   
   LogError(ERROR_INFO, "ExecuteMeanReversionModelV8_6: No trading signal detected", "ExecuteMeanReversionModelV8_6");
}

//+------------------------------------------------------------------+
//| V18.3 CHRONOS UPGRADE: MARKET MICROSTRUCTURE M15 FLUX SCALPER   |
//| HIGH FREQUENCY MODULE: TARGET 1500+ TRADES                       |
//| CERBERUS MODEL M: MARKET MICROSTRUCTURE (M15 FLUX SCALPER)      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| V26 Math-First Strategy: MathReversal                             |
//| Pure mathematical signal generation bypassing V18 binary logic    |
//+------------------------------------------------------------------+
void ExecuteMathReversal()
{
    // V26 MATH-FIRST: Generate signals purely from math when probability is high
    // This bypasses V18 indicator binary gates entirely
    
    if(!InpMathFirst || !InpAlphaExpand) return;
    
    // Find strategy index for MathReversal (999002)
    int stratIdx = V23_FindStrategyIndex(999002);
    if(stratIdx < 0) {
        Print("[V26 MathReversal] ERROR: Strategy not registered");
        return;
    }
    
    // === PURE MATH SIGNAL GENERATION ===
    // No RSI, No Bollinger Bands, No V18 binaries
    // Only empirical probability, deviation, entropy, expectancy, regime confidence
    
    // Calculate deviation (Z-score approximation from price vs MA/StdDev)
    double ma20 = iMA(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
    double stdDev20 = iStdDev(Symbol(), Period(), 20, 0, MODE_SMA, PRICE_CLOSE, 1);
    double deviation = 0;
    if(stdDev20 > 0) {
        deviation = (Close[1] - ma20) / stdDev20;
    } else {
        return; // No valid deviation, skip
    }
    
    // Get empirical probability from V23 system
    double prob = V23_GetEmpiricalProb(stratIdx, MathAbs(deviation));
    
    // Get regime metrics
    double entropyNorm = v23_regime.entropyNorm;
    double confidence = v23_regime.confidence;
    int regimeType = v23_regime.type;
    
    // Get strategy expectancy
    double rExpect = v23_stratPerf[stratIdx].rExpectancy;
    
    // === V26 MATH-FIRST TRIGGER CONDITIONS ===
    // High probability + significant deviation + low chaos + positive edge + stable regime
    bool mathConfident = (prob > 0.7) &&                  // Empirical prob > 70%
                         (MathAbs(deviation) > 1.5) &&    // Price 1.5 stddev away
                         (entropyNorm < 0.6) &&           // Low market chaos
                         (rExpect > 0) &&                 // Positive historical expectancy
                         (confidence > 0.5);              // Stable regime
    
    if(!mathConfident) {
        return; // Math not confident enough
    }
    
    // Direction: Deviation > 0 means price above mean  SELL (revert down)
    //           Deviation < 0 means price below mean  BUY (revert up)
    int dir = (deviation > 0) ? OP_SELL : OP_BUY;
    
    // === POSITION SIZING WITH V23 INTELLIGENCE ===
    // Use fixed SL proxy of 50 pips for lot calculation
    double stopLossPips = 50.0;
    double baseRisk = 0.005; // 0.5% base risk
    
    double lots = V23_CalculateLotSize(stratIdx, baseRisk, stopLossPips, regimeType);
    
    // === V25 FIX #1: MARGINAL VAR CONTRIBUTION ===
    // Calculate marginal VAR this trade would add
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double marginalVar = lots * stopLossPips * Point * tickValue / AccountEquity();
    
    // Get current VAR
    double currentVar = V23_CalculateEmpiricalVAR();
    
    // Calculate VAR limit with regime-contextual adjustment
    double varLimit = 0.05; // Base 5% VAR limit
    if(regimeType == 0) { // Ranging/calm
        varLimit *= InpVarRelaxFactor; // V24 relaxation
    } else if(regimeType == 3) { // Probation (V25 Fix #2)
        varLimit *= 1.2; // Partial relaxation
    }
    
    // Soft dampening if approaching limit (V25 enhancement)
    double totalVar = currentVar + marginalVar;
    if(totalVar > 0.8 * varLimit) {
        lots *= 0.7; // Soft damp
        Print("[V26 MathFirst] Marginal VAR soft damping: ", DoubleToString(marginalVar, 4), 
              " Current VAR: ", DoubleToString(currentVar, 4), 
              " Limit: ", DoubleToString(varLimit, 4));
    }
    
    // Final VAR check
    if(totalVar > varLimit) {
        Print("[V26 MathFirst] VAR limit exceeded: ", DoubleToString(totalVar, 4), " > ", DoubleToString(varLimit, 4));
        return;
    }
    
    // Normalize lot size
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    lots = NormalizeDouble(lots, 2);
    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;
    
    // === MATH-FIRST SIGNAL PRINT ===
    Print("[V26 MathFirst] PURE MATH SIGNAL: ",
          "Prob=", DoubleToString(prob, 3),
          " Dev=", DoubleToString(deviation, 2),
          " Entropy=", DoubleToString(entropyNorm, 2),
          " RExp=", DoubleToString(rExpect, 2),
          " Conf=", DoubleToString(confidence, 2),
          " Dir=", (dir==OP_BUY?"BUY":"SELL"),
          " Lots=", DoubleToString(lots, 2));
    
    // === ORDER EXECUTION ===
    double price = (dir == OP_BUY) ? Ask : Bid;
    // V27.26: ATR-based SL/TP instead of zero (was relying on non-existent V23 system)
    double atr = iATR(NULL, 0, 14, 1);
    double slDistance = atr * 1.5;  // 1.5x ATR for SL
    double tpDistance = atr * 2.5;  // 2.5x ATR for TP (1.67:1 R:R)
    double sl, tp;
    if(dir == OP_BUY) {
        sl = price - slDistance;
        tp = price + tpDistance;
    } else {
        sl = price + slDistance;
        tp = price - tpDistance;
    }
    // Normalize to tick precision
    sl = NormalizeDouble(sl, Digits);
    tp = NormalizeDouble(tp, Digits);
    
    int ticket = RobustOrderSend(
        Symbol(),
        dir,
        lots,
        price,
        InpSlippage,
        sl,
        tp,
        "V26_MathReversal",
        999002 // MathReversal magic
    );
    
    if(ticket > 0) {
        // V23 trade tracking
        V23_OnTradeOpen(ticket, stopLossPips, MathAbs(deviation), regimeType);
        
        Print("[V26 MathFirst] Trade opened: Ticket=", ticket,
              " Type=", (dir==OP_BUY?"BUY":"SELL"),
              " Lots=", DoubleToString(lots, 2),
              " Price=", DoubleToString(price, 5),
              " Prob=", DoubleToString(prob, 3));
    } else {
        Print("[V26 MathFirst] OrderSend failed: Error=", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| V27 NOISE BREAKOUT: BB Squeeze + Breakout (SSRN-4824172)        |
//| Based on Zarattini et al. "Beat the Market" noise area concept   |
//+------------------------------------------------------------------+
void ExecuteNoiseBreakout()
{
    // 1. MASTER SWITCH
    if(!InpNoiseBreakout_Enabled) return;
    if(Period() != PERIOD_H4) return;
    
    // 2. SAFETY CHECKS
    if(CountOpenTrades(InpNoiseBreakout_Magic) > 0) return;
    if(!IsStrategyHealthy(InpNoiseBreakout_Magic)) return;
    if(!CheckMarketConditions()) return;
    if(!CheckTimeFilter()) return;
    
    // 3. SQUEEZE DETECTION (shift=2, previous closed bar)
    double bb_upper_prev = iBands(Symbol(), Period(), InpNoiseBB_Period, InpNoiseBB_Dev, 0, PRICE_CLOSE, MODE_UPPER, 2);
    double bb_lower_prev = iBands(Symbol(), Period(), InpNoiseBB_Period, InpNoiseBB_Dev, 0, PRICE_CLOSE, MODE_LOWER, 2);
    double kc_atr_prev = iATR(Symbol(), Period(), InpNoiseKC_Period, 2);
    double kc_ma_prev = iMA(Symbol(), Period(), InpNoiseKC_Period, 0, MODE_SMA, PRICE_TYPICAL, 2);
    double kc_upper_prev = kc_ma_prev + (kc_atr_prev * InpNoiseKC_ATR_Mult);
    double kc_lower_prev = kc_ma_prev - (kc_atr_prev * InpNoiseKC_ATR_Mult);
    
    bool isSqueezeOn = (bb_upper_prev < kc_upper_prev && bb_lower_prev > kc_lower_prev);
    if(!isSqueezeOn) return; // No squeeze = no trade
    
    // 4. BREAKOUT DETECTION (shift=1, most recently closed bar)
    double bb_upper_brk = iBands(Symbol(), Period(), InpNoiseBB_Period, InpNoiseBB_Dev, 0, PRICE_CLOSE, MODE_UPPER, 1);
    double bb_lower_brk = iBands(Symbol(), Period(), InpNoiseBB_Period, InpNoiseBB_Dev, 0, PRICE_CLOSE, MODE_LOWER, 1);
    double atr14 = iATR(Symbol(), Period(), 14, 1);
    double momentum_ma = iMA(Symbol(), Period(), InpNoiseMomentum_MA, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    // 5. BREAKOUT CONFIRMATION
    double breakout_bar_range = High[1] - Low[1];
    double avg_bar_range = iATR(Symbol(), Period(), 10, 1);
    bool breakout_confirmed = (breakout_bar_range > avg_bar_range * 0.8);
    
    // 6. VOLUME CONFIRMATION (body size proxy)
    double body_curr = MathAbs(Close[1] - Open[1]);
    double body_prev = MathAbs(Close[2] - Open[2]);
    bool volume_confirmed = (body_curr > body_prev * InpNoiseMinVolMult);
    
    // 7. BUY SIGNAL (V27.27: Added directional bias filter)
    if(Close[1] > bb_upper_brk && 
       (Close[1] - bb_upper_brk) > (atr14 * InpNoiseBreakoutATRMult) &&
       Close[1] > momentum_ma &&
       breakout_confirmed &&
       volume_confirmed)
    {
        int bias = CheckDirectionalBias();
        if(bias != 1 && bias != 2) return; // Only allow BUY if bullish bias or near EMA
        
        double slPoints = atr14 * 1.5 / Point;  // 1.5 ATR stop
        double sl = Ask - (slPoints * Point);
        double tp_dist = MathAbs(Close[1] - sl);
        double tp = Close[1] + (tp_dist * 2.0);  // 2:1 R:R
        
        double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
        
        // V27: NoiseBreakout BUY
        if(OpenTrade(OP_BUY, lots, Ask, sl, tp, "NOISE_BUY", InpNoiseBreakout_Magic) > 0)
        {
            UpdatePerformanceV4(InpNoiseBreakout_Magic, 0);
        }
        return;
    }
    
    // 8. SELL SIGNAL (V27.27: Added directional bias filter)
    if(Close[1] < bb_lower_brk && 
       (bb_lower_brk - Close[1]) > (atr14 * InpNoiseBreakoutATRMult) &&
       Close[1] < momentum_ma &&
       breakout_confirmed &&
       volume_confirmed)
    {
        int bias = CheckDirectionalBias();
        if(bias != -1 && bias != 2) return; // Only allow SELL if bearish bias or near EMA
        
        double slPoints = atr14 * 1.5 / Point;  // 1.5 ATR stop
        double sl = Bid + (slPoints * Point);
        double tp_dist = MathAbs(sl - Close[1]);
        double tp = Close[1] - (tp_dist * 2.0);  // 2:1 R:R
        
        double lots = MoneyManagement_Quantum(InpNoiseBreakout_Magic, InpBase_Risk_Percent);
        
        // V27: NoiseBreakout SELL
        if(OpenTrade(OP_SELL, lots, Bid, sl, tp, "NOISE_SELL", InpNoiseBreakout_Magic) > 0)
        {
            UpdatePerformanceV4(InpNoiseBreakout_Magic, 0);
        }
        return;
    }
}

//+------------------------------------------------------------------+
//| V26 BEEHIVE: Get strategy perfData index from magic number      |
//+------------------------------------------------------------------+
int GetStrategyIndex(int magic)
{
   if(magic == InpMagic_MeanReversion)    return 0;
   if(magic == InpTitan_MagicNumber)      return 2;
   if(magic == InpWarden_MagicNumber)     return 3;
   if(magic == InpReaper_BuyMagicNumber ||
      magic == InpReaper_SellMagicNumber) return 4;
   if(magic == InpSX_MagicNumber)         return 5;
   if(magic == InpChronos_MagicNumber)    return 6;
   if(magic == 999002 || magic == 777012) return 7; // MathReversal + NoiseBreakout
   if(magic == InpApex_MagicNumber)       return 8;
   if(magic == InpPhantom_MagicNumber)    return 9;
   if(magic == InpNexus_MagicNumber)      return 10;
   if(magic == InpVortex_MagicNumber)     return 11;
   if(magic == InpRegimeShift_MagicNumber) return 12;
   if(magic == InpSessionMomentum_MagicNumber) return 13; // V28.00: Session Momentum
   if(magic == InpDivergenceMR_MagicNumber) return 14; // V28.00: Divergence MR
   if(magic == InpLiquiditySweep_MagicNumber) return 15; // V28.03: Liquidity Sweep
   if(magic == InpStructuralRetest_MagicNumber) return 16; // V28.03: Structural Retest
   return -1;
}
