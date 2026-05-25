# SURGICAL EXPERIMENT PLAN — Crush $75K Target

## Approach
One change at a time. No more 50-change versions. Each experiment uses the EXACT original V28_06.mq4 code (commit 6b2590b) that produced $68K.

## Baseline
- **Code:** DESTROYER_QUANTUM_V28_06_ORIGINAL.mq4
- **Set:** V28_06_AGGRESSIVE_QUEEN8.set
- **Expected:** ~$68K (original) or better (with Queen unlock)

## Experiment Queue

### EXP 1: Queen 8.0 (QUEEN8.set) ← CURRENT TEST
**Change:** Queen_MaxExposureLots 2.0 → 8.0
**Theory:** Reaper's grid is choked at Level 6/8. Levels 7-8 carry 2.17 lots. Queen at 2.0 blocks them.
**Expected:** +$5K-$15K improvement
**Risk:** Low — just unlocks existing grid levels

### EXP 2: Queen 8.0 + MaxLevels 12 (QUEEN8_MAXLEVELS12.set)
**Change:** Queen 8.0 + Reaper_MaxLevels 10 → 12
**Theory:** More grid levels = more entries during extended trends
**Expected:** +$3K-$8K on top of EXP 1
**Risk:** Medium — more levels = more DD exposure

### EXP 3: Queen 8.0 + Base_Risk 2.0% (QUEEN8_RISK2.set)
**Change:** Queen 8.0 + Base_Risk_Percent 1.5 → 2.0
**Theory:** More risk per trade = more profit per winning trade
**Expected:** +$5K-$10K on top of EXP 1
**Risk:** Medium — more risk = more DD

### EXP 4: Queen 8.0 + SX Disabled (QUEEN8_SXOFF.set)
**Change:** Queen 8.0 + Silicon-X disabled
**Theory:** SX consumes Queen exposure budget while barely profitable
**Expected:** +$3K-$5K on top of EXP 1
**Risk:** Low — SX was barely profitable anyway

### EXP 5: Queen 8.0 + SX Off + Risk 2.0% (QUEEN8_SXOFF_RISK2.set)
**Change:** Queen 8.0 + SX disabled + Base_Risk 2.0%
**Theory:** Combined improvements
**Expected:** +$8K-$15K on top of EXP 1
**Risk:** Medium-High — multiple changes

## Testing Order
1. Run EXP 1 (Queen 8.0)
2. If better than $68K → Run EXP 4 (add SX off)
3. If EXP 4 better → Run EXP 3 (add Risk 2.0%)
4. If EXP 3 better → We're close to $75K
5. If any experiment is worse → Revert and try next

## Results Tracking

| Experiment | Profit | PF | DD | Trades | Notes |
|------------|--------|-----|-----|--------|-------|
| Baseline (Aggressive) | $68,938 | 1.89 | 26% | 582 | Original |
| EXP 1: Queen 8.0 | TBD | | | | |
| EXP 2: +MaxLevels 12 | TBD | | | | |
| EXP 3: +Risk 2.0% | TBD | | | | |
| EXP 4: +SX Off | TBD | | | | |
| EXP 5: Nuclear | TBD | | | | |

## VENI VIDI VICI
