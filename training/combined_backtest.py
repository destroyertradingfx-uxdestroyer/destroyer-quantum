#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Combined Strategy Backtester
All strategies + ML filter working together.
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
import json
import sys
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


def engineer_features(df):
    """Create features for ML model."""
    df['return_1'] = df['close'].pct_change()
    df['return_5'] = df['close'].pct_change(5)
    df['return_10'] = df['close'].pct_change(10)
    df['return_20'] = df['close'].pct_change(20)
    
    for period in [5, 10, 20]:
        df[f'vol_{period}'] = df['return_1'].rolling(period).std()
    
    tr_list = [0]
    for i in range(1, len(df)):
        h = df.iloc[i]['high']
        l = df.iloc[i]['low']
        c_prev = df.iloc[i-1]['close']
        tr = max(h - l, abs(h - c_prev), abs(l - c_prev))
        tr_list.append(tr)
    df['tr'] = tr_list
    df['atr_14'] = df['tr'].rolling(14).mean()
    df['atr_ratio'] = df['tr'] / df['atr_14']
    
    for period in [20, 50, 100]:
        sma = df['close'].rolling(period).mean()
        df[f'dist_sma_{period}'] = (df['close'] - sma) / sma * 10000
    
    df['rsi_14'] = calculate_rsi(df['close'], 14)
    df['rsi_7'] = calculate_rsi(df['close'], 7)
    
    bb_period = 20
    sma = df['close'].rolling(bb_period).mean()
    std = df['close'].rolling(bb_period).std()
    df['bb_position'] = (df['close'] - sma) / (2 * std)
    df['bb_width'] = (4 * std) / sma * 10000
    
    df['gap'] = df['open'] - df['close'].shift(1)
    df['gap_pips'] = df['gap'] * 10000
    
    df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
    df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
    df['dow_sin'] = np.sin(2 * np.pi * df['dayofweek'] / 5)
    df['dow_cos'] = np.cos(2 * np.pi * df['dayofweek'] / 5)
    
    df['range'] = (df['high'] - df['low']) * 10000
    df['body'] = abs(df['close'] - df['open']) * 10000
    df['body_ratio'] = df['body'] / df['range'].replace(0, np.nan)
    
    return df


def create_labels(df, forward_bars=6):
    """Create labels for ML training."""
    df['fwd_return'] = df['close'].shift(-forward_bars) - df['close']
    df['fwd_return_pips'] = df['fwd_return'] * 10000
    
    conditions = [
        (df['fwd_return_pips'] > 20) & (df['rsi_14'] < 70) & (df['return_5'] > 0),
        (df['fwd_return_pips'] < -20) & (df['rsi_14'] > 30) & (df['return_5'] < 0),
        (df['fwd_return_pips'] > 10) & (df['rsi_14'] < 35) & (df['bb_position'] < -0.5),
        (df['fwd_return_pips'] < -10) & (df['rsi_14'] > 65) & (df['bb_position'] > 0.5),
        (df['atr_ratio'] > 1.5) & (abs(df['fwd_return_pips']) > 15),
    ]
    choices = [1, 2, 3, 4, 5]
    df['label'] = np.select(conditions, choices, default=0)
    
    return df


