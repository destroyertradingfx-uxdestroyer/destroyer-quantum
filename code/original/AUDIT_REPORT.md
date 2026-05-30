# V28.06 VENDETTA — FULL AUDIT REPORT
# Date: 2026-05-28
# File: DESTROYER_QUANTUM_V28_06_VENDETTA_64k.mq4 (14,514 lines)

## CRITICAL FINDING: 4 INDEXING FUNCTIONS WITH COMPLETELY DIFFERENT MAPPINGS

### Function 1: GetStrategyIndexFromMagic (line 5859)
- Used by: ReconcileFinalPerformance, GetStrategyVolatility, GetStrategySharpe, CalculateWinRate, Elite systems
- Indices: MR=0, Titan=2, Warden=3, Reaper=4, SX=5, Chronos=6, Noise=7, Apex=8, Phantom=9, Nexus=10, MathReversal=11, Vortex=11(!), Regime=12, SM=13, DMR=14, LS=15, SR=16
- BUG: MathReversal(999002) and Vortex both return 11 (COLLISION)

### Function 2: GetStrategyIndex (line 6733)
- Used by: Apex, Phantom, Nexus, Vortex, RegimeShift, SessionMomentum, DivergenceMR, LiquiditySweep, StructuralRetest execution functions
- Indices: MR=0, Titan=2, Warden=3, Reaper=4, SX=5, Chronos=6, MathReversal+Noise=7, Apex=8, Phantom=9, Nexus=10, Vortex=11, Regime=12, SM=13, DMR=14, LS=15, SR=16
- BUG: 999002 and 777012 both return 7 (MathReversal grouped with NoiseBreakout)

### Function 3: GetStrategyIndexByMagic (line 14280)
- Used by: RecordStrategyResult (Consecutive Loss Guardian)
- Indices: Reaper=0, SX=1, Warden=2, Titan=3, MR=4, Phantom=5, Noise=6, Nexus=7, Apex=8, Chronos=9, Vortex=10, Regime=11, SM=12, DMR=13, LS=14, SR=15
- COMPLETELY DIFFERENT ORDER from Functions 1 and 2
- This is the ROOT CAUSE of the $64K→$37K regression

### Function 4: V23_FindStrategyIndex (line 13806)
- Used by: V23_RegisterStrategy, V23 system
- Dynamic lookup via v23_stratCount loop
- Separate from static [17] arrays

### INDEX MISMATCH TABLE

| Strategy      | Func1 (5859) | Func2 (6733) | Func3 (14280) | Match? |
|---------------|-------------|-------------|--------------|--------|
| MeanReversion | 0           | 0           | 4            | ❌     |
| Titan         | 2           | 2           | 3            | ❌     |
| Warden        | 3           | 3           | 2            | ❌     |
| Reaper        | 4           | 4           | 0            | ❌     |
| SX            | 5           | 5           | 1            | ❌     |
| Chronos       | 6           | 6           | 9            | ❌     |
| NoiseBreakout | 7           | 7           | 6            | ❌     |
| Apex          | 8           | 8           | 8            | ✅     |
| Phantom       | 9           | 9           | 5            | ❌     |
| Nexus         | 10          | 10          | 7            | ❌     |
| MathReversal  | 11(!)       | 7(!)        | -1           | ❌     |
| Vortex        | 11(!)       | 11          | 10           | ❌     |
| RegimeShift   | 12          | 12          | 11           | ❌     |
| SessionMom    | 13          | 13          | 12           | ❌     |
| DivergenceMR  | 14          | 14          | 13           | ❌     |
| LiqSweep      | 15          | 15          | 14           | ❌     |
| StructRetest  | 16          | 16          | 15           | ❌     |

### ARRAY SIZE MISMATCHES

| Array                  | Size | Expected | Issue? |
|------------------------|------|----------|--------|
| g_perfData             | [17] | [17]     | ✅     |
| g_strategyMultiplier   | [17] | [17]     | ✅     |
| g_consecLossTracker    | [17] | [17]     | ✅     |
| g_strategyLockoutUntil | [15] | [17]     | ❌ TOO SMALL |

### MAGIC NUMBER COLLISIONS

- MathReversal (999002) and Vortex share index 11 in GetStrategyIndexFromMagic
- MathReversal (999002) and NoiseBreakout (777012) share index 7 in GetStrategyIndex

### CONSOLIDATION PLAN

Create ONE function: `int DQ_GetStrategyIdx(int magic)`
- Single source of truth for ALL systems
- Consistent indices 0-16 (17 strategies)
- Every caller (Guardian, Reconcile, Dashboard, RecordStrategyResult, execution functions) uses this one function
- Fix g_strategyLockoutUntil to [17]
- Fix MathReversal/Vortex collision
