"""
DESTROYER QUANTUM — Python Training Framework
Trains and optimizes strategy parameters using historical data.
"""

import pandas as pd
import numpy as np
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
import json
from datetime import datetime


# ============================================================
# DATA STRUCTURES
# ============================================================

@dataclass
class Trade:
    strategy: str
    direction: str  # 'BUY' or 'SELL'
    entry_price: float
    entry_time: datetime
    sl_price: float
    tp_price: float
    lot_size: float
    exit_price: float = 0.0
    exit_time: Optional[datetime] = None
    pnl: float = 0.0
    status: str = 'OPEN'  # OPEN, CLOSED_WIN, CLOSED_LOSS, CLOSED_SL, CLOSED_TP


@dataclass
class StrategyPerformance:
    name: str
    trades: List[Trade] = field(default_factory=list)
    
    @property
    def total_trades(self) -> int:
        return len(self.trades)
    
    @property
    def winning_trades(self) -> int:
        return len([t for t in self.trades if t.pnl > 0])
    
    @property
    def losing_trades(self) -> int:
        return len([t for t in self.trades if t.pnl < 0])
    
    @property
    def win_rate(self) -> float:
        if self.total_trades == 0:
            return 0.0
        return self.winning_trades / self.total_trades
    
    @property
    def gross_profit(self) -> float:
        return sum(t.pnl for t in self.trades if t.pnl > 0)
    
    @property
    def gross_loss(self) -> float:
        return abs(sum(t.pnl for t in self.trades if t.pnl < 0))
    
    @property
    def net_profit(self) -> float:
        return sum(t.pnl for t in self.trades)
    
    @property
    def profit_factor(self) -> float:
        if self.gross_loss == 0:
            return 999.0 if self.gross_profit > 0 else 0.0
        return self.gross_profit / self.gross_loss
    
    @property
    def avg_win(self) -> float:
        wins = [t.pnl for t in self.trades if t.pnl > 0]
        return np.mean(wins) if wins else 0.0
    
    @property
    def avg_loss(self) -> float:
        losses = [abs(t.pnl) for t in self.trades if t.pnl < 0]
        return np.mean(losses) if losses else 0.0
    
    @property
    def max_consecutive_losses(self) -> int:
        max_streak = 0
        current_streak = 0
        for t in self.trades:
            if t.pnl < 0:
                current_streak += 1
                max_streak = max(max_streak, current_streak)
            else:
                current_streak = 0
        return max_streak
    
    @property
    def sharpe_ratio(self) -> float:
        if len(self.trades) < 2:
            return 0.0
        returns = [t.pnl for t in self.trades]
        mean_ret = np.mean(returns)
        std_ret = np.std(returns)
        if std_ret == 0:
            return 0.0
        return mean_ret / std_ret * np.sqrt(252)  # Annualized


@dataclass
class BacktestResult:
    initial_deposit: float
    final_equity: float
    net_profit: float
    gross_profit: float
    gross_loss: float
    profit_factor: float
    max_drawdown: float
    max_drawdown_pct: float
    total_trades: int
    win_rate: float
    strategies: Dict[str, StrategyPerformance]
    equity_curve: List[float]
    
    @property
    def profit_target_hit(self) -> bool:
        return self.final_equity >= 75000.0
    
    def summary(self) -> str:
        lines = [
            f"=== DESTROYER QUANTUM BACKTEST RESULTS ===",
            f"Initial Deposit:  ${self.initial_deposit:,.2f}",
            f"Final Equity:     ${self.final_equity:,.2f}",
            f"Net Profit:       ${self.net_profit:,.2f}",
            f"Gross Profit:     ${self.gross_profit:,.2f}",
            f"Gross Loss:       ${self.gross_loss:,.2f}",
            f"Profit Factor:    {self.profit_factor:.2f}",
            f"Max Drawdown:     ${self.max_drawdown:,.2f} ({self.max_drawdown_pct:.2f}%)",
            f"Total Trades:     {self.total_trades}",
            f"Win Rate:         {self.win_rate:.2%}",
            f"",
            f"=== STRATEGY BREAKDOWN ===",
        ]
        for name, perf in sorted(self.strategies.items(), key=lambda x: -x[1].net_profit):
            lines.append(
                f"  {name:30s} | Trades: {perf.total_trades:4d} | "
                f"PF: {perf.profit_factor:6.2f} | "
                f"Net: ${perf.net_profit:>10,.2f} | "
                f"WR: {perf.win_rate:.1%}"
            )
        return "\n".join(lines)


# ============================================================
# STRATEGY IMPLEMENTATIONS
# ============================================================

