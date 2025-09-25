defmodule Quant.Math do
  @moduledoc """
  Mathematical utilities for financial data analysis.

  This module serves as the main entry point for technical indicators and
  mathematical operations that work with Explorer DataFrames. All operations
  are optimized using NX tensors internally while maintaining a DataFrame-first API.

  ## Architecture

  The module is organized into specialized submodules:

  - `Quant.Math.MovingAverages` - Various moving average indicators (SMA, EMA, WMA, etc.)
  - `Quant.Math.Oscillators` - Momentum and oscillator indicators (MACD, RSI, etc.)
  - `Quant.Math.Trend` - Trend analysis indicators (ADX, Parabolic SAR, etc.) - *Coming soon*
  - `Quant.Math.Volatility` - Volatility indicators (Bollinger Bands, ATR, etc.) - *Coming soon*
  - `Quant.Math.Volume` - Volume-based indicators (OBV, VWAP, MFI, etc.) - *Coming soon*
  - `Quant.Math.Utils` - Shared utility functions for mathematical operations

  ## Features

  - **DataFrame-first API** that supports method chaining
  - **Efficient rolling operations** using NX tensors internally
  - **Proper handling of NaN/missing data** according to financial standards
  - **Configurable column naming and validation**
  - **Modular architecture** for easy extension and maintenance

  ## Usage

  All functions can be called directly from this module through delegation:

      # Simple Moving Average
      df |> Quant.Math.add_sma!(:close, period: 20)

      # Method chaining for multiple indicators
      df
      |> Quant.Math.add_sma!(:close, period: 20, name: "sma_20")
      |> Quant.Math.add_sma!(:close, period: 50, name: "sma_50")

  Or accessed directly through the specialized submodules:

      # Direct access to MovingAverages module
      df |> Quant.Math.MovingAverages.add_sma!(:close, period: 20)

  ## Adding New Indicators

  When adding new indicators, follow this pattern:

  1. Create or extend the appropriate submodule
  2. Add a delegation in this main module
  3. Follow the consistent API pattern with DataFrame input/output
  4. Use shared utilities from `Quant.Math.Utils`
  """

  # Type definitions for consistency across modules
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

  #
  # Moving Averages Delegation
  #

  @doc """
  Add Simple Moving Average (SMA) to a DataFrame.

  Delegates to `Quant.Math.MovingAverages.add_sma!/3`.

  See `Quant.Math.MovingAverages.add_sma!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.add_sma!(df, :close, period: 3)
      iex> "close_sma_3" in Map.keys(result.dtypes)
      true
  """
  defdelegate add_sma!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  @doc """
  Add Exponential Moving Average (EMA) to a DataFrame.

  Delegates to `Quant.Math.MovingAverages.add_ema!/3`.

  See `Quant.Math.MovingAverages.add_ema!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.add_ema!(df, :close, period: 3)
      iex> "close_ema_3" in Map.keys(result.dtypes)
      true
  """
  defdelegate add_ema!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  @doc """
  Add Weighted Moving Average (WMA) to a DataFrame.

  Delegates to `Quant.Math.MovingAverages.add_wma!/3`.

  See `Quant.Math.MovingAverages.add_wma!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [10, 12, 14, 16, 18, 20]})
      iex> result = Quant.Math.add_wma!(df, :close, period: 3)
      iex> "close_wma_3" in Map.keys(result.dtypes)
      true
  """
  defdelegate add_wma!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  @doc """
  Add Hull Moving Average (HMA) to a DataFrame.

  Delegates to `Quant.Math.MovingAverages.add_hma!/3`.

  See `Quant.Math.MovingAverages.add_hma!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]})
      iex> result = Quant.Math.add_hma!(df, :close, period: 4)
      iex> "close_hma_4" in Map.keys(result.dtypes)
      true
  """
  defdelegate add_hma!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  @doc """
  Add Double Exponential Moving Average (DEMA) to a DataFrame.

  Delegates to `Quant.Math.MovingAverages.add_dema!/3`.

  See `Quant.Math.MovingAverages.add_dema!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]})
      iex> result = Quant.Math.add_dema!(df, :close, period: 4)
      iex> "close_dema_4" in Map.keys(result.dtypes)
      true
  """
  defdelegate add_dema!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  @doc """
  Add Triple Exponential Moving Average (TEMA) to a DataFrame.

  Delegates to `Quant.Math.MovingAverages.add_tema!/3`.

  See `Quant.Math.MovingAverages.add_tema!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]})
      iex> result = Quant.Math.add_tema!(df, :close, period: 3)
      iex> "close_tema_3" in Map.keys(result.dtypes)
      true
  """
  defdelegate add_tema!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  @doc """
  Add Kaufman Adaptive Moving Average (KAMA) to a DataFrame.

  Delegates to `Quant.Math.MovingAverages.add_kama!/3`.

  See `Quant.Math.MovingAverages.add_kama!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]})
      iex> result = Quant.Math.add_kama!(df, :close, period: 10)
      iex> "close_kama_10" in Map.keys(result.dtypes)
      true
  """
  defdelegate add_kama!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  @doc """
  Analyze moving average results in a DataFrame.

  Delegates to `Quant.Math.MovingAverages.analyze_ma_results!/2`.

  This helper function provides insights into moving average calculations,
  especially useful for understanding NaN values that appear before
  sufficient data points are available.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})
      iex> result = Quant.Math.add_sma!(df, :close, period: 3)
      iex> info = Quant.Math.analyze_ma_results!(result, "close_sma_3")
      iex> info.nan_count
      2
  """
  defdelegate analyze_ma_results!(dataframe, column), to: Quant.Math.MovingAverages

  #
  # Oscillators Delegation
  #

  @doc """
  Add MACD (Moving Average Convergence Divergence) to a DataFrame.

  MACD is a trend-following momentum indicator that shows the relationship between
  two moving averages of a security's price. Calculates MACD line, Signal line, and Histogram.

  Delegates to `Quant.Math.Oscillators.add_macd!/3`.

  See `Quant.Math.Oscillators.add_macd!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0, 29.0]})
      iex> result = Quant.Math.add_macd!(df, :close, fast_period: 5, slow_period: 8, signal_period: 3)
      iex> column_names = Explorer.DataFrame.names(result)
      iex> "close_macd_5_8" in column_names and "close_signal_3" in column_names
      true
  """
  defdelegate add_macd!(dataframe, column, opts \\ []), to: Quant.Math.Oscillators

  @doc """
  Detect MACD crossovers in a DataFrame.

  Identifies bullish and bearish crossovers between MACD line and Signal line.

  Delegates to `Quant.Math.Oscillators.detect_macd_crossovers/4`.

  See `Quant.Math.Oscillators.detect_macd_crossovers/4` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{macd: [0.1, -0.1], signal: [-0.1, 0.1]})
      iex> result = Quant.Math.detect_macd_crossovers(df, "macd", "signal")
      iex> "macd_crossover" in Explorer.DataFrame.names(result)
      true
  """
  defdelegate detect_macd_crossovers(dataframe, macd_column, signal_column, opts \\ []),
    to: Quant.Math.Oscillators

  @doc """
  Add RSI (Relative Strength Index) to a DataFrame.

  RSI is a momentum oscillator that measures the speed and change of price movements.
  It oscillates between 0 and 100 and is typically used to identify overbought and
  oversold conditions in a security.

  Delegates to `Quant.Math.Oscillators.add_rsi!/3`.

  See `Quant.Math.Oscillators.add_rsi!/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{close: [44.0, 44.3, 44.1, 44.2, 44.5, 43.4, 44.0, 44.25, 44.8, 45.1, 45.4, 45.8, 46.0, 45.9, 45.2]})
      iex> result = Quant.Math.add_rsi!(df, :close, period: 14)
      iex> "close_rsi_14" in Explorer.DataFrame.names(result)
      true
  """
  defdelegate add_rsi!(dataframe, column, opts \\ []), to: Quant.Math.Oscillators

  @doc """
  Identify RSI overbought and oversold conditions.

  Analyzes RSI values to identify potential trading signals based on traditional
  overbought (>70) and oversold (<30) levels.

  Delegates to `Quant.Math.Oscillators.rsi_signals/3`.

  See `Quant.Math.Oscillators.rsi_signals/3` for detailed documentation.

  ## Quick Example

      iex> df = Explorer.DataFrame.new(%{rsi: [20, 40, 60, 80, 50, 25, 75]})
      iex> result = Quant.Math.rsi_signals(df, "rsi")
      iex> "rsi_signal" in Explorer.DataFrame.names(result)
      true
  """
  defdelegate rsi_signals(dataframe, rsi_column, opts \\ []), to: Quant.Math.Oscillators

  #
  # Future delegations will be added here as modules are implemented
  #

  # @doc """
  # Add Exponential Moving Average (EMA) to a DataFrame.
  #
  # Delegates to `Quant.Math.MovingAverages.add_ema!/3`.
  #
  # *Coming soon in Phase 1.3*
  # """
  # defdelegate add_ema!(dataframe, column, opts \\ []), to: Quant.Math.MovingAverages

  # @doc """
  # Add MACD (Moving Average Convergence Divergence) to a DataFrame.
  #
  # Delegates to `Quant.Math.Trend.add_macd/3`.
  #
  # *Coming soon in Phase 2.1*
  # """
  # defdelegate add_macd(dataframe, column, opts \\ []), to: Quant.Math.Trend

  # @doc """
  # Add RSI (Relative Strength Index) to a DataFrame.
  #
  # Delegates to `Quant.Math.Oscillators.add_rsi/3`.
  #
  # *Coming soon in Phase 2.2*
  # """
  # defdelegate add_rsi(dataframe, column, opts \\ []), to: Quant.Math.Oscillators
end
