# Parameter Optimization Implementation Plan

Based on this YouTube video which demonstrates vectorbt parameter optimization: https://www.youtube.com/watch?v=Yt0FDobtLSk

## Current vectorbt Example

```python
import vectorbt as vbt
import numpy as np
import yfinance as yf

start_date = '2005-01-01'
end_date = '2025-01-01'
price = yf.download('EURUSD=X', start=start_date, end=end_date, auto_adjust=False)['Close']

def simulate_all_params(price, ma_periods):
    fast_ma, slow_ma = vbt.MA.run_combs(price, window=ma_periods)

    entries = fast_ma.ma_above(slow_ma)
    exits = fast_ma.ma_below(slow_ma)

    return vbt.Portfolio.from_signals(price, entries, exits, direction='both', freq='d')

ma_periods = np.arange(50, 150)

in_portfolio = simulate_all_params(price, ma_periods)
best_params = in_portfolio.total_return().idxmax()
```

## Proposed Elixir Implementation

### 1. Core Parameter Optimization Module

Create `lib/quant_strategy/optimization.ex` with the following capabilities:

```elixir
defmodule Quant.Strategy.Optimization do
  @moduledoc """
  Parameter optimization engine for systematic strategy tuning.
  
  This module provides vectorbt-like functionality for testing parameter
  combinations and finding optimal strategy configurations.
  """
  
  alias Explorer.DataFrame
  alias Quant.Strategy
  
  # Main optimization functions
  def run_combinations(dataframe, strategy_type, param_ranges, opts \\ [])
  def find_best_params(results, metric \\ :total_return)
  def parameter_heatmap(results, x_param, y_param, metric)
  def walk_forward_optimization(dataframe, strategy_type, param_ranges, opts \\ [])
  
  # Concurrent processing
  def run_combinations_parallel(dataframe, strategy_type, param_ranges, opts \\ [])
  
  # Analysis and visualization helpers  
  def analyze_parameter_sensitivity(results, param_name)
  def stability_analysis(results, metric, threshold \\ 0.1)
end
```

### 2. Parameter Range Generation

```elixir
defmodule Quant.Strategy.Optimization.Ranges do
  @moduledoc """
  Utilities for generating parameter ranges and combinations.
  """
  
  # Generate ranges similar to numpy.arange
  def range(start, stop, step \\ 1)
  def linspace(start, stop, num)
  
  # Generate all combinations of parameters
  def parameter_grid(param_map)
  def random_search(param_map, n_samples)
  
  # Smart parameter selection
  def fibonacci_sequence(start, stop)
  def logarithmic_range(start, stop, base \\ 2)
end
```

### 3. Results Analysis Module

```elixir
defmodule Quant.Strategy.Optimization.Results do
  @moduledoc """
  Analysis and ranking of optimization results.
  """
  
  # Ranking and selection
  def rank_by_metric(results, metric, order \\ :desc)
  def top_n_params(results, n, metric \\ :total_return)
  def pareto_frontier(results, metrics)
  
  # Statistical analysis
  def parameter_correlation(results, param1, param2)
  def sensitivity_analysis(results, param_name)
  def robustness_test(results, metric, percentile \\ 0.9)
  
  # Performance metrics
  def risk_adjusted_ranking(results, return_metric, risk_metric)
  def stability_score(results, metric)
end
```

### 4. Implementation Plan

#### Phase 1: Basic Parameter Sweeping (Week 1)

**Core Functionality:**
- [x] Implement `run_combinations/4` for single-parameter sweeps
- [ ] Add basic SMA crossover parameter optimization
- [ ] Create result DataFrame structure with consistent schema
- [ ] Implement `find_best_params/2` for metric-based ranking

**Example Usage:**
```elixir
# Test SMA crossover with different periods
param_ranges = %{
  fast_period: 5..20,
  slow_period: 20..50
}

{:ok, results} = Quant.Strategy.Optimization.run_combinations(
  historical_df, 
  :sma_crossover, 
  param_ranges,
  initial_capital: 10_000
)

best_params = Quant.Strategy.Optimization.find_best_params(results, :total_return)
# => %{fast_period: 12, slow_period: 26, total_return: 0.247}
```