class BaseStrategy:
    """Base class for all strategies."""
    
    def __init__(self, name: str, params: dict):
        self.name = name
        self.params = params
        self.open_trades: List[Trade] = []
        self.closed_trades: List[Trade] = []
    
    def check_entry(self, bars: pd.DataFrame, idx: int) -> Optional[Trade]:
        """Override in subclass. Returns a Trade if entry conditions are met."""
        raise NotImplementedError
    
    def check_exit(self, bars: pd.DataFrame, idx: int, trade: Trade) -> Optional[float]:
        """Override in subclass. Returns exit price if exit conditions are met."""
        raise NotImplementedError
    
    def get_performance(self) -> StrategyPerformance:
        return StrategyPerformance(
            name=self.name,
            trades=self.closed_trades + self.open_trades
        )


class PhantomStrategy(BaseStrategy):
    """
    Phantom Gap Fill Strategy
    Fades Monday gaps against the gap direction.
    Entry: Monday open vs Friday close, gap > min_gap and < max_gap
    SL: gap * sl_mult, TP: gap * tp_mult
    """
    
    def __init__(self, params: dict):
        defaults = {
            'enabled': True,
            'min_gap_pips': 5.0,
            'max_gap_pips': 30.0,
            'sl_gap_mult': 2.0,
            'tp_gap_mult': 0.9,
            'risk_pct': 1.5,
        }
        merged = {**defaults, **params}
        super().__init__("Phantom", merged)
    
    def check_entry(self, bars: pd.DataFrame, idx: int) -> Optional[Trade]:
        if not self.params['enabled']:
            return None
        
        if len(self.open_trades) > 0:
            return None
        
        row = bars.iloc[idx]
        
        # Only trade on Monday (dayofweek == 0 in pandas)
        if row['dayofweek'] != 0:
            return None
        
        # Only first H4 bar of Monday (hour 0-4)
        if row['hour'] > 4:
            return None
        
        # Find Friday close (scan back)
        friday_close = None
        for lookback in range(1, min(10, idx + 1)):
            prev_row = bars.iloc[idx - lookback]
            if prev_row['dayofweek'] == 4:  # Friday
                friday_close = prev_row['close']
                break
            elif prev_row['dayofweek'] == 3 and prev_row['hour'] >= 20:
                friday_close = prev_row['close']
                break
        
        if friday_close is None:
            return None
        
        monday_open = row['open']
        gap_pips = abs(monday_open - friday_close) * 10000  # EURUSD pips
        
        if gap_pips < self.params['min_gap_pips']:
            return None
        if gap_pips > self.params['max_gap_pips']:
            return None
        
        gap_price = gap_pips / 10000
        sl = gap_price * self.params['sl_gap_mult']
        tp = gap_price * self.params['tp_gap_mult']
        
        # Fade the gap
        if monday_open > friday_close:
            # Gap up → SELL
            entry = row['close']
            sl_price = entry + sl
            tp_price = entry - tp
            direction = 'SELL'
        else:
            # Gap down → BUY
            entry = row['close']
            sl_price = entry - sl
            tp_price = entry + tp
            direction = 'BUY'
        
        lot_size = self.params.get('lot_size', 0.1)
        
        trade = Trade(
            strategy=self.name,
            direction=direction,
            entry_price=entry,
            entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
            sl_price=sl_price,
            tp_price=tp_price,
            lot_size=lot_size,
        )
        self.open_trades.append(trade)
        return trade
    
    def check_exit(self, bars: pd.DataFrame, idx: int, trade: Trade) -> Optional[float]:
        row = bars.iloc[idx]
        high = row['high']
        low = row['low']
        
        if trade.direction == 'BUY':
            if low <= trade.sl_price:
                return trade.sl_price
            if high >= trade.tp_price:
                return trade.tp_price
        else:  # SELL
            if high >= trade.sl_price:
                return trade.sl_price
            if low <= trade.tp_price:
                return trade.tp_price
        
        return None


