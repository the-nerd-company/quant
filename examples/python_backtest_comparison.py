#!/usr/bin/env python3
"""
Python Backtest Comparison - Equivalent to Elixir Quant Explorer

This script demonstrates multi-strategy backtesting using popular Python libraries
to compare with the Elixir implementation in backtest_examples.livemd

Dependencies:
pip install yfinance pandas numpy matplotlib plotly dash scipy ta-lib

Author: Generated for Quant Explorer comparison
"""

import yfinance as yf
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.express as px
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

class TradingStrategy:
    """Base class for trading strategies"""
    
    def __init__(self, name, initial_capital=100000, commission=0.001, slippage=0.0005):
        self.name = name
        self.initial_capital = initial_capital
        self.commission = commission
        self.slippage = slippage
        
    def generate_signals(self, data):
        """Override in subclasses to generate trading signals"""
        raise NotImplementedError
        
    def backtest(self, data):
        """Run backtest for the strategy"""
        df = data.copy()
        
        # Generate signals
        signals = self.generate_signals(df)
        df['signal'] = signals
        
        # Initialize portfolio tracking
        df['position'] = 0.0
        df['portfolio_value'] = self.initial_capital
        df['cash'] = self.initial_capital
        df['holdings'] = 0.0
        df['trades'] = 0
        
        position = 0.0
        cash = self.initial_capital
        trades = []
        
        for i in range(1, len(df)):
            prev_position = position
            signal = df.iloc[i]['signal']
            price = df.iloc[i]['close']
            
            if signal == 1 and position == 0:  # Buy signal
                # Calculate position size (invest all available cash)
                shares_to_buy = cash / (price * (1 + self.commission + self.slippage))
                position = shares_to_buy
                cash = cash - (shares_to_buy * price * (1 + self.commission + self.slippage))
                trades.append({
                    'date': df.index[i],
                    'type': 'buy',
                    'price': price,
                    'shares': shares_to_buy
                })
                
            elif signal == -1 and position > 0:  # Sell signal
                # Sell all shares
                cash = cash + (position * price * (1 - self.commission - self.slippage))
                trades.append({
                    'date': df.index[i],
                    'type': 'sell',
                    'price': price,
                    'shares': position
                })
                position = 0.0
            
            df.iloc[i, df.columns.get_loc('position')] = position
            df.iloc[i, df.columns.get_loc('cash')] = cash
            df.iloc[i, df.columns.get_loc('holdings')] = position * price
            df.iloc[i, df.columns.get_loc('portfolio_value')] = cash + (position * price)
            df.iloc[i, df.columns.get_loc('trades')] = len(trades)
        
        # Calculate performance metrics
        returns = df['portfolio_value'].pct_change().dropna()
        
        results = {
            'data': df,
            'trades': trades,
            'final_value': df['portfolio_value'].iloc[-1],
            'total_return': (df['portfolio_value'].iloc[-1] - self.initial_capital) / self.initial_capital,
            'max_drawdown': self._calculate_max_drawdown(df['portfolio_value']),
            'win_rate': self._calculate_win_rate(trades),
            'trade_count': len(trades),
            'sharpe_ratio': self._calculate_sharpe_ratio(returns),
            'volatility': returns.std() * np.sqrt(252)  # Annualized volatility
        }
        
        return results
    
    def _calculate_max_drawdown(self, portfolio_values):
        """Calculate maximum drawdown"""
        peak = portfolio_values.expanding(min_periods=1).max()
        drawdown = (portfolio_values - peak) / peak
        return drawdown.min()
    
    def _calculate_win_rate(self, trades):
        """Calculate win rate from trades"""
        if len(trades) < 2:
            return 0.0
            
        winning_trades = 0
        for i in range(1, len(trades), 2):  # Pairs of buy/sell
            if i < len(trades):
                buy_price = trades[i-1]['price']
                sell_price = trades[i]['price']
                if sell_price > buy_price:
                    winning_trades += 1
        
        total_trade_pairs = len(trades) // 2
        return winning_trades / total_trade_pairs if total_trade_pairs > 0 else 0.0
    
    def _calculate_sharpe_ratio(self, returns, risk_free_rate=0.02):
        """Calculate Sharpe ratio"""
        if len(returns) == 0 or returns.std() == 0:
            return 0.0
        excess_returns = returns.mean() * 252 - risk_free_rate  # Annualized
        return excess_returns / (returns.std() * np.sqrt(252))

