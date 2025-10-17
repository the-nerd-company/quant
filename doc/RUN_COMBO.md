# Run combo

in this youtube video, it describes how to find best parameters for a strategy (naive and suited for real use cases) https://www.youtube.com/watch?v=Yt0FDobtLSk

```python
import vectorbt as vbt
import numpy as np
import yfinance as yf

def run_backtest(price, fast_ma, slow_ma):
    fast_ma = vbt.MA.run(price, window=fast_ma, per_column=True)
    slow_ma = vbt.MA.run(price, window=slow_ma, per_column=True)

    entries = fast_ma.ma_above(slow_ma)
    exits = fast_ma.ma_below(slow_ma)

    return vbt.Portfolio.from_signals(price, entries, exits, direction='both', freq='d')

def simulate_all_params(price, ma_periods):
    fast_ma, slow_ma = vbt.MA.run_combs(price, window=ma_periods)

    entries = fast_ma.ma_above(slow_ma)
    exits = fast_ma.ma_below(slow_ma)

    return vbt.Portfolio.from_signals(price, entries, exits, direction='both', freq='d')

ma_periods = np.arange(50, 150)

in_portfolio = simulate_all_params(price, ma_periods)
best_params = in_portfolio.total_return().idxmax()
```