class NoiseBreakoutStrategy(BaseStrategy):
    """
    Noise Breakout Strategy
    Detects false breakouts and trades the reversal.
    """
    
    def __init__(self, params: dict):
        defaults = {
            'enabled': True,
            'lookback': 20,
            'noise_threshold': 0.5,
            'atr_period': 14,
            'atr_mult_sl': 1.5,
            'atr_mult_tp': 2.0,
            'risk_pct': 1.5,
        }
        merged = {**defaults, **params}
        super().__init__("NoiseBreakout", merged)
    
    def _calc_atr(self, bars: pd.DataFrame, idx: int, period: int) -> float:
        if idx < period:
            return 0.001
        highs = bars['high'].iloc[idx-period:idx]
        lows = bars['low'].iloc[idx-period:idx]
        closes = bars['close'].iloc[idx-period:idx]
        tr = pd.concat([
            highs.values - lows.values,
            np.abs(highs.values - np.roll(closes.values, 1)),
            np.abs(lows.values - np.roll(closes.values, 1))
        ], axis=1).max(axis=1) if False else 0
        
        # Simple ATR calculation
        tr_list = []
        for i in range(idx-period, idx):
            h = bars.iloc[i]['high']
            l = bars.iloc[i]['low']
            c_prev = bars.iloc[i-1]['close'] if i > 0 else bars.iloc[i]['open']
            tr = max(h - l, abs(h - c_prev), abs(l - c_prev))
            tr_list.append(tr)
        return np.mean(tr_list) if tr_list else 0.001
    
    def check_entry(self, bars: pd.DataFrame, idx: int) -> Optional[Trade]:
        if not self.params['enabled']:
            return None
        
        if len(self.open_trades) > 0:
            return None
        
        if idx < self.params['lookback'] + 1:
            return None
        
        row = bars.iloc[idx]
        prev = bars.iloc[idx - 1]
        
        atr = self._calc_atr(bars, idx, self.params['atr_period'])
        
        # Look for false breakouts
        lookback = self.params['lookback']
        high_n = bars['high'].iloc[idx-lookback:idx].max()
        low_n = bars['low'].iloc[idx-lookback:idx].min()
        
        # Breakout above → reversal SELL
        if prev['high'] > high_n and row['close'] < prev['close']:
            if (prev['high'] - high_n) < atr * self.params['noise_threshold']:
                entry = row['close']
                sl_price = entry + atr * self.params['atr_mult_sl']
                tp_price = entry - atr * self.params['atr_mult_tp']
                
                trade = Trade(
                    strategy=self.name,
                    direction='SELL',
                    entry_price=entry,
                    entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                    sl_price=sl_price,
                    tp_price=tp_price,
                    lot_size=self.params.get('lot_size', 0.1),
                )
                self.open_trades.append(trade)
                return trade
        
        # Breakout below → reversal BUY
        elif prev['low'] < low_n and row['close'] > prev['close']:
            if (low_n - prev['low']) < atr * self.params['noise_threshold']:
                entry = row['close']
                sl_price = entry - atr * self.params['atr_mult_sl']
                tp_price = entry + atr * self.params['atr_mult_tp']
                
                trade = Trade(
                    strategy=self.name,
                    direction='BUY',
                    entry_price=entry,
                    entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                    sl_price=sl_price,
                    tp_price=tp_price,
                    lot_size=self.params.get('lot_size', 0.1),
                )
                self.open_trades.append(trade)
                return trade
        
        return None
    
    def check_exit(self, bars: pd.DataFrame, idx: int, trade: Trade) -> Optional[float]:
        row = bars.iloc[idx]
        if trade.direction == 'BUY':
            if row['low'] <= trade.sl_price:
                return trade.sl_price
            if row['high'] >= trade.tp_price:
                return trade.tp_price
        else:
            if row['high'] >= trade.sl_price:
                return trade.sl_price
            if row['low'] <= trade.tp_price:
                return trade.tp_price
        return None