class SMAStrategy(TradingStrategy):
    """Simple Moving Average Crossover Strategy"""
    
    def __init__(self, fast_period=10, slow_period=30, **kwargs):
        super().__init__(f"SMA({fast_period},{slow_period})", **kwargs)
        self.fast_period = fast_period
        self.slow_period = slow_period
    
    def generate_signals(self, data):
        df = data.copy()
        df[f'sma_{self.fast_period}'] = df['close'].rolling(window=self.fast_period).mean()
        df[f'sma_{self.slow_period}'] = df['close'].rolling(window=self.slow_period).mean()
        
        signals = np.zeros(len(df))
        
        for i in range(1, len(df)):
            fast_current = df.iloc[i][f'sma_{self.fast_period}']
            slow_current = df.iloc[i][f'sma_{self.slow_period}']
            fast_prev = df.iloc[i-1][f'sma_{self.fast_period}']
            slow_prev = df.iloc[i-1][f'sma_{self.slow_period}']
            
            # Buy signal: fast MA crosses above slow MA
            if (fast_current > slow_current and fast_prev <= slow_prev and 
                not pd.isna(fast_current) and not pd.isna(slow_current)):
                signals[i] = 1
            # Sell signal: fast MA crosses below slow MA
            elif (fast_current < slow_current and fast_prev >= slow_prev and 
                  not pd.isna(fast_current) and not pd.isna(slow_current)):
                signals[i] = -1
                
        return signals

class EMAStrategy(TradingStrategy):
    """Exponential Moving Average Crossover Strategy"""
    
    def __init__(self, fast_period=12, slow_period=26, **kwargs):
        super().__init__(f"EMA({fast_period},{slow_period})", **kwargs)
        self.fast_period = fast_period
        self.slow_period = slow_period
    
    def generate_signals(self, data):
        df = data.copy()
        df[f'ema_{self.fast_period}'] = df['close'].ewm(span=self.fast_period).mean()
        df[f'ema_{self.slow_period}'] = df['close'].ewm(span=self.slow_period).mean()
        
        signals = np.zeros(len(df))
        
        for i in range(1, len(df)):
            fast_current = df.iloc[i][f'ema_{self.fast_period}']
            slow_current = df.iloc[i][f'ema_{self.slow_period}']
            fast_prev = df.iloc[i-1][f'ema_{self.fast_period}']
            slow_prev = df.iloc[i-1][f'ema_{self.slow_period}']
            
            # Buy signal: fast EMA crosses above slow EMA
            if (fast_current > slow_current and fast_prev <= slow_prev):
                signals[i] = 1
            # Sell signal: fast EMA crosses below slow EMA
            elif (fast_current < slow_current and fast_prev >= slow_prev):
                signals[i] = -1
                
        return signals

class RSIStrategy(TradingStrategy):
    """RSI Mean Reversion Strategy"""
    
    def __init__(self, period=14, oversold=30, overbought=70, **kwargs):
        super().__init__(f"RSI({period},{oversold},{overbought})", **kwargs)
        self.period = period
        self.oversold = oversold
        self.overbought = overbought
    
    def generate_signals(self, data):
        df = data.copy()
        
        # Calculate RSI
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=self.period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=self.period).mean()
        rs = gain / loss
        df['rsi'] = 100 - (100 / (1 + rs))
        
        signals = np.zeros(len(df))
        
        for i in range(1, len(df)):
            rsi = df.iloc[i]['rsi']
            prev_rsi = df.iloc[i-1]['rsi']
            
            # Buy signal: RSI crosses above oversold threshold
            if rsi > self.oversold and prev_rsi <= self.oversold:
                signals[i] = 1
            # Sell signal: RSI crosses below overbought threshold
            elif rsi < self.overbought and prev_rsi >= self.overbought:
                signals[i] = -1
                
        return signals

class MACDStrategy(TradingStrategy):
    """MACD Crossover Strategy"""
    
    def __init__(self, fast_period=12, slow_period=26, signal_period=9, **kwargs):
        super().__init__(f"MACD({fast_period},{slow_period},{signal_period})", **kwargs)
        self.fast_period = fast_period
        self.slow_period = slow_period
        self.signal_period = signal_period
    
    def generate_signals(self, data):
        df = data.copy()
        
        # Calculate MACD
        ema_fast = df['close'].ewm(span=self.fast_period).mean()
        ema_slow = df['close'].ewm(span=self.slow_period).mean()
        df['macd'] = ema_fast - ema_slow
        df['macd_signal'] = df['macd'].ewm(span=self.signal_period).mean()
        df['macd_histogram'] = df['macd'] - df['macd_signal']
        
        signals = np.zeros(len(df))
        
        for i in range(1, len(df)):
            macd = df.iloc[i]['macd']
            macd_signal = df.iloc[i]['macd_signal']
            prev_macd = df.iloc[i-1]['macd']
            prev_macd_signal = df.iloc[i-1]['macd_signal']
            
            # Buy signal: MACD crosses above signal line
            if macd > macd_signal and prev_macd <= prev_macd_signal:
                signals[i] = 1
            # Sell signal: MACD crosses below signal line
            elif macd < macd_signal and prev_macd >= prev_macd_signal:
                signals[i] = -1
                
        return signals

