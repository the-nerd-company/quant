defmodule Quant.Strategy.Utils do
  @moduledoc """
  Utility functions for strategy operations.

  This module provides common utility functions used across
  different strategy types, including DataFrame validation,
  column management, and data preprocessing.

  """

  alias Explorer.DataFrame
  alias Explorer.Series

  @doc """
  Validate that a DataFrame has the required structure for strategy execution.

  ## Parameters

  - `dataframe` - DataFrame to validate
  - `strategy` - Strategy configuration
  - `opts` - Additional validation options

  ## Returns

  `{:ok, dataframe}` if valid, `{:error, reason}` if invalid.

  ## Validations Performed

  - Check for required columns
  - Validate minimum number of rows
  - Check for proper data types
  - Ensure datetime index if required

  """
  @spec validate_dataframe(DataFrame.t(), map(), keyword()) ::
          {:ok, DataFrame.t()} | {:error, term()}
  def validate_dataframe(dataframe, strategy, opts \\ []) do
    with :ok <- validate_not_empty(dataframe),
         :ok <- validate_required_columns(dataframe, strategy),
         :ok <- validate_minimum_rows(dataframe, strategy, opts),
         :ok <- validate_data_types(dataframe, strategy) do
      {:ok, dataframe}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Remove intermediate indicator columns that are not needed in final output.

  ## Parameters

  - `dataframe` - DataFrame with intermediate columns
  - `strategy` - Strategy configuration

  ## Returns

  DataFrame with only essential columns retained.

  """
  @spec cleanup_intermediate_columns(DataFrame.t(), map()) :: DataFrame.t()
  def cleanup_intermediate_columns(dataframe, strategy) do
    columns_to_keep = get_essential_columns(dataframe, strategy)
    DataFrame.select(dataframe, columns_to_keep)
  end

  @doc """
  Calculate position sizing based on strategy configuration and risk parameters.

  ## Parameters

  - `dataframe` - DataFrame with price data
  - `strategy` - Strategy configuration
  - `opts` - Position sizing options

  ## Options

  - `:method` - Position sizing method (`:fixed`, `:percent_capital`, `:volatility`)
  - `:capital` - Total available capital
  - `:risk_per_trade` - Risk percentage per trade
  - `:atr_multiplier` - ATR multiplier for volatility-based sizing

  ## Returns

  DataFrame with position sizes added.

  """
  @spec calculate_position_sizes(DataFrame.t(), map(), keyword()) :: DataFrame.t()
  def calculate_position_sizes(dataframe, _strategy, opts \\ []) do
    method = Keyword.get(opts, :method, :fixed)
    capital = Keyword.get(opts, :capital, 10_000.0)
    risk_per_trade = Keyword.get(opts, :risk_per_trade, 0.02)

    position_sizes =
      case method do
        :fixed ->
          fixed_size = Keyword.get(opts, :fixed_size, 100)
          create_constant_series(dataframe, fixed_size)

        :percent_capital ->
          percent = Keyword.get(opts, :percent, 0.1)
          create_constant_series(dataframe, capital * percent)

        :volatility ->
          calculate_volatility_based_sizing(dataframe, capital, risk_per_trade, opts)

        _ ->
          # Default fallback
          create_constant_series(dataframe, 100)
      end

    DataFrame.put(dataframe, "position_size", position_sizes)
  end

  @doc """
  Add timing information for strategy signals.

  Adds columns for signal timing analysis:
  - `signal_duration`: How long each signal lasts
  - `time_since_last_signal`: Time elapsed since previous signal
  - `signal_sequence`: Sequential numbering of signals

  """
  @spec add_timing_analysis(DataFrame.t()) :: DataFrame.t()
  def add_timing_analysis(dataframe) do
    if "signal" in DataFrame.names(dataframe) do
      signals = DataFrame.pull(dataframe, "signal") |> Series.to_list()

      # Calculate signal sequences and timing
      {durations, time_since_last, sequences} = calculate_signal_timing(signals)

      dataframe
      |> DataFrame.put("signal_duration", Series.from_list(durations))
      |> DataFrame.put("time_since_last_signal", Series.from_list(time_since_last))
      |> DataFrame.put("signal_sequence", Series.from_list(sequences))
    else
      dataframe
    end
  end

  # Private helper functions

  defp validate_not_empty(dataframe) do
    if DataFrame.n_rows(dataframe) == 0 do
      {:error, :empty_dataframe}
    else
      :ok
    end
  end

  defp validate_required_columns(dataframe, strategy) do
    required_columns = get_required_columns(strategy)
    existing_columns = DataFrame.names(dataframe)

    missing_columns =
      required_columns
      |> Enum.reject(&(&1 in existing_columns))

    case missing_columns do
      [] -> :ok
      missing -> {:error, {:missing_columns, missing}}
    end
  end

  defp validate_minimum_rows(dataframe, strategy, opts) do
    min_rows = calculate_minimum_rows(strategy, opts)
    actual_rows = DataFrame.n_rows(dataframe)

    if actual_rows < min_rows do
      {:error, {:insufficient_data, %{required: min_rows, actual: actual_rows}}}
    else
      :ok
    end
  end

  defp validate_data_types(dataframe, strategy) do
    # Skip data type validation for composite strategies
    if strategy.type == :composite do
      :ok
    else
      validate_price_column_type(dataframe, strategy)
    end
  end

  defp validate_price_column_type(dataframe, strategy) do
    price_column = Atom.to_string(strategy.column)

    if price_column in DataFrame.names(dataframe) do
      price_series = DataFrame.pull(dataframe, price_column)
      check_numeric_data_type(price_series)
    else
      # Column validation handled elsewhere
      :ok
    end
  end

  defp check_numeric_data_type(price_series) do
    case Series.dtype(price_series) do
      # Float type
      {:f, _} -> :ok
      # Signed integer type
      {:s, _} -> :ok
      # Unsigned integer type
      {:u, _} -> :ok
      _ -> {:error, {:invalid_price_column_type, Series.dtype(price_series)}}
    end
  end

  defp get_required_columns(strategy) do
    # Add strategy-specific required columns
    case strategy.type do
      type when type in [:sma_crossover, :ema_crossover, :macd_crossover, :rsi_threshold] ->
        base_columns = [Atom.to_string(strategy.column)]
        base_columns

      :bollinger_bands ->
        base_columns = [Atom.to_string(strategy.column)]
        # Will need :high, :low when implemented
        base_columns

      :composite ->
        # Composite strategies inherit requirements from sub-strategies
        strategy.strategies
        |> Enum.flat_map(&get_required_columns/1)
        |> Enum.uniq()

      _ ->
        if Map.has_key?(strategy, :column) do
          [Atom.to_string(strategy.column)]
        else
          []
        end
    end
  end

  defp calculate_minimum_rows(strategy, opts) do
    base_minimum = Keyword.get(opts, :min_periods, 1)

    strategy_minimum =
      case strategy.type do
        :sma_crossover ->
          max(strategy.fast_period, strategy.slow_period)

        :ema_crossover ->
          max(strategy.fast_period, strategy.slow_period)

        :macd_crossover ->
          strategy.slow_period + strategy.signal_period

        :rsi_threshold ->
          strategy.period

        :composite ->
          strategy.strategies
          |> Enum.map(&calculate_minimum_rows(&1, opts))
          |> Enum.max(fn -> 1 end)

        _ ->
          1
      end

    max(base_minimum, strategy_minimum)
  end

  defp get_essential_columns(dataframe, _strategy) do
    all_columns = DataFrame.names(dataframe)

    # Keep original OHLCV columns and signal columns
    essential_patterns = [
      ~r/^(open|high|low|close|volume|timestamp|date)$/,
      ~r/^signal/,
      ~r/^position/,
      ~r/^portfolio/
    ]

    Enum.filter(all_columns, fn column ->
      Enum.any?(essential_patterns, &Regex.match?(&1, column))
    end)
  end

  defp create_constant_series(dataframe, value) do
    row_count = DataFrame.n_rows(dataframe)
    List.duplicate(value, row_count) |> Series.from_list()
  end

  defp calculate_volatility_based_sizing(dataframe, capital, risk_per_trade, opts) do
    # Placeholder for volatility-based position sizing
    # This would use ATR or other volatility measures
    atr_multiplier = Keyword.get(opts, :atr_multiplier, 2.0)

    if "atr" in DataFrame.names(dataframe) do
      calculate_atr_based_sizes(dataframe, capital, risk_per_trade, atr_multiplier)
    else
      # Fallback to percentage of capital
      create_constant_series(dataframe, capital * 0.1)
    end
  end

  defp calculate_atr_based_sizes(dataframe, capital, risk_per_trade, atr_multiplier) do
    atr_values = DataFrame.pull(dataframe, "atr") |> Series.to_list()
    close_values = DataFrame.pull(dataframe, "close") |> Series.to_list()

    sizes =
      atr_values
      |> Enum.zip(close_values)
      |> Enum.map(&calculate_single_atr_size(&1, capital, risk_per_trade, atr_multiplier))

    Series.from_list(sizes)
  end

  defp calculate_single_atr_size({atr, close}, capital, risk_per_trade, atr_multiplier) do
    if is_number(atr) and is_number(close) and atr > 0 do
      risk_amount = capital * risk_per_trade
      stop_distance = atr * atr_multiplier
      position_value = risk_amount / stop_distance * close
      # Cap at 20% of capital
      min(position_value, capital * 0.2)
    else
      # Default to 10% of capital
      capital * 0.1
    end
  end

  defp calculate_signal_timing(signals) do
    initial_state = {[], [], [], 0, 0, 0}

    {durations, time_since_last, sequences, _, _, _} =
      signals
      |> Enum.with_index()
      |> Enum.reduce(initial_state, &process_signal_timing/2)

    {Enum.reverse(durations), Enum.reverse(time_since_last), Enum.reverse(sequences)}
  end

  defp process_signal_timing({signal, index}, state) do
    {dur_acc, time_acc, seq_acc, current_signal_start, last_signal_index, signal_count} = state

    cond do
      signal != 0 and current_signal_start == 0 ->
        handle_new_signal(index, dur_acc, time_acc, seq_acc, last_signal_index, signal_count)

      signal != 0 and current_signal_start > 0 ->
        handle_continuing_signal(
          index,
          dur_acc,
          time_acc,
          seq_acc,
          current_signal_start,
          last_signal_index,
          signal_count
        )

      signal == 0 ->
        handle_no_signal(index, dur_acc, time_acc, seq_acc, last_signal_index, signal_count)
    end
  end

  defp handle_new_signal(index, dur_acc, time_acc, seq_acc, last_signal_index, signal_count) do
    time_since = if last_signal_index > 0, do: index - last_signal_index, else: 0

    {[0 | dur_acc], [time_since | time_acc], [signal_count + 1 | seq_acc], index, index,
     signal_count + 1}
  end

  defp handle_continuing_signal(
         index,
         dur_acc,
         time_acc,
         seq_acc,
         current_signal_start,
         last_signal_index,
         signal_count
       ) do
    duration = index - current_signal_start
    time_since = if last_signal_index > 0, do: index - last_signal_index, else: 0

    {[duration | dur_acc], [time_since | time_acc], [signal_count | seq_acc],
     current_signal_start, last_signal_index, signal_count}
  end

  defp handle_no_signal(index, dur_acc, time_acc, seq_acc, last_signal_index, signal_count) do
    time_since = if last_signal_index > 0, do: index - last_signal_index, else: 0

    {[0 | dur_acc], [time_since | time_acc], [0 | seq_acc], 0, last_signal_index, signal_count}
  end
end