class MeanReversionStrategy(BaseStrategy):
    """
    Mean Reversion Strategy using Bollinger Bands + RSI
    """
    
    def __init__(self, params: dict):
        defaults = {
            'enabled': True,
            'bb_period': 20,
            'bb_dev': 2.0,
            'rsi_period': 14,
            'rsi_ob': 70,
            'rsi_os': 30,
            'adx_threshold': 25,
            'atr_period': 14,
            'sl_atr_mult': 1.5,
            'tp_atr_mult': 1.0,
            'risk_pct': 1.5,
        }
        merged = {**defaults, **params}
        super().__init__("MeanReversion", merged)
    
    def _calc_rsi(self, closes: pd.Series, period: int) -> float:
        if len(closes) < period + 1:
            return 50.0
        delta = closes.diff()
        gain = delta.where(delta > 0, 0).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return rsi.iloc[-1] if not np.isnan(rsi.iloc[-1]) else 50.0
    
    def _calc_bb(self, closes: pd.Series, period: int, dev: float):
        if len(closes) < period:
            return None, None, None
        sma = closes.rolling(window=period).mean()
        std = closes.rolling(window=period).std()
        upper = sma + std * dev
        lower = sma - std * dev
        return upper.iloc[-1], sma.iloc[-1], lower.iloc[-1]
    
    def check_entry(self, bars: pd.DataFrame, idx: int) -> Optional[Trade]:
        if not self.params['enabled']:
            return None
        
        if len(self.open_trades) > 0:
            return None
        
        if idx < max(self.params['bb_period'], self.params['rsi_period']) + 1:
            return None
        
        row = bars.iloc[idx]
        closes = bars['close'].iloc[:idx+1]
        
        rsi = self._calc_rsi(closes, self.params['rsi_period'])
        upper_bb, middle_bb, lower_bb = self._calc_bb(
            closes, self.params['bb_period'], self.params['bb_dev']
        )
        
        if upper_bb is None:
            return None
        
        atr = self._calc_atr(bars, idx, self.params['atr_period'])
        
        # BUY: Price at lower BB + RSI oversold
        if row['close'] <= lower_bb and rsi < self.params['rsi_os']:
            entry = row['close']
            sl_price = entry - atr * self.params['sl_atr_mult']
            tp_price = entry + atr * self.params['tp_atr_mult']
            
            trade = Trade(
                strategy=self.name,
                direction='BUY',
                entry_price=entry,
                entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                sl_price=sl_price,
                tp_price=tp_price,
                lot_size=self.params.get('lot_size', 0.1),
            )
            self.open_trades.append(trade)
            return trade
        
        # SELL: Price at upper BB + RSI overbought
        elif row['close'] >= upper_bb and rsi > self.params['rsi_ob']:
            entry = row['close']
            sl_price = entry + atr * self.params['sl_atr_mult']
            tp_price = entry - atr * self.params['tp_atr_mult']
            
            trade = Trade(
                strategy=self.name,
                direction='SELL',
                entry_price=entry,
                entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                sl_price=sl_price,
                tp_price=tp_price,
                lot_size=self.params.get('lot_size', 0.1),
            )
            self.open_trades.append(trade)
            return trade
        
        return None
    
    def _calc_atr(self, bars: pd.DataFrame, idx: int, period: int) -> float:
        if idx < period:
            return 0.001
        tr_list = []
        for i in range(idx-period, idx):
            h = bars.iloc[i]['high']
            l = bars.iloc[i]['low']
            c_prev = bars.iloc[i-1]['close'] if i > 0 else bars.iloc[i]['open']
            tr = max(h - l, abs(h - c_prev), abs(l - c_prev))
            tr_list.append(tr)
        return np.mean(tr_list) if tr_list else 0.001
    
    def check_exit(self, bars: pd.DataFrame, idx: int, trade: Trade) -> Optional[float]:
        row = bars.iloc[idx]
        if trade.direction == 'BUY':
            if row['low'] <= trade.sl_price:
                return trade.sl_price
            if row['high'] >= trade.tp_price:
                return trade.tp_price
        else:
            if row['high'] >= trade.sl_price:
                return trade.sl_price
            if row['low'] <= trade.tp_price:
                return trade.tp_price
        return None


