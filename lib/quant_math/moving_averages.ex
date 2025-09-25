defmodule Quant.Math.MovingAverages do
  @moduledoc """
  Moving Average technical indicators.

  This module implements various moving average calculations including:
  - Simple Moving Average (SMA)
  - Exponential Moving Average (EMA) - Coming soon
  - Weighted Moving Average (WMA) - Coming soon
  - Hull Moving Average (HMA) - Coming soon

  All functions work with Explorer DataFrames and use NX tensors internally
  for high-performance calculations.
  """

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math.Utils

  @type period_option :: pos_integer()
  @type name_option :: String.t() | atom()
  @type nan_policy :: :drop | :fill_forward | :error

  @type sma_opts :: [
          period: period_option(),
          name: name_option(),
          nan_policy: nan_policy(),
          min_periods: pos_integer(),
          fillna: any()
        ]

  @type ema_opts :: [
          period: period_option(),
          alpha: float(),
          name: name_option(),
          nan_policy: nan_policy(),
          min_periods: pos_integer(),
          fillna: any()
        ]

  @doc """
  Add Simple Moving Average (SMA) to a DataFrame.

  The Simple Moving Average is calculated as the arithmetic mean of values
  over a specified period. Values before the minimum required periods are
  set to NaN.

  ## Parameters

  - `dataframe` - The Explorer DataFrame
  - `column` - The column to calculate SMA for (atom)
  - `opts` - Options (keyword list)

  ## Options

  - `:period` - Number of periods for the moving average (default: 20)
  - `:name` - Name for the new column (default: "<column>_sma_<period>")
  - `:nan_policy` - How to handle NaN values (default: :drop)
  - `:min_periods` - Minimum periods required (default: same as period)
  - `:fillna` - Value to fill NaN results with (default: nil)

  ## Examples

      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.MovingAverages.add_sma!(df, :close, period: 3)
      iex> "close_sma_3" in Map.keys(result.dtypes)
      true

      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.MovingAverages.add_sma!(df, :close, period: 2, name: "ma_2")
      iex> "ma_2" in Map.keys(result.dtypes)
      true
  """
  @spec add_sma!(DataFrame.t(), atom(), sma_opts()) :: DataFrame.t()
  def add_sma!(dataframe, column, opts \\ []) do
    # Validate inputs
    case Utils.validate_column(dataframe, column) do
      :ok ->
        # Set default options
        period = Keyword.get(opts, :period, 20)
        column_name = generate_sma_column_name(column, opts)

        # Validate period
        if period <= 0 do
          raise ArgumentError, "Period must be a positive integer, got: #{period}"
        end

        # Extract the series and convert to tensor
        series = DataFrame.pull(dataframe, column)

        # Handle empty series case
        series_list = Series.to_list(series)

        if Enum.empty?(series_list) do
          # Create empty series with same dtype
          result_series = Series.from_list([], dtype: :f64)
          DataFrame.put(dataframe, column_name, result_series)
        else
          tensor = Utils.to_tensor(series)

          # Calculate rolling mean
          result_tensor = Utils.rolling_mean(tensor, period)

          # Convert back to series
          result_series = Utils.to_series(result_tensor, column_name)

          # Add the new column to the DataFrame
          DataFrame.put(dataframe, column_name, result_series)
        end

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  @doc """
  Add Exponential Moving Average (EMA) to a DataFrame.

  The Exponential Moving Average gives more weight to recent prices and responds
  more quickly to price changes than a simple moving average. The first EMA value
  is calculated as the SMA of the first `period` values.

  ## Parameters

  - `dataframe` - The Explorer DataFrame
  - `column` - The column to calculate EMA for (atom)
  - `opts` - Options (keyword list)

  ## Options

  - `:period` - Number of periods for the exponential moving average (default: 12)
  - `:alpha` - Smoothing factor (default: 2/(period+1))
  - `:name` - Name for the new column (default: "<column>_ema_<period>")
  - `:nan_policy` - How to handle NaN values (default: :drop)
  - `:min_periods` - Minimum periods required (default: same as period)
  - `:fillna` - Value to fill NaN results with (default: nil)

  ## Examples

      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.MovingAverages.add_ema!(df, :close, period: 3)
      iex> "close_ema_3" in Map.keys(result.dtypes)
      true

      iex> df = Explorer.DataFrame.new(%{close: [10.0, 12.0, 14.0, 16.0, 18.0]})
      iex> result = Quant.Math.MovingAverages.add_ema!(df, :close, period: 2, name: "ema_2")
      iex> "ema_2" in Map.keys(result.dtypes)
      true
  """
  @spec add_ema!(DataFrame.t(), atom(), ema_opts()) :: DataFrame.t()
  def add_ema!(dataframe, column, opts \\ []) do
    # Validate inputs
    case Utils.validate_column(dataframe, column) do
      :ok ->
        # Set default options
        period = Keyword.get(opts, :period, 12)
        alpha = Keyword.get(opts, :alpha)
        column_name = generate_ema_column_name(column, opts)

        # Validate period
        if period <= 0 do
          raise ArgumentError, "Period must be a positive integer, got: #{period}"
        end

        # Validate alpha if provided
        if alpha && (alpha <= 0.0 || alpha > 1.0) do
          raise ArgumentError, "Alpha must be between 0.0 and 1.0, got: #{alpha}"
        end

        # Extract the series and convert to tensor
        series = DataFrame.pull(dataframe, column)

        # Handle empty series case
        series_list = Series.to_list(series)

        if Enum.empty?(series_list) do
          # Create empty series with same dtype
          result_series = Series.from_list([], dtype: :f64)
          DataFrame.put(dataframe, column_name, result_series)
        else
          tensor = Utils.to_tensor(series)

          # Calculate exponential mean
          result_tensor = Utils.exponential_mean(tensor, period, alpha)

          # Convert back to series
          result_series = Utils.to_series(result_tensor, column_name)

          # Add the new column to the DataFrame
          DataFrame.put(dataframe, column_name, result_series)
        end

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  @doc """
  Get information about SMA/EMA results in a DataFrame.

  This function helps users understand moving average results,
  especially regarding NaN values that appear before sufficient
  data points are available.

  ## Parameters

  - `dataframe` - DataFrame containing moving average results
  - `column` - The moving average column to analyze (atom or string)

  ## Returns

  A map containing:
  - `:total_rows` - Total number of rows
  - `:nan_count` - Number of NaN values
  - `:valid_count` - Number of valid (non-NaN) values
  - `:first_valid_index` - Index of first valid value
  - `:summary_stats` - Min, max, mean of valid values

  ## Examples

      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.MovingAverages.add_sma!(df, :close, period: 3)
      iex> info = Quant.Math.MovingAverages.analyze_ma_results!(result, "close_sma_3")
      iex> info.valid_count
      3
  """
  @spec analyze_ma_results!(DataFrame.t(), atom() | String.t()) :: map()
  def analyze_ma_results!(dataframe, column) do
    column_name = if is_atom(column), do: Atom.to_string(column), else: column

    # Validate column exists
    unless column_name in Map.keys(dataframe.dtypes) do
      raise ArgumentError, "Column #{inspect(column)} not found in DataFrame"
    end

    # Extract values
    values = DataFrame.pull(dataframe, column_name) |> Series.to_list()
    total_rows = length(values)

    # Analyze NaN vs valid values
    {nan_values, valid_values} = Enum.split_with(values, fn val -> val == :nan end)
    nan_count = length(nan_values)
    valid_count = length(valid_values)

    # Find first valid index
    first_valid_index = Enum.find_index(values, fn val -> val != :nan end)

    # Calculate summary stats for valid values
    summary_stats =
      if valid_count > 0 do
        %{
          min: Enum.min(valid_values),
          max: Enum.max(valid_values),
          mean: Enum.sum(valid_values) / valid_count
        }
      else
        %{min: nil, max: nil, mean: nil}
      end

    %{
      total_rows: total_rows,
      nan_count: nan_count,
      valid_count: valid_count,
      first_valid_index: first_valid_index,
      summary_stats: summary_stats
    }
  end

  @doc """
  Add Weighted Moving Average (WMA) column to a DataFrame.

  WMA gives more weight to recent prices with configurable weight vectors.
  Default uses linear weights: [1, 2, 3, ..., period] where recent prices have higher weights.

  ## Parameters
  - `df` - Explorer DataFrame containing price data
  - `price_column` - Name of the column containing prices (default: :close)
  - `options` - Keyword list with the following options:
    - `:period` - WMA period (required, positive integer)
    - `:column_name` - Name for the WMA column (default: :wma_N where N is period)
    - `:weights` - Custom weight vector as list (default: linear [1, 2, 3, ..., period])
    - `:validate` - Whether to validate inputs (default: true)

  ## Returns
  - `{:ok, DataFrame.t()}` - DataFrame with WMA column added
  - `{:error, reason}` - Error tuple if validation fails

  ## Examples
      iex> df = Explorer.DataFrame.new(%{close: [10, 12, 14, 16, 18, 20]})
      iex> result = Quant.Math.MovingAverages.add_wma!(df, :close, period: 3)
      iex> Explorer.DataFrame.to_columns(result)["close_wma_3"] |> Enum.take(-3) |> Enum.map(&Float.round(&1, 2))
      [14.67, 16.67, 18.67]  # Weighted averages with linear weights

      # Custom weights (equal weights = SMA)
      iex> df = Explorer.DataFrame.new(%{close: [10, 12, 14, 16, 18, 20]})
      iex> result = Quant.Math.MovingAverages.add_wma!(df, :close, period: 3, weights: [1, 1, 1])
      iex> Explorer.DataFrame.to_columns(result)["close_wma_3"] |> Enum.take(-3)
      [14.0, 16.0, 18.0]  # Same as SMA with equal weights

  ## Algorithm
  - Linear weights (default): WMA_t = (P_t×N + P_(t-1)×(N-1) + ... + P_(t-N+1)×1) / (1+2+...+N)
  - Custom weights: WMA_t = (P_t×W_N + P_(t-1)×W_(N-1) + ... + P_(t-N+1)×W_1) / Σ(W_i)
  - Returns NaN for periods with insufficient data
  """
  @spec add_wma!(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  def add_wma!(df, price_column \\ :close, options \\ []) do
    # Validate column exists
    case Utils.validate_column(df, price_column) do
      :ok ->
        do_add_wma(df, price_column, options)

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  @doc false
  @spec do_add_wma(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  defp do_add_wma(df, price_column, options) do
    # Handle empty DataFrame early
    if DataFrame.n_rows(df) == 0 do
      # Create empty column and return
      column_name = generate_wma_column_name(price_column, options)

      empty_series = Series.from_list([], dtype: :f64)
      DataFrame.put(df, column_name, empty_series)
    else
      do_add_wma_with_data(df, price_column, options)
    end
  end

  @doc false
  @spec do_add_wma_with_data(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  defp do_add_wma_with_data(df, price_column, options) do
    # Extract and validate period
    period = validate_wma_period(options)

    # Extract other options with defaults
    column_name = generate_wma_column_name(price_column, options)
    weights = Keyword.get(options, :weights, nil)
    validate = Keyword.get(options, :validate, true)

    # Additional validation if enabled
    if validate and DataFrame.n_rows(df) < period do
      raise ArgumentError, "DataFrame has #{DataFrame.n_rows(df)} rows but period is #{period}"
    end

    # Convert weights to NX tensor if provided
    weight_tensor = validate_and_convert_weights(weights, period)

    # Extract the series from the DataFrame
    series = DataFrame.pull(df, price_column)

    result_tensor =
      series
      |> Utils.to_tensor()
      |> Utils.weighted_mean(period, weight_tensor)

    # Convert back to series
    result_series = Utils.to_series(result_tensor, column_name)

    # Add the new column to the DataFrame
    DataFrame.put(df, column_name, result_series)
  end

  @doc false
  @spec validate_wma_period(Keyword.t()) :: pos_integer()
  defp validate_wma_period(options) do
    case Keyword.get(options, :period) do
      nil ->
        raise ArgumentError, "Period is required"

      period when is_integer(period) and period > 0 ->
        period

      period ->
        raise ArgumentError, "Period must be a positive integer, got: #{inspect(period)}"
    end
  end

  @doc false
  @spec validate_and_convert_weights(list() | nil, pos_integer()) :: Nx.Tensor.t() | nil
  defp validate_and_convert_weights(nil, _period), do: nil

  defp validate_and_convert_weights(weights, period) do
    if length(weights) != period do
      raise ArgumentError, "Weight vector length #{length(weights)} must match period #{period}"
    end

    Nx.tensor(weights, type: :f64)
  end

  @doc false
  @spec generate_sma_column_name(atom(), Keyword.t()) :: String.t()
  defp generate_sma_column_name(base_column, opts) do
    case Keyword.get(opts, :name) do
      nil ->
        period = Keyword.get(opts, :period, "unknown")
        "#{base_column}_sma_#{period}"

      name when is_atom(name) ->
        Atom.to_string(name)

      name when is_binary(name) ->
        name
    end
  end

  @doc false
  @spec generate_ema_column_name(atom(), Keyword.t()) :: String.t()
  defp generate_ema_column_name(base_column, opts) do
    case Keyword.get(opts, :name) do
      nil ->
        period = Keyword.get(opts, :period, "unknown")
        "#{base_column}_ema_#{period}"

      name when is_atom(name) ->
        Atom.to_string(name)

      name when is_binary(name) ->
        name
    end
  end

  @doc false
  @spec generate_wma_column_name(atom(), Keyword.t()) :: String.t()
  defp generate_wma_column_name(base_column, opts) do
    case Keyword.get(opts, :column_name) do
      nil ->
        period = Keyword.get(opts, :period, "unknown")
        "#{base_column}_wma_#{period}"

      name when is_atom(name) ->
        Atom.to_string(name)

      name when is_binary(name) ->
        name
    end
  end

  @doc false
  @spec generate_hma_column_name(atom(), Keyword.t()) :: String.t()
  defp generate_hma_column_name(base_column, opts) do
    case Keyword.get(opts, :column_name) do
      nil ->
        period = Keyword.get(opts, :period, "unknown")
        "#{base_column}_hma_#{period}"

      name when is_atom(name) ->
        Atom.to_string(name)

      name when is_binary(name) ->
        name
    end
  end

  @doc false
  @spec generate_dema_column_name(atom(), Keyword.t()) :: String.t()
  defp generate_dema_column_name(base_column, opts) do
    case Keyword.get(opts, :column_name) do
      nil ->
        period = Keyword.get(opts, :period, "unknown")
        "#{base_column}_dema_#{period}"

      name when is_atom(name) ->
        Atom.to_string(name)

      name when is_binary(name) ->
        name
    end
  end

  @doc false
  @spec generate_tema_column_name(atom(), Keyword.t()) :: String.t()
  defp generate_tema_column_name(base_column, opts) do
    case Keyword.get(opts, :column_name) do
      nil ->
        period = Keyword.get(opts, :period, "unknown")
        "#{base_column}_tema_#{period}"

      name when is_atom(name) ->
        Atom.to_string(name)

      name when is_binary(name) ->
        name

      other ->
        raise ArgumentError, "column_name must be a string or atom, got: #{inspect(other)}"
    end
  end

  @doc """
  Add Hull Moving Average (HMA) to a DataFrame.

  The Hull Moving Average was developed by Alan Hull to address the lag inherent in traditional moving averages.
  It uses weighted moving averages and a square root period to significantly reduce lag while maintaining smoothness.

  ## Algorithm
  1. Calculate WMA(period/2) of the price data
  2. Calculate WMA(period) of the price data
  3. Calculate raw HMA: 2 × WMA(period/2) - WMA(period)
  4. Apply WMA(√period) to the raw HMA for final smoothing

  ## Parameters
  - `df` - Explorer DataFrame containing price data
  - `price_column` - Name of the column containing prices (default: :close)
  - `options` - Keyword list with the following options:
    - `:period` - HMA period (required, positive integer)
    - `:column_name` - Name for the HMA column (default: :hma_N where N is period)
    - `:validate` - Whether to validate inputs (default: true)

  ## Returns
  - `DataFrame.t()` - DataFrame with HMA column added

  ## Raises
  - `ArgumentError` - If inputs are invalid or insufficient data

  ## Examples
      iex> df = Explorer.DataFrame.new(%{close: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]})
      iex> result = Quant.Math.MovingAverages.add_hma!(df, :close, period: 4)
      iex> "close_hma_4" in Map.keys(result.dtypes)
      true

      # Hull MA reduces lag compared to traditional moving averages
      iex> df = Explorer.DataFrame.new(%{close: [10, 12, 11, 13, 12, 14, 13, 15, 14, 16]})
      iex> result = Quant.Math.MovingAverages.add_hma!(df, :close, period: 4)
      iex> hma_values = Explorer.DataFrame.to_columns(result)["close_hma_4"]
      iex> is_list(hma_values) and length(hma_values) == 10
      true

  ## Mathematical Properties
  - **Reduced Lag**: Responds faster to price changes than SMA/EMA
  - **Smoothness**: Maintains smoothness despite reduced lag
  - **Trend Following**: Excellent for trend identification
  - **Whipsaws**: May produce more false signals in choppy markets
  """
  @spec add_hma!(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  def add_hma!(df, price_column \\ :close, options \\ []) do
    # Validate column exists
    case Utils.validate_column(df, price_column) do
      :ok ->
        do_add_hma(df, price_column, options)

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  @doc false
  @spec do_add_hma(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  defp do_add_hma(df, price_column, options) do
    # Handle empty DataFrame early
    if DataFrame.n_rows(df) == 0 do
      # Create empty column and return
      column_name = generate_hma_column_name(price_column, options)

      empty_series = Series.from_list([], dtype: :f64)
      DataFrame.put(df, column_name, empty_series)
    else
      do_add_hma_with_data(df, price_column, options)
    end
  end

  @doc false
  @spec do_add_hma_with_data(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  defp do_add_hma_with_data(df, price_column, options) do
    # Extract and validate period
    period = validate_hma_period(options)

    # Extract other options with defaults
    column_name = generate_hma_column_name(price_column, options)
    validate = Keyword.get(options, :validate, true)

    # Additional validation if enabled
    if validate and DataFrame.n_rows(df) < period do
      raise ArgumentError, "DataFrame has #{DataFrame.n_rows(df)} rows but period is #{period}"
    end

    # Calculate Hull MA using the standard algorithm
    calculate_hull_ma(df, price_column, period, column_name)
  end

  @doc false
  @spec calculate_hull_ma(DataFrame.t(), atom(), pos_integer(), String.t()) :: DataFrame.t()
  defp calculate_hull_ma(df, price_column, period, column_name) do
    # Extract the series from the DataFrame
    series = DataFrame.pull(df, price_column)
    tensor = Utils.to_tensor(series)

    # Step 1: Calculate WMA with period/2
    half_period = div(period, 2)
    wma_half = Utils.weighted_mean(tensor, half_period, nil)

    # Step 2: Calculate WMA with full period
    wma_full = Utils.weighted_mean(tensor, period, nil)

    # Step 3: Calculate raw Hull MA: 2 * WMA(period/2) - WMA(period)
    raw_hma = Nx.subtract(Nx.multiply(wma_half, 2.0), wma_full)

    # Step 4: Apply WMA with sqrt(period) to the raw HMA for final smoothing
    sqrt_period = max(1, round(:math.sqrt(period)))
    final_hma = Utils.weighted_mean(raw_hma, sqrt_period, nil)

    # Convert back to series
    result_series = Utils.to_series(final_hma, column_name)

    # Add the new column to the DataFrame
    DataFrame.put(df, column_name, result_series)
  end

  @doc false
  @spec validate_hma_period(Keyword.t()) :: pos_integer()
  defp validate_hma_period(options) do
    case Keyword.get(options, :period) do
      nil ->
        raise ArgumentError, "Period is required"

      period when is_integer(period) and period > 0 ->
        period

      period ->
        raise ArgumentError, "Period must be a positive integer, got: #{inspect(period)}"
    end
  end

  @doc """
  Add Double Exponential Moving Average (DEMA) to a DataFrame.

  The Double Exponential Moving Average was developed by Patrick Mulloy to reduce the lag
  inherent in traditional exponential moving averages by applying double smoothing.

  ## Algorithm
  1. Calculate EMA(period) of the price data (EMA1)
  2. Calculate EMA(period) of EMA1 (EMA2)
  3. DEMA = 2 × EMA1 - EMA2

  ## Parameters
  - `df` - Explorer DataFrame containing price data
  - `price_column` - Name of the column containing prices (default: :close)
  - `options` - Keyword list with the following options:
    - `:period` - DEMA period (required, positive integer)
    - `:column_name` - Name for the DEMA column (default: "dema_N" where N is period)
    - `:alpha` - Optional smoothing factor. If not provided, uses 2/(period+1)
    - `:validate` - Whether to validate inputs (default: true)

  ## Returns
  - `DataFrame.t()` - DataFrame with DEMA column added

  ## Raises
  - `ArgumentError` - If inputs are invalid or insufficient data

  ## Examples
      iex> df = Explorer.DataFrame.new(%{close: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]})
      iex> result = Quant.Math.MovingAverages.add_dema!(df, :close, period: 4)
      iex> "close_dema_4" in Map.keys(result.dtypes)
      true

      # DEMA reduces lag compared to traditional EMA
      iex> df = Explorer.DataFrame.new(%{close: [10, 12, 11, 13, 12, 14, 13, 15, 14, 16]})
      iex> result = Quant.Math.MovingAverages.add_dema!(df, :close, period: 4)
      iex> dema_values = Explorer.DataFrame.to_columns(result)["close_dema_4"]
      iex> is_list(dema_values) and length(dema_values) == 10
      true

  ## Mathematical Properties
  - **Reduced Lag**: Responds faster to price changes than traditional EMA
  - **Double Smoothing**: Uses two EMA calculations for improved trend following
  - **Trend Sensitivity**: More sensitive to recent price changes than single EMA
  - **Overshooting**: May overshoot in trending markets due to reduced lag
  """
  @spec add_dema!(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  def add_dema!(df, price_column \\ :close, options \\ []) do
    # Validate column exists
    case Utils.validate_column(df, price_column) do
      :ok ->
        do_add_dema(df, price_column, options)

      {:error, message} ->
        raise ArgumentError, message
    end
  end

  @doc false
  @spec do_add_dema(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  defp do_add_dema(df, price_column, options) do
    # Handle empty DataFrame early
    if DataFrame.n_rows(df) == 0 do
      # Create empty column and return
      column_name = generate_dema_column_name(price_column, options)

      empty_series = Series.from_list([], dtype: :f64)
      DataFrame.put(df, column_name, empty_series)
    else
      do_add_dema_with_data(df, price_column, options)
    end
  end

  @doc false
  @spec do_add_dema_with_data(DataFrame.t(), atom(), Keyword.t()) :: DataFrame.t()
  defp do_add_dema_with_data(df, price_column, options) do
    # Extract and validate period
    period = validate_dema_period(options)

    # Extract other options with defaults
    column_name = generate_dema_column_name(price_column, options)
    alpha = Keyword.get(options, :alpha)
    validate = Keyword.get(options, :validate, true)

    # Validate alpha if provided
    if alpha && (alpha <= 0.0 || alpha > 1.0) do
      raise ArgumentError, "Alpha must be between 0.0 and 1.0, got: #{alpha}"
    end

    # Additional validation if enabled
    if validate and DataFrame.n_rows(df) < period do
      raise ArgumentError, "DataFrame has #{DataFrame.n_rows(df)} rows but period is #{period}"
    end

    # Calculate DEMA using the standard algorithm
    calculate_dema(df, price_column, period, alpha, column_name)
  end

  @doc false
  @spec calculate_dema(DataFrame.t(), atom(), pos_integer(), float() | nil, String.t()) ::
          DataFrame.t()
  defp calculate_dema(df, price_column, period, alpha, column_name) do
    # Extract the series from the DataFrame
    series = DataFrame.pull(df, price_column)
    tensor = Utils.to_tensor(series)
    {n} = Nx.shape(tensor)

    # Step 1: Calculate first EMA of the price data
    alpha_value = alpha || 2.0 / (period + 1)
    ema1 = Utils.exponential_mean(tensor, period, alpha_value)

    # Step 2: For the second EMA, we need to handle the fact that the first EMA
    # has NaN values at the beginning. We calculate EMA2 by taking the valid
    # portion of EMA1 and applying EMA with appropriate positioning

    # Find the first valid index in EMA1 (should be at period-1)
    first_valid_index = period - 1

    ema2 =
      if first_valid_index < n do
        # Extract the valid portion of EMA1 for the second EMA calculation
        valid_ema1 = Nx.slice_along_axis(ema1, first_valid_index, n - first_valid_index, axis: 0)

        # Calculate EMA2 on the valid portion
        ema2_valid = Utils.exponential_mean(valid_ema1, period, alpha_value)

        # Create full-length EMA2 with NaN padding at the beginning
        ema2_base = Nx.broadcast(:nan, {n})

        # The second EMA will have valid values starting from (first_valid_index + period - 1)
        second_valid_start = first_valid_index + period - 1

        if second_valid_start < n do
          # Get the valid portion of EMA2 and place it in the correct position
          ema2_valid_portion =
            Nx.slice_along_axis(ema2_valid, period - 1, n - second_valid_start, axis: 0)

          Nx.put_slice(ema2_base, [second_valid_start], ema2_valid_portion)
        else
          ema2_base
        end
      else
        # Not enough data for any EMA calculation
        Nx.broadcast(:nan, {n})
      end

    # Step 3: Calculate DEMA: 2 * EMA1 - EMA2
    # Only calculate where both EMA1 and EMA2 are valid
    dema_tensor = Nx.subtract(Nx.multiply(ema1, 2.0), ema2)

    # Convert back to series
    result_series = Utils.to_series(dema_tensor, column_name)

    # Add the new column to the DataFrame
    DataFrame.put(df, column_name, result_series)
  end

  @doc false
  @spec validate_dema_period(Keyword.t()) :: pos_integer()
  defp validate_dema_period(options) do
    case Keyword.get(options, :period) do
      nil ->
        raise ArgumentError, "Period is required"

      period when is_integer(period) and period > 0 ->
        period

      period ->
        raise ArgumentError, "Period must be a positive integer, got: #{inspect(period)}"
    end
  end

  # ===== Triple Exponential Moving Average (TEMA) =====

  @doc """
  Add Triple Exponential Moving Average (TEMA) to a DataFrame.

  The Triple Exponential Moving Average extends the DEMA concept by applying
  a third level of exponential smoothing, further reducing lag while maintaining
  smoothness. TEMA is calculated as:

  EMA1 = EMA(price, period)
  EMA2 = EMA(EMA1, period)
  EMA3 = EMA(EMA2, period)
  TEMA = 3 * EMA1 - 3 * EMA2 + EMA3

  This provides even faster response to price changes than DEMA while minimizing
  noise. TEMA requires approximately 3 * (period - 1) observations before producing
  valid values.

  ## Parameters

  - `dataframe` - The Explorer DataFrame
  - `price_column` - The column to calculate TEMA for (default: :close)
  - `options` - Options (keyword list)

  ## Options

  - `:period` - Number of periods for calculation (required, positive integer)
  - `:alpha` - Smoothing factor (optional, overrides period-based calculation)
  - `:column_name` - Name for the TEMA column (default: "tema_N" where N is period)

  ## Examples

      # Basic TEMA with 10-period
      df |> Quant.Math.add_tema!(period: 10)

      # TEMA with custom column name and alpha
      df |> Quant.Math.add_tema!(:high, period: 20, column_name: "tema_high", alpha: 0.15)

  ## Returns

  The DataFrame with the TEMA column added. Raises `ArgumentError` if parameters
  are invalid or if there's insufficient data.

  """
  @spec add_tema!(DataFrame.t(), atom(), keyword()) :: DataFrame.t()
  def add_tema!(df, price_column \\ :close, options \\ []) do
    do_add_tema(df, price_column, options)
  end

  @doc false
  @spec do_add_tema(DataFrame.t(), atom(), keyword()) :: DataFrame.t()
  defp do_add_tema(df, price_column, options) do
    period = validate_tema_period(options)

    # Check if we have enough data (need approximately 2 * period for meaningful TEMA)
    min_required = 2 * period

    case DataFrame.n_rows(df) do
      n when n < min_required ->
        raise ArgumentError,
              "Insufficient data for TEMA calculation. Need at least #{min_required} rows, got #{n}"

      _ ->
        do_add_tema_with_data(df, price_column, options)
    end
  end

  @doc false
  @spec do_add_tema_with_data(DataFrame.t(), atom(), keyword()) :: DataFrame.t()
  defp do_add_tema_with_data(df, price_column, options) do
    period = validate_tema_period(options)
    alpha = Keyword.get(options, :alpha)
    column_name = generate_tema_column_name(price_column, options)

    # Validate that the price column exists
    case Utils.validate_column(df, price_column) do
      :ok -> :ok
      {:error, reason} -> raise ArgumentError, reason
    end

    calculate_tema(df, price_column, period, alpha, column_name)
  end

  @doc false
  @spec calculate_tema(DataFrame.t(), atom(), pos_integer(), float() | nil, String.t()) ::
          DataFrame.t()
  defp calculate_tema(df, price_column, period, alpha, column_name) do
    # Extract the series from the DataFrame
    series = DataFrame.pull(df, price_column)
    tensor = Utils.to_tensor(series)
    {n} = Nx.shape(tensor)

    # Calculate the smoothing factor
    alpha_value = alpha || 2.0 / (period + 1)

    # Step 1: Calculate first EMA of the price data
    ema1 = Utils.exponential_mean(tensor, period, alpha_value)

    # Step 2: Calculate second EMA (EMA of EMA1)
    # We need to handle NaN values properly by working on valid portions
    first_valid_index = period - 1

    ema2 =
      if first_valid_index < n do
        # Extract valid portion of EMA1 (from first_valid_index onwards)
        valid_ema1 = Nx.slice_along_axis(ema1, first_valid_index, n - first_valid_index, axis: 0)

        # Calculate EMA on this valid portion
        ema2_valid = Utils.exponential_mean(valid_ema1, period, alpha_value)

        # Create full-length tensor with NaN padding
        ema2_full = Nx.broadcast(:nan, {n})

        # Place valid EMA2 values starting from the correct position
        second_valid_start = first_valid_index + period - 1

        if second_valid_start < n do
          # Extract only the valid portion of ema2_valid (skip its initial NaN values)
          ema2_to_place =
            Nx.slice_along_axis(ema2_valid, period - 1, n - second_valid_start, axis: 0)

          Nx.put_slice(ema2_full, [second_valid_start], ema2_to_place)
        else
          ema2_full
        end
      else
        Nx.broadcast(:nan, {n})
      end

    # Step 3: Calculate third EMA (EMA of EMA2)
    second_valid_start = first_valid_index + period - 1

    ema3 =
      if second_valid_start < n do
        # Extract valid portion of EMA2
        valid_ema2 =
          Nx.slice_along_axis(ema2, second_valid_start, n - second_valid_start, axis: 0)

        # Calculate EMA on this valid portion
        ema3_valid = Utils.exponential_mean(valid_ema2, period, alpha_value)

        # Create full-length tensor with NaN padding
        ema3_full = Nx.broadcast(:nan, {n})

        # Place valid EMA3 values starting from the correct position
        third_valid_start = second_valid_start + period - 1

        if third_valid_start < n do
          # Extract only the valid portion of ema3_valid
          ema3_to_place =
            Nx.slice_along_axis(ema3_valid, period - 1, n - third_valid_start, axis: 0)

          Nx.put_slice(ema3_full, [third_valid_start], ema3_to_place)
        else
          ema3_full
        end
      else
        Nx.broadcast(:nan, {n})
      end

    # Step 4: Calculate TEMA: 3 * EMA1 - 3 * EMA2 + EMA3
    tema_tensor =
      ema1
      |> Nx.multiply(3.0)
      |> Nx.subtract(Nx.multiply(ema2, 3.0))
      |> Nx.add(ema3)

    # Convert back to series
    result_series = Utils.to_series(tema_tensor, column_name)

    # Add the new column to the DataFrame
    DataFrame.put(df, column_name, result_series)
  end

  @doc false
  @spec validate_tema_period(Keyword.t()) :: pos_integer()
  defp validate_tema_period(options) do
    case Keyword.get(options, :period) do
      nil ->
        raise ArgumentError, "Period is required"

      period when is_integer(period) and period > 0 ->
        period

      period ->
        raise ArgumentError, "Period must be a positive integer, got: #{inspect(period)}"
    end
  end

  # ===== Kaufman Adaptive Moving Average (KAMA) =====

  @doc """
  Add Kaufman Adaptive Moving Average (KAMA) to a DataFrame.

  KAMA is an adaptive moving average that adjusts its smoothing based on market
  conditions. It uses an Efficiency Ratio to determine how much noise is in the
  price movement, applying more smoothing during choppy markets and less smoothing
  during trending markets.

  ## Parameters

  - `dataframe` - The Explorer DataFrame
  - `price_column` - The column to calculate KAMA for (default: :close)
  - `options` - Options (keyword list)

  ## Options

  - `:period` - Number of periods for efficiency ratio calculation (required, positive integer)
  - `:fast_sc` - Fast smoothing constant (default: 2, for fast EMA equivalent)
  - `:slow_sc` - Slow smoothing constant (default: 30, for slow EMA equivalent)
  - `:column_name` - Name for the KAMA column (default: "close_kama_N" where N is period)

  ## Algorithm

  1. **Efficiency Ratio (ER)** = |Price Change| / Sum of |Daily Changes|
  2. **Smoothing Constant (SC)** = [ER × (Fastest SC - Slowest SC) + Slowest SC]²
  3. **KAMA** = Previous KAMA + SC × (Current Price - Previous KAMA)

  The Efficiency Ratio ranges from 0 (very choppy) to 1 (perfectly trending).
  KAMA adapts between the fast and slow smoothing constants based on this ratio.

  ## Examples

      # Basic KAMA with 10-period efficiency ratio
      df |> Quant.Math.add_kama!(:close, period: 10)

      # KAMA with custom fast/slow parameters
      df |> Quant.Math.add_kama!(:close, period: 14, fast_sc: 2, slow_sc: 30)

      # KAMA with custom column name
      df |> Quant.Math.add_kama!(:high, period: 20, column_name: "kama_high")

  ## Returns

  The DataFrame with the KAMA column added. Raises `ArgumentError` if parameters
  are invalid or if there's insufficient data.

  """
  @spec add_kama!(DataFrame.t(), atom(), keyword()) :: DataFrame.t()
  def add_kama!(df, price_column \\ :close, options \\ []) do
    do_add_kama(df, price_column, options)
  end

  @doc false
  @spec do_add_kama(DataFrame.t(), atom(), keyword()) :: DataFrame.t()
  defp do_add_kama(df, price_column, options) do
    period = validate_kama_period(options)

    # Check if we have enough data (need at least period + 1 for KAMA calculation)
    min_required = period + 1

    case DataFrame.n_rows(df) do
      n when n < min_required ->
        raise ArgumentError,
              "Insufficient data for KAMA calculation. Need at least #{min_required} rows, got #{n}"

      _ ->
        do_add_kama_with_data(df, price_column, options)
    end
  end

  @doc false
  @spec do_add_kama_with_data(DataFrame.t(), atom(), keyword()) :: DataFrame.t()
  defp do_add_kama_with_data(df, price_column, options) do
    period = validate_kama_period(options)
    fast_sc = Keyword.get(options, :fast_sc, 2)
    slow_sc = Keyword.get(options, :slow_sc, 30)
    column_name = generate_kama_column_name(price_column, options)

    # Validate fast and slow smoothing constants
    if fast_sc <= 0 or slow_sc <= 0 do
      raise ArgumentError,
            "fast_sc and slow_sc must be positive, got fast_sc: #{fast_sc}, slow_sc: #{slow_sc}"
    end

    if fast_sc >= slow_sc do
      raise ArgumentError,
            "fast_sc must be less than slow_sc, got fast_sc: #{fast_sc}, slow_sc: #{slow_sc}"
    end

    # Validate that the price column exists
    case Utils.validate_column(df, price_column) do
      :ok -> :ok
      {:error, reason} -> raise ArgumentError, reason
    end

    calculate_kama(df, price_column, period, fast_sc, slow_sc, column_name)
  end

  @doc false
  @spec generate_kama_column_name(atom(), Keyword.t()) :: String.t()
  defp generate_kama_column_name(base_column, opts) do
    case Keyword.get(opts, :column_name) do
      nil ->
        period = Keyword.get(opts, :period, "unknown")
        "#{base_column}_kama_#{period}"

      name when is_atom(name) ->
        Atom.to_string(name)

      name when is_binary(name) ->
        name

      other ->
        raise ArgumentError, "column_name must be a string or atom, got: #{inspect(other)}"
    end
  end

  @doc false
  @spec calculate_kama(
          DataFrame.t(),
          atom(),
          pos_integer(),
          pos_integer(),
          pos_integer(),
          String.t()
        ) ::
          DataFrame.t()
  defp calculate_kama(df, price_column, period, fast_sc, slow_sc, column_name) do
    # Extract the series from the DataFrame
    series = DataFrame.pull(df, price_column)
    tensor = Utils.to_tensor(series)
    {n} = Nx.shape(tensor)

    # Convert smoothing constants to smoothing factors (equivalent to EMA alphas)
    fastest_sc = 2.0 / (fast_sc + 1.0)
    slowest_sc = 2.0 / (slow_sc + 1.0)

    # Calculate KAMA step by step
    kama_values = calculate_kama_values(tensor, period, fastest_sc, slowest_sc, n)

    # Convert back to series
    result_series = Utils.to_series(kama_values, column_name)

    # Add the new column to the DataFrame
    DataFrame.put(df, column_name, result_series)
  end

  @doc false
  @spec calculate_kama_values(Nx.Tensor.t(), pos_integer(), float(), float(), pos_integer()) ::
          Nx.Tensor.t()
  defp calculate_kama_values(prices, period, fastest_sc, slowest_sc, _n) do
    # Convert to lists for easier iteration (KAMA requires sequential calculation)
    price_list = Nx.to_list(prices)

    # Calculate KAMA values iteratively (can't be fully vectorized due to dependencies)
    kama_list = calculate_kama_iteratively(price_list, period, fastest_sc, slowest_sc)

    # Convert back to tensor
    Nx.tensor(kama_list, type: :f64)
  end

  @doc false
  @spec calculate_kama_iteratively(list(float()), pos_integer(), float(), float()) ::
          list(float())
  defp calculate_kama_iteratively(prices, period, fastest_sc, slowest_sc) do
    n = length(prices)

    if n <= period do
      List.duplicate(:nan, n)
    else
      do_calculate_kama_iteratively(prices, period, fastest_sc, slowest_sc)
    end
  end

  @spec do_calculate_kama_iteratively(list(float()), pos_integer(), float(), float()) ::
          list(float())
  defp do_calculate_kama_iteratively(prices, period, fastest_sc, slowest_sc) do
    # Calculate initial KAMA (use SMA for first valid value)
    initial_window = Enum.take(prices, period + 1)
    initial_kama = Enum.sum(initial_window) / (period + 1)

    # Calculate KAMA for remaining values
    prices_with_indices = Enum.with_index(prices)

    {_, kama_values} =
      Enum.reduce(prices_with_indices, {initial_kama, []}, fn {_price, i}, {prev_kama, acc} ->
        calculate_kama_at_index(
          prices,
          i,
          period,
          prev_kama,
          acc,
          fastest_sc,
          slowest_sc,
          initial_kama
        )
      end)

    # Reverse to get correct order and take only what we need
    Enum.reverse(kama_values)
  end

  @spec calculate_kama_at_index(
          list(float()),
          non_neg_integer(),
          pos_integer(),
          float(),
          list(float()),
          float(),
          float(),
          float()
        ) :: {float(), list(float())}
  defp calculate_kama_at_index(
         prices,
         i,
         period,
         prev_kama,
         acc,
         fastest_sc,
         slowest_sc,
         initial_kama
       ) do
    cond do
      i < period ->
        # Not enough data yet
        {prev_kama, [:nan | acc]}

      i == period ->
        # First valid KAMA value
        {initial_kama, [initial_kama | acc]}

      true ->
        # Calculate KAMA using efficiency ratio
        window_start = i - period
        window_prices = Enum.slice(prices, window_start, period + 1)

        new_kama = calculate_single_kama(window_prices, prev_kama, fastest_sc, slowest_sc)
        {new_kama, [new_kama | acc]}
    end
  end

  @doc false
  @spec calculate_single_kama(list(float()), float(), float(), float()) :: float()
  defp calculate_single_kama(window_prices, prev_kama, fastest_sc, slowest_sc) do
    # Calculate efficiency ratio
    period_change = abs(List.last(window_prices) - List.first(window_prices))

    # Calculate sum of absolute price changes
    price_changes =
      window_prices
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] -> abs(curr - prev) end)
      |> Enum.sum()

    # Avoid division by zero
    efficiency_ratio = if price_changes == 0.0, do: 0.0, else: period_change / price_changes

    # Calculate smoothing constant
    sc = efficiency_ratio * (fastest_sc - slowest_sc) + slowest_sc
    # Square the smoothing constant
    smoothing_constant = sc * sc

    # Calculate KAMA
    current_price = List.last(window_prices)
    prev_kama + smoothing_constant * (current_price - prev_kama)
  end

  @doc false
  @spec validate_kama_period(Keyword.t()) :: pos_integer()
  defp validate_kama_period(options) do
    case Keyword.get(options, :period) do
      nil ->
        raise ArgumentError, "Period is required"

      period when is_integer(period) and period > 0 ->
        period

      period ->
        raise ArgumentError, "Period must be a positive integer, got: #{inspect(period)}"
    end
  end
end
