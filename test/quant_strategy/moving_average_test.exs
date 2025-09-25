defmodule Quant.Strategy.MovingAverageTest do
  @moduledoc """
  Tests for moving average based trading strategies.
  """

  use ExUnit.Case, async: true
  alias Explorer.DataFrame
  alias Quant.Strategy.MovingAverage

  # Test data with clear trend patterns
  @uptrend_data %{
    close: [100.0, 102.0, 104.0, 106.0, 108.0, 110.0, 112.0, 114.0, 116.0, 118.0]
  }

  describe "sma_crossover/1" do
    test "creates SMA crossover strategy with default parameters" do
      strategy = MovingAverage.sma_crossover()

      assert strategy.type == :sma_crossover
      assert strategy.indicator == :sma
      assert strategy.fast_period == 12
      assert strategy.slow_period == 26
      assert strategy.column == :close
    end

    test "creates SMA crossover strategy with custom parameters" do
      strategy =
        MovingAverage.sma_crossover(
          fast_period: 5,
          slow_period: 10,
          column: :high
        )

      assert strategy.fast_period == 5
      assert strategy.slow_period == 10
      assert strategy.column == :high
    end
  end

  describe "ema_crossover/1" do
    test "creates EMA crossover strategy with default parameters" do
      strategy = MovingAverage.ema_crossover()

      assert strategy.type == :ema_crossover
      assert strategy.indicator == :ema
      assert strategy.fast_period == 12
      assert strategy.slow_period == 26
    end

    test "creates EMA crossover strategy with custom parameters" do
      strategy =
        MovingAverage.ema_crossover(
          fast_period: 8,
          slow_period: 21
        )

      assert strategy.fast_period == 8
      assert strategy.slow_period == 21
    end
  end

  describe "apply_indicators/3" do
    test "applies SMA indicators successfully" do
      df = DataFrame.new(@uptrend_data)
      strategy = MovingAverage.sma_crossover(fast_period: 3, slow_period: 5)

      assert {:ok, result_df} = MovingAverage.apply_indicators(df, strategy)

      # Check that SMA columns were added
      assert "close_sma_3" in DataFrame.names(result_df)
      assert "close_sma_5" in DataFrame.names(result_df)

      # Verify SMA values are reasonable
      sma_3 = DataFrame.pull(result_df, "close_sma_3") |> Explorer.Series.to_list()
      sma_5 = DataFrame.pull(result_df, "close_sma_5") |> Explorer.Series.to_list()

      # First few values should be NaN due to insufficient data
      first_sma_3 = Enum.at(sma_3, 0)
      first_sma_5 = Enum.at(sma_5, 0)
      # Check for nil or NaN (represented as :nan atom)
      assert is_nil(first_sma_3) or first_sma_3 == :nan
      assert is_nil(first_sma_5) or first_sma_5 == :nan

      # Later values should be numbers
      assert is_number(Enum.at(sma_3, -1))
      assert is_number(Enum.at(sma_5, -1))
    end

    test "applies EMA indicators successfully" do
      df = DataFrame.new(@uptrend_data)
      strategy = MovingAverage.ema_crossover(fast_period: 3, slow_period: 5)

      assert {:ok, result_df} = MovingAverage.apply_indicators(df, strategy)

      # Check that EMA columns were added
      assert "close_ema_3" in DataFrame.names(result_df)
      assert "close_ema_5" in DataFrame.names(result_df)
    end

    test "handles unsupported indicator type" do
      df = DataFrame.new(@uptrend_data)

      invalid_strategy = %{
        type: :sma_crossover,
        indicator: :invalid_ma,
        fast_period: 3,
        slow_period: 5,
        column: :close
      }

      assert {:error, {:indicator_application_failed, _}} =
               MovingAverage.apply_indicators(df, invalid_strategy)
    end
  end

  describe "validate_dataframe/2" do
    test "validates DataFrame with required columns" do
      df = DataFrame.new(@uptrend_data)
      strategy = MovingAverage.sma_crossover()

      assert :ok = MovingAverage.validate_dataframe(df, strategy)
    end

    test "fails validation for missing columns" do
      df = DataFrame.new(%{high: [100.0, 101.0, 102.0]})
      strategy = MovingAverage.sma_crossover(column: :close)

      assert {:error, {:missing_columns, ["close"]}} =
               MovingAverage.validate_dataframe(df, strategy)
    end
  end

  describe "get_indicator_columns/1" do
    test "returns correct column names for SMA strategy" do
      strategy = MovingAverage.sma_crossover(fast_period: 5, slow_period: 10)
      columns = MovingAverage.get_indicator_columns(strategy)

      assert "close_sma_5" in columns
      assert "close_sma_10" in columns
      assert length(columns) == 2
    end

    test "returns correct column names for EMA strategy" do
      strategy = MovingAverage.ema_crossover(fast_period: 8, slow_period: 21)
      columns = MovingAverage.get_indicator_columns(strategy)

      assert "close_ema_8" in columns
      assert "close_ema_21" in columns
    end

    test "handles custom column name" do
      strategy =
        MovingAverage.sma_crossover(
          fast_period: 5,
          slow_period: 10,
          column: :high
        )

      columns = MovingAverage.get_indicator_columns(strategy)

      assert "high_sma_5" in columns
      assert "high_sma_10" in columns
    end
  end
end