class MLFilter:
    """ML-based trade filter."""
    
    def __init__(self):
        self.model = None
        self.scaler = None
        self.feature_cols = None
    
    def train(self, df):
        self.feature_cols = [
            'return_1', 'return_5', 'return_10', 'return_20',
            'vol_5', 'vol_10', 'vol_20',
            'atr_14', 'atr_ratio',
            'dist_sma_20', 'dist_sma_50', 'dist_sma_100',
            'rsi_14', 'rsi_7',
            'bb_position', 'bb_width',
            'gap_pips',
            'hour_sin', 'hour_cos', 'dow_sin', 'dow_cos',
            'range', 'body', 'body_ratio',
        ]
        
        df_clean = df.dropna(subset=self.feature_cols + ['label'])
        X = df_clean[self.feature_cols].values
        y = df_clean['label'].values
        
        self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X)
        
        self.model = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=4,
            learning_rate=0.1,
            random_state=42,
        )
        self.model.fit(X_scaled, y)
        print(f"  ML Filter trained on {len(df_clean)} samples")
    
    def predict(self, df, idx, strategy_type):
        """Predict if we should trade this bar."""
        if self.model is None:
            return True, 0.5
        
        row = df.iloc[idx]
        
        features = []
        for col in self.feature_cols:
            if col in df.columns:
                features.append(row[col])
            else:
                features.append(0)
        
        features = np.array(features, dtype=float).reshape(1, -1)
        features = np.nan_to_num(features, nan=0.0)
        features_scaled = self.scaler.transform(features)
        
        prediction = self.model.predict(features_scaled)[0]
        probabilities = self.model.predict_proba(features_scaled)[0]
        confidence = max(probabilities)
        
        # Filter based on strategy type
        if strategy_type == 'momentum':
            should_trade = prediction in [1, 2, 5] and confidence > 0.6
        elif strategy_type == 'mean_reversion':
            should_trade = prediction in [3, 4] and confidence > 0.6
        elif strategy_type == 'breakout':
            should_trade = prediction == 5 and confidence > 0.7
        elif strategy_type == 'gap_fill':
            should_trade = prediction != 0 and confidence > 0.5
        elif strategy_type == 'grid':
            should_trade = prediction != 0 and confidence > 0.5
        else:
            should_trade = prediction != 0 and confidence > 0.6
        
        return should_trade, confidence


class Trade:
    """Trade object."""
    def __init__(self, strategy, direction, entry, sl, tp, lots, bar):
        self.strategy = strategy
        self.direction = direction
        self.entry = entry
        self.sl = sl
        self.tp = tp
        self.lots = lots
        self.bar = bar
        self.exit = None
        self.pnl = 0.0
        self.status = 'OPEN'


