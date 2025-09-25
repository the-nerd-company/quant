defmodule Quant.Strategy.Momentum do
  @moduledoc """
  Momentum-based trading strategies.

  This module implements strategies based on momentum indicators
  such as MACD, RSI, and other oscillators that help identify
  trend strength and potential reversal points.

  ## Supported Strategies

  - **MACD Crossover**: MACD line crossing signal line
  - **RSI Threshold**: RSI oversold/overbought levels
  - **RSI Divergence**: Price vs RSI divergence detection

  ## Strategy Examples

      # Classic MACD crossover
      strategy = Quant.Strategy.Momentum.macd_crossover(
        fast_period: 12,
        slow_period: 26,
        signal_period: 9
      )

      # RSI mean reversion
      strategy = Quant.Strategy.Momentum.rsi_threshold(
        period: 14,
        oversold: 30,
        overbought: 70
      )

  """

  alias Explorer.DataFrame
  alias Quant.Math

  @doc """
  Create a MACD crossover strategy.

  Generates buy signals when MACD line crosses above signal line
  and sell signals when MACD line crosses below signal line.

  ## Parameters

  - `:fast_period` - Fast EMA period (default: 12)
  - `:slow_period` - Slow EMA period (default: 26)
  - `:signal_period` - Signal line EMA period (default: 9)
  - `:column` - Price column to use (default: :close)

  ## Examples

      iex> strategy = Quant.Strategy.Momentum.macd_crossover()
      iex> strategy.type
      :macd_crossover
      iex> strategy.fast_period
      12

  """
  @spec macd_crossover(keyword()) :: map()
  def macd_crossover(opts \\ []) do
    %{
      type: :macd_crossover,
      fast_period: Keyword.get(opts, :fast_period, 12),
      slow_period: Keyword.get(opts, :slow_period, 26),
      signal_period: Keyword.get(opts, :signal_period, 9),
      column: Keyword.get(opts, :column, :close),
      description: "MACD Crossover Strategy"
    }
  end

  @doc """
  Create an RSI threshold strategy.

  Generates buy signals when RSI drops below oversold threshold
  and sell signals when RSI rises above overbought threshold.

  ## Parameters

  - `:period` - RSI calculation period (default: 14)
  - `:oversold` - Oversold threshold (default: 30)
  - `:overbought` - Overbought threshold (default: 70)
  - `:column` - Price column to use (default: :close)

  ## Examples

      iex> strategy = Quant.Strategy.Momentum.rsi_threshold(oversold: 25, overbought: 75)
      iex> strategy.type
      :rsi_threshold
      iex> strategy.oversold
      25
      iex> strategy.overbought
      75

  """
  @spec rsi_threshold(keyword()) :: map()
  def rsi_threshold(opts \\ []) do
    %{
      type: :rsi_threshold,
      period: Keyword.get(opts, :period, 14),
      oversold: Keyword.get(opts, :oversold, 30),
      overbought: Keyword.get(opts, :overbought, 70),
      column: Keyword.get(opts, :column, :close),
      description: "RSI Threshold Strategy"
    }
  end

  @doc """
  Apply the required technical indicators for momentum strategies.

  ## Parameters

  - `dataframe` - Input DataFrame with OHLCV data
  - `strategy` - Strategy configuration
  - `opts` - Additional options

  ## Returns

  DataFrame with momentum indicators added as new columns.

  """
  @spec apply_indicators(DataFrame.t(), map(), keyword()) ::
          {:ok, DataFrame.t()} | {:error, term()}
  def apply_indicators(dataframe, strategy, opts \\ []) do
    column = Keyword.get(opts, :column, strategy.column)

    try do
      result_df =
        case strategy.type do
          :macd_crossover ->
            dataframe
            |> Math.add_macd!(column,
              fast_period: strategy.fast_period,
              slow_period: strategy.slow_period,
              signal_period: strategy.signal_period
            )
            |> Math.detect_macd_crossovers(
              "close_macd_#{strategy.fast_period}_#{strategy.slow_period}",
              "close_signal_#{strategy.signal_period}"
            )

          :rsi_threshold ->
            dataframe
            |> Math.add_rsi!(column, period: strategy.period)

          _ ->
            raise "Unsupported momentum strategy type: #{strategy.type}"
        end

      {:ok, result_df}
    rescue
      e -> {:error, {:momentum_indicator_failed, Exception.message(e)}}
    end
  end

  @doc """
  Validate that a DataFrame has the required columns for momentum strategies.

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

  ## Examples

      iex> strategy = Quant.Strategy.Momentum.macd_crossover()
      iex> columns = Quant.Strategy.Momentum.get_indicator_columns(strategy)
      iex> "close_macd_12_26" in columns
      true

  """
  @spec get_indicator_columns(map()) :: [String.t()]
  def get_indicator_columns(strategy) do
    base_column = Atom.to_string(strategy.column)

    case strategy.type do
      :macd_crossover ->
        [
          "#{base_column}_macd_#{strategy.fast_period}_#{strategy.slow_period}",
          "#{base_column}_signal_#{strategy.signal_period}",
          "#{base_column}_histogram_#{strategy.signal_period}",
          "macd_crossover"
        ]

      :rsi_threshold ->
        [
          "#{base_column}_rsi_#{strategy.period}"
        ]

      _ ->
        []
    end
  end
end
