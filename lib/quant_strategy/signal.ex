defmodule Quant.Strategy.Signal do
  @moduledoc """
  Core signal generation module for trading strategies.

  This module handles the actual generation of buy/sell/hold signals
  based on technical indicator values and strategy rules.

  ## Signal Values

  - `-1`: Sell signal
  - `0`: Hold signal (no action)
  - `1`: Buy signal

  ## Signal Strength

  Signal strength is a float value between 0.0 and 1.0 indicating
  the confidence level of the signal:
  - `0.0-0.3`: Weak signal
  - `0.3-0.7`: Moderate signal
  - `0.7-1.0`: Strong signal

  """

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Strategy.Composite

  @type signal_value :: -1 | 0 | 1
  @type signal_strength :: float()

  @doc """
  Generate trading signals based on strategy configuration.

  ## Parameters

  - `dataframe` - DataFrame with technical indicators already applied
  - `strategy` - Strategy configuration map
  - `opts` - Additional options

  ## Returns

  DataFrame with added signal columns:
  - `signal`: Integer signal values (-1, 0, 1)
  - `signal_strength`: Float confidence values (0.0-1.0)
  - `signal_reason`: String describing signal trigger

  """
  @spec generate(DataFrame.t(), map(), keyword()) :: {:ok, DataFrame.t()} | {:error, term()}
  def generate(dataframe, strategy, opts \\ []) do
    case strategy.type do
      :sma_crossover -> generate_crossover_signals(dataframe, strategy, opts)
      :ema_crossover -> generate_crossover_signals(dataframe, strategy, opts)
      :macd_crossover -> generate_macd_signals(dataframe, strategy, opts)
      :rsi_threshold -> generate_rsi_signals(dataframe, strategy, opts)
      :bollinger_bands -> generate_bollinger_signals(dataframe, strategy, opts)
      :composite -> generate_composite_signals(dataframe, strategy, opts)
      _ -> {:error, {:unsupported_strategy_type, strategy.type}}
    end
  end

  # Moving average crossover signals
  defp generate_crossover_signals(dataframe, strategy, _opts) do
    fast_col = "close_#{strategy.indicator}_#{strategy.fast_period}"
    slow_col = "close_#{strategy.indicator}_#{strategy.slow_period}"

    try do
      fast_ma = DataFrame.pull(dataframe, fast_col)
      slow_ma = DataFrame.pull(dataframe, slow_col)

      # Generate crossover signals
      signals = generate_ma_crossover_logic(fast_ma, slow_ma)
      signal_strength = calculate_crossover_strength(fast_ma, slow_ma)
      signal_reasons = generate_crossover_reasons(signals, strategy)

      result_df =
        dataframe
        |> DataFrame.put("signal", signals)
        |> DataFrame.put("signal_strength", signal_strength)
        |> DataFrame.put("signal_reason", signal_reasons)

      {:ok, result_df}
    rescue
      e -> {:error, {:signal_generation_failed, Exception.message(e)}}
    end
  end

  # MACD crossover signals
  defp generate_macd_signals(dataframe, strategy, _opts) do
    # Use existing MACD crossover detection from Quant.Math
    macd_col = "close_macd_#{strategy.fast_period}_#{strategy.slow_period}"
    signal_col = "close_signal_#{strategy.signal_period}"

    if "macd_crossover" in DataFrame.names(dataframe) do
      crossovers = DataFrame.pull(dataframe, "macd_crossover")
      macd_values = DataFrame.pull(dataframe, macd_col)
      signal_values = DataFrame.pull(dataframe, signal_col)

      signals =
        Series.transform(crossovers, fn
          # Bullish crossover -> Buy
          1 -> 1
          # Bearish crossover -> Sell
          -1 -> -1
          # No crossover -> Hold
          _ -> 0
        end)

      signal_strength = calculate_macd_strength(macd_values, signal_values)
      signal_reasons = generate_macd_reasons(crossovers)

      result_df =
        dataframe
        |> DataFrame.put("signal", signals)
        |> DataFrame.put("signal_strength", signal_strength)
        |> DataFrame.put("signal_reason", signal_reasons)

      {:ok, result_df}
    else
      {:error, :missing_macd_crossover_column}
    end
  rescue
    e -> {:error, {:macd_signal_generation_failed, Exception.message(e)}}
  end

  # RSI threshold signals
  defp generate_rsi_signals(dataframe, strategy, _opts) do
    rsi_col = "close_rsi_#{strategy.period}"
    rsi_values = DataFrame.pull(dataframe, rsi_col)

    oversold = strategy.oversold
    overbought = strategy.overbought

    signals =
      Series.transform(rsi_values, fn
        # Oversold -> Buy
        rsi when is_number(rsi) and rsi <= oversold -> 1
        # Overbought -> Sell
        rsi when is_number(rsi) and rsi >= overbought -> -1
        # Neutral zone -> Hold
        _ -> 0
      end)

    signal_strength = calculate_rsi_strength(rsi_values, oversold, overbought)
    signal_reasons = generate_rsi_reasons(rsi_values, oversold, overbought)

    result_df =
      dataframe
      |> DataFrame.put("signal", signals)
      |> DataFrame.put("signal_strength", signal_strength)
      |> DataFrame.put("signal_reason", signal_reasons)

    {:ok, result_df}
  rescue
    e -> {:error, {:rsi_signal_generation_failed, Exception.message(e)}}
  end

  # Bollinger Bands signals (placeholder)
  # Note: Will be implemented when Bollinger Bands are added to Quant.Math
  defp generate_bollinger_signals(dataframe, _strategy, _opts) do
    # This will be implemented when Bollinger Bands are added to Quant.Math
    row_count = DataFrame.n_rows(dataframe)
    signals = Series.from_list(List.duplicate(0, row_count))
    signal_strength = Series.from_list(List.duplicate(0.0, row_count))
    signal_reasons = Series.from_list(List.duplicate("bollinger_not_implemented", row_count))

    result_df =
      dataframe
      |> DataFrame.put("signal", signals)
      |> DataFrame.put("signal_strength", signal_strength)
      |> DataFrame.put("signal_reason", signal_reasons)

    {:ok, result_df}
  end

  # Composite signals (handled by Composite module)
  defp generate_composite_signals(dataframe, strategy, opts) do
    Composite.generate_signals(dataframe, strategy, opts)
  end

  # Helper functions for signal generation logic

  defp generate_ma_crossover_logic(fast_ma, slow_ma) do
    fast_list = Series.to_list(fast_ma)
    slow_list = Series.to_list(slow_ma)

    signals =
      fast_list
      |> Enum.zip(slow_list)
      |> Enum.with_index()
      |> Enum.map(&calculate_crossover_signal(&1, fast_list, slow_list))

    Series.from_list(signals)
  end

  defp calculate_crossover_signal({{fast, slow}, index}, fast_list, slow_list) do
    cond do
      # No signal on first data point
      index == 0 ->
        0

      is_number(fast) and is_number(slow) ->
        check_crossover(fast, slow, index, fast_list, slow_list)

      # Handle NaN or invalid values
      true ->
        0
    end
  end

  defp check_crossover(fast, slow, index, fast_list, slow_list) do
    prev_fast = Enum.at(fast_list, index - 1)
    prev_slow = Enum.at(slow_list, index - 1)

    cond do
      # Bullish crossover: fast was below, now above
      crossover_bullish?(prev_fast, prev_slow, fast, slow) -> 1
      # Bearish crossover: fast was above, now below
      crossover_bearish?(prev_fast, prev_slow, fast, slow) -> -1
      true -> 0
    end
  end

  defp crossover_bullish?(prev_fast, prev_slow, fast, slow) do
    is_number(prev_fast) and is_number(prev_slow) and
      prev_fast <= prev_slow and fast > slow
  end

  defp crossover_bearish?(prev_fast, prev_slow, fast, slow) do
    is_number(prev_fast) and is_number(prev_slow) and
      prev_fast >= prev_slow and fast < slow
  end

  defp calculate_crossover_strength(fast_ma, slow_ma) do
    fast_list = Series.to_list(fast_ma)
    slow_list = Series.to_list(slow_ma)

    strengths =
      fast_list
      |> Enum.zip(slow_list)
      |> Enum.map(fn {fast, slow} ->
        if is_number(fast) and is_number(slow) and slow != 0 do
          # Strength based on percentage difference
          (abs(fast - slow) / slow) |> min(1.0)
        else
          0.0
        end
      end)

    Series.from_list(strengths)
  end

  defp calculate_macd_strength(macd_values, signal_values) do
    macd_list = Series.to_list(macd_values)
    signal_list = Series.to_list(signal_values)

    strengths =
      macd_list
      |> Enum.zip(signal_list)
      |> Enum.map(fn {macd, signal} ->
        if is_number(macd) and is_number(signal) and signal != 0 do
          (abs(macd - signal) / abs(signal)) |> min(1.0)
        else
          0.0
        end
      end)

    Series.from_list(strengths)
  end

  defp calculate_rsi_strength(rsi_values, oversold, overbought) do
    rsi_list = Series.to_list(rsi_values)

    strengths =
      Enum.map(rsi_list, fn rsi ->
        cond do
          is_number(rsi) and rsi <= oversold ->
            # Stronger signal the further below oversold
            ((oversold - rsi) / oversold) |> min(1.0)

          is_number(rsi) and rsi >= overbought ->
            # Stronger signal the further above overbought
            ((rsi - overbought) / (100 - overbought)) |> min(1.0)

          true ->
            0.0
        end
      end)

    Series.from_list(strengths)
  end

  defp generate_crossover_reasons(signals, strategy) do
    signal_list = Series.to_list(signals)
    indicator = strategy.indicator
    fast = strategy.fast_period
    slow = strategy.slow_period

    reasons =
      Enum.map(signal_list, fn
        1 -> "#{indicator}_bullish_crossover_#{fast}_#{slow}"
        -1 -> "#{indicator}_bearish_crossover_#{fast}_#{slow}"
        0 -> "no_signal"
      end)

    Series.from_list(reasons)
  end

  defp generate_macd_reasons(crossovers) do
    crossover_list = Series.to_list(crossovers)

    reasons =
      Enum.map(crossover_list, fn
        1 -> "macd_bullish_crossover"
        -1 -> "macd_bearish_crossover"
        _ -> "no_signal"
      end)

    Series.from_list(reasons)
  end

  defp generate_rsi_reasons(rsi_values, oversold, overbought) do
    rsi_list = Series.to_list(rsi_values)

    reasons =
      Enum.map(rsi_list, fn rsi ->
        cond do
          is_number(rsi) and rsi <= oversold -> "rsi_oversold_#{oversold}"
          is_number(rsi) and rsi >= overbought -> "rsi_overbought_#{overbought}"
          true -> "no_signal"
        end
      end)

    Series.from_list(reasons)
  end
end