class CombinedBacktester:
    """Combined strategy backtester with ML filter."""
    
    def __init__(self, initial_deposit=10000.0, spread_pips=21.0):
        self.initial_deposit = initial_deposit
        self.spread_pips = spread_pips
        self.ml_filter = MLFilter()
        self.open_trades = []
        self.closed_trades = []
    
    def run(self, df, use_ml=True, max_concurrent=3):
        """Run combined backtest."""
        print(f"\nRunning combined backtest (ML={use_ml}, max_concurrent={max_concurrent})")
        
        equity = self.initial_deposit
        equity_curve = [equity]
        self.open_trades = []
        self.closed_trades = []
        
        # Strategy parameters
        rsi_period = 14
        bb_period = 20
        bb_dev = 2.0
        atr_period = 14
        sl_mult = 1.5
        tp_mult = 2.0
        risk_pct = 1.5
        
        min_bars = max(bb_period, rsi_period, atr_period) + 1
        
        for idx in range(min_bars, len(df)):
            row = df.iloc[idx]
            prev = df.iloc[idx - 1]
            
            # Calculate indicators
            closes = df['close'].iloc[:idx+1]
            rsi = calculate_rsi(closes, rsi_period).iloc[-1]
            if np.isnan(rsi):
                rsi = 50
            
            sma = closes.rolling(bb_period).mean().iloc[-1]
            std = closes.rolling(bb_period).std().iloc[-1]
            if np.isnan(std):
                std = 0.001
            upper_bb = sma + std * bb_dev
            lower_bb = sma - std * bb_dev
            
            atr = df['atr_14'].iloc[idx]
            if np.isnan(atr):
                atr = 0.001
            
            # ---- EXIT LOGIC ----
            for trade in list(self.open_trades):
                exited = False
                
                if trade.direction == 'BUY':
                    if row['low'] <= trade.sl:
                        trade.exit = trade.sl
                        exited = True
                    elif row['high'] >= trade.tp:
                        trade.exit = trade.tp
                        exited = True
                else:  # SELL
                    if row['high'] >= trade.sl:
                        trade.exit = trade.sl
                        exited = True
                    elif row['low'] <= trade.tp:
                        trade.exit = trade.tp
                        exited = True
                
                if exited:
                    if trade.direction == 'BUY':
                        trade.pnl = (trade.exit - trade.entry) * trade.lots * 100000
                    else:
                        trade.pnl = (trade.entry - trade.exit) * trade.lots * 100000
                    trade.pnl -= self.spread_pips * trade.lots * 10
                    trade.status = 'WIN' if trade.pnl > 0 else 'LOSS'
                    equity += trade.pnl
                    self.open_trades.remove(trade)
                    self.closed_trades.append(trade)
            
            # ---- ENTRY LOGIC ----
            if len(self.open_trades) >= max_concurrent:
                equity_curve.append(equity)
                continue
            
            # Get ML predictions
            if use_ml:
                mom_ok, mom_conf = self.ml_filter.predict(df, idx, 'momentum')
                mr_ok, mr_conf = self.ml_filter.predict(df, idx, 'mean_reversion')
                bo_ok, bo_conf = self.ml_filter.predict(df, idx, 'breakout')
            else:
                mom_ok, mom_conf = True, 0.5
                mr_ok, mr_conf = True, 0.5
                bo_ok, bo_conf = True, 0.5
            
            # Check which strategies are already active
            active_strategies = [t.strategy for t in self.open_trades]
            
            # --- STRATEGY 1: Momentum ---
            if 'momentum' not in active_strategies and mom_ok:
                # Strong trend + RSI confirmation
                if rsi > 55 and row['close'] > sma and df['return_5'].iloc[idx] > 0:
                    entry = row['close']
                    sl = entry - atr * sl_mult
                    tp = entry + atr * tp_mult
                    lots = (equity * risk_pct / 100) / (atr * 100000)
                    lots = min(lots, 0.5)  # Cap lot size
                    
                    trade = Trade('momentum', 'BUY', entry, sl, tp, lots, idx)
                    self.open_trades.append(trade)
                
                elif rsi < 45 and row['close'] < sma and df['return_5'].iloc[idx] < 0:
                    entry = row['close']
                    sl = entry + atr * sl_mult
                    tp = entry - atr * tp_mult
                    lots = (equity * risk_pct / 100) / (atr * 100000)
                    lots = min(lots, 0.5)
                    
                    trade = Trade('momentum', 'SELL', entry, sl, tp, lots, idx)
                    self.open_trades.append(trade)
            
            # --- STRATEGY 2: Mean Reversion ---
            if 'mean_reversion' not in active_strategies and mr_ok:
                # Oversold bounce
                if rsi < 30 and row['close'] < lower_bb:
                    entry = row['close']
                    sl = entry - atr * sl_mult
                    tp = entry + atr * tp_mult * 0.5  # Tighter TP for MR
                    lots = (equity * risk_pct / 100) / (atr * 100000)
                    lots = min(lots, 0.5)
                    
                    trade = Trade('mean_reversion', 'BUY', entry, sl, tp, lots, idx)
                    self.open_trades.append(trade)
                
                # Overbought fade
                elif rsi > 70 and row['close'] > upper_bb:
                    entry = row['close']
                    sl = entry + atr * sl_mult
                    tp = entry - atr * tp_mult * 0.5
                    lots = (equity * risk_pct / 100) / (atr * 100000)
                    lots = min(lots, 0.5)
                    
                    trade = Trade('mean_reversion', 'SELL', entry, sl, tp, lots, idx)
                    self.open_trades.append(trade)
            
            # --- STRATEGY 3: Breakout ---
            if 'breakout' not in active_strategies and bo_ok:
                # High volatility breakout
                if df['atr_ratio'].iloc[idx] > 1.5 and not np.isnan(df['atr_ratio'].iloc[idx]):
                    if row['close'] > row['open']:  # Bullish candle
                        entry = row['close']
                        sl = entry - atr * sl_mult
                        tp = entry + atr * tp_mult * 1.5  # Wider TP for breakouts
                        lots = (equity * risk_pct / 100) / (atr * 100000)
                        lots = min(lots, 0.5)
                        
                        trade = Trade('breakout', 'BUY', entry, sl, tp, lots, idx)
                        self.open_trades.append(trade)
                    else:  # Bearish candle
                        entry = row['close']
                        sl = entry + atr * sl_mult
                        tp = entry - atr * tp_mult * 1.5
                        lots = (equity * risk_pct / 100) / (atr * 100000)
                        lots = min(lots, 0.5)
                        
                        trade = Trade('breakout', 'SELL', entry, sl, tp, lots, idx)
                        self.open_trades.append(trade)
            
            # --- STRATEGY 4: Gap Fill (Phantom) ---
            if 'gap_fill' not in active_strategies:
                # Monday gap detection
                if row['dayofweek'] == 0 and row['hour'] <= 4:
                    gap_pips = abs(df['gap_pips'].iloc[idx])
                    if not np.isnan(gap_pips) and 5 <= gap_pips <= 30:
                        gap_direction = 'up' if df['gap'].iloc[idx] > 0 else 'down'
                        
                        if gap_direction == 'up':
                            # Fade gap up → SELL
                            entry = row['close']
                            sl = entry + (gap_pips / 10000) * 2
                            tp = entry - (gap_pips / 10000) * 0.9
                            lots = (equity * risk_pct / 100) / ((gap_pips / 10000) * 100000)
                            lots = min(lots, 0.5)
                            
                            trade = Trade('gap_fill', 'SELL', entry, sl, tp, lots, idx)
                            self.open_trades.append(trade)
                        else:
                            # Fade gap down → BUY
                            entry = row['close']
                            sl = entry - (gap_pips / 10000) * 2
                            tp = entry + (gap_pips / 10000) * 0.9
                            lots = (equity * risk_pct / 100) / ((gap_pips / 10000) * 100000)
                            lots = min(lots, 0.5)
                            
                            trade = Trade('gap_fill', 'BUY', entry, sl, tp, lots, idx)
                            self.open_trades.append(trade)
            
            equity_curve.append(equity)
        
        # Close remaining trades
        for trade in list(self.open_trades):
            exit_price = df.iloc[-1]['close']
            if trade.direction == 'BUY':
                trade.pnl = (exit_price - trade.entry) * trade.lots * 100000
            else:
                trade.pnl = (trade.entry - exit_price) * trade.lots * 100000
            trade.pnl -= self.spread_pips * trade.lots * 10
            trade.status = 'WIN' if trade.pnl > 0 else 'LOSS'
            equity += trade.pnl
            self.closed_trades.append(trade)
        self.open_trades = []
        
        # Calculate results
        all_trades = self.closed_trades
        winning = [t for t in all_trades if t.pnl > 0]
        losing = [t for t in all_trades if t.pnl < 0]
        
        total_profit = sum(t.pnl for t in winning)
        total_loss = abs(sum(t.pnl for t in losing))
        
        equity_arr = np.array(equity_curve)
        peak = np.maximum.accumulate(equity_arr)
        dd = peak - equity_arr
        max_dd = np.max(dd)
        max_dd_pct = (max_dd / peak[np.argmax(dd)]) * 100 if peak[np.argmax(dd)] > 0 else 0
        
        # Per-strategy breakdown
        strategy_stats = {}
        for t in all_trades:
            if t.strategy not in strategy_stats:
                strategy_stats[t.strategy] = {'trades': 0, 'wins': 0, 'pnl': 0}
            strategy_stats[t.strategy]['trades'] += 1
            if t.pnl > 0:
                strategy_stats[t.strategy]['wins'] += 1
            strategy_stats[t.strategy]['pnl'] += t.pnl
        
        return {
            'initial_deposit': self.initial_deposit,
            'final_equity': equity,
            'net_profit': equity - self.initial_deposit,
            'gross_profit': total_profit,
            'gross_loss': total_loss,
            'profit_factor': total_profit / total_loss if total_loss > 0 else 999,
            'max_drawdown': max_dd,
            'max_drawdown_pct': max_dd_pct,
            'total_trades': len(all_trades),
            'winning_trades': len(winning),
            'losing_trades': len(losing),
            'win_rate': len(winning) / len(all_trades) if all_trades else 0,
            'strategy_stats': strategy_stats,
            'equity_curve': equity_curve,
        }


