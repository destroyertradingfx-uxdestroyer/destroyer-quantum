#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Genetic Algorithm Optimizer
Optimizes strategy parameters using evolutionary algorithms.
"""

import pandas as pd
import numpy as np
import json
import sys
import random
import copy
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')


def load_data(filepath):
    df = pd.read_csv(filepath)
    df.columns = [c.lower().strip() for c in df.columns]
    
    time_col = None
    for c in df.columns:
        if 'datetime' in c or 'time' in c or 'date' in c:
            time_col = c
            break
    
    if time_col:
        df = df.rename(columns={time_col: 'time'})
        df['time'] = pd.to_datetime(df['time'], utc=True)
        df['hour'] = df['time'].dt.hour
        df['dayofweek'] = df['time'].dt.dayofweek
    
    for col in ['open', 'high', 'low', 'close']:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    
    return df.dropna(subset=['open', 'high', 'low', 'close'])


def calculate_rsi(prices, period):
    delta = prices.diff()
    gain = delta.where(delta > 0, 0).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))


# Parameter search space
PARAM_SPACE = {
    # Mean Reversion
    'mr_bb_period': (10, 30, 1),      # min, max, step
    'mr_bb_dev': (1.5, 2.5, 0.1),
    'mr_rsi_period': (7, 21, 1),
    'mr_rsi_os': (20, 40, 5),
    'mr_rsi_ob': (60, 80, 5),
    'mr_sl_atr': (1.0, 3.0, 0.25),
    'mr_tp_atr': (0.5, 2.0, 0.25),
    
    # Momentum
    'mom_rsi_period': (7, 21, 1),
    'mom_rsi_buy': (50, 65, 5),
    'mom_rsi_sell': (35, 50, 5),
    'mom_sma_period': (10, 50, 5),
    'mom_sl_atr': (1.0, 3.0, 0.25),
    'mom_tp_atr': (1.0, 4.0, 0.25),
    
    # Breakout
    'bo_atr_ratio': (1.2, 2.0, 0.1),
    'bo_sl_atr': (1.0, 3.0, 0.25),
    'bo_tp_atr': (1.5, 4.0, 0.25),
    
    # Gap Fill
    'gf_min_gap': (3, 15, 1),
    'gf_max_gap': (20, 50, 5),
    'gf_sl_mult': (1.5, 3.0, 0.5),
    'gf_tp_mult': (0.5, 1.5, 0.1),
    
    # Risk
    'risk_pct': (0.5, 3.0, 0.5),
    'max_concurrent': (1, 5, 1),
}


class Individual:
    """An individual in the genetic algorithm."""
    
    def __init__(self, params=None):
        if params is None:
            self.params = self.random_params()
        else:
            self.params = params
        self.fitness = None
        self.results = None
    
    def random_params(self):
        """Generate random parameters."""
        params = {}
        for key, (min_val, max_val, step) in PARAM_SPACE.items():
            if isinstance(min_val, int):
                params[key] = random.randint(min_val, max_val)
            else:
                steps = int((max_val - min_val) / step)
                params[key] = min_val + random.randint(0, steps) * step
                params[key] = round(params[key], 2)
        return params
    
    def mutate(self, mutation_rate=0.1):
        """Mutate parameters."""
        for key, (min_val, max_val, step) in PARAM_SPACE.items():
            if random.random() < mutation_rate:
                if isinstance(min_val, int):
                    self.params[key] = random.randint(min_val, max_val)
                else:
                    steps = int((max_val - min_val) / step)
                    self.params[key] = min_val + random.randint(0, steps) * step
                    self.params[key] = round(self.params[key], 2)
    
    def crossover(self, other):
        """Crossover with another individual."""
        child_params = {}
        for key in PARAM_SPACE:
            if random.random() < 0.5:
                child_params[key] = self.params[key]
            else:
                child_params[key] = other.params[key]
        return Individual(child_params)


def run_backtest(df, params, spread_pips=21.0, initial_deposit=10000.0):
    """Run backtest with given parameters."""
    equity = initial_deposit
    open_trades = []
    closed_trades = []
    
    # Precompute tr and gap columns
    df = df.copy()
    tr_list = [0.0]
    for i in range(1, len(df)):
        h = df.iloc[i]['high']
        l = df.iloc[i]['low']
        c_prev = df.iloc[i-1]['close']
        tr_list.append(max(h - l, abs(h - c_prev), abs(l - c_prev)))
    df['tr'] = tr_list
    df['gap'] = df['open'] - df['close'].shift(1)
    df['gap_pips'] = df['gap'] * 10000
    
    min_bars = max(params['mr_bb_period'], params['mom_sma_period'], 14) + 1
    
    for idx in range(min_bars, len(df)):
        row = df.iloc[idx]
        prev = df.iloc[idx - 1]
        
        # Calculate indicators
        closes = df['close'].iloc[:idx+1]
        
        # ATR
        atr = df['atr_14'].iloc[idx]
        if np.isnan(atr) or atr == 0:
            atr = 0.001
        
        # RSI
        mr_period = min([7, 10, 14, 21], key=lambda p: abs(p - params['mr_rsi_period']))
        mom_period = min([7, 10, 14, 21], key=lambda p: abs(p - params['mom_rsi_period']))
        mr_rsi = df[f'rsi_{mr_period}'].iloc[idx]
        mom_rsi = df[f'rsi_{mom_period}'].iloc[idx]
        if np.isnan(mr_rsi): mr_rsi = 50
        if np.isnan(mom_rsi): mom_rsi = 50
        
        # BB for Mean Reversion
        bb_sma = df['close'].iloc[max(0,idx-params['mr_bb_period']+1):idx+1].mean()
        bb_std = df['close'].iloc[max(0,idx-params['mr_bb_period']+1):idx+1].std()
        if np.isnan(bb_std) or bb_std == 0:
            bb_std = 0.001
        upper_bb = bb_sma + bb_std * params['mr_bb_dev']
        lower_bb = bb_sma - bb_std * params['mr_bb_dev']
        
        # SMA for Momentum
        mom_sma = df['close'].iloc[max(0,idx-params['mom_sma_period']+1):idx+1].mean()
        if np.isnan(mom_sma):
            mom_sma = row['close']
        
        # ATR ratio for Breakout
        atr_ratio = df['tr'].iloc[idx] / atr if atr > 0 else 1.0
        if np.isnan(atr_ratio) or np.isinf(atr_ratio):
            atr_ratio = 1.0
        
        # ---- EXIT LOGIC ----
        for trade in list(open_trades):
            exited = False
            
            if trade['direction'] == 'BUY':
                if row['low'] <= trade['sl']:
                    trade['exit'] = trade['sl']
                    exited = True
                elif row['high'] >= trade['tp']:
                    trade['exit'] = trade['tp']
                    exited = True
            else:
                if row['high'] >= trade['sl']:
                    trade['exit'] = trade['sl']
                    exited = True
                elif row['low'] <= trade['tp']:
                    trade['exit'] = trade['tp']
                    exited = True
            
            if exited:
                if trade['direction'] == 'BUY':
                    trade['pnl'] = (trade['exit'] - trade['entry']) * trade['lots'] * 100000
                else:
                    trade['pnl'] = (trade['entry'] - trade['exit']) * trade['lots'] * 100000
                trade['pnl'] -= spread_pips * trade['lots'] * 10
                equity += trade['pnl']
                open_trades.remove(trade)
                closed_trades.append(trade)
        
        # ---- ENTRY LOGIC ----
        if len(open_trades) >= params['max_concurrent']:
            continue
        
        active_strategies = [t['strategy'] for t in open_trades]
        
        # Mean Reversion
        if 'mean_reversion' not in active_strategies:
            if mr_rsi < params['mr_rsi_os'] and row['close'] < lower_bb:
                entry = row['close']
                sl = entry - atr * params['mr_sl_atr']
                tp = entry + atr * params['mr_tp_atr']
                lots = (equity * params['risk_pct'] / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                
                open_trades.append({
                    'strategy': 'mean_reversion', 'direction': 'BUY',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                })
            elif mr_rsi > params['mr_rsi_ob'] and row['close'] > upper_bb:
                entry = row['close']
                sl = entry + atr * params['mr_sl_atr']
                tp = entry - atr * params['mr_tp_atr']
                lots = (equity * params['risk_pct'] / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                
                open_trades.append({
                    'strategy': 'mean_reversion', 'direction': 'SELL',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                })
        
        # Momentum
        if 'momentum' not in active_strategies:
            if mom_rsi > params['mom_rsi_buy'] and row['close'] > mom_sma:
                entry = row['close']
                sl = entry - atr * params['mom_sl_atr']
                tp = entry + atr * params['mom_tp_atr']
                lots = (equity * params['risk_pct'] / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                
                open_trades.append({
                    'strategy': 'momentum', 'direction': 'BUY',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                })
            elif mom_rsi < params['mom_rsi_sell'] and row['close'] < mom_sma:
                entry = row['close']
                sl = entry + atr * params['mom_sl_atr']
                tp = entry - atr * params['mom_tp_atr']
                lots = (equity * params['risk_pct'] / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                
                open_trades.append({
                    'strategy': 'momentum', 'direction': 'SELL',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                })
        
        # Breakout
        if 'breakout' not in active_strategies:
            if atr_ratio > params['bo_atr_ratio']:
                if row['close'] > row['open']:
                    entry = row['close']
                    sl = entry - atr * params['bo_sl_atr']
                    tp = entry + atr * params['bo_tp_atr']
                    lots = (equity * params['risk_pct'] / 100) / (atr * 100000)
                    lots = min(lots, 0.5)
                    
                    open_trades.append({
                        'strategy': 'breakout', 'direction': 'BUY',
                        'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                    })
                else:
                    entry = row['close']
                    sl = entry + atr * params['bo_sl_atr']
                    tp = entry - atr * params['bo_tp_atr']
                    lots = (equity * params['risk_pct'] / 100) / (atr * 100000)
                    lots = min(lots, 0.5)
                    
                    open_trades.append({
                        'strategy': 'breakout', 'direction': 'SELL',
                        'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                    })
        
        # Gap Fill
        if 'gap_fill' not in active_strategies:
            if row['dayofweek'] == 0 and row['hour'] <= 4:
                gap_pips = abs(df['gap_pips'].iloc[idx])
                if not np.isnan(gap_pips) and params['gf_min_gap'] <= gap_pips <= params['gf_max_gap']:
                    gap_direction = 'up' if df['gap'].iloc[idx] > 0 else 'down'
                    
                    if gap_direction == 'up':
                        entry = row['close']
                        sl = entry + (gap_pips / 10000) * params['gf_sl_mult']
                        tp = entry - (gap_pips / 10000) * params['gf_tp_mult']
                        lots = (equity * params['risk_pct'] / 100) / ((gap_pips / 10000) * 100000)
                        lots = min(lots, 0.5)
                        
                        open_trades.append({
                            'strategy': 'gap_fill', 'direction': 'SELL',
                            'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                        })
                    else:
                        entry = row['close']
                        sl = entry - (gap_pips / 10000) * params['gf_sl_mult']
                        tp = entry + (gap_pips / 10000) * params['gf_tp_mult']
                        lots = (equity * params['risk_pct'] / 100) / ((gap_pips / 10000) * 100000)
                        lots = min(lots, 0.5)
                        
                        open_trades.append({
                            'strategy': 'gap_fill', 'direction': 'BUY',
                            'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots, 'bar': idx,
                        })
    
    # Close remaining trades
    for trade in open_trades:
        exit_price = df.iloc[-1]['close']
        if trade['direction'] == 'BUY':
            trade['pnl'] = (exit_price - trade['entry']) * trade['lots'] * 100000
        else:
            trade['pnl'] = (trade['entry'] - exit_price) * trade['lots'] * 100000
        trade['pnl'] -= spread_pips * trade['lots'] * 10
        closed_trades.append(trade)
    
    # Calculate fitness
    if not closed_trades:
        return -10000, {}
    
    winning = [t for t in closed_trades if t['pnl'] > 0]
    losing = [t for t in closed_trades if t['pnl'] < 0]
    
    total_profit = sum(t['pnl'] for t in winning)
    total_loss = abs(sum(t['pnl'] for t in losing))
    net_profit = equity - initial_deposit
    
    pf = total_profit / total_loss if total_loss > 0 else 999
    win_rate = len(winning) / len(closed_trades)
    
    # Calculate drawdown
    equity_curve = [initial_deposit]
    current_equity = initial_deposit
    for t in closed_trades:
        current_equity += t['pnl']
        equity_curve.append(current_equity)
    
    equity_arr = np.array(equity_curve)
    peak = np.maximum.accumulate(equity_arr)
    dd = peak - equity_arr
    max_dd_pct = (np.max(dd) / peak[np.argmax(dd)]) * 100 if peak[np.argmax(dd)] > 0 else 100
    
    # Fitness = profit * PF * win_rate / (1 + max_dd%)
    # Penalize high drawdown and low win rate
    fitness = net_profit * min(pf, 5) * win_rate / (1 + max_dd_pct / 100)
    
    # Penalty for too few trades
    if len(closed_trades) < 20:
        fitness *= 0.5
    
    results = {
        'net_profit': net_profit,
        'profit_factor': pf,
        'win_rate': win_rate,
        'max_drawdown_pct': max_dd_pct,
        'total_trades': len(closed_trades),
        'winning_trades': len(winning),
        'losing_trades': len(losing),
    }
    
    return fitness, results


def genetic_algorithm(df, population_size=50, generations=30, mutation_rate=0.1):
    """Run genetic algorithm optimization."""
    print(f"\n{'='*60}")
    print(f"GENETIC ALGORITHM OPTIMIZATION")
    print(f"Population: {population_size} | Generations: {generations}")
    print(f"{'='*60}")
    
    # Initialize population
    population = [Individual() for _ in range(population_size)]
    
    best_ever = None
    best_fitness = -float('inf')
    
    for gen in range(generations):
        # Evaluate fitness
        for ind in population:
            if ind.fitness is None:
                fitness, results = run_backtest(df, ind.params)
                ind.fitness = fitness
                ind.results = results
        
        # Sort by fitness
        population.sort(key=lambda x: x.fitness, reverse=True)
        
        # Track best
        if population[0].fitness > best_fitness:
            best_fitness = population[0].fitness
            best_ever = copy.deepcopy(population[0])
        
        # Print progress
        best = population[0]
        avg_fitness = np.mean([ind.fitness for ind in population])
        
        print(f"\nGeneration {gen+1}/{generations}:")
        print(f"  Best: fitness={best.fitness:.2f} profit=${best.results['net_profit']:,.2f} PF={best.results['profit_factor']:.2f} WR={best.results['win_rate']:.1%} DD={best.results['max_drawdown_pct']:.1f}% trades={best.results['total_trades']}")
        print(f"  Avg fitness: {avg_fitness:.2f}")
        
        if best_ever and best_ever.fitness > best.fitness:
            print(f"  Best ever: fitness={best_ever.fitness:.2f}")
        
        # Selection (top 20%)
        elite_size = max(2, population_size // 5)
        elite = population[:elite_size]
        
        # Create next generation
        new_population = list(elite)  # Keep elite
        
        while len(new_population) < population_size:
            # Tournament selection
            parent1 = random.choice(elite)
            parent2 = random.choice(elite)
            
            # Crossover
            child = parent1.crossover(parent2)
            
            # Mutation
            child.mutate(mutation_rate)
            
            new_population.append(child)
        
        population = new_population
    
    return best_ever


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'eurusd_h4_real.csv'
    
    print("=" * 60)
    print("DESTROYER QUANTUM — GENETIC ALGORITHM OPTIMIZER")
    print("=" * 60)
    
    # Load data
    df = load_data(filepath)
    # Precompute columns once
    tr_list = [0.0]
    for i in range(1, len(df)):
        h = df.iloc[i]['high']
        l = df.iloc[i]['low']
        c_prev = df.iloc[i-1]['close']
        tr_list.append(max(h - l, abs(h - c_prev), abs(l - c_prev)))
    df['tr'] = tr_list
    df['gap'] = df['open'] - df['close'].shift(1)
    df['gap_pips'] = df['gap'] * 10000
    df['atr_14'] = df['tr'].rolling(14).mean()
    
    # Precompute RSI for common periods
    for period in [7, 10, 14, 21]:
        delta = df['close'].diff()
        gain = delta.where(delta > 0, 0).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        df[f'rsi_{period}'] = 100 - (100 / (1 + rs))
    
    print(f"Loaded {len(df)} bars (precomputed tr, gap, atr_14, rsi_7/10/14/21)")
    
    # Run genetic algorithm
    best = genetic_algorithm(df, population_size=30, generations=20, mutation_rate=0.15)
    
    print(f"\n{'='*60}")
    print(f"BEST PARAMETERS FOUND")
    print(f"{'='*60}")
    print(f"\nResults:")
    print(f"  Net Profit:     ${best.results['net_profit']:,.2f}")
    print(f"  Profit Factor:  {best.results['profit_factor']:.2f}")
    print(f"  Win Rate:       {best.results['win_rate']:.1%}")
    print(f"  Max Drawdown:   {best.results['max_drawdown_pct']:.1f}%")
    print(f"  Total Trades:   {best.results['total_trades']}")
    
    print(f"\nOptimized Parameters:")
    for key, value in sorted(best.params.items()):
        print(f"  {key}: {value}")
    
    # Save results
    output = {
        'results': best.results,
        'params': best.params,
        'timestamp': datetime.now().isoformat(),
    }
    
    with open('ga_optimized_params.json', 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\nResults saved to ga_optimized_params.json")
    
    # Generate .set file
    print(f"\n{'='*60}")
    print(f"GENERATED .SET FILE PARAMETERS")
    print(f"{'='*60}")
    
    set_params = {
        '; === MEAN REVERSION ===': None,
        'InpMR_BB_Period': best.params['mr_bb_period'],
        'InpMR_BB_Dev': best.params['mr_bb_dev'],
        'InpMR_RSI_Period': best.params['mr_rsi_period'],
        'InpMR_RSI_OS': best.params['mr_rsi_os'],
        'InpMR_RSI_OB': best.params['mr_rsi_ob'],
        'InpMR_SL_ATR_Mult': best.params['mr_sl_atr'],
        'InpMR_TP_ATR_Mult': best.params['mr_tp_atr'],
        '; === SESSION MOMENTUM ===': None,
        'InpSM_RSI_Period': best.params['mom_rsi_period'],
        'InpSM_RSI_Buy': best.params['mom_rsi_buy'],
        'InpSM_RSI_Sell': best.params['mom_rsi_sell'],
        'InpSM_SMA_Period': best.params['mom_sma_period'],
        'InpSM_SL_ATR_Mult': best.params['mom_sl_atr'],
        'InpSM_TP_ATR_Mult': best.params['mom_tp_atr'],
        '; === NOISE BREAKOUT ===': None,
        'InpNB_ATR_Ratio': best.params['bo_atr_ratio'],
        'InpNB_SL_ATR_Mult': best.params['bo_sl_atr'],
        'InpNB_TP_ATR_Mult': best.params['bo_tp_atr'],
        '; === GAP FILL ===': None,
        'InpGF_MinGap': best.params['gf_min_gap'],
        'InpGF_MaxGap': best.params['gf_max_gap'],
        'InpGF_SL_Mult': best.params['gf_sl_mult'],
        'InpGF_TP_Mult': best.params['gf_tp_mult'],
        '; === RISK ===': None,
        'InpBase_Risk': best.params['risk_pct'],
    }
    
    for key, value in set_params.items():
        if value is None:
            print(f"\n{key}")
        else:
            print(f"{key}={value}")
    
    print(f"\n{'='*60}")
    print(f"OPTIMIZATION COMPLETE")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
