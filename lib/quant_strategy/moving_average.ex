defmodule Quant.Strategy.MovingAverage do
  @moduledoc """
  Moving average based trading strategies.

  This module implements various moving average crossover strategies
  that generate buy/sell signals when faster moving averages cross
  above or below slower moving averages.

  ## Supported Strategies

  - **SMA Crossover**: Simple Moving Average crossover
  - **EMA Crossover**: Exponential Moving Average crossover
  - **Dual MA**: Combination of different MA types

  ## Strategy Examples

      # Golden Cross: 50-day SMA crosses above 200-day SMA
      strategy = Quant.Strategy.MovingAverage.sma_crossover(
        fast_period: 50,
        slow_period: 200
      )

      # Fast EMA crossover for short-term trading
      strategy = Quant.Strategy.MovingAverage.ema_crossover(
        fast_period: 12,
        slow_period: 26
      )

  """

  alias Explorer.DataFrame
  alias Quant.Math

  @doc """
  Create a Simple Moving Average crossover strategy.

  ## Parameters

  - `:fast_period` - Period for fast SMA (default: 12)
  - `:slow_period` - Period for slow SMA (default: 26)
  - `:column` - Price column to use (default: :close)

  ## Returns

  Strategy configuration map for use with `Quant.Strategy.generate_signals/2`.

  ## Examples

      iex> strategy = Quant.Strategy.MovingAverage.sma_crossover(fast_period: 5, slow_period: 10)
      iex> strategy.type
      :sma_crossover
      iex> strategy.fast_period
      5
      iex> strategy.slow_period
      10

  """
  @spec sma_crossover(keyword()) :: map()
  def sma_crossover(opts \\ []) do
    %{
      type: :sma_crossover,
      indicator: :sma,
      fast_period: Keyword.get(opts, :fast_period, 12),
      slow_period: Keyword.get(opts, :slow_period, 26),
      column: Keyword.get(opts, :column, :close),
      description: "Simple Moving Average Crossover Strategy"
    }
  end

  @doc """
  Create an Exponential Moving Average crossover strategy.

  ## Parameters

  - `:fast_period` - Period for fast EMA (default: 12)
  - `:slow_period` - Period for slow EMA (default: 26)
  - `:column` - Price column to use (default: :close)

  ## Examples

      iex> strategy = Quant.Strategy.MovingAverage.ema_crossover(fast_period: 8, slow_period: 21)
      iex> strategy.type
      :ema_crossover
      iex> strategy.indicator
      :ema

  """
  @spec ema_crossover(keyword()) :: map()
  def ema_crossover(opts \\ []) do
    %{
      type: :ema_crossover,
      indicator: :ema,
      fast_period: Keyword.get(opts, :fast_period, 12),
      slow_period: Keyword.get(opts, :slow_period, 26),
      column: Keyword.get(opts, :column, :close),
      description: "Exponential Moving Average Crossover Strategy"
    }
  end

  @doc """
  Apply the required technical indicators for moving average strategies.

  This function adds the necessary moving averages to the DataFrame
  before signal generation.

  ## Parameters

  - `dataframe` - Input DataFrame with OHLCV data
  - `strategy` - Strategy configuration
  - `opts` - Additional options

  ## Returns

  DataFrame with moving averages added as new columns.

  """
  @spec apply_indicators(DataFrame.t(), map(), keyword()) ::
          {:ok, DataFrame.t()} | {:error, term()}
  def apply_indicators(dataframe, strategy, opts \\ []) do
    column = Keyword.get(opts, :column, strategy.column)

    try do
      result_df =
        case strategy.indicator do
          :sma ->
            dataframe
            |> Math.add_sma!(column, period: strategy.fast_period)
            |> Math.add_sma!(column, period: strategy.slow_period)

          :ema ->
            dataframe
            |> Math.add_ema!(column, period: strategy.fast_period)
            |> Math.add_ema!(column, period: strategy.slow_period)

          _ ->
            raise "Unsupported moving average type: #{strategy.indicator}"
        end

      {:ok, result_df}
    rescue
      e -> {:error, {:indicator_application_failed, Exception.message(e)}}
    end
  end

  @doc """
  Validate that a DataFrame has the required columns for moving average strategies.

  ## Parameters

  - `dataframe` - DataFrame to validate
  - `strategy` - Strategy configuration

  ## Returns

  `:ok` if valid, `{:error, reason}` if invalid.

  """
  @spec validate_dataframe(DataFrame.t(), map()) :: :ok | {:error, term()}
  def validate_dataframe(dataframe, strategy) do
    required_columns = [Atom.to_string(strategy.column)]

    missing_columns =
      required_columns
      |> Enum.reject(&(&1 in DataFrame.names(dataframe)))

    case missing_columns do
      [] -> :ok
      missing -> {:error, {:missing_columns, missing}}
    end
  end

  @doc """
  Get the column names that will be created by this strategy.

  Useful for understanding what columns will be added to the DataFrame.

  ## Examples

      iex> strategy = Quant.Strategy.MovingAverage.sma_crossover(fast_period: 5, slow_period: 10)
      iex> Quant.Strategy.MovingAverage.get_indicator_columns(strategy)
      ["close_sma_5", "close_sma_10"]

  """
  @spec get_indicator_columns(map()) :: [String.t()]
  def get_indicator_columns(strategy) do
    base_column = Atom.to_string(strategy.column)
    indicator = Atom.to_string(strategy.indicator)

    [
      "#{base_column}_#{indicator}_#{strategy.fast_period}",
      "#{base_column}_#{indicator}_#{strategy.slow_period}"
    ]
  end
end