def print_results(results, label):
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    print(f"  Initial Deposit:  ${results['initial_deposit']:,.2f}")
    print(f"  Final Equity:     ${results['final_equity']:,.2f}")
    print(f"  Net Profit:       ${results['net_profit']:,.2f}")
    print(f"  Profit Factor:    {results['profit_factor']:.2f}")
    print(f"  Max Drawdown:     ${results['max_drawdown']:,.2f} ({results['max_drawdown_pct']:.1f}%)")
    print(f"  Total Trades:     {results['total_trades']}")
    print(f"  Win Rate:         {results['win_rate']:.1%}")
    
    print(f"\n  Strategy Breakdown:")
    for strat, stats in sorted(results['strategy_stats'].items(), key=lambda x: -x[1]['pnl']):
        wr = stats['wins'] / stats['trades'] * 100 if stats['trades'] > 0 else 0
        print(f"    {strat:20s}: {stats['trades']:3d} trades | ${stats['pnl']:>10,.2f} | WR: {wr:.0f}%")
    
    print(f"{'='*60}")


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'eurusd_h4_real.csv'
    
    print("=" * 60)
    print("DESTROYER QUANTUM — COMBINED STRATEGY BACKTESTER")
    print("=" * 60)
    
    # Load data
    df = load_data(filepath)
    print(f"Loaded {len(df)} bars")
    
    # Engineer features
    df = engineer_features(df)
    df = create_labels(df)
    
    # Create backtester
    bt = CombinedBacktester(initial_deposit=10000.0, spread_pips=21.0)
    
    # Train ML filter
    print("\nTraining ML filter...")
    bt.ml_filter.train(df)
    
    # Run without ML
    results_no_ml = bt.run(df, use_ml=False, max_concurrent=3)
    print_results(results_no_ml, "ALL STRATEGIES — NO ML FILTER")
    
    # Run with ML
    results_ml = bt.run(df, use_ml=True, max_concurrent=3)
    print_results(results_ml, "ALL STRATEGIES — WITH ML FILTER")
    
    # Comparison
    print(f"\n{'='*60}")
    print(f"  ML FILTER COMPARISON")
    print(f"{'='*60}")
    print(f"  {'Metric':25s} {'No ML':>12s} {'With ML':>12s} {'Change':>12s}")
    print(f"  {'-'*61}")
    print(f"  {'Net Profit':25s} ${results_no_ml['net_profit']:>10,.2f} ${results_ml['net_profit']:>10,.2f} ${results_ml['net_profit']-results_no_ml['net_profit']:>+10,.2f}")
    print(f"  {'Profit Factor':25s} {results_no_ml['profit_factor']:>12.2f} {results_ml['profit_factor']:>12.2f} {results_ml['profit_factor']-results_no_ml['profit_factor']:>+12.2f}")
    print(f"  {'Max Drawdown %':25s} {results_no_ml['max_drawdown_pct']:>11.1f}% {results_ml['max_drawdown_pct']:>11.1f}% {results_ml['max_drawdown_pct']-results_no_ml['max_drawdown_pct']:>+11.1f}%")
    print(f"  {'Total Trades':25s} {results_no_ml['total_trades']:>12d} {results_ml['total_trades']:>12d} {results_ml['total_trades']-results_no_ml['total_trades']:>+12d}")
    print(f"  {'Win Rate':25s} {results_no_ml['win_rate']:>11.1%} {results_ml['win_rate']:>11.1%} {results_ml['win_rate']-results_no_ml['win_rate']:>+11.1%}")
    print(f"{'='*60}")
    
    # Save results
    output = {
        'no_ml': {k: v for k, v in results_no_ml.items() if k != 'equity_curve' and k != 'strategy_stats'},
        'with_ml': {k: v for k, v in results_ml.items() if k != 'equity_curve' and k != 'strategy_stats'},
        'improvement': {
            'profit_change': results_ml['net_profit'] - results_no_ml['net_profit'],
            'pf_change': results_ml['profit_factor'] - results_no_ml['profit_factor'],
            'dd_change': results_ml['max_drawdown_pct'] - results_no_ml['max_drawdown_pct'],
        }
    }
    
    with open('combined_backtest_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    
    print("\nResults saved to combined_backtest_results.json")
    print("\n" + "=" * 60)
    print("BACKTEST COMPLETE")
    print("=" * 60)


if __name__ == '__main__':
    main()