#### Phase 2: Multi-Parameter Optimization (Week 2)

**Advanced Features:**
- [ ] Multi-parameter grid search
- [ ] Parallel processing using Task.async_stream
- [ ] Memory-efficient streaming for large parameter spaces
- [ ] Progress tracking and estimated completion times

**Example Usage:**
```elixir
# Complex parameter grid
param_ranges = %{
  fast_period: [5, 8, 12, 15, 20],
  slow_period: [20, 26, 30, 40, 50],
  rsi_period: [10, 14, 20],
  rsi_oversold: [20, 25, 30],
  rsi_overbought: [70, 75, 80]
}

# Parallel processing with progress callback
{:ok, results} = Quant.Strategy.Optimization.run_combinations_parallel(
  df, 
  :composite_sma_rsi,
  param_ranges,
  concurrency: 8,
  progress_callback: &IO.puts("Progress: #{&1}%")
)

# Multi-metric analysis
top_performers = Quant.Strategy.Optimization.Results.pareto_frontier(
  results, 
  [:total_return, :sharpe_ratio, :max_drawdown]
)
```

#### Phase 3: Advanced Analytics (Week 3)

**Sophisticated Analysis:**
- [ ] Walk-forward optimization with rolling windows
- [ ] Parameter stability analysis
- [ ] Sensitivity analysis and robustness testing
- [ ] Performance attribution and correlation analysis

**Example Usage:**
```elixir
# Walk-forward optimization
{:ok, wf_results} = Quant.Strategy.Optimization.walk_forward_optimization(
  long_df,
  :sma_crossover,
  param_ranges,
  training_window: 252,  # 1 year
  testing_window: 63,    # 1 quarter
  step_size: 21          # 1 month
)

# Stability analysis
stability = Quant.Strategy.Optimization.Results.stability_score(
  wf_results, 
  :total_return
)

# Parameter sensitivity
sensitivity = Quant.Strategy.Optimization.Results.sensitivity_analysis(
  results, 
  :fast_period
)
```

#### Phase 4: Visualization & Export (Week 4)

**Output and Visualization:**
- [ ] Export results to CSV/Excel for external analysis
- [ ] Parameter heatmaps using Explorer's plotting capabilities
- [ ] Performance surface plotting for 2D parameter analysis
- [ ] Integration with LiveBook for interactive analysis

### 5. Data Structures

#### Optimization Results Schema

```elixir
# Results DataFrame columns:
# - param_1, param_2, ... (parameter values)
# - total_return (portfolio total return)
# - annualized_return (annualized return)
# - sharpe_ratio (risk-adjusted return)
# - sortino_ratio (downside deviation adjusted)
# - max_drawdown (maximum portfolio decline)
# - win_rate (percentage of winning trades)
# - profit_factor (gross profit / gross loss)
# - trade_count (number of trades)
# - avg_trade_duration (average holding period)
# - volatility (portfolio volatility)
# - calmar_ratio (return / max drawdown)

%{
  params: %{fast_period: 12, slow_period: 26},
  metrics: %{
    total_return: 0.247,
    sharpe_ratio: 1.34,
    max_drawdown: 0.156,
    win_rate: 0.63,
    trade_count: 23
  },
  backtest_data: %DataFrame{} # Full backtest results if requested
}
```

### 6. Performance Considerations

#### Memory Management

- [ ] Stream processing for large parameter spaces
- [ ] Lazy evaluation using Elixir's Stream module
- [ ] Option to store only summary metrics vs full backtest data
- [ ] Garbage collection optimization for long-running optimizations

#### Concurrency

- [ ] Leverage Elixir's Actor model for parallel backtesting
- [ ] Task supervision trees for fault tolerance
- [ ] Progress monitoring and cancellation support
- [ ] Resource pooling for database/file operations

#### Future Performance Enhancements

- [ ] **Caching** (Phase 5+): Memoization of indicator calculations, parameter result caching
- [ ] **Distributed Computing**: Scale across multiple nodes for massive parameter spaces
- [ ] **Smart Sampling**: Bayesian optimization and genetic algorithms for parameter selection

