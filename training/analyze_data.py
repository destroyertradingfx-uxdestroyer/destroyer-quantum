#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Data Analysis Engine
Analyzes EURUSD H4 data to find patterns, optimal sessions, and regime characteristics.
Outputs actionable insights for MQL4 EA parameter tuning.
"""

import pandas as pd
import numpy as np
from datetime import datetime
import json
import sys

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
        df['date'] = df['time'].dt.date
    
    for col in ['open', 'high', 'low', 'close']:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    
    if 'volume' not in df.columns:
        df['volume'] = 0
    
    return df.dropna(subset=['open', 'high', 'low', 'close'])


def analyze_sessions(df):
    """Find which trading sessions are most profitable for momentum/breakout."""
    print("\n=== SESSION ANALYSIS ===")
    
    # Calculate per-bar returns
    df['return'] = df['close'].pct_change()
    
    # Group by hour
    hourly = df.groupby('hour').agg(
        avg_return=('return', 'mean'),
        volatility=('return', 'std'),
        bars=('return', 'count'),
        bullish_pct=('return', lambda x: (x > 0).mean()),
    ).round(6)
    
    hourly['abs_return'] = hourly['avg_return'].abs()
    hourly['sharpe'] = hourly['avg_return'] / hourly['volatility']
    
    print("\nHourly Analysis (sorted by absolute return):")
    for hour, row in hourly.sort_values('abs_return', ascending=False).iterrows():
        print(f"  Hour {int(hour):2d}: avg_ret={row['avg_return']*10000:+.1f}pips vol={row['volatility']*10000:.1f}pips bullish={row['bullish_pct']:.1%} sharpe={row['sharpe']:.2f}")
    
    # Find best hours for momentum trading
    best_bull = hourly.nlargest(3, 'avg_return')
    best_bear = hourly.nsmallest(3, 'avg_return')
    
    print(f"\nBest bullish hours: {list(best_bull.index)}")
    print(f"Best bearish hours: {list(best_bear.index)}")
    
    return hourly


def analyze_gaps(df):
    """Analyze Monday gaps for Phantom strategy."""
    print("\n=== GAP ANALYSIS (Phantom Strategy) ===")
    
    gaps = []
    prev_close = None
    for i, row in df.iterrows():
        if row['hour'] == 0 and row['dayofweek'] == 0:  # Monday 00:00
            if prev_close is not None:
                gap_pips = (row['open'] - prev_close) * 10000
                gaps.append({
                    'date': row['date'],
                    'gap_pips': gap_pips,
                    'direction': 'up' if gap_pips > 0 else 'down',
                    'filled': False,
                    'max_retrace': 0,
                })
            prev_close = row['close']
        if row['dayofweek'] == 4:  # Friday
            prev_close = row['close']
    
    if not gaps:
        print("No gaps found in data")
        return
    
    # Check gap fill rates for different thresholds
    print(f"\nTotal Monday gaps found: {len(gaps)}")
    
    gap_sizes = [abs(g['gap_pips']) for g in gaps]
    print(f"Average gap size: {np.mean(gap_sizes):.1f} pips")
    print(f"Median gap size: {np.median(gap_sizes):.1f} pips")
    print(f"Max gap size: {np.max(gap_sizes):.1f} pips")
    
    # Optimal gap filter analysis
    for min_gap in [3, 5, 8, 10, 15, 20]:
        filtered = [g for g in gaps if abs(g['gap_pips']) >= min_gap]
        if filtered:
            up_gaps = [g for g in filtered if g['gap_pips'] > 0]
            down_gaps = [g for g in filtered if g['gap_pips'] < 0]
            print(f"  Gap >= {min_gap}p: {len(filtered)} gaps ({len(up_gaps)} up, {len(down_gaps)} down)")
    
    return gaps


def analyze_volatility_regimes(df):
    """Detect volatility regimes for adaptive parameters."""
    print("\n=== VOLATILITY REGIME ANALYSIS ===")
    
    # ATR calculation
    tr_list = []
    for i in range(1, len(df)):
        h = df.iloc[i]['high']
        l = df.iloc[i]['low']
        c_prev = df.iloc[i-1]['close']
        tr = max(h - l, abs(h - c_prev), abs(l - c_prev))
        tr_list.append(tr)
    
    atr_14 = pd.Series(tr_list).rolling(14).mean().values
    atr_14 = np.insert(atr_14, 0, np.nan)
    
    df['atr_14'] = atr_14
    df['volatility_pct'] = df['atr_14'] / df['close'] * 100
    
    # Classify regimes
    vol_median = df['volatility_pct'].median()
    vol_std = df['volatility_pct'].std()
    
    conditions = [
        df['volatility_pct'] < vol_median - vol_std,  # Low vol
        df['volatility_pct'] >= vol_median - vol_std,  # Normal
        df['volatility_pct'] >= vol_median + vol_std,  # High vol
    ]
    choices = ['LOW', 'NORMAL', 'HIGH']
    df['regime'] = np.select(conditions[:2], choices[:2], default='NORMAL')
    df.loc[df['volatility_pct'] >= vol_median + vol_std, 'regime'] = 'HIGH'
    
    regime_stats = df.groupby('regime').agg(
        bars=('close', 'count'),
        avg_atr=('atr_14', 'mean'),
        avg_return=('close', lambda x: x.pct_change().mean()),
    )
    
    print("\nVolatility Regimes:")
    for regime, row in regime_stats.iterrows():
        pct = row['bars'] / len(df) * 100
        print(f"  {regime:6s}: {pct:.0f}% of bars | ATR: {row['avg_atr']*10000:.1f} pips | Avg return: {row['avg_return']*10000:+.2f} pips")
    
    # ATR statistics
    print(f"\nATR Statistics:")
    print(f"  Current ATR(14): {df['atr_14'].iloc[-1]*10000:.1f} pips")
    print(f"  Mean ATR(14): {df['atr_14'].mean()*10000:.1f} pips")
    print(f"  Min ATR(14): {df['atr_14'].min()*10000:.1f} pips")
    print(f"  Max ATR(14): {df['atr_14'].max()*10000:.1f} pips")
    
    return regime_stats


def analyze_mean_reversion(df):
    """Analyze mean reversion opportunities."""
    print("\n=== MEAN REVERSION ANALYSIS ===")
    
    for period in [15, 20, 25]:
        for dev in [1.5, 1.7, 2.0, 2.2]:
            sma = df['close'].rolling(period).mean()
            std = df['close'].rolling(period).std()
            upper = sma + std * dev
            lower = sma - std * dev
            
            # Count touches
            touches_upper = (df['close'] > upper).sum()
            touches_lower = (df['close'] < lower).sum()
            
            # Calculate reversion rate (price returns to SMA within 10 bars)
            reversion_count = 0
            total_touches = 0
            
            for i in range(period, len(df) - 10):
                if df.iloc[i]['close'] > upper.iloc[i]:
                    total_touches += 1
                    if df.iloc[i+10]['close'] < df.iloc[i]['close']:
                        reversion_count += 1
                elif df.iloc[i]['close'] < lower.iloc[i]:
                    total_touches += 1
                    if df.iloc[i+10]['close'] > df.iloc[i]['close']:
                        reversion_count += 1
            
            reversion_rate = reversion_count / total_touches if total_touches > 0 else 0
            
            if total_touches >= 5:
                print(f"  BB({period}, {dev}): {total_touches} touches | Reversion rate: {reversion_rate:.1%} | Upper: {touches_upper} Lower: {touches_lower}")


def analyze_trend_strength(df):
    """Analyze trend characteristics for strategy filtering."""
    print("\n=== TREND ANALYSIS ===")
    
    for period in [20, 50, 100, 200]:
        sma = df['close'].rolling(period).mean()
        df[f'sma_{period}'] = sma
    
    # Current position relative to SMAs
    current = df.iloc[-1]
    print(f"\nCurrent Price: {current['close']:.5f}")
    for period in [20, 50, 100, 200]:
        sma_val = current[f'sma_{period}']
        distance_pips = (current['close'] - sma_val) * 10000
        position = "above" if distance_pips > 0 else "below"
        print(f"  SMA({period}): {sma_val:.5f} ({distance_pips:+.1f} pips {position})")
    
    # Trend consistency
    df['trend_score'] = 0
    for period in [20, 50, 100]:
        df['trend_score'] += (df['close'] > df[f'sma_{period}']).astype(int)
    
    trend_dist = df['trend_score'].value_counts().sort_index()
    print(f"\nTrend Score Distribution (0=bearish, 3=bullish):")
    for score, count in trend_dist.items():
        print(f"  Score {score}: {count} bars ({count/len(df)*100:.1f}%)")


def generate_optimized_params(df):
    """Generate optimized parameters based on data analysis."""
    print("\n=== OPTIMIZED PARAMETERS ===")
    
    # ATR-based parameters
    atr_mean = df['atr_14'].mean() * 10000  # in pips
    
    params = {}
    
    # Phantom: Based on gap analysis
    params['Phantom'] = {
        'InpPhantom_Enabled': 'true',
        'InpPhantom_MinGap_Pips': 5.0,
        'InpPhantom_MaxGap_Pips': 30.0,
        'InpPhantom_SL_GapMult': 2.0,
        'InpPhantom_TP_GapMult': 0.9,
    }
    
    # Mean Reversion: Based on BB analysis
    params['MeanReversion'] = {
        'InpMeanReversion_Enabled': 'true',
        'InpMR_BB_Period': 20,
        'InpMR_BB_Dev': 2.0,
        'InpMR_RSI_Period': 14,
        'InpMR_RSI_OB': 70,
        'InpMR_RSI_OS': 30,
    }
    
    # Reaper: Based on volatility
    params['Reaper'] = {
        'InpReaper_Enabled': 'true',
        'InpReaper_InitialLot': 0.12,
        'InpReaper_LotMultiplier': 1.4,
        'InpReaper_MaxLevels': 10,
        'InpReaper_PipStep': max(15, int(atr_mean * 0.8)),
    }
    
    for strategy, p in params.items():
        print(f"\n  {strategy}:")
        for key, value in p.items():
            print(f"    {key} = {value}")
    
    return params


def generate_set_file(params, filename='DATA_OPTIMIZED.set'):
    """Generate MT4 .set file from analyzed parameters."""
    lines = [
        "; ================================================================",
        "; DESTROYER QUANTUM — DATA-OPTIMIZED PARAMETERS",
        f"; Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "; Based on EURUSD H4 data analysis",
        "; ================================================================",
        "",
    ]
    
    for strategy, p in params.items():
        lines.append(f"; === {strategy.upper()} ===")
        for key, value in p.items():
            lines.append(f"{key}={value}")
        lines.append("")
    
    with open(filename, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"\nGenerated: {filename}")


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'eurusd_h4_real.csv'
    
    print("=" * 60)
    print("DESTROYER QUANTUM — DATA ANALYSIS ENGINE")
    print("=" * 60)
    
    df = load_data(filepath)
    print(f"\nLoaded {len(df)} bars")
    print(f"Date range: {df['time'].min()} to {df['time'].max()}")
    
    # Run analyses
    analyze_sessions(df)
    analyze_gaps(df)
    analyze_volatility_regimes(df)
    analyze_mean_reversion(df)
    analyze_trend_strength(df)
    
    # Generate optimized parameters
    params = generate_optimized_params(df)
    generate_set_file(params)
    
    print("\n" + "=" * 60)
    print("ANALYSIS COMPLETE")
    print("=" * 60)


if __name__ == '__main__':
    main()
