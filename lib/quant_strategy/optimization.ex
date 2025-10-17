defmodule Quant.Strategy.Optimization do
  @moduledoc """
  Parameter optimization engine for systematic strategy tuning.

  This module provides vectorbt-like functionality for testing parameter
  combinations and finding optimal strategy configurations.

  ## Features

  - Single and multi-parameter optimization
  - Parallel processing for efficient computation
  - Comprehensive result analysis and ranking
  - Walk-forward optimization for robust validation
  - Integration with all existing strategy types

  ## Basic Usage

      # Simple parameter sweep
      param_ranges = %{fast_period: 5..20, slow_period: 20..50}
      {:ok, results} = Quant.Strategy.Optimization.run_combinations(
        df, :sma_crossover, param_ranges
      )

      # Find best parameters
      best = Quant.Strategy.Optimization.find_best_params(results, :total_return)

  ## Parallel Processing

      # Use all available cores
      {:ok, results} = Quant.Strategy.Optimization.run_combinations_parallel(
        df, :sma_crossover, param_ranges, concurrency: System.schedulers_online()
      )
  """

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Strategy
  alias Quant.Strategy.Optimization.{Ranges, Results}

  @type strategy_type :: atom()
  @type param_ranges :: %{atom() => Range.t() | [any()]}
  @type optimization_options :: [
          initial_capital: float(),
          commission: float(),
          slippage: float(),
          concurrency: pos_integer(),
          progress_callback: function() | nil,
          store_backtest_data: boolean()
        ]
  @type optimization_result :: {:ok, DataFrame.t()} | {:error, term()}

  @doc """
  Run parameter combinations for a single strategy type.

  Tests all combinations of the provided parameter ranges and returns
  optimization results as a DataFrame.

  ## Parameters

  - `dataframe` - Historical OHLCV data
  - `strategy_type` - Strategy type atom (e.g., :sma_crossover, :rsi_threshold)
  - `param_ranges` - Map of parameter names to ranges or lists of values
  - `opts` - Optimization options

  ## Options

  - `:initial_capital` - Starting capital (default: 10000.0)
  - `:commission` - Trading commission rate (default: 0.001)
  - `:slippage` - Market slippage rate (default: 0.0005)
  - `:store_backtest_data` - Whether to store full backtest results (default: false)

  ## Examples

      # Test SMA crossover periods
      param_ranges = %{fast_period: 5..15, slow_period: 20..40}
      {:ok, results} = run_combinations(df, :sma_crossover, param_ranges)

      # Test with custom options
      {:ok, results} = run_combinations(df, :sma_crossover, param_ranges,
        initial_capital: 50_000.0,
        commission: 0.002
      )
  """
  @spec run_combinations(DataFrame.t(), strategy_type(), param_ranges(), optimization_options()) ::
          optimization_result()
  def run_combinations(dataframe, strategy_type, param_ranges, opts \\ []) do
    with {:ok, param_combinations} <- Ranges.parameter_grid(param_ranges),
         {:ok, results} <-
           run_parameter_combinations(dataframe, strategy_type, param_combinations, opts) do
      {:ok, results}
    else
      {:error, reason} -> {:error, {:optimization_failed, reason}}
    end
  end

  @doc """
  Run parameter combinations using parallel processing.

  Same as `run_combinations/4` but processes parameter combinations
  concurrently for improved performance.

  ## Additional Options

  - `:concurrency` - Number of parallel tasks (default: System.schedulers_online())
  - `:progress_callback` - Function called with progress percentage
  - `:timeout` - Timeout per parameter combination in ms (default: 30_000)

  ## Examples

      # Use all CPU cores
      {:ok, results} = run_combinations_parallel(df, :sma_crossover, param_ranges,
        concurrency: System.schedulers_online()
      )

      # With progress tracking
      progress_fn = fn progress -> IO.puts("Progress: " <> Integer.to_string(progress) <> "%") end
      {:ok, results} = run_combinations_parallel(df, :sma_crossover, param_ranges,
        progress_callback: progress_fn
      )
  """
  @spec run_combinations_parallel(
          DataFrame.t(),
          strategy_type(),
          param_ranges(),
          optimization_options()
        ) ::
          optimization_result()
  def run_combinations_parallel(dataframe, strategy_type, param_ranges, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())
    progress_callback = Keyword.get(opts, :progress_callback)
    timeout = Keyword.get(opts, :timeout, 30_000)

    case Ranges.parameter_grid(param_ranges) do
      {:ok, param_combinations} ->
        total_combinations = length(param_combinations)

        results =
          process_combinations_parallel(
            param_combinations,
            dataframe,
            strategy_type,
            opts,
            concurrency,
            timeout,
            progress_callback,
            total_combinations
          )

        {:ok, Results.combine_results(results)}

      {:error, reason} ->
        {:error, {:parallel_optimization_failed, reason}}
    end
  end

  @doc """
  Find the best parameter combination based on a specific metric.

  ## Parameters

  - `results` - DataFrame from optimization results
  - `metric` - Metric to optimize for (default: :total_return)

  ## Available Metrics

  - `:total_return` - Total portfolio return
  - `:sharpe_ratio` - Risk-adjusted return
  - `:sortino_ratio` - Downside deviation adjusted return
  - `:calmar_ratio` - Return divided by max drawdown
  - `:win_rate` - Percentage of winning trades
  - `:profit_factor` - Gross profit divided by gross loss

  ## Examples

      # Find best total return
      best = find_best_params(results, :total_return)

      # Find best risk-adjusted return
      best = find_best_params(results, :sharpe_ratio)
  """
  @spec find_best_params(DataFrame.t(), atom()) :: map() | nil
  def find_best_params(results, metric \\ :total_return) do
    Results.find_best_params(results, metric)
  end

  @doc """
  Generate parameter heatmap data for visualization.

  Creates a 2D heatmap showing how a performance metric varies
  across two parameter dimensions.

  ## Parameters

  - `results` - Optimization results DataFrame
  - `x_param` - Parameter for X-axis
  - `y_param` - Parameter for Y-axis
  - `metric` - Performance metric to visualize

  ## Examples

      # Create heatmap of total return vs fast/slow periods
      heatmap = parameter_heatmap(results, :fast_period, :slow_period, :total_return)
  """
  @spec parameter_heatmap(DataFrame.t(), atom(), atom(), atom()) ::
          {:ok, DataFrame.t()} | {:error, term()}
  def parameter_heatmap(results, x_param, y_param, metric) do
    Results.parameter_heatmap(results, x_param, y_param, metric)
  end

  @doc """
  Perform walk-forward optimization with rolling windows.

  Tests parameter stability over time by optimizing on a training
  window and testing on a subsequent period, then rolling forward.

  ## Parameters

  - `dataframe` - Long-term historical data
  - `strategy_type` - Strategy to optimize
  - `param_ranges` - Parameter ranges to test
  - `opts` - Walk-forward options

  ## Walk-Forward Options

  - `:training_window` - Size of training period in days (default: 252)
  - `:testing_window` - Size of testing period in days (default: 63)
  - `:step_size` - Days to step forward each iteration (default: 21)
  - `:min_trades` - Minimum trades required for valid result (default: 5)

  ## Examples

      # Annual training, quarterly testing, monthly steps
      {:ok, wf_results} = walk_forward_optimization(df, :sma_crossover, param_ranges,
        training_window: 252,
        testing_window: 63,
        step_size: 21
      )
  """
  @spec walk_forward_optimization(DataFrame.t(), strategy_type(), param_ranges(), keyword()) ::
          optimization_result()
  def walk_forward_optimization(_dataframe, _strategy_type, _param_ranges, _opts \\ []) do
    # Implementation will be added in Phase 3
    {:error, :not_implemented}
  end

  @doc """
  Analyze parameter sensitivity across results.

  Shows how changes in a specific parameter affect performance metrics.

  ## Examples

      # See how fast_period affects returns
      sensitivity = analyze_parameter_sensitivity(results, :fast_period)
  """
  @spec analyze_parameter_sensitivity(DataFrame.t(), atom()) ::
          {:ok, map()} | {:error, term()}
  def analyze_parameter_sensitivity(results, param_name) do
    Results.sensitivity_analysis(results, param_name)
  end

  @doc """
  Analyze parameter stability across different metrics.

  Identifies parameter combinations that perform consistently
  well across multiple performance metrics.

  ## Parameters

  - `results` - Optimization results
  - `metric` - Primary metric to analyze
  - `threshold` - Stability threshold (default: 0.1)

  ## Examples

      # Find stable parameter combinations
      stability = stability_analysis(results, :total_return, 0.15)
  """
  @spec stability_analysis(DataFrame.t(), atom(), float()) ::
          {:ok, map()} | {:error, term()}
  def stability_analysis(results, metric, threshold \\ 0.1) do
    Results.stability_analysis(results, metric, threshold)
  end

  # Private functions

  defp process_combinations_parallel(
         param_combinations,
         dataframe,
         strategy_type,
         opts,
         concurrency,
         timeout,
         progress_callback,
         total_combinations
       ) do
    param_combinations
    |> Task.async_stream(
      fn params ->
        run_single_combination(dataframe, strategy_type, params, opts)
      end,
      max_concurrency: concurrency,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Stream.with_index()
    |> Stream.map(fn {result, index} ->
      # Report progress if callback provided
      if progress_callback do
        progress = trunc((index + 1) / total_combinations * 100)
        progress_callback.(progress)
      end

      process_task_result(result)
    end)
    |> Stream.reject(&is_nil/1)
    |> Enum.to_list()
  end

  defp process_task_result(result) do
    case result do
      {:ok, {:ok, result_row}} -> result_row
      {:ok, {:error, _reason}} -> nil
      {:exit, _reason} -> nil
    end
  end

  defp run_parameter_combinations(dataframe, strategy_type, param_combinations, opts) do
    if Enum.empty?(param_combinations) do
      # Return empty DataFrame with expected structure
      {:ok,
       DataFrame.new(%{
         fast_period: [],
         slow_period: [],
         total_return: [],
         sharpe_ratio: [],
         max_drawdown: [],
         win_rate: [],
         trade_count: [],
         volatility: []
       })}
    else
      results =
        param_combinations
        |> Enum.map(&run_single_combination(dataframe, strategy_type, &1, opts))
        |> Enum.filter(fn
          {:ok, _} -> true
          {:error, _} -> false
        end)
        |> Enum.map(fn {:ok, result} -> result end)

      if Enum.empty?(results) do
        {:error, :no_valid_results}
      else
        {:ok, Results.combine_results(results)}
      end
    end
  end

  defp run_single_combination(dataframe, strategy_type, params, opts) do
    # Create strategy with parameters
    strategy = create_strategy(strategy_type, params)

    # Run backtest
    backtest_opts = [
      initial_capital: Keyword.get(opts, :initial_capital, 10_000.0),
      commission: Keyword.get(opts, :commission, 0.001),
      slippage: Keyword.get(opts, :slippage, 0.0005)
    ]

    case Strategy.backtest(dataframe, strategy, backtest_opts) do
      {:ok, backtest_results} ->
        result_row = extract_performance_metrics(params, backtest_results, opts)
        {:ok, result_row}

      {:error, reason} ->
        {:error, {:backtest_failed, reason}}
    end
  rescue
    e -> {:error, {:strategy_creation_failed, Exception.message(e)}}
  end

  defp create_strategy(strategy_type, params) do
    case strategy_type do
      :sma_crossover ->
        Strategy.sma_crossover(
          fast_period: Map.get(params, :fast_period, 12),
          slow_period: Map.get(params, :slow_period, 26)
        )

      :ema_crossover ->
        Strategy.ema_crossover(
          fast_period: Map.get(params, :fast_period, 12),
          slow_period: Map.get(params, :slow_period, 26)
        )

      :rsi_threshold ->
        Strategy.rsi_threshold(
          period: Map.get(params, :period, 14),
          oversold: Map.get(params, :oversold, 30),
          overbought: Map.get(params, :overbought, 70)
        )

      :macd_crossover ->
        Strategy.macd_crossover(
          fast_period: Map.get(params, :fast_period, 12),
          slow_period: Map.get(params, :slow_period, 26),
          signal_period: Map.get(params, :signal_period, 9)
        )

      _ ->
        raise ArgumentError, "Unsupported strategy type: #{strategy_type}"
    end
  end

  defp extract_performance_metrics(params, backtest_results, opts) do
    # Extract key metrics from backtest results
    portfolio_values = DataFrame.pull(backtest_results, "portfolio_value") |> Series.to_list()

    total_return =
      DataFrame.pull(backtest_results, "total_return") |> Series.to_list() |> List.last()

    max_drawdown =
      DataFrame.pull(backtest_results, "max_drawdown") |> Series.to_list() |> List.last()

    win_rate = DataFrame.pull(backtest_results, "win_rate") |> Series.to_list() |> List.last()

    trade_count =
      DataFrame.pull(backtest_results, "trade_count") |> Series.to_list() |> List.last()

    # Calculate additional metrics
    returns = calculate_returns(portfolio_values)
    volatility = calculate_volatility(returns)
    sharpe_ratio = if volatility > 0, do: total_return / volatility, else: 0.0
    sortino_ratio = calculate_sortino_ratio(returns, total_return)
    calmar_ratio = if max_drawdown > 0, do: total_return / max_drawdown, else: 0.0

    # Build result row
    result =
      params
      |> Map.put(:total_return, total_return)
      # Simplified for now
      |> Map.put(:annualized_return, total_return)
      |> Map.put(:sharpe_ratio, sharpe_ratio)
      |> Map.put(:sortino_ratio, sortino_ratio)
      |> Map.put(:calmar_ratio, calmar_ratio)
      |> Map.put(:max_drawdown, max_drawdown)
      |> Map.put(:win_rate, win_rate)
      |> Map.put(:trade_count, trade_count)
      |> Map.put(:volatility, volatility)

    # Include full backtest data if requested
    if Keyword.get(opts, :store_backtest_data, false) do
      Map.put(result, :backtest_data, backtest_results)
    else
      result
    end
  end

  defp calculate_returns(portfolio_values) do
    portfolio_values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      if prev > 0, do: (curr - prev) / prev, else: 0.0
    end)
  end

  defp calculate_volatility(returns) do
    if length(returns) < 2 do
      0.0
    else
      mean_return = Enum.sum(returns) / length(returns)

      variance =
        returns
        |> Enum.map(fn r -> :math.pow(r - mean_return, 2) end)
        |> Enum.sum()
        |> Kernel./(length(returns) - 1)

      :math.sqrt(variance)
    end
  end

  defp calculate_sortino_ratio(returns, total_return) do
    downside_returns = Enum.filter(returns, &(&1 < 0))

    if length(downside_returns) < 2 do
      0.0
    else
      downside_deviation =
        downside_returns
        |> Enum.map(&:math.pow(&1, 2))
        |> Enum.sum()
        |> Kernel./(length(downside_returns))
        |> :math.sqrt()

      if downside_deviation > 0, do: total_return / downside_deviation, else: 0.0
    end
  end
end
