#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Regime Detection & Strategy Selector
Uses ML to classify market regimes and select optimal strategies.
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import classification_report, accuracy_score
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


def engineer_features(df):
    """Create features for ML model."""
    print("Engineering features...")
    
    # Price-based features
    df['return_1'] = df['close'].pct_change()
    df['return_5'] = df['close'].pct_change(5)
    df['return_10'] = df['close'].pct_change(10)
    df['return_20'] = df['close'].pct_change(20)
    
    # Volatility features
    for period in [5, 10, 20]:
        df[f'vol_{period}'] = df['return_1'].rolling(period).std()
    
    # ATR
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
    
    # Trend features
    for period in [20, 50, 100]:
        sma = df['close'].rolling(period).mean()
        df[f'dist_sma_{period}'] = (df['close'] - sma) / sma * 10000  # in pips
    
    # Momentum features
    df['rsi_14'] = calculate_rsi(df['close'], 14)
    df['rsi_7'] = calculate_rsi(df['close'], 7)
    
    # Bollinger Band position
    bb_period = 20
    sma = df['close'].rolling(bb_period).mean()
    std = df['close'].rolling(bb_period).std()
    df['bb_position'] = (df['close'] - sma) / (2 * std)  # -1 to +1
    df['bb_width'] = (4 * std) / sma * 10000  # in pips
    
    # Gap features
    df['gap'] = df['open'] - df['close'].shift(1)
    df['gap_pips'] = df['gap'] * 10000
    
    # Time features
    df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
    df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
    df['dow_sin'] = np.sin(2 * np.pi * df['dayofweek'] / 5)
    df['dow_cos'] = np.cos(2 * np.pi * df['dayofweek'] / 5)
    
    # Range features
    df['range'] = (df['high'] - df['low']) * 10000
    df['body'] = abs(df['close'] - df['open']) * 10000
    df['body_ratio'] = df['body'] / df['range'].replace(0, np.nan)
    
    return df


def calculate_rsi(prices, period):
    delta = prices.diff()
    gain = delta.where(delta > 0, 0).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))


def create_labels(df, forward_bars=6):
    """Create labels: which strategy would have been profitable?"""
    print("Creating labels...")
    
    # Forward returns
    df['fwd_return'] = df['close'].shift(-forward_bars) - df['close']
    df['fwd_return_pips'] = df['fwd_return'] * 10000
    
    # Label: which strategy would work?
    # 0 = No trade (choppy)
    # 1 = Momentum BUY (strong uptrend)
    # 2 = Momentum SELL (strong downtrend)  
    # 3 = Mean Reversion BUY (oversold bounce)
    # 4 = Mean Reversion SELL (overbought fade)
    # 5 = Breakout
    
    conditions = [
        # Momentum BUY: strong bullish, RSI not overbought
        (df['fwd_return_pips'] > 20) & (df['rsi_14'] < 70) & (df['return_5'] > 0),
        # Momentum SELL: strong bearish, RSI not oversold
        (df['fwd_return_pips'] < -20) & (df['rsi_14'] > 30) & (df['return_5'] < 0),
        # Mean Reversion BUY: oversold, price at lower BB
        (df['fwd_return_pips'] > 10) & (df['rsi_14'] < 35) & (df['bb_position'] < -0.5),
        # Mean Reversion SELL: overbought, price at upper BB
        (df['fwd_return_pips'] < -10) & (df['rsi_14'] > 65) & (df['bb_position'] > 0.5),
        # Breakout: large range, high ATR ratio
        (df['atr_ratio'] > 1.5) & (abs(df['fwd_return_pips']) > 15),
    ]
    choices = [1, 2, 3, 4, 5]
    df['label'] = np.select(conditions, choices, default=0)
    
    print(f"\nLabel distribution:")
    for label, count in df['label'].value_counts().sort_index().items():
        print(f"  Label {label}: {count} ({count/len(df)*100:.1f}%)")
    
    return df


def train_model(df):
    """Train regime detection model."""
    print("\nTraining model...")
    
    feature_cols = [
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
    
    # Drop NaN
    df_clean = df.dropna(subset=feature_cols + ['label'])
    
    X = df_clean[feature_cols].values
    y = df_clean['label'].values
    
    # Scale features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Time series cross-validation
    tscv = TimeSeriesSplit(n_splits=5)
    
    best_model = None
    best_accuracy = 0
    
    for fold, (train_idx, test_idx) in enumerate(tscv.split(X_scaled)):
        X_train, X_test = X_scaled[train_idx], X_scaled[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]
        
        # Train Random Forest
        model = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=4,
            learning_rate=0.1,
            random_state=42,
        )
        model.fit(X_train, y_train)
        
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        print(f"  Fold {fold+1}: Accuracy = {accuracy:.3f}")
        
        if accuracy > best_accuracy:
            best_accuracy = accuracy
            best_model = model
    
    print(f"\nBest model accuracy: {best_accuracy:.3f}")
    
    # Feature importance
    importance = best_model.feature_importances_
    feature_importance = sorted(zip(feature_cols, importance), key=lambda x: -x[1])
    
    print("\nTop 10 Important Features:")
    for feat, imp in feature_importance[:10]:
        print(f"  {feat:20s}: {imp:.4f}")
    
    return best_model, scaler, feature_cols


