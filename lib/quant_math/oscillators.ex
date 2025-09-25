defmodule Quant.Math.Oscillators do
  @moduledoc """
  Momentum oscillators and technical indicators for financial time series analysis.

  This module provides implementations of popular momentum indicators including:
  - MACD (Moving Average Convergence Divergence)
  - RSI (Relative Strength Index)

  All functions are DataFrame-first and integrate seamlessly with Explorer DataFrames.
  """

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math.MovingAverages
  alias Quant.Math.Utils

  @doc """
  Add MACD (Moving Average Convergence Divergence) to a DataFrame.

  MACD is a trend-following momentum indicator that shows the relationship between
  two moving averages of a security's price. The MACD is calculated by subtracting
  the 26-period Exponential Moving Average (EMA) from the 12-period EMA.

  ## Components
  - **MACD Line**: Fast EMA - Slow EMA
  - **Signal Line**: EMA of the MACD Line (typically 9-period)
  - **Histogram**: MACD Line - Signal Line

  ## Parameters
  - `dataframe` - Explorer DataFrame with financial data
  - `column` - Column name to calculate MACD on (typically :close)
  - `opts` - Options keyword list:
    - `:fast_period` - Fast EMA period (default: 12)
    - `:slow_period` - Slow EMA period (default: 26)
    - `:signal_period` - Signal EMA period (default: 9)
    - `:macd_column` - MACD line column name (default: auto-generated)
    - `:signal_column` - Signal line column name (default: auto-generated)
    - `:histogram_column` - Histogram column name (default: auto-generated)

  ## Examples

      iex> df = Explorer.DataFrame.new(%{
      ...>   close: [10.0, 11.0, 12.0, 11.5, 13.0, 12.8, 14.0, 13.5, 15.0, 14.2,
      ...>           16.0, 15.5, 17.0, 16.8, 18.0, 17.5, 19.0, 18.2, 20.0, 19.5,
      ...>           21.0, 20.8, 22.0, 21.5, 23.0, 22.2, 24.0, 23.8, 25.0, 24.5]
      ...> })
      iex> result = Quant.Math.Oscillators.add_macd!(df, :close)
      iex> result |> Explorer.DataFrame.names() |> Enum.sort()
      ["close", "close_histogram_12_26_9", "close_macd_12_26", "close_signal_9"]

      # Custom parameters
      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.Oscillators.add_macd!(df, :close, fast_period: 2, slow_period: 3, signal_period: 2)
      iex> Explorer.DataFrame.names(result) |> Enum.member?("close_macd_2_3")
      true
  """
  def add_macd!(dataframe, column, opts \\ []) do
    # Validate inputs
    Utils.validate_dataframe!(dataframe)
    Utils.validate_column!(dataframe, column)

    # Extract options with defaults
    fast_period = Keyword.get(opts, :fast_period, 12)
    slow_period = Keyword.get(opts, :slow_period, 26)
    signal_period = Keyword.get(opts, :signal_period, 9)

    # Validate periods
    Utils.validate_period!(fast_period, "fast_period")
    Utils.validate_period!(slow_period, "slow_period")
    Utils.validate_period!(signal_period, "signal_period")

    if fast_period >= slow_period do
      raise ArgumentError,
            "fast_period (#{fast_period}) must be less than slow_period (#{slow_period})"
    end

    # Generate column names
    base_name = Atom.to_string(column)

    macd_column =
      Keyword.get(opts, :macd_column, "#{base_name}_macd_#{fast_period}_#{slow_period}")

    signal_column = Keyword.get(opts, :signal_column, "#{base_name}_signal_#{signal_period}")

    histogram_column =
      Keyword.get(
        opts,
        :histogram_column,
        "#{base_name}_histogram_#{fast_period}_#{slow_period}_#{signal_period}"
      )

    # Calculate MACD components
    calculate_macd_components(
      dataframe,
      column,
      fast_period,
      slow_period,
      signal_period,
      macd_column,
      signal_column,
      histogram_column
    )
  end

  # Private function to calculate MACD components
  defp calculate_macd_components(
         dataframe,
         column,
         fast_period,
         slow_period,
         signal_period,
         macd_column,
         signal_column,
         histogram_column
       ) do
    # Step 1: Calculate Fast EMA and Slow EMA
    df_with_emas =
      dataframe
      |> MovingAverages.add_ema!(column, period: fast_period, name: "__temp_fast_ema")
      |> MovingAverages.add_ema!(column, period: slow_period, name: "__temp_slow_ema")

    # Step 2: Calculate MACD Line (Fast EMA - Slow EMA)
    fast_ema_series = DataFrame.pull(df_with_emas, "__temp_fast_ema")
    slow_ema_series = DataFrame.pull(df_with_emas, "__temp_slow_ema")

    macd_series = Series.subtract(fast_ema_series, slow_ema_series)
    df_with_macd = DataFrame.put(df_with_emas, macd_column, macd_series)

    # Step 3: Calculate Signal Line (EMA of MACD Line)
    df_with_signal =
      calculate_signal_line(df_with_macd, macd_column, signal_period, signal_column)

    # Step 4: Calculate Histogram (MACD - Signal)
    macd_final = DataFrame.pull(df_with_signal, macd_column)
    signal_final = DataFrame.pull(df_with_signal, signal_column)
    histogram_series = Series.subtract(macd_final, signal_final)

    # Step 5: Clean up temporary columns and add histogram
    df_with_signal
    |> DataFrame.put(histogram_column, histogram_series)
    |> DataFrame.select(fn col_name ->
      not String.starts_with?(col_name, "__temp_")
    end)
  end

  # Calculate signal line using EMA on MACD values
  defp calculate_signal_line(dataframe, macd_column, signal_period, signal_column) do
    # Get MACD series
    macd_series = DataFrame.pull(dataframe, macd_column)

    # Convert to list for easier processing
    macd_values = Series.to_list(macd_series)

    # Calculate EMA manually for the MACD series (preserving length)
    signal_values = calculate_ema_on_series_preserve_length(macd_values, signal_period)

    # Add signal column to DataFrame
    DataFrame.put(dataframe, signal_column, signal_values)
  end

  # Calculate EMA on a series of values (preserving original length)
  defp calculate_ema_on_series_preserve_length(values, period) do
    alpha = 2.0 / (period + 1)

    # Find first sufficient non-nil values for initial SMA
    {valid_start_idx, initial_sma} = find_initial_sma_for_signal(values, period)

    case initial_sma do
      nil ->
        # Not enough valid values - return all NaN/nil with same length
        Enum.map(values, fn
          nil -> nil
          :nan -> :nan
          _ -> nil
        end)

      _ ->
        # Calculate EMA from the valid start index
        calculate_signal_ema_from_start(values, alpha, valid_start_idx, initial_sma)
    end
  end

  # Find initial SMA for signal calculation (returns index and value)
  defp find_initial_sma_for_signal(values, period) do
    find_initial_sma_for_signal(values, period, [], 0)
  end

  defp find_initial_sma_for_signal([], _period, _acc, _idx) do
    {nil, nil}
  end

  defp find_initial_sma_for_signal([value | rest], period, acc, idx) do
    case value do
      num when is_number(num) and num != :nan ->
        new_acc = [num | acc]

        if length(new_acc) == period do
          initial_sma = Enum.sum(new_acc) / period
          {idx, initial_sma}
        else
          find_initial_sma_for_signal(rest, period, new_acc, idx + 1)
        end

      _ ->
        find_initial_sma_for_signal(rest, period, acc, idx + 1)
    end
  end

  # Calculate EMA from a specific start index (preserving total length)
  @spec calculate_signal_ema_from_start([any()], float(), pos_integer(), float()) ::
          [any()]
  defp calculate_signal_ema_from_start(values, alpha, start_idx, initial_sma) do
    total_length = length(values)

    # Pre-fill with nil/nan for positions before start
    prefix =
      values
      |> Enum.take(start_idx)
      |> Enum.map(fn
        nil -> nil
        :nan -> :nan
        # Convert numbers to nil since we don't have signal yet
        _ -> nil
      end)

    # Calculate from start position
    remaining_values = Enum.drop(values, start_idx + 1)

    {result_suffix, _final_ema} =
      Enum.reduce(remaining_values, {[initial_sma], initial_sma}, fn current_value,
                                                                     {acc, prev_ema} ->
        case current_value do
          num when is_number(num) and num != :nan ->
            new_ema = alpha * num + (1 - alpha) * prev_ema
            {[new_ema | acc], new_ema}

          :nan ->
            {[:nan | acc], prev_ema}

          nil ->
            {[nil | acc], prev_ema}

          _ ->
            {[nil | acc], prev_ema}
        end
      end)

    result = prefix ++ Enum.reverse(result_suffix)

    # Ensure we have the exact same length as input
    if length(result) != total_length do
      # Pad or truncate as needed
      result
      |> Enum.take(total_length)
      |> Kernel.++(List.duplicate(nil, max(0, total_length - length(result))))
    else
      result
    end
  end

  @doc """
  Detect MACD crossovers in a DataFrame.

  Identifies bullish and bearish crossovers between MACD line and Signal line:
  - **Bullish Crossover**: MACD line crosses above Signal line (buy signal)
  - **Bearish Crossover**: MACD line crosses below Signal line (sell signal)

  ## Parameters
  - `dataframe` - DataFrame with MACD and Signal columns
  - `macd_column` - MACD line column name
  - `signal_column` - Signal line column name
  - `opts` - Options:
    - `:crossover_column` - Output column name (default: "macd_crossover")

  ## Returns
  DataFrame with additional crossover column containing:
  - `1` for bullish crossover (MACD crosses above Signal)
  - `-1` for bearish crossover (MACD crosses below Signal)
  - `0` for no crossover

  ## Examples

      iex> df = Explorer.DataFrame.new(%{
      ...>   macd: [0.1, 0.2, 0.15, -0.1, -0.2, 0.05, 0.15],
      ...>   signal: [0.05, 0.15, 0.25, 0.1, -0.05, -0.1, 0.05]
      ...> })
      iex> result = Quant.Math.Oscillators.detect_macd_crossovers(df, "macd", "signal")
      iex> crossovers = result |> Explorer.DataFrame.pull("macd_crossover") |> Explorer.Series.to_list()
      iex> Enum.any?(crossovers, fn x -> x != 0 end)
      true
  """
  @spec detect_macd_crossovers(DataFrame.t(), String.t(), String.t(), keyword()) :: DataFrame.t()
  def detect_macd_crossovers(dataframe, macd_column, signal_column, opts \\ []) do
    crossover_column = Keyword.get(opts, :crossover_column, "macd_crossover")

    # Get MACD and Signal series
    macd_series = DataFrame.pull(dataframe, macd_column)
    signal_series = DataFrame.pull(dataframe, signal_column)

    # Convert to lists for processing
    macd_values = Series.to_list(macd_series)
    signal_values = Series.to_list(signal_series)

    # Calculate crossovers
    crossover_values = calculate_crossovers(macd_values, signal_values)

    # Add crossover column
    DataFrame.put(dataframe, crossover_column, crossover_values)
  end

  # Calculate crossover points between two series
  @spec calculate_crossovers([any()], [any()]) :: [integer()]
  defp calculate_crossovers(macd_values, signal_values) do
    pairs = Enum.zip(macd_values, signal_values)

    {crossovers, _prev_state} =
      Enum.reduce(pairs, {[], nil}, fn {macd, signal}, {acc, prev_state} ->
        current_state = determine_position_state(macd, signal)
        crossover = detect_crossover(prev_state, current_state)
        {[crossover | acc], current_state}
      end)

    Enum.reverse(crossovers)
  end

  # Determine whether MACD is above, below, or equal to Signal
  @spec determine_position_state(any(), any()) :: :above | :below | :equal | :invalid
  defp determine_position_state(macd, signal) when is_number(macd) and is_number(signal) do
    # Handle NaN values using proper float NaN detection
    if not finite?(macd) or not finite?(signal) do
      :invalid
    else
      cond do
        macd > signal -> :above
        macd < signal -> :below
        true -> :equal
      end
    end
  end

  defp determine_position_state(_, _), do: :invalid

  # Helper function to check if a number is finite (not NaN or infinity)
  defp finite?(value) when is_number(value) do
    # Use implicit try to detect NaN/infinity without compiler warnings
    _ = value + 0.0
    true
  rescue
    ArithmeticError -> false
  end

  # Detect crossover based on state transitions
  @spec detect_crossover(
          :above | :below | :equal | :invalid | nil,
          :above | :below | :equal | :invalid
        ) :: integer()
  # Bullish crossover
  defp detect_crossover(:below, :above), do: 1
  # Bearish crossover
  defp detect_crossover(:above, :below), do: -1
  # No crossover
  defp detect_crossover(_, _), do: 0

  @doc """
  Add RSI (Relative Strength Index) to a DataFrame.

  RSI is a momentum oscillator that measures the speed and change of price movements.
  It oscillates between 0 and 100 and is typically used to identify overbought and
  oversold conditions in a security.

  ## Algorithm
  RSI uses Wilder's smoothing method (different from standard EMA):
  - Calculate daily price changes (gains and losses)
  - Apply Wilder's smoothing to average gains and losses
  - RSI = 100 - (100 / (1 + RS)) where RS = Average Gain / Average Loss

  ## Parameters
  - `dataframe` - Explorer DataFrame with financial data
  - `column` - Column name to calculate RSI on (typically :close)
  - `opts` - Options keyword list:
    - `:period` - RSI period (default: 14)
    - `:column_name` - Output column name (default: auto-generated)
    - `:overbought` - Overbought threshold for analysis (default: 70)
    - `:oversold` - Oversold threshold for analysis (default: 30)

  ## Returns
  DataFrame with additional RSI column

  ## Examples

      iex> df = Explorer.DataFrame.new(%{
      ...>   close: [44.0, 44.3, 44.1, 44.2, 44.5, 43.4, 44.0, 44.25, 44.8, 45.1,
      ...>           45.4, 45.8, 46.0, 45.9, 45.2, 44.8, 44.6, 44.4, 44.2, 44.0]
      ...> })
      iex> result = Quant.Math.Oscillators.add_rsi!(df, :close)
      iex> "close_rsi_14" in Explorer.DataFrame.names(result)
      true

      # Custom parameters
      iex> df = Explorer.DataFrame.new(%{close: [10.0, 11.0, 12.0, 11.5, 13.0, 12.8, 14.0, 13.5, 15.0, 14.2]})
      iex> result = Quant.Math.Oscillators.add_rsi!(df, :close, period: 5, column_name: "custom_rsi")
      iex> "custom_rsi" in Explorer.DataFrame.names(result)
      true
  """
  def add_rsi!(dataframe, column, opts \\ []) do
    # Validate inputs
    Utils.validate_dataframe!(dataframe)
    Utils.validate_column!(dataframe, column)

    # Extract options with defaults
    period = Keyword.get(opts, :period, 14)
    column_name = Keyword.get(opts, :column_name, generate_rsi_column_name(column, period))

    # Validate period
    Utils.validate_period!(period, "period")

    # Calculate RSI
    calculate_rsi(dataframe, column, period, column_name)
  end

  @doc """
  Identify RSI overbought and oversold conditions.

  Analyzes RSI values to identify potential trading signals based on traditional
  overbought (>70) and oversold (<30) levels.

  ## Parameters
  - `dataframe` - DataFrame with RSI column
  - `rsi_column` - RSI column name
  - `opts` - Options:
    - `:overbought` - Overbought threshold (default: 70)
    - `:oversold` - Oversold threshold (default: 30)
    - `:signal_column` - Output column name (default: "rsi_signal")

  ## Returns
  DataFrame with additional signal column containing:
  - `1` for oversold condition (potential buy signal)
  - `-1` for overbought condition (potential sell signal)
  - `0` for neutral condition

  ## Examples

      iex> df = Explorer.DataFrame.new(%{rsi: [20, 40, 60, 80, 50, 25, 75]})
      iex> result = Quant.Math.Oscillators.rsi_signals(df, "rsi")
      iex> signals = result |> Explorer.DataFrame.pull("rsi_signal") |> Explorer.Series.to_list()
      iex> Enum.member?(signals, 1) and Enum.member?(signals, -1)
      true
  """
  def rsi_signals(dataframe, rsi_column, opts \\ []) do
    overbought = Keyword.get(opts, :overbought, 70)
    oversold = Keyword.get(opts, :oversold, 30)
    signal_column = Keyword.get(opts, :signal_column, "rsi_signal")

    # Get RSI series
    rsi_series = DataFrame.pull(dataframe, rsi_column)
    rsi_values = Series.to_list(rsi_series)

    # Generate signals
    signal_values =
      Enum.map(rsi_values, fn
        # Buy signal
        rsi when is_number(rsi) and rsi <= oversold -> 1
        # Sell signal
        rsi when is_number(rsi) and rsi >= overbought -> -1
        # Neutral
        _ -> 0
      end)

    # Add signal column
    DataFrame.put(dataframe, signal_column, signal_values)
  end

  # Generate RSI column name based on column and period
  defp generate_rsi_column_name(column, period) do
    base_name = Atom.to_string(column)
    "#{base_name}_rsi_#{period}"
  end

  # Calculate RSI using Wilder's smoothing method
  defp calculate_rsi(dataframe, column, period, column_name) do
    # Get price series and calculate price changes
    price_series = DataFrame.pull(dataframe, column)
    price_values = Series.to_list(price_series)

    # Calculate price changes (gains and losses)
    {gains, losses} = calculate_gains_losses(price_values)

    # Apply Wilder's smoothing to gains and losses
    avg_gains = wilders_smoothing(gains, period)
    avg_losses = wilders_smoothing(losses, period)

    # Calculate RSI values
    rsi_values = calculate_rsi_values(avg_gains, avg_losses, period)

    # Add RSI column to DataFrame
    DataFrame.put(dataframe, column_name, rsi_values)
  end

  # Calculate gains and losses from price changes
  defp calculate_gains_losses(price_values) do
    price_changes = calculate_price_changes(price_values)

    gains =
      Enum.map(price_changes, fn
        change when is_number(change) and change > 0 -> change
        _ -> 0.0
      end)

    losses =
      Enum.map(price_changes, fn
        change when is_number(change) and change < 0 -> abs(change)
        _ -> 0.0
      end)

    {gains, losses}
  end

  # Calculate price changes between consecutive periods
  defp calculate_price_changes(price_values) do
    case price_values do
      [] ->
        []

      # First value has no previous value
      [_single] ->
        [nil]

      prices ->
        [nil | calculate_consecutive_changes(prices)]
    end
  end

  # Calculate consecutive price changes
  defp calculate_consecutive_changes([_prev]), do: []

  defp calculate_consecutive_changes([prev, current | rest])
       when is_number(prev) and is_number(current) do
    change = current - prev
    [change | calculate_consecutive_changes([current | rest])]
  end

  defp calculate_consecutive_changes([_prev, current | rest]) do
    [nil | calculate_consecutive_changes([current | rest])]
  end

  # Apply Wilder's smoothing method (equivalent to pandas ewm(alpha=1/N, adjust=False))
  defp wilders_smoothing(values, period) do
    # Wilder's uses 1/N alpha
    alpha = 1.0 / period

    # Calculate Wilder's smoothed values
    calculate_wilders_smoothed_series(values, alpha)
  end

  # Calculate Wilder's smoothed series (equivalent to pandas ewm(alpha=alpha, adjust=False))
  defp calculate_wilders_smoothed_series(values, alpha) do
    {smoothed, _} =
      Enum.reduce(values, {[], nil}, fn value, {acc, prev_smoothed} ->
        case {value, prev_smoothed} do
          # First valid value becomes the initial smoothed value
          {num, nil} when is_number(num) ->
            {[num | acc], num}

          # Apply Wilder's formula: new = alpha * current + (1 - alpha) * previous
          {num, prev} when is_number(num) and is_number(prev) ->
            new_smoothed = alpha * num + (1 - alpha) * prev
            {[new_smoothed | acc], new_smoothed}

          # Invalid current value - propagate previous or nil
          {_, prev} ->
            {[nil | acc], prev}
        end
      end)

    Enum.reverse(smoothed)
  end

  # Calculate RSI values from average gains and losses
  defp calculate_rsi_values(avg_gains, avg_losses, _period) do
    pairs = Enum.zip(avg_gains, avg_losses)

    Enum.map(pairs, fn
      {gain, loss} when is_number(gain) and is_number(loss) and loss > 0 ->
        rs = gain / loss
        100 - 100 / (1 + rs)

      {gain, loss} when is_number(gain) and is_number(loss) and loss == 0 ->
        # All gains or no change
        if gain > 0, do: 100.0, else: 50.0

      _ ->
        # Insufficient data (nil values from smoothing)
        nil
    end)
  end
end
