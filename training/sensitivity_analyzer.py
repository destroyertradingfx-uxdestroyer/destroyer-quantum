#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Parameter Sensitivity Analyzer
Analyzes which parameters have the biggest impact on performance.
"""

import pandas as pd
import numpy as np
import json
import sys
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


def run_backtest(df, params, spread_pips=21.0, initial_deposit=10000.0):
    """Run backtest with given parameters."""
    equity = initial_deposit
    open_trades = []
    closed_trades = []
    
    # Precompute
    tr_list = [0.0]
    for i in range(1, len(df)):
        h = df.iloc[i]['high']
        l = df.iloc[i]['low']
        c_prev = df.iloc[i-1]['close']
        tr_list.append(max(h - l, abs(h - c_prev), abs(l - c_prev)))
    df = df.copy()
    df['tr'] = tr_list
    df['atr_14'] = df['tr'].rolling(14).mean()
    df['gap'] = df['open'] - df['close'].shift(1)
    df['gap_pips'] = df['gap'] * 10000
    
    # Precompute RSI
    for period in [7, 10, 14, 21]:
        delta = df['close'].diff()
        gain = delta.where(delta > 0, 0).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        df[f'rsi_{period}'] = 100 - (100 / (1 + rs))
    
    min_bars = max(params.get('mr_bb_period', 20), params.get('mom_sma_period', 20), 14) + 1
    
    for idx in range(min_bars, len(df)):
        row = df.iloc[idx]
        
        # ATR
        atr = df['atr_14'].iloc[idx]
        if np.isnan(atr) or atr == 0:
            atr = 0.001
        
        # RSI
        mr_period = min([7, 10, 14, 21], key=lambda p: abs(p - params.get('mr_rsi_period', 14)))
        mom_period = min([7, 10, 14, 21], key=lambda p: abs(p - params.get('mom_rsi_period', 14)))
        mr_rsi = df[f'rsi_{mr_period}'].iloc[idx]
        mom_rsi = df[f'rsi_{mom_period}'].iloc[idx]
        if np.isnan(mr_rsi): mr_rsi = 50
        if np.isnan(mom_rsi): mom_rsi = 50
        
        # BB
        bb_sma = df['close'].iloc[max(0,idx-params.get('mr_bb_period', 20)+1):idx+1].mean()
        bb_std = df['close'].iloc[max(0,idx-params.get('mr_bb_period', 20)+1):idx+1].std()
        if np.isnan(bb_std) or bb_std == 0:
            bb_std = 0.001
        upper_bb = bb_sma + bb_std * params.get('mr_bb_dev', 2.0)
        lower_bb = bb_sma - bb_std * params.get('mr_bb_dev', 2.0)
        
        # SMA
        mom_sma = df['close'].iloc[max(0,idx-params.get('mom_sma_period', 20)+1):idx+1].mean()
        if np.isnan(mom_sma):
            mom_sma = row['close']
        
        # ATR ratio
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
        max_concurrent = params.get('max_concurrent', 3)
        if len(open_trades) >= max_concurrent:
            continue
        
        risk_pct = params.get('risk_pct', 1.5)
        active_strategies = [t['strategy'] for t in open_trades]
        
        # Mean Reversion
        if 'mean_reversion' not in active_strategies:
            if mr_rsi < params.get('mr_rsi_os', 30) and row['close'] < lower_bb:
                entry = row['close']
                sl = entry - atr * params.get('mr_sl_atr', 1.5)
                tp = entry + atr * params.get('mr_tp_atr', 1.5)
                lots = (equity * risk_pct / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                open_trades.append({
                    'strategy': 'mean_reversion', 'direction': 'BUY',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
                })
            elif mr_rsi > params.get('mr_rsi_ob', 70) and row['close'] > upper_bb:
                entry = row['close']
                sl = entry + atr * params.get('mr_sl_atr', 1.5)
                tp = entry - atr * params.get('mr_tp_atr', 1.5)
                lots = (equity * risk_pct / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                open_trades.append({
                    'strategy': 'mean_reversion', 'direction': 'SELL',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
                })
        
        # Momentum
        if 'momentum' not in active_strategies:
            if mom_rsi > params.get('mom_rsi_buy', 55) and row['close'] > mom_sma:
                entry = row['close']
                sl = entry - atr * params.get('mom_sl_atr', 1.5)
                tp = entry + atr * params.get('mom_tp_atr', 2.0)
                lots = (equity * risk_pct / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                open_trades.append({
                    'strategy': 'momentum', 'direction': 'BUY',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
                })
            elif mom_rsi < params.get('mom_rsi_sell', 45) and row['close'] < mom_sma:
                entry = row['close']
                sl = entry + atr * params.get('mom_sl_atr', 1.5)
                tp = entry - atr * params.get('mom_tp_atr', 2.0)
                lots = (equity * risk_pct / 100) / (atr * 100000)
                lots = min(lots, 0.5)
                open_trades.append({
                    'strategy': 'momentum', 'direction': 'SELL',
                    'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
                })
        
        # Breakout
        if 'breakout' not in active_strategies:
            if atr_ratio > params.get('bo_atr_ratio', 1.5):
                if row['close'] > row['open']:
                    entry = row['close']
                    sl = entry - atr * params.get('bo_sl_atr', 1.5)
                    tp = entry + atr * params.get('bo_tp_atr', 2.5)
                    lots = (equity * risk_pct / 100) / (atr * 100000)
                    lots = min(lots, 0.5)
                    open_trades.append({
                        'strategy': 'breakout', 'direction': 'BUY',
                        'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
                    })
                else:
                    entry = row['close']
                    sl = entry + atr * params.get('bo_sl_atr', 1.5)
                    tp = entry - atr * params.get('bo_tp_atr', 2.5)
                    lots = (equity * risk_pct / 100) / (atr * 100000)
                    lots = min(lots, 0.5)
                    open_trades.append({
                        'strategy': 'breakout', 'direction': 'SELL',
                        'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
                    })
        
        # Gap Fill
        if 'gap_fill' not in active_strategies:
            if row['dayofweek'] == 0 and row['hour'] <= 4:
                gap_pips = abs(df['gap_pips'].iloc[idx])
                if not np.isnan(gap_pips) and params.get('gf_min_gap', 5) <= gap_pips <= params.get('gf_max_gap', 30):
                    gap_direction = 'up' if df['gap'].iloc[idx] > 0 else 'down'
                    if gap_direction == 'up':
                        entry = row['close']
                        sl = entry + (gap_pips / 10000) * params.get('gf_sl_mult', 2.0)
                        tp = entry - (gap_pips / 10000) * params.get('gf_tp_mult', 0.9)
                        lots = (equity * risk_pct / 100) / ((gap_pips / 10000) * 100000)
                        lots = min(lots, 0.5)
                        open_trades.append({
                            'strategy': 'gap_fill', 'direction': 'SELL',
                            'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
                        })
                    else:
                        entry = row['close']
                        sl = entry - (gap_pips / 10000) * params.get('gf_sl_mult', 2.0)
                        tp = entry + (gap_pips / 10000) * params.get('gf_tp_mult', 0.9)
                        lots = (equity * risk_pct / 100) / ((gap_pips / 10000) * 100000)
                        lots = min(lots, 0.5)
                        open_trades.append({
                            'strategy': 'gap_fill', 'direction': 'BUY',
                            'entry': entry, 'sl': sl, 'tp': tp, 'lots': lots,
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
    
    # Calculate results
    if not closed_trades:
        return {'net_profit': -10000, 'profit_factor': 0, 'win_rate': 0, 'max_drawdown_pct': 100, 'total_trades': 0}
    
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
    
    return {
        'net_profit': net_profit,
        'profit_factor': pf,
        'win_rate': win_rate,
        'max_drawdown_pct': max_dd_pct,
        'total_trades': len(closed_trades),
        'winning_trades': len(winning),
        'losing_trades': len(losing),
    }


def analyze_sensitivity(df, base_params, param_name, test_values):
    """Analyze sensitivity of a single parameter."""
    results = []
    
    for value in test_values:
        params = base_params.copy()
        params[param_name] = value
        
        result = run_backtest(df, params)
        results.append({
            'value': value,
            'net_profit': result['net_profit'],
            'profit_factor': result['profit_factor'],
            'win_rate': result['win_rate'],
            'max_drawdown_pct': result['max_drawdown_pct'],
            'total_trades': result['total_trades'],
        })
    
    return results


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'eurusd_h4_real.csv'
    
    print("=" * 60)
    print("DESTROYER QUANTUM — PARAMETER SENSITIVITY ANALYZER")
    print("=" * 60)
    
    # Load data
    df = load_data(filepath)
    print(f"Loaded {len(df)} bars")
    
    # Base parameters (Aggressive model)
    base_params = {
        'mr_bb_period': 20,
        'mr_bb_dev': 2.0,
        'mr_rsi_period': 14,
        'mr_rsi_os': 30,
        'mr_rsi_ob': 70,
        'mr_sl_atr': 1.5,
        'mr_tp_atr': 1.5,
        'mom_rsi_period': 14,
        'mom_rsi_buy': 55,
        'mom_rsi_sell': 45,
        'mom_sma_period': 20,
        'mom_sl_atr': 1.5,
        'mom_tp_atr': 2.0,
        'bo_atr_ratio': 1.5,
        'bo_sl_atr': 1.5,
        'bo_tp_atr': 2.5,
        'gf_min_gap': 5,
        'gf_max_gap': 30,
        'gf_sl_mult': 2.0,
        'gf_tp_mult': 0.9,
        'risk_pct': 1.5,
        'max_concurrent': 3,
    }
    
    # Test baseline
    print("\nRunning baseline...")
    baseline = run_backtest(df, base_params)
    print(f"  Baseline: profit=${baseline['net_profit']:,.2f} PF={baseline['profit_factor']:.2f} WR={baseline['win_rate']:.1%} DD={baseline['max_drawdown_pct']:.1f}%")
    
    # Parameters to test
    param_tests = {
        'mr_bb_period': [10, 15, 20, 25, 30],
        'mr_bb_dev': [1.5, 1.7, 2.0, 2.2, 2.5],
        'mr_rsi_period': [7, 10, 14, 21],
        'mr_rsi_os': [20, 25, 30, 35, 40],
        'mr_rsi_ob': [60, 65, 70, 75, 80],
        'mr_sl_atr': [1.0, 1.25, 1.5, 1.75, 2.0],
        'mr_tp_atr': [1.0, 1.25, 1.5, 1.75, 2.0],
        'mom_rsi_period': [7, 10, 14, 21],
        'mom_rsi_buy': [50, 55, 60, 65],
        'mom_rsi_sell': [35, 40, 45, 50],
        'mom_sma_period': [10, 15, 20, 30, 50],
        'mom_sl_atr': [1.0, 1.25, 1.5, 1.75, 2.0],
        'mom_tp_atr': [1.5, 2.0, 2.5, 3.0],
        'bo_atr_ratio': [1.2, 1.3, 1.5, 1.7, 2.0],
        'risk_pct': [0.5, 1.0, 1.5, 2.0, 2.5],
        'max_concurrent': [1, 2, 3, 4, 5],
    }
    
    all_results = {}
    
    for param_name, test_values in param_tests.items():
        print(f"\nTesting {param_name}...")
        results = analyze_sensitivity(df, base_params, param_name, test_values)
        all_results[param_name] = results
        
        # Find best value
        best = max(results, key=lambda x: x['net_profit'])
        worst = min(results, key=lambda x: x['net_profit'])
        
        print(f"  Best: {param_name}={best['value']} → profit=${best['net_profit']:,.2f} PF={best['profit_factor']:.2f}")
        print(f"  Worst: {param_name}={worst['value']} → profit=${worst['net_profit']:,.2f} PF={worst['profit_factor']:.2f}")
    
    # Generate report
    print(f"\n{'='*60}")
    print(f"SENSITIVITY ANALYSIS RESULTS")
    print(f"{'='*60}")
    
    # Sort by impact (profit difference)
    impacts = []
    for param_name, results in all_results.items():
        profits = [r['net_profit'] for r in results]
        impact = max(profits) - min(profits)
        best_value = max(results, key=lambda x: x['net_profit'])['value']
        impacts.append({
            'param': param_name,
            'impact': impact,
            'best_value': best_value,
            'baseline_value': base_params[param_name],
        })
    
    impacts.sort(key=lambda x: -x['impact'])
    
    print(f"\nParameter Impact (sorted by profit difference):")
    for i, imp in enumerate(impacts):
        improved = imp['best_value'] != imp['baseline_value']
        marker = "← CHANGE" if improved else ""
        print(f"  {i+1:2d}. {imp['param']:20s}: impact=${imp['impact']:>10,.2f} | best={imp['best_value']} | baseline={imp['baseline_value']} {marker}")
    
    # Save results
    output = {
        'baseline': baseline,
        'param_tests': all_results,
        'impacts': impacts,
        'timestamp': datetime.now().isoformat(),
    }
    
    with open('sensitivity_analysis.json', 'w') as f:
        json.dump(output, f, indent=2, default=str)
    
    print(f"\nResults saved to sensitivity_analysis.json")
    print(f"\n{'='*60}")
    print(f"ANALYSIS COMPLETE")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