class ReaperGridStrategy(BaseStrategy):
    """
    Reaper Grid Strategy
    Opens grid levels with increasing lot sizes.
    """
    
    def __init__(self, params: dict):
        defaults = {
            'enabled': True,
            'initial_lot': 0.08,
            'lot_multiplier': 1.3,
            'max_levels': 8,
            'pip_step': 25,
            'basket_tp_pips': 50,
            'basket_tp_money': 400,
            'trail_start_money': 150,
            'trail_stop_pips': 300,
            'risk_pct': 1.0,
        }
        merged = {**defaults, **params}
        super().__init__("Reaper", merged)
        self.grid_levels = 0
        self.grid_direction = None
        self.grid_avg_price = 0.0
        self.grid_total_lots = 0.0
    
    def check_entry(self, bars: pd.DataFrame, idx: int) -> Optional[Trade]:
        if not self.params['enabled']:
            return None
        
        if self.grid_levels >= self.params['max_levels']:
            return None
        
        row = bars.iloc[idx]
        
        # Simple grid logic: open new level when price moves against us by pip_step
        pip_step = self.params['pip_step'] / 10000
        
        if self.grid_levels == 0:
            # First entry based on trend
            closes = bars['close'].iloc[max(0,idx-20):idx+1]
            sma = closes.mean()
            
            if row['close'] > sma:
                direction = 'BUY'
                entry = row['close']
                sl_price = entry - pip_step * 10  # Wide SL
                tp_price = entry + self.params['basket_tp_pips'] / 10000
            else:
                direction = 'SELL'
                entry = row['close']
                sl_price = entry + pip_step * 10
                tp_price = entry - self.params['basket_tp_pips'] / 10000
            
            self.grid_direction = direction
            lot_size = self.params['initial_lot']
            
            trade = Trade(
                strategy=self.name,
                direction=direction,
                entry_price=entry,
                entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                sl_price=sl_price,
                tp_price=tp_price,
                lot_size=lot_size,
            )
            self.open_trades.append(trade)
            self.grid_levels = 1
            self.grid_avg_price = entry
            self.grid_total_lots = lot_size
            return trade
        
        else:
            # Add grid level when price moves against us
            last_trade = self.open_trades[-1]
            
            if self.grid_direction == 'BUY':
                if row['low'] <= last_trade.entry_price - pip_step:
                    entry = row['close']
                    lot_size = self.params['initial_lot'] * (
                        self.params['lot_multiplier'] ** self.grid_levels
                    )
                    
                    trade = Trade(
                        strategy=self.name,
                        direction='BUY',
                        entry_price=entry,
                        entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                        sl_price=entry - pip_step * 10,
                        tp_price=0,  # Basket TP
                        lot_size=lot_size,
                    )
                    self.open_trades.append(trade)
                    self.grid_levels += 1
                    self.grid_total_lots += lot_size
                    self.grid_avg_price = (
                        self.grid_avg_price * (self.grid_total_lots - lot_size) + 
                        entry * lot_size
                    ) / self.grid_total_lots
                    return trade
            else:
                if row['high'] >= last_trade.entry_price + pip_step:
                    entry = row['close']
                    lot_size = self.params['initial_lot'] * (
                        self.params['lot_multiplier'] ** self.grid_levels
                    )
                    
                    trade = Trade(
                        strategy=self.name,
                        direction='SELL',
                        entry_price=entry,
                        entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                        sl_price=entry + pip_step * 10,
                        tp_price=0,
                        lot_size=lot_size,
                    )
                    self.open_trades.append(trade)
                    self.grid_levels += 1
                    self.grid_total_lots += lot_size
                    self.grid_avg_price = (
                        self.grid_avg_price * (self.grid_total_lots - lot_size) + 
                        entry * lot_size
                    ) / self.grid_total_lots
                    return trade
        
        return None
    
    def check_exit(self, bars: pd.DataFrame, idx: int, trade: Trade) -> Optional[float]:
        # Grid uses basket TP - close all when total profit hits target
        if len(self.open_trades) < 2:
            # Single trade - use individual SL/TP
            row = bars.iloc[idx]
            if trade.tp_price > 0:
                if trade.direction == 'BUY':
                    if row['low'] <= trade.sl_price:
                        return trade.sl_price
                    if row['high'] >= trade.tp_price:
                        return trade.tp_price
                else:
                    if row['high'] >= trade.sl_price:
                        return trade.sl_price
                    if row['low'] <= trade.tp_price:
                        return trade.tp_price
        return None
    
    def check_basket_close(self, bars: pd.DataFrame, idx: int) -> bool:
        """Check if entire basket should be closed."""
        if not self.open_trades:
            return False
        
        row = bars.iloc[idx]
        current_price = row['close']
        
        # Calculate total P&L
        total_pnl = 0
        for trade in self.open_trades:
            if trade.direction == 'BUY':
                pnl = (current_price - trade.entry_price) * trade.lot_size * 100000
            else:
                pnl = (trade.entry_price - current_price) * trade.lot_size * 100000
            total_pnl += pnl
        
        # Close basket if profit target hit
        if total_pnl >= self.params['basket_tp_money']:
            return True
        
        # Close basket if stop loss hit (Hades)
        if total_pnl <= -self.params.get('basket_sl_money', 250):
            return True
        
        return False
    
    def close_basket(self, bars: pd.DataFrame, idx: int):
        """Close all trades in the basket."""
        row = bars.iloc[idx]
        current_price = row['close']
        
        for trade in self.open_trades:
            trade.exit_price = current_price
            trade.exit_time = row.name if isinstance(row.name, datetime) else datetime.now()
            
            if trade.direction == 'BUY':
                trade.pnl = (current_price - trade.entry_price) * trade.lot_size * 100000
            else:
                trade.pnl = (trade.entry_price - current_price) * trade.lot_size * 100000
            
            trade.status = 'CLOSED_WIN' if trade.pnl > 0 else 'CLOSED_LOSS'
            self.closed_trades.append(trade)
        
        self.open_trades.clear()
        self.grid_levels = 0
        self.grid_avg_price = 0
        self.grid_total_lots = 0