def fetch_data(symbol, period="2y"):
    """Fetch stock data using yfinance"""
    try:
        ticker = yf.Ticker(symbol)
        data = ticker.history(period=period)
        data.columns = data.columns.str.lower()
        return data
    except Exception as e:
        print(f"Error fetching data for {symbol}: {e}")
        return None

def calculate_buy_hold_performance(data, initial_capital):
    """Calculate buy and hold benchmark performance"""
    initial_price = data['close'].iloc[0]
    shares = initial_capital / initial_price
    return data['close'] * shares

def create_performance_comparison_chart(results, symbol):
    """Create interactive performance comparison chart using Plotly"""
    
    fig = make_subplots(
        rows=2, cols=1,
        subplot_titles=('Portfolio Performance Comparison', 'Trading Signals'),
        vertical_spacing=0.08,
        row_heights=[0.7, 0.3],
        shared_xaxes=True
    )
    
    # Get buy and hold data
    first_result = next(iter(results.values()))
    buy_hold = calculate_buy_hold_performance(first_result['data'], 100000)
    
    # Add buy and hold line
    fig.add_trace(
        go.Scatter(
            x=first_result['data'].index,
            y=buy_hold,
            mode='lines',
            name='Buy & Hold',
            line=dict(dash='dash', color='orange', width=2),
            hovertemplate='<b>Buy & Hold</b><br>Date: %{x}<br>Value: $%{y:,.2f}<extra></extra>'
        ),
        row=1, col=1
    )
    
    # Colors for strategies
    colors = ['blue', 'green', 'red', 'purple', 'brown']
    
    # Add strategy performance lines and signals
    for i, (strategy_name, result) in enumerate(results.items()):
        color = colors[i % len(colors)]
        
        # Performance line
        fig.add_trace(
            go.Scatter(
                x=result['data'].index,
                y=result['data']['portfolio_value'],
                mode='lines',
                name=strategy_name,
                line=dict(color=color, width=2),
                hovertemplate=f'<b>{strategy_name}</b><br>Date: %{{x}}<br>Value: $%{{y:,.2f}}<extra></extra>'
            ),
            row=1, col=1
        )
        
        # Buy signals
        buy_signals = result['data'][result['data']['signal'] == 1]
        if not buy_signals.empty:
            fig.add_trace(
                go.Scatter(
                    x=buy_signals.index,
                    y=buy_signals['portfolio_value'],
                    mode='markers',
                    name=f'{strategy_name} Buy',
                    marker=dict(symbol='triangle-up', size=8, color='green'),
                    showlegend=False,
                    hovertemplate=f'<b>{strategy_name} BUY</b><br>Date: %{{x}}<br>Price: $%{{customdata}}<extra></extra>',
                    customdata=buy_signals['close']
                ),
                row=1, col=1
            )
        
        # Sell signals
        sell_signals = result['data'][result['data']['signal'] == -1]
        if not sell_signals.empty:
            fig.add_trace(
                go.Scatter(
                    x=sell_signals.index,
                    y=sell_signals['portfolio_value'],
                    mode='markers',
                    name=f'{strategy_name} Sell',
                    marker=dict(symbol='triangle-down', size=8, color='red'),
                    showlegend=False,
                    hovertemplate=f'<b>{strategy_name} SELL</b><br>Date: %{{x}}<br>Price: $%{{customdata}}<extra></extra>',
                    customdata=sell_signals['close']
                ),
                row=1, col=1
            )
        
        # Signal subplot
        fig.add_trace(
            go.Scatter(
                x=result['data'].index,
                y=result['data']['signal'] + i * 3,  # Offset signals vertically
                mode='markers',
                name=f'{strategy_name} Signals',
                marker=dict(
                    symbol=['circle' if s == 0 else ('triangle-up' if s == 1 else 'triangle-down') 
                           for s in result['data']['signal']],
                    size=[4 if s == 0 else 8 for s in result['data']['signal']],
                    color=[color if s != 0 else 'lightgray' for s in result['data']['signal']]
                ),
                showlegend=False,
                hovertemplate=f'<b>{strategy_name}</b><br>Date: %{{x}}<br>Signal: %{{y}}<extra></extra>'
            ),
            row=2, col=1
        )
    
    # Update layout
    fig.update_layout(
        title=f'Multi-Strategy Backtest Comparison - {symbol}',
        height=800,
        hovermode='x unified',
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right",
            x=1
        )
    )
    
    fig.update_xaxes(title_text="Date", row=2, col=1)
    fig.update_yaxes(title_text="Portfolio Value ($)", row=1, col=1)
    fig.update_yaxes(title_text="Signal", row=2, col=1)
    
    return fig

