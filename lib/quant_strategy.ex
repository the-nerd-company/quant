defmodule Quant.Strategy do
  @moduledoc """
  Main API module for quantitative trading strategies.

  This module provides a unified interface for creating, composing, and executing
  trading strategies using technical indicators from `Quant.Math`.

  ## Strategy Types

  - **Signal-based strategies**: Generate buy/sell signals based on technical indicators
  - **Momentum strategies**: Follow trends using moving averages and momentum indicators
  - **Mean reversion strategies**: Trade on price reversals using oscillators
  - **Composite strategies**: Combine multiple indicators for robust signal generation

  ## Basic Usage

      # Simple moving average crossover strategy
      strategy = Quant.Strategy.sma_crossover(fast_period: 12, slow_period: 26)
      signals = Quant.Strategy.generate_signals(df, strategy)

      # RSI oversold/overbought strategy
      strategy = Quant.Strategy.rsi_threshold(oversold: 30, overbought: 70)
      signals = Quant.Strategy.generate_signals(df, strategy)

      # Composite strategy combining multiple indicators
      strategy = Quant.Strategy.composite([
        Quant.Strategy.sma_crossover(fast_period: 12, slow_period: 26),
        Quant.Strategy.rsi_threshold(oversold: 30, overbought: 70)
      ], logic: :all)

  ## Signal Format

  All strategies generate signals as DataFrame columns:
  - `signal`: Integer values (-1: sell, 0: hold, 1: buy)
  - `signal_strength`: Float values (0.0-1.0) indicating confidence
  - `signal_reason`: String describing the signal trigger

  ## Strategy Composition

  Strategies can be combined using logical operators:
  - `:all` - All component strategies must agree (AND logic)
  - `:any` - Any component strategy can trigger (OR logic)
  - `:majority` - Majority of strategies must agree
  - `:weighted` - Weighted combination based on strategy confidence

  """

  alias Explorer.DataFrame
  alias Quant.Strategy.Backtest
  alias Quant.Strategy.{Composite, Momentum, MovingAverage, Volatility}
  alias Quant.Strategy.{Performance, Signal, Utils}

  @type signal_value :: -1 | 0 | 1
  @type signal_strength :: float()
  @type strategy :: map()
  @type strategy_result :: {:ok, DataFrame.t()} | {:error, term()}

  # Delegate to strategy implementations
  defdelegate sma_crossover(opts \\ []), to: Quant.Strategy.MovingAverage, as: :sma_crossover
  defdelegate ema_crossover(opts \\ []), to: Quant.Strategy.MovingAverage, as: :ema_crossover
  defdelegate macd_crossover(opts \\ []), to: Quant.Strategy.Momentum, as: :macd_crossover
  defdelegate rsi_threshold(opts \\ []), to: Quant.Strategy.Momentum, as: :rsi_threshold
  defdelegate bollinger_bands(opts \\ []), to: Quant.Strategy.Volatility, as: :bollinger_bands

  # Composite strategy functions
  defdelegate composite(strategies, opts \\ []), to: Quant.Strategy.Composite, as: :create

  defdelegate combine_signals(signals_list, opts \\ []),
    to: Quant.Strategy.Composite,
    as: :combine

  @doc """
  Generate trading signals for a given DataFrame using the specified strategy.

  ## Parameters

  - `dataframe` - Explorer DataFrame with OHLCV data
  - `strategy` - Strategy configuration map
  - `opts` - Optional parameters for signal generation

  ## Options

  - `:column` - Base price column to use (default: `:close`)
  - `:validate` - Whether to validate required columns (default: `true`)
  - `:cleanup` - Whether to remove intermediate indicator columns (default: `false`)

  ## Examples

      # Simple SMA crossover
      iex> strategy = Quant.Strategy.sma_crossover(fast_period: 5, slow_period: 10)
      iex> {:ok, df_with_signals} = Quant.Strategy.generate_signals(df, strategy)
      iex> DataFrame.names(df_with_signals) |> Enum.member?("signal")
      true

      # RSI with custom thresholds
      iex> strategy = Quant.Strategy.rsi_threshold(oversold: 25, overbought: 75)
      iex> {:ok, df_with_signals} = Quant.Strategy.generate_signals(df, strategy, column: :close)

  """
  @spec generate_signals(DataFrame.t(), strategy(), keyword()) :: strategy_result()
  def generate_signals(dataframe, strategy, opts \\ []) do
    with {:ok, validated_df} <- Utils.validate_dataframe(dataframe, strategy, opts),
         {:ok, enriched_df} <- apply_indicators(validated_df, strategy, opts),
         {:ok, signals_df} <- Signal.generate(enriched_df, strategy, opts) do
      final_df = maybe_cleanup_columns(signals_df, strategy, opts)
      {:ok, final_df}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Backtest a strategy against historical data.

  ## Parameters

  - `dataframe` - Historical OHLCV data
  - `strategy` - Strategy to test
  - `opts` - Backtesting options

  ## Options

  - `:initial_capital` - Starting capital (default: 10000.0)
  - `:position_size` - Position sizing method (default: `:fixed`)
  - `:commission` - Trading commission rate (default: 0.001)
  - `:slippage` - Market slippage rate (default: 0.0005)

  ## Returns

  DataFrame with backtest results including:
  - Portfolio value over time
  - Positions and trades
  - Performance metrics

  """
  @spec backtest(DataFrame.t(), strategy(), keyword()) :: strategy_result()
  def backtest(dataframe, strategy, opts \\ []) do
    Backtest.run(dataframe, strategy, opts)
  end

  @doc """
  Analyze strategy performance and generate metrics.

  Returns comprehensive performance analysis including:
  - Total return, annualized return
  - Sharpe ratio, Sortino ratio
  - Maximum drawdown
  - Win rate, profit factor
  - Risk metrics

  """
  @spec analyze_performance(DataFrame.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_performance(backtest_results, opts \\ []) do
    Performance.analyze(backtest_results, opts)
  end

  # Private functions

  defp apply_indicators(dataframe, strategy, opts) do
    case strategy.type do
      :sma_crossover -> MovingAverage.apply_indicators(dataframe, strategy, opts)
      :ema_crossover -> MovingAverage.apply_indicators(dataframe, strategy, opts)
      :macd_crossover -> Momentum.apply_indicators(dataframe, strategy, opts)
      :rsi_threshold -> Momentum.apply_indicators(dataframe, strategy, opts)
      :bollinger_bands -> Volatility.apply_indicators(dataframe, strategy, opts)
      :composite -> Composite.apply_indicators(dataframe, strategy, opts)
      _ -> {:error, {:unsupported_strategy, strategy.type}}
    end
  end

  defp maybe_cleanup_columns(dataframe, strategy, opts) do
    if Keyword.get(opts, :cleanup, false) do
      Utils.cleanup_intermediate_columns(dataframe, strategy)
    else
      dataframe
    end
  end
end