class SessionMomentumStrategy(BaseStrategy):
    """
    Session Momentum Strategy
    Trades momentum during specific sessions (London/NY overlap).
    """
    
    def __init__(self, params: dict):
        defaults = {
            'enabled': True,
            'lookback': 10,
            'momentum_threshold': 0.002,
            'atr_period': 14,
            'sl_atr_mult': 2.0,
            'tp_atr_mult': 3.0,
            'risk_pct': 1.5,
            'trade_hours': [8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
        }
        merged = {**defaults, **params}
        super().__init__("SessionMomentum", merged)
    
    def check_entry(self, bars: pd.DataFrame, idx: int) -> Optional[Trade]:
        if not self.params['enabled']:
            return None
        
        if len(self.open_trades) > 0:
            return None
        
        if idx < self.params['lookback'] + 1:
            return None
        
        row = bars.iloc[idx]
        
        # Only trade during specified hours
        if row['hour'] not in self.params['trade_hours']:
            return None
        
        # Calculate momentum
        lookback = self.params['lookback']
        closes = bars['close'].iloc[idx-lookback:idx+1]
        momentum = (closes.iloc[-1] - closes.iloc[0]) / closes.iloc[0]
        
        atr = self._calc_atr(bars, idx, self.params['atr_period'])
        
        # Strong bullish momentum → BUY
        if momentum > self.params['momentum_threshold']:
            entry = row['close']
            sl_price = entry - atr * self.params['sl_atr_mult']
            tp_price = entry + atr * self.params['tp_atr_mult']
            
            trade = Trade(
                strategy=self.name,
                direction='BUY',
                entry_price=entry,
                entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                sl_price=sl_price,
                tp_price=tp_price,
                lot_size=self.params.get('lot_size', 0.1),
            )
            self.open_trades.append(trade)
            return trade
        
        # Strong bearish momentum → SELL
        elif momentum < -self.params['momentum_threshold']:
            entry = row['close']
            sl_price = entry + atr * self.params['sl_atr_mult']
            tp_price = entry - atr * self.params['tp_atr_mult']
            
            trade = Trade(
                strategy=self.name,
                direction='SELL',
                entry_price=entry,
                entry_time=row.name if isinstance(row.name, datetime) else datetime.now(),
                sl_price=sl_price,
                tp_price=tp_price,
                lot_size=self.params.get('lot_size', 0.1),
            )
            self.open_trades.append(trade)
            return trade
        
        return None
    
    def _calc_atr(self, bars: pd.DataFrame, idx: int, period: int) -> float:
        if idx < period:
            return 0.001
        tr_list = []
        for i in range(idx-period, idx):
            h = bars.iloc[i]['high']
            l = bars.iloc[i]['low']
            c_prev = bars.iloc[i-1]['close'] if i > 0 else bars.iloc[i]['open']
            tr = max(h - l, abs(h - c_prev), abs(l - c_prev))
            tr_list.append(tr)
        return np.mean(tr_list) if tr_list else 0.001
    
    def check_exit(self, bars: pd.DataFrame, idx: int, trade: Trade) -> Optional[float]:
        row = bars.iloc[idx]
        if trade.direction == 'BUY':
            if row['low'] <= trade.sl_price:
                return trade.sl_price
            if row['high'] >= trade.tp_price:
                return trade.tp_price
        else:
            if row['high'] >= trade.sl_price:
                return trade.sl_price
            if row['low'] <= trade.tp_price:
                return trade.tp_price
        return None


# ============================================================
# BACKTESTER ENGINE
# ============================================================

class Backtester:
    """Core backtesting engine for DESTROYER QUANTUM."""
    
    def __init__(self, initial_deposit: float = 10000.0, spread_pips: float = 21.0):
        self.initial_deposit = initial_deposit
        self.spread_pips = spread_pips
        self.equity = initial_deposit
        self.equity_curve = [initial_deposit]
        self.strategies: List[BaseStrategy] = []
        self.all_trades: List[Trade] = []
    
    def add_strategy(self, strategy: BaseStrategy):
        self.strategies.append(strategy)
    
    def run(self, data: pd.DataFrame) -> BacktestResult:
        """Run backtest on historical data."""
        print(f"Running backtest on {len(data)} bars...")
        print(f"Date range: {data.index[0]} to {data.index[-1]}")
        
        for idx in range(len(data)):
            # Process each strategy
            for strategy in self.strategies:
                # Check for entries
                trade = strategy.check_entry(data, idx)
                if trade:
                    # Apply spread
                    if trade.direction == 'BUY':
                        trade.entry_price += self.spread_pips / 200000
                    else:
                        trade.entry_price -= self.spread_pips / 200000
                
                # Check for exits
                for open_trade in list(strategy.open_trades):
                    exit_price = strategy.check_exit(data, idx, open_trade)
                    if exit_price:
                        self._close_trade(open_trade, exit_price, data.iloc[idx])
                
                # Check basket close for grid strategies
                if hasattr(strategy, 'check_basket_close'):
                    if strategy.check_basket_close(data, idx):
                        strategy.close_basket(data, idx)
                        for trade in strategy.closed_trades[-100:]:
                            if trade.exit_time == data.iloc[idx].name:
                                self.equity += trade.pnl
            
            # Update equity curve
            current_equity = self._calculate_equity(data, idx)
            self.equity_curve.append(current_equity)
            
            if idx % 1000 == 0:
                print(f"  Bar {idx}/{len(data)} | Equity: ${current_equity:,.2f}")
        
        # Close any remaining open trades
        for strategy in self.strategies:
            for trade in list(strategy.open_trades):
                self._close_trade(trade, data.iloc[-1]['close'], data.iloc[-1])
        
        return self._generate_results()
    
    def _close_trade(self, trade: Trade, exit_price: float, bar):
        """Close a trade and calculate P&L."""
        trade.exit_price = exit_price
        trade.exit_time = bar.name if isinstance(bar.name, datetime) else datetime.now()
        
        if trade.direction == 'BUY':
            pnl = (exit_price - trade.entry_price) * trade.lot_size * 100000
        else:
            pnl = (trade.entry_price - exit_price) * trade.lot_size * 100000
        
        # Subtract spread from P&L
        pnl -= self.spread_pips * trade.lot_size * 10
        
        trade.pnl = pnl
        trade.status = 'CLOSED_WIN' if pnl > 0 else 'CLOSED_LOSS'
        
        # Move from open to closed
        strategy = next(s for s in self.strategies if s.name == trade.strategy)
        if trade in strategy.open_trades:
            strategy.open_trades.remove(trade)
        strategy.closed_trades.append(trade)
        
        self.equity += pnl
        self.all_trades.append(trade)
    
    def _calculate_equity(self, data: pd.DataFrame, idx: int) -> float:
        """Calculate current equity including open positions."""
        equity = self.initial_deposit
        
        # Add closed trade P&L
        for trade in self.all_trades:
            equity += trade.pnl
        
        # Add open trade unrealized P&L
        current_price = data.iloc[idx]['close']
        for strategy in self.strategies:
            for trade in strategy.open_trades:
                if trade.direction == 'BUY':
                    unrealized = (current_price - trade.entry_price) * trade.lot_size * 100000
                else:
                    unrealized = (trade.entry_price - current_price) * trade.lot_size * 100000
                equity += unrealized
        
        return equity
    
    def _generate_results(self) -> BacktestResult:
        """Generate backtest results."""
        strategy_perfs = {}
        for strategy in self.strategies:
            strategy_perfs[strategy.name] = strategy.get_performance()
        
        # Calculate max drawdown
        equity_array = np.array(self.equity_curve)
        peak = np.maximum.accumulate(equity_array)
        drawdown = peak - equity_array
        max_drawdown = np.max(drawdown)
        max_drawdown_pct = (max_drawdown / peak[np.argmax(drawdown)]) * 100
        
        # Overall stats
        total_trades = sum(p.total_trades for p in strategy_perfs.values())
        total_profit = sum(t.pnl for t in self.all_trades if t.pnl > 0)
        total_loss = abs(sum(t.pnl for t in self.all_trades if t.pnl < 0))
        winning_trades = len([t for t in self.all_trades if t.pnl > 0])
        
        return BacktestResult(
            initial_deposit=self.initial_deposit,
            final_equity=self.equity,
            net_profit=self.equity - self.initial_deposit,
            gross_profit=total_profit,
            gross_loss=total_loss,
            profit_factor=total_profit / total_loss if total_loss > 0 else 999.0,
            max_drawdown=max_drawdown,
            max_drawdown_pct=max_drawdown_pct,
            total_trades=total_trades,
            win_rate=winning_trades / total_trades if total_trades > 0 else 0.0,
            strategies=strategy_perfs,
            equity_curve=self.equity_curve,
        )


# ============================================================
# PARAMETER OPTIMIZER (ML-based)
# ============================================================

from scipy.optimize import differential_evolution

class ParameterOptimizer:
    """Optimizes strategy parameters using genetic algorithms."""
    
    def __init__(self, backtester_factory, data: pd.DataFrame):
        """
        backtester_factory: callable that takes params dict and returns a configured Backtester
        data: historical OHLCV data
        """
        self.backtester_factory = backtester_factory
        self.data = data
        self.best_params = None
        self.best_score = -float('inf')
        self.history = []
    
    def optimize(self, param_space: dict, max_iter: int = 50, popsize: int = 15) -> dict:
        """
        Run optimization using differential evolution.
        
        param_space: dict of {param_name: (min, max)} bounds
        """
        param_names = list(param_space.keys())
        bounds = [param_space[name] for name in param_names]
        
        def objective(x):
            params = dict(zip(param_names, x))
            
            # Run backtest
            bt = self.backtester_factory(params)
            result = bt.run(self.data)
            
            # Score: maximize profit while penalizing drawdown
            score = result.net_profit - (result.max_drawdown_pct * 100)
            
            # Track history
            self.history.append({
                'params': params.copy(),
                'profit': result.net_profit,
                'pf': result.profit_factor,
                'dd': result.max_drawdown_pct,
                'score': score,
            })
            
            if score > self.best_score:
                self.best_score = score
                self.best_params = params.copy()
                print(f"  New best: Profit=${result.net_profit:,.0f} PF={result.profit_factor:.2f} DD={result.max_drawdown_pct:.1f}% Score={score:.0f}")
            
            return -score  # Minimize negative score
        
        print(f"Starting optimization with {len(param_names)} parameters...")
        print(f"Population size: {popsize}, Max iterations: {max_iter}")
        
        result = differential_evolution(
            objective,
            bounds,
            maxiter=max_iter,
            popsize=popsize,
            tol=0.01,
            seed=42,
            disp=True,
        )
        
        return self.best_params


# ============================================================
# DATA LOADING
# ============================================================

def load_mt4_csv(filepath: str) -> pd.DataFrame:
    """Load MT4 exported CSV data."""
    df = pd.read_csv(filepath, parse_dates=['time'] if 'time' in pd.read_csv(filepath, nrows=0).columns else [0])
    
    # Standardize column names
    col_map = {
        'Time': 'time', 'time': 'time',
        'Open': 'open', 'open': 'open',
        'High': 'high', 'high': 'high',
        'Low': 'low', 'low': 'low',
        'Close': 'close', 'close': 'close',
        'Volume': 'volume', 'volume': 'volume',
    }
    df = df.rename(columns={k: v for k, v in col_map.items() if k in df.columns})
    
    # Add time features
    if 'time' in df.columns:
        df['hour'] = df['time'].dt.hour
        df['dayofweek'] = df['time'].dt.dayofweek
        df.set_index('time', inplace=True)
    
    # Ensure numeric
    for col in ['open', 'high', 'low', 'close', 'volume']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
    
    df = df.dropna()
    
    return df


def load_generic_csv(filepath: str) -> pd.DataFrame:
    """Load generic OHLCV CSV (any format)."""
    df = pd.read_csv(filepath)
    
    # Try to detect time column
    time_cols = [c for c in df.columns if 'time' in c.lower() or 'date' in c.lower()]
    if time_cols:
        df = df.rename(columns={time_cols[0]: 'time'})
        df['time'] = pd.to_datetime(df['time'])
        df['hour'] = df['time'].dt.hour
        df['dayofweek'] = df['time'].dt.dayofweek
        df.set_index('time', inplace=True)
    
    # Try to detect OHLCV columns
    for target, patterns in {
        'open': ['open', 'o'],
        'high': ['high', 'h'],
        'low': ['low', 'l'],
        'close': ['close', 'c', 'adj close'],
        'volume': ['volume', 'vol', 'v'],
    }.items():
        for pattern in patterns:
            matches = [c for c in df.columns if pattern in c.lower()]
            if matches:
                df = df.rename(columns={matches[0]: target})
                break
    
    for col in ['open', 'high', 'low', 'close']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
    
    if 'volume' not in df.columns:
        df['volume'] = 0
    
    if 'hour' not in df.columns:
        df['hour'] = 12
    if 'dayofweek' not in df.columns:
        df['dayofweek'] = 2
    
    df = df.dropna(subset=['open', 'high', 'low', 'close'])
    
    return df


# ============================================================
# MAIN — Quick Test
# ============================================================

if __name__ == "__main__":
    print("DESTROYER QUANTUM — Python Training Framework")
    print("=" * 60)
    print("Ready to receive data and train strategies.")
    print("")
    print("Usage:")
    print("  1. Load your data: df = load_mt4_csv('EURUSD_H4.csv')")
    print("  2. Create backtester with strategies")
    print("  3. Run backtest or optimize parameters")
    print("")
    print("Example:")
    print("  df = load_mt4_csv('EURUSD_H4.csv')")
    print("  bt = Backtester(initial_deposit=10000)")
    print("  bt.add_strategy(PhantomStrategy({'min_gap_pips': 5.0, 'max_gap_pips': 30.0}))")
    print("  bt.add_strategy(NoiseBreakoutStrategy({}))")
    print("  bt.add_strategy(MeanReversionStrategy({}))")
    print("  result = bt.run(df)")
    print("  print(result.summary())")