def print_performance_summary(results, symbol):
    """Print performance summary table"""
    print(f"\n{'='*80}")
    print(f"PERFORMANCE SUMMARY - {symbol}")
    print(f"{'='*80}")
    
    # Get buy and hold performance
    first_result = next(iter(results.values()))
    initial_capital = 100000
    buy_hold = calculate_buy_hold_performance(first_result['data'], initial_capital)
    buy_hold_return = (buy_hold.iloc[-1] - initial_capital) / initial_capital
    
    print(f"{'Strategy':<25} | {'Return':<10} | {'Max DD':<10} | {'Trades':<8} | {'Sharpe':<8} | {'Win Rate':<10} | Final Value")
    print("-" * 95)
    
    # Buy and hold
    print(f"{'Buy & Hold':<25} | {f'{buy_hold_return*100:.1f}%':<10} | {'0.0%':<10} | {'1':<8} | {'N/A':<8} | {'N/A':<10} | ${buy_hold.iloc[-1]:,.0f}")
    
    # Strategies
    for strategy_name, result in results.items():
        return_str = f"{result['total_return']*100:.1f}%"
        dd_str = f"{abs(result['max_drawdown'])*100:.1f}%"
        trades_str = str(result['trade_count'])
        sharpe_str = f"{result['sharpe_ratio']:.2f}" if result['sharpe_ratio'] != 0 else "N/A"
        win_rate_str = f"{result['win_rate']*100:.1f}%" if result['win_rate'] > 0 else "N/A"
        final_str = f"${result['final_value']:,.0f}"
        
        print(f"{strategy_name:<25} | {return_str:<10} | {dd_str:<10} | {trades_str:<8} | {sharpe_str:<8} | {win_rate_str:<10} | {final_str}")

def main():
    """Main execution function"""
    print("Python Multi-Strategy Backtest - Quant Explorer Comparison")
    print("=" * 60)
    
    # Fetch data
    symbols = ['AAPL', 'MSFT']
    
    for symbol in symbols:
        print(f"\nFetching data for {symbol}...")
        data = fetch_data(symbol, period="2y")
        
        if data is None:
            print(f"Failed to fetch data for {symbol}")
            continue
            
        print(f"Data shape: {data.shape}")
        print(f"Date range: {data.index[0].date()} to {data.index[-1].date()}")
        
        # Initialize strategies
        strategies = [
            SMAStrategy(fast_period=10, slow_period=30),
            SMAStrategy(fast_period=20, slow_period=50),
            EMAStrategy(fast_period=12, slow_period=26),
            RSIStrategy(period=14, oversold=30, overbought=70),
            MACDStrategy(fast_period=12, slow_period=26, signal_period=9)
        ]
        
        # Run backtests
        results = {}
        print(f"\nRunning backtests for {symbol}...")
        
        for strategy in strategies:
            print(f"  Testing {strategy.name}...")
            try:
                result = strategy.backtest(data)
                results[strategy.name] = result
                print(f"    ✓ Final Value: ${result['final_value']:,.2f}")
                print(f"    ✓ Return: {result['total_return']*100:.2f}%")
                print(f"    ✓ Max Drawdown: {abs(result['max_drawdown'])*100:.2f}%")
                print(f"    ✓ Trades: {result['trade_count']}")
            except Exception as e:
                print(f"    ✗ Error: {e}")
        
        if results:
            # Print summary
            print_performance_summary(results, symbol)
            
            # Create interactive chart
            print(f"\nGenerating interactive chart for {symbol}...")
            fig = create_performance_comparison_chart(results, symbol)
            
            # Save chart as HTML
            filename = f"backtest_comparison_{symbol.lower()}.html"
            fig.write_html(filename)
            print(f"Chart saved as: {filename}")
            
            # Optionally show chart (requires browser)
            # fig.show()
        
        print(f"\nCompleted analysis for {symbol}")
        print("-" * 50)

if __name__ == "__main__":
    main()