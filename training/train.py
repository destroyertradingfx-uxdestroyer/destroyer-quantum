#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Main Training Script
Trains and optimizes strategy parameters on historical data.

Usage:
    python train.py --data EURUSD_H4.csv --mode optimize
    python train.py --data EURUSD_H4.csv --mode backtest
    python train.py --data EURUSD_H4.csv --mode train --epochs 100
"""

import argparse
import sys
import os
import json
from datetime import datetime

# Add training directory to path
sys.path.insert(0, os.path.dirname(__file__))

from destroyer_trainer import (
    load_mt4_csv, load_generic_csv,
    Backtester, BacktestResult,
    PhantomStrategy, NoiseBreakoutStrategy,
    MeanReversionStrategy, ReaperGridStrategy,
    SessionMomentumStrategy, ParameterOptimizer,
)


# ============================================================
# AGGRESSIVE SET FILE MODEL (from proven $68K config)
# ============================================================

AGGRESSIVE_MODEL = {
    'phantom': {
        'enabled': True,
        'min_gap_pips': 5.0,
        'max_gap_pips': 30.0,
        'sl_gap_mult': 2.0,
        'tp_gap_mult': 0.9,
        'risk_pct': 1.5,
    },
    'noise_breakout': {
        'enabled': True,
        'lookback': 20,
        'noise_threshold': 0.5,
        'atr_period': 14,
        'atr_mult_sl': 1.5,
        'atr_mult_tp': 2.0,
        'risk_pct': 1.5,
    },
    'mean_reversion': {
        'enabled': True,
        'bb_period': 15,
        'bb_dev': 1.7,
        'rsi_period': 10,
        'rsi_ob': 58.0,
        'rsi_os': 42.0,
        'adx_threshold': 18.0,
        'atr_period': 14,
        'sl_atr_mult': 1.5,
        'tp_atr_mult': 1.0,
        'risk_pct': 1.5,
    },
    'reaper': {
        'enabled': True,
        'initial_lot': 0.12,
        'lot_multiplier': 1.4,
        'max_levels': 10,
        'pip_step': 20,
        'basket_tp_pips': 75,
        'basket_tp_money': 600,
        'trail_start_money': 200,
        'trail_stop_pips': 400,
        'risk_pct': 1.5,
    },
    'session_momentum': {
        'enabled': True,
        'lookback': 10,
        'momentum_threshold': 0.002,
        'atr_period': 14,
        'sl_atr_mult': 2.0,
        'tp_atr_mult': 3.0,
        'risk_pct': 1.5,
        'trade_hours': [8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    },
}


# ============================================================
# BACKTESTER FACTORY
# ============================================================

def create_backtester(params: dict = None, model: dict = None) -> Backtester:
    """Create a configured backtester with all strategies."""
    if model is None:
        model = AGGRESSIVE_MODEL
    
    if params is None:
        params = {}
    
    # Merge any overrides into model
    for key, value in params.items():
        parts = key.split('.')
        if len(parts) == 2:
            strategy, param = parts
            if strategy in model:
                model[strategy][param] = value
    
    bt = Backtester(initial_deposit=10000.0, spread_pips=21.0)
    
    # Add strategies
    if model.get('phantom', {}).get('enabled', True):
        bt.add_strategy(PhantomStrategy(model['phantom']))
    
    if model.get('noise_breakout', {}).get('enabled', True):
        bt.add_strategy(NoiseBreakoutStrategy(model['noise_breakout']))
    
    if model.get('mean_reversion', {}).get('enabled', True):
        bt.add_strategy(MeanReversionStrategy(model['mean_reversion']))
    
    if model.get('reaper', {}).get('enabled', True):
        bt.add_strategy(ReaperGridStrategy(model['reaper']))
    
    if model.get('session_momentum', {}).get('enabled', True):
        bt.add_strategy(SessionMomentumStrategy(model['session_momentum']))
    
    return bt


# ============================================================
# TRAINING MODES
# ============================================================

def run_backtest(data, model=None):
    """Run a single backtest with given model."""
    print("\n" + "=" * 60)
    print("RUNNING BACKTEST")
    print("=" * 60)
    
    bt = create_backtester(model=model)
    result = bt.run(data)
    
    print("\n" + result.summary())
    
    return result


def run_optimization(data, max_iter=50, popsize=15):
    """Run parameter optimization."""
    print("\n" + "=" * 60)
    print("RUNNING OPTIMIZATION")
    print("=" * 60)
    
    # Define parameter space for optimization
    param_space = {
        'phantom.min_gap_pips': (2.0, 10.0),
        'phantom.max_gap_pips': (15.0, 50.0),
        'phantom.sl_gap_mult': (1.0, 3.0),
        'phantom.tp_gap_mult': (0.5, 2.0),
        'noise_breakout.lookback': (10, 30),
        'noise_breakout.noise_threshold': (0.3, 0.8),
        'noise_breakout.atr_mult_sl': (1.0, 3.0),
        'noise_breakout.atr_mult_tp': (1.5, 4.0),
        'mean_reversion.bb_period': (10, 30),
        'mean_reversion.bb_dev': (1.5, 2.5),
        'mean_reversion.rsi_period': (7, 21),
        'mean_reversion.rsi_ob': (60, 80),
        'mean_reversion.rsi_os': (20, 40),
        'reaper.initial_lot': (0.05, 0.20),
        'reaper.lot_multiplier': (1.2, 1.6),
        'reaper.max_levels': (6, 12),
        'reaper.pip_step': (15, 40),
        'session_momentum.momentum_threshold': (0.001, 0.005),
        'session_momentum.lookback': (5, 20),
    }
    
    optimizer = ParameterOptimizer(create_backtester, data)
    best_params = optimizer.optimize(param_space, max_iter=max_iter, popsize=popsize)
    
    print("\n" + "=" * 60)
    print("OPTIMIZATION COMPLETE")
    print("=" * 60)
    print(f"\nBest parameters found:")
    for key, value in best_params.items():
        print(f"  {key}: {value}")
    
    # Run final backtest with optimized params
    print("\nRunning final backtest with optimized parameters...")
    result = run_backtest(data, model=None)  # Uses optimized params
    
    # Save results
    output = {
        'timestamp': datetime.now().isoformat(),
        'best_params': best_params,
        'results': {
            'net_profit': result.net_profit,
            'profit_factor': result.profit_factor,
            'max_drawdown_pct': result.max_drawdown_pct,
            'total_trades': result.total_trades,
            'win_rate': result.win_rate,
            'final_equity': result.final_equity,
        },
        'history': optimizer.history[-10:],  # Last 10 iterations
    }
    
    with open('optimization_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    
    print("\nResults saved to optimization_results.json")
    
    return best_params, result


def run_training(data, epochs=100):
    """
    Run iterative training — adjusts parameters based on performance feedback.
    This simulates 'training' the model by iteratively improving parameters.
    """
    print("\n" + "=" * 60)
    print("RUNNING TRAINING")
    print("=" * 60)
    
    current_model = AGGRESSIVE_MODEL.copy()
    best_profit = -float('inf')
    best_model = current_model.copy()
    
    for epoch in range(epochs):
        print(f"\n--- Epoch {epoch + 1}/{epochs} ---")
        
        # Run backtest with current model
        bt = create_backtester(model=current_model)
        result = bt.run(data)
        
        print(f"  Profit: ${result.net_profit:,.2f} | PF: {result.profit_factor:.2f} | DD: {result.max_drawdown_pct:.1f}%")
        
        # Update best if improved
        if result.net_profit > best_profit:
            best_profit = result.net_profit
            best_model = current_model.copy()
            print(f"  *** New best! ***")
        
        # Adaptive parameter adjustment based on results
        for strat_name, perf in result.strategies.items():
            if perf.total_trades == 0:
                continue
            
            if strat_name == 'Phantom' and strat_name.lower() in [k.lower() for k in current_model.keys()]:
                key = [k for k in current_model.keys() if k.lower() == 'phantom'][0]
                if perf.win_rate < 0.6:
                    current_model[key]['min_gap_pips'] *= 1.1  # Tighten filter
                elif perf.win_rate > 0.8:
                    current_model[key]['min_gap_pips'] *= 0.9  # Loosen filter
            
            elif strat_name == 'MeanReversion':
                key = [k for k in current_model.keys() if k.lower() == 'mean_reversion'][0]
                if perf.profit_factor < 1.0:
                    current_model[key]['bb_dev'] *= 1.05  # Tighter bands
                    current_model[key]['rsi_ob'] = min(80, current_model[key]['rsi_ob'] + 2)
                    current_model[key]['rsi_os'] = max(20, current_model[key]['rsi_os'] - 2)
                elif perf.profit_factor > 2.0:
                    current_model[key]['bb_dev'] *= 0.95  # Looser bands
    
    print("\n" + "=" * 60)
    print("TRAINING COMPLETE")
    print("=" * 60)
    print(f"\nBest profit achieved: ${best_profit:,.2f}")
    
    # Run final backtest with best model
    print("\nFinal backtest with best model:")
    result = run_backtest(data, model=best_model)
    
    # Save trained model
    with open('trained_model.json', 'w') as f:
        json.dump(best_model, f, indent=2)
    
    print("\nTrained model saved to trained_model.json")
    
    return best_model, result


# ============================================================
# GENERATE .SET FILE
# ============================================================

def generate_set_file(model: dict, filename: str = 'TRAINED_MODEL.set'):
    """Generate a MT4 .set file from trained model."""
    lines = [
        "; ================================================================",
        "; DESTROYER QUANTUM — TRAINED MODEL",
        f"; Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "; ================================================================",
        "",
    ]
    
    # Map model params to EA extern names
    param_map = {
        'phantom': {
            'enabled': 'InpPhantom_Enabled',
            'min_gap_pips': 'InpPhantom_MinGap_Pips',
            'max_gap_pips': 'InpPhantom_MaxGap_Pips',
            'sl_gap_mult': 'InpPhantom_SL_GapMult',
            'tp_gap_mult': 'InpPhantom_TP_GapMult',
        },
        'noise_breakout': {
            'enabled': 'InpNoiseBreakout_Enabled',
        },
        'mean_reversion': {
            'enabled': 'InpMeanReversion_Enabled',
            'bb_period': 'InpMR_BB_Period',
            'bb_dev': 'InpMR_BB_Dev',
            'rsi_period': 'InpMR_RSI_Period',
            'rsi_ob': 'InpMR_RSI_OB',
            'rsi_os': 'InpMR_RSI_OS',
            'adx_threshold': 'InpMR_ADX_Threshold',
        },
        'reaper': {
            'enabled': 'InpReaper_Enabled',
            'initial_lot': 'InpReaper_InitialLot',
            'lot_multiplier': 'InpReaper_LotMultiplier',
            'max_levels': 'InpReaper_MaxLevels',
            'pip_step': 'InpReaper_PipStep',
            'basket_tp_pips': 'InpReaper_BasketTP',
            'basket_tp_money': 'InpReaper_BasketTP_Money',
            'trail_start_money': 'InpReaper_TrailStart_Money',
            'trail_stop_pips': 'InpReaper_TrailStop_Pips',
        },
        'session_momentum': {
            'enabled': 'InpSessionMomentum_Enabled',
            'lookback': 'InpSM_Lookback',
            'momentum_threshold': 'InpSM_MomentumThreshold',
        },
    }
    
    for strategy_key, param_mapping in param_map.items():
        if strategy_key in model:
            lines.append(f"; === {strategy_key.upper()} ===")
            for model_param, ea_name in param_mapping.items():
                if model_param in model[strategy_key]:
                    value = model[strategy_key][model_param]
                    if isinstance(value, bool):
                        lines.append(f"{ea_name}={'true' if value else 'false'}")
                    elif isinstance(value, float):
                        lines.append(f"{ea_name}={value}")
                    elif isinstance(value, int):
                        lines.append(f"{ea_name}={value}")
                    else:
                        lines.append(f"{ea_name}={value}")
            lines.append("")
    
    with open(filename, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"Generated .set file: {filename}")


# ============================================================
# MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser(description='DESTROYER QUANTUM Training Framework')
    parser.add_argument('--data', type=str, required=True, help='Path to OHLCV data file (CSV)')
    parser.add_argument('--mode', type=str, default='backtest', 
                       choices=['backtest', 'optimize', 'train'],
                       help='Training mode')
    parser.add_argument('--epochs', type=int, default=100, help='Number of training epochs')
    parser.add_argument('--max-iter', type=int, default=50, help='Max optimization iterations')
    parser.add_argument('--popsize', type=int, default=15, help='Population size for optimization')
    parser.add_argument('--output', type=str, default='trained_model.json', help='Output file')
    
    args = parser.parse_args()
    
    # Load data
    print(f"Loading data from {args.data}...")
    data = load_generic_csv(args.data)
    
    print(f"Loaded {len(data)} bars")
    print(f"Date range: {data.index[0]} to {data.index[-1]}")
    print(f"Columns: {list(data.columns)}")
    
    # Run mode
    if args.mode == 'backtest':
        result = run_backtest(data)
        generate_set_file(AGGRESSIVE_MODEL, 'aggressive_model.set')
        
    elif args.mode == 'optimize':
        best_params, result = run_optimization(data, args.max_iter, args.popsize)
        generate_set_file(AGGRESSIVE_MODEL, 'optimized_model.set')
        
    elif args.mode == 'train':
        best_model, result = run_training(data, args.epochs)
        generate_set_file(best_model, 'trained_model.set')
    
    print("\n" + "=" * 60)
    print("DONE")
    print("=" * 60)


if __name__ == "__main__":
    main()
