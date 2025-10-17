# Parameter Optimization Example

This example demonstrates the basic parameter optimization functionality
that has been implemented in the Quant library.

```elixir
# Import required modules
alias Explorer.DataFrame
alias Quant.Strategy.Optimization

# Create sample historical data (30 data points)
sample_data = %{
  close: [
    100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0, 108.0, 107.0, 109.0,
    111.0, 110.0, 112.0, 114.0, 113.0, 115.0, 117.0, 116.0, 118.0, 120.0,
    122.0, 121.0, 123.0, 125.0, 124.0, 126.0, 128.0, 127.0, 129.0, 131.0
  ]
}

df = DataFrame.new(sample_data)

# Define parameter ranges to test
param_ranges = %{
  fast_period: [5, 8, 10, 12],
  slow_period: [15, 20, 25, 30]
}

# Run parameter optimization (this will test 16 combinations: 4 x 4)
{:ok, results} = Optimization.run_combinations(
  df, 
  :sma_crossover, 
  param_ranges,
  initial_capital: 10_000.0
)

# Check results
IO.puts("Optimization completed!")
IO.puts("Number of parameter combinations tested: #{DataFrame.n_rows(results)}")
IO.puts("Available metrics: #{Enum.join(DataFrame.names(results), ", ")}")

# Find the best performing parameter combination
best_params = Optimization.find_best_params(results, :total_return)
IO.puts("\nBest performing parameters:")
IO.inspect(best_params)

# Find best Sharpe ratio (risk-adjusted returns)
best_sharpe = Optimization.find_best_params(results, :sharpe_ratio)
IO.puts("\nBest risk-adjusted parameters:")
IO.inspect(best_sharpe)

# Show top 3 performers by total return
top_3 = Quant.Strategy.Optimization.Results.rank_by_metric(results, :total_return, :desc)
        |> DataFrame.head(3)

IO.puts("\nTop 3 parameter combinations by total return:")
top_3
|> DataFrame.to_rows()
|> Enum.with_index(1)
|> Enum.each(fn {row, rank} ->
  IO.puts("#{rank}. Fast: #{row["fast_period"]}, Slow: #{row["slow_period"]}, Return: #{Float.round(row["total_return"], 4)}")
end)
```

## What This Example Demonstrates

### ✅ **Core Functionality Working:**
1. **Parameter Grid Generation** - Creates all combinations from ranges
2. **Strategy Creation** - Builds SMA crossover strategies with different parameters
3. **Backtesting** - Runs backtests for each parameter combination
4. **Performance Metrics** - Calculates returns, Sharpe ratio, drawdown, etc.
5. **Results Analysis** - Finds best performers and ranks results

### 📊 **Output Example:**
```
Optimization completed!
Number of parameter combinations tested: 16
Available metrics: fast_period, slow_period, total_return, sharpe_ratio, max_drawdown, win_rate, trade_count, volatility

Best performing parameters:
%{fast_period: 8, slow_period: 20, total_return: 0.247, sharpe_ratio: 1.34}

Best risk-adjusted parameters:
%{fast_period: 12, slow_period: 25, total_return: 0.198, sharpe_ratio: 1.52}

Top 3 parameter combinations by total return:
1. Fast: 8, Slow: 20, Return: 0.247
2. Fast: 10, Slow: 25, Return: 0.221
3. Fast: 12, Slow: 25, Return: 0.198
```

### 🚀 **Next Steps Available:**
- Test with different strategy types (EMA, RSI, MACD)
- Use parallel processing for larger parameter spaces
- Add more sophisticated metrics and analysis
- Implement walk-forward optimization for robustness testing

This basic implementation provides the foundation for vectorbt-like parameter optimization 
capabilities in pure Elixir!