### 7. Usage Examples

#### Basic SMA Optimization (equivalent to vectorbt example)

```elixir
# Load historical data
{:ok, df} = Quant.Explorer.fetch("AAPL", period: "2y")

# Define parameter ranges (equivalent to np.arange(50, 150))
param_ranges = %{
  fast_period: 5..50,
  slow_period: 50..150
}

# Run optimization (equivalent to simulate_all_params)
{:ok, results} = Quant.Strategy.Optimization.run_combinations(
  df,
  :sma_crossover,
  param_ranges,
  initial_capital: 10_000
)

# Find best parameters (equivalent to in_portfolio.total_return().idxmax())
best = Quant.Strategy.Optimization.find_best_params(results, :total_return)

IO.inspect(best)
# => %{fast_period: 12, slow_period: 50, total_return: 0.347, sharpe_ratio: 1.82}
```

#### Multi-Strategy Optimization

```elixir
# Compare different strategy types
strategies_to_test = [
  {:sma_crossover, %{fast_period: 5..20, slow_period: 20..60}},
  {:ema_crossover, %{fast_period: 5..20, slow_period: 20..60}},
  {:rsi_threshold, %{period: 10..20, oversold: 20..35, overbought: 65..80}},
  {:macd_crossover, %{fast_period: 8..15, slow_period: 20..30, signal_period: 5..12}}
]

results = Enum.map(strategies_to_test, fn {strategy_type, params} ->
  {:ok, result} = Quant.Strategy.Optimization.run_combinations(
    df, strategy_type, params, initial_capital: 10_000
  )
  
  best = Quant.Strategy.Optimization.find_best_params(result, :sharpe_ratio)
  Map.put(best, :strategy_type, strategy_type)
end)

winner = Enum.max_by(results, & &1.sharpe_ratio)
IO.puts("Best strategy: #{winner.strategy_type} with Sharpe ratio: #{winner.sharpe_ratio}")
```

### 8. Integration with Existing Codebase

This optimization framework will seamlessly integrate with the existing Quant library:

- **Reuses existing strategies**: All current strategy types (SMA, EMA, RSI, MACD) work out of the box
- **Leverages existing backtesting**: Uses `Quant.Strategy.Backtest` for individual parameter tests
- **Explorer DataFrame compatibility**: All results returned as DataFrames for consistency
- **Modular design**: Can be used independently or integrated into larger trading systems

### 9. Testing Strategy

- [ ] **Unit tests**: Test parameter range generation and result analysis functions
- [ ] **Integration tests**: End-to-end optimization with known datasets and expected results
- [ ] **Performance tests**: Measure optimization speed and memory usage
- [ ] **Property-based tests**: Use StreamData to test with various parameter combinations

### 10. Documentation and Examples

- [ ] **LiveBook examples**: Interactive optimization tutorials
- [ ] **API documentation**: Complete function documentation with examples
- [ ] **Performance benchmarks**: Speed comparisons with other optimization libraries
- [ ] **Best practices guide**: When to use different optimization approaches

## Next Steps

### Immediate Implementation (Phase 1-4)

1. [x] **Create basic optimization module structure** (Day 1)
2. [ ] **Implement single-parameter sweep functionality** (Days 2-3)
3. [ ] **Add multi-parameter grid search** (Days 4-5)
4. [ ] **Implement parallel processing** (Days 6-7)
5. [ ] **Add advanced analytics and walk-forward optimization** (Week 2)
6. [ ] **Create comprehensive test suite** (Week 3)
7. [ ] **Write documentation and examples** (Week 4)

### Future Enhancements (Phase 5+)

- [ ] **Caching Layer**: Implement memoization and result caching for performance
- [ ] **Distributed Processing**: Scale optimization across multiple nodes
- [ ] **Advanced Algorithms**: Bayesian optimization, genetic algorithms
- [ ] **Real-time Optimization**: Live parameter adjustment based on market conditions

This implementation will provide vectorbt-like parameter optimization capabilities while leveraging Elixir's strengths in concurrent processing and fault tolerance.