def generate_strategy_signals(df, model, scaler, feature_cols):
    """Generate strategy signals using trained model."""
    print("\nGenerating strategy signals...")
    
    df_clean = df.dropna(subset=feature_cols)
    X = scaler.transform(df_clean[feature_cols].values)
    
    predictions = model.predict(X)
    probabilities = model.predict_proba(X)
    
    # Add predictions to dataframe
    df.loc[df_clean.index, 'predicted_regime'] = predictions
    
    # Calculate signal confidence
    for i, prob in enumerate(probabilities):
        max_prob = max(prob)
        idx = df_clean.index[i]
        df.loc[idx, 'signal_confidence'] = max_prob
    
    # Strategy recommendations
    strategy_map = {
        0: 'NO_TRADE',
        1: 'MOMENTUM_BUY',
        2: 'MOMENTUM_SELL',
        3: 'MEAN_REVERSION_BUY',
        4: 'MEAN_REVERSION_SELL',
        5: 'BREAKOUT',
    }
    
    df['strategy'] = df['predicted_regime'].map(strategy_map)
    
    # Summary
    print("\nStrategy Signal Distribution:")
    for strategy, count in df['strategy'].value_counts().items():
        avg_conf = df[df['strategy'] == strategy]['signal_confidence'].mean()
        print(f"  {strategy:25s}: {count:4d} signals | Avg confidence: {avg_conf:.2f}")
    
    return df


def save_model_results(model, scaler, feature_cols, df, filename='ml_model_results.json'):
    """Save model and results."""
    results = {
        'feature_cols': feature_cols,
        'feature_importance': dict(zip(feature_cols, model.feature_importances_.tolist())),
        'strategy_distribution': df['strategy'].value_counts().to_dict(),
        'model_type': 'GradientBoostingClassifier',
        'n_estimators': 100,
        'max_depth': 4,
    }
    
    with open(filename, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nModel results saved to {filename}")


def generate_set_recommendations(df):
    """Generate .set file recommendations based on ML analysis."""
    print("\n=== ML-BASED .SET FILE RECOMMENDATIONS ===")
    
    # Analyze which strategies are most recommended
    strategy_counts = df['strategy'].value_counts()
    total_signals = len(df[df['strategy'] != 'NO_TRADE'])
    
    recommendations = {}
    
    # Phantom (gap fill) - always enabled
    recommendations['InpPhantom_Enabled'] = 'true'
    
    # Mean Reversion - enable if lots of MR signals
    mr_signals = strategy_counts.get('MEAN_REVERSION_BUY', 0) + strategy_counts.get('MEAN_REVERSION_SELL', 0)
    if mr_signals > 100:
        recommendations['InpMeanReversion_Enabled'] = 'true'
        print(f"  Mean Reversion: ENABLED ({mr_signals} signals)")
    else:
        recommendations['InpMeanReversion_Enabled'] = 'false'
        print(f"  Mean Reversion: DISABLED ({mr_signals} signals, too few)")
    
    # Session Momentum - enable if lots of momentum signals
    mom_signals = strategy_counts.get('MOMENTUM_BUY', 0) + strategy_counts.get('MOMENTUM_SELL', 0)
    if mom_signals > 100:
        recommendations['InpSessionMomentum_Enabled'] = 'true'
        print(f"  Session Momentum: ENABLED ({mom_signals} signals)")
    else:
        recommendations['InpSessionMomentum_Enabled'] = 'false'
        print(f"  Session Momentum: DISABLED ({mom_signals} signals, too few)")
    
    # Noise Breakout - enable if lots of breakout signals
    bo_signals = strategy_counts.get('BREAKOUT', 0)
    if bo_signals > 50:
        recommendations['InpNoiseBreakout_Enabled'] = 'true'
        print(f"  Noise Breakout: ENABLED ({bo_signals} signals)")
    else:
        recommendations['InpNoiseBreakout_Enabled'] = 'false'
        print(f"  Noise Breakout: DISABLED ({bo_signals} signals, too few)")
    
    # Reaper - always enabled (grid)
    recommendations['InpReaper_Enabled'] = 'true'
    
    # Risk adjustments based on volatility
    avg_vol = df['vol_20'].mean()
    if avg_vol > 0.005:
        recommendations['InpBase_Risk'] = 1.0  # Lower risk in high vol
        print(f"  Risk: REDUCED to 1.0% (high volatility)")
    else:
        recommendations['InpBase_Risk'] = 1.5  # Normal risk
        print(f"  Risk: NORMAL at 1.5% (low volatility)")
    
    print("\nRecommended .set parameters:")
    for key, value in recommendations.items():
        print(f"  {key} = {value}")
    
    return recommendations


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'eurusd_h4_real.csv'
    
    print("=" * 60)
    print("DESTROYER QUANTUM — ML REGIME DETECTION")
    print("=" * 60)
    
    # Load and prepare data
    df = load_data(filepath)
    print(f"Loaded {len(df)} bars")
    
    # Engineer features
    df = engineer_features(df)
    
    # Create labels
    df = create_labels(df)
    
    # Train model
    model, scaler, feature_cols = train_model(df)
    
    # Generate signals
    df = generate_strategy_signals(df, model, scaler, feature_cols)
    
    # Save results
    save_model_results(model, scaler, feature_cols, df)
    
    # Generate recommendations
    recommendations = generate_set_recommendations(df)
    
    print("\n" + "=" * 60)
    print("ML ANALYSIS COMPLETE")
    print("=" * 60)


if __name__ == '__main__':
    main()
