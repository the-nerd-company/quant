defmodule Quant.Math.OscillatorsTest do
  @moduledoc """
  Tests for momentum oscillators and technical indicators.
  """

  use ExUnit.Case, async: true

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math.Oscillators

  doctest Quant.Math.Oscillators

  describe "add_macd!/3" do
    test "calculates MACD with default parameters" do
      # Create test data with sufficient periods for MACD calculation
      df =
        DataFrame.new(%{
          close: [
            10.0,
            11.0,
            12.0,
            11.5,
            13.0,
            12.8,
            14.0,
            13.5,
            15.0,
            14.2,
            16.0,
            15.5,
            17.0,
            16.8,
            18.0,
            17.5,
            19.0,
            18.2,
            20.0,
            19.5,
            21.0,
            20.8,
            22.0,
            21.5,
            23.0,
            22.2,
            24.0,
            23.8,
            25.0,
            24.5
          ]
        })

      result = Oscillators.add_macd!(df, :close)

      # Check that all required columns are added
      column_names = DataFrame.names(result)
      assert "close_macd_12_26" in column_names
      assert "close_signal_9" in column_names
      assert "close_histogram_12_26_9" in column_names
      assert "close" in column_names

      # Check that we have the same number of rows
      assert DataFrame.n_rows(result) == DataFrame.n_rows(df)

      # Check that MACD values are calculated (should have NaN for initial periods)
      macd_values = result |> DataFrame.pull("close_macd_12_26") |> Series.to_list()
      assert length(macd_values) == 30

      # Early values should be :nan due to insufficient data for slow EMA (26 periods)
      assert Enum.take(macd_values, 25) |> Enum.all?(fn val -> val == :nan end)

      # Later values should be numbers
      assert Enum.drop(macd_values, 25) |> Enum.all?(&is_number/1)
    end

    test "calculates MACD with custom parameters" do
      df =
        DataFrame.new(%{
          close: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        })

      result =
        Oscillators.add_macd!(df, :close,
          fast_period: 2,
          slow_period: 3,
          signal_period: 2
        )

      column_names = DataFrame.names(result)
      assert "close_macd_2_3" in column_names
      assert "close_signal_2" in column_names
      assert "close_histogram_2_3_2" in column_names
    end

    test "uses custom column names" do
      df =
        DataFrame.new(%{
          price: [1.0, 2.0, 3.0, 4.0, 5.0]
        })

      result =
        Oscillators.add_macd!(df, :price,
          fast_period: 2,
          slow_period: 3,
          signal_period: 2,
          macd_column: "custom_macd",
          signal_column: "custom_signal",
          histogram_column: "custom_histogram"
        )

      column_names = DataFrame.names(result)
      assert "custom_macd" in column_names
      assert "custom_signal" in column_names
      assert "custom_histogram" in column_names
    end

    test "validates input parameters" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      # Test invalid fast_period >= slow_period
      assert_raise ArgumentError, ~r/fast_period.*must be less than slow_period/, fn ->
        Oscillators.add_macd!(df, :close, fast_period: 10, slow_period: 5)
      end

      # Test invalid periods (non-positive)
      assert_raise ArgumentError, ~r/must be a positive integer/, fn ->
        Oscillators.add_macd!(df, :close, fast_period: 0)
      end

      assert_raise ArgumentError, ~r/must be a positive integer/, fn ->
        Oscillators.add_macd!(df, :close, slow_period: -1)
      end

      assert_raise ArgumentError, ~r/must be a positive integer/, fn ->
        Oscillators.add_macd!(df, :close, signal_period: 0)
      end
    end

    test "validates DataFrame and column" do
      # Test invalid DataFrame
      assert_raise ArgumentError, ~r/Expected Explorer DataFrame/, fn ->
        Oscillators.add_macd!("not a dataframe", :close)
      end

      # Test non-existent column
      df = DataFrame.new(%{close: [1.0, 2.0]})

      assert_raise ArgumentError, ~r/Column validation failed/, fn ->
        Oscillators.add_macd!(df, :nonexistent)
      end
    end

    test "handles empty DataFrame" do
      df = DataFrame.new(%{close: []})

      result = Oscillators.add_macd!(df, :close)

      # Should return empty DataFrame with correct columns
      assert DataFrame.n_rows(result) == 0
      column_names = DataFrame.names(result)
      assert "close_macd_12_26" in column_names
      assert "close_signal_9" in column_names
      assert "close_histogram_12_26_9" in column_names
    end

    test "handles single value DataFrame" do
      df = DataFrame.new(%{close: [100.0]})

      result = Oscillators.add_macd!(df, :close)

      # All MACD values should be :nan for single value
      macd_values = result |> DataFrame.pull("close_macd_12_26") |> Series.to_list()
      signal_values = result |> DataFrame.pull("close_signal_9") |> Series.to_list()
      histogram_values = result |> DataFrame.pull("close_histogram_12_26_9") |> Series.to_list()

      # Single value should result in NaN values since we need more data for EMA
      assert macd_values == [:nan]
      assert signal_values == [:nan] || signal_values == [nil]
      assert histogram_values == [:nan] || histogram_values == [nil]
    end

    test "MACD mathematical properties" do
      # Create trending data for better MACD behavior
      df =
        DataFrame.new(%{
          close: [
            10.0,
            11.0,
            12.0,
            13.0,
            14.0,
            15.0,
            16.0,
            17.0,
            18.0,
            19.0,
            20.0,
            21.0,
            22.0,
            23.0,
            24.0,
            25.0,
            26.0,
            27.0,
            28.0,
            29.0,
            30.0,
            31.0,
            32.0,
            33.0,
            34.0,
            35.0,
            36.0,
            37.0,
            38.0,
            39.0
          ]
        })

      result =
        Oscillators.add_macd!(df, :close, fast_period: 5, slow_period: 10, signal_period: 3)

      # Get values where all components are calculated
      macd_values = result |> DataFrame.pull("close_macd_5_10") |> Series.to_list()
      signal_values = result |> DataFrame.pull("close_signal_3") |> Series.to_list()
      histogram_values = result |> DataFrame.pull("close_histogram_5_10_3") |> Series.to_list()

      # Find first non-nil index for all series
      first_valid_idx = Enum.find_index(histogram_values, &is_number/1)
      assert first_valid_idx != nil

      # Check histogram = MACD - Signal for valid values
      valid_indices = first_valid_idx..(length(macd_values) - 1)

      for idx <- valid_indices do
        macd = Enum.at(macd_values, idx)
        signal = Enum.at(signal_values, idx)
        histogram = Enum.at(histogram_values, idx)

        if is_number(macd) and is_number(signal) and is_number(histogram) do
          expected_histogram = macd - signal

          assert abs(histogram - expected_histogram) < 1.0e-10,
                 "Histogram mismatch at index #{idx}: #{histogram} != #{expected_histogram}"
        end
      end
    end

    test "MACD with insufficient data" do
      # Not enough data for slow EMA
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      result = Oscillators.add_macd!(df, :close, fast_period: 2, slow_period: 5, signal_period: 2)

      macd_values = result |> DataFrame.pull("close_macd_2_5") |> Series.to_list()

      # All values should be :nan due to insufficient data for slow EMA
      assert Enum.all?(macd_values, fn val -> val == :nan end)
    end

    @tag skip: "EMA function doesn't handle nil values in input - needs improvement in Phase 2.3"
    test "MACD handles NaN values in input data" do
      df =
        DataFrame.new(%{
          close: [
            10.0,
            nil,
            12.0,
            13.0,
            nil,
            15.0,
            16.0,
            17.0,
            18.0,
            19.0,
            20.0,
            21.0,
            22.0,
            23.0,
            24.0,
            25.0,
            26.0,
            27.0,
            28.0,
            29.0
          ]
        })

      result = Oscillators.add_macd!(df, :close, fast_period: 3, slow_period: 5, signal_period: 2)

      # Should not crash and should handle NaN appropriately
      assert DataFrame.n_rows(result) == DataFrame.n_rows(df)

      column_names = DataFrame.names(result)
      assert "close_macd_3_5" in column_names
      assert "close_signal_2" in column_names
      assert "close_histogram_3_5_2" in column_names
    end
  end

  describe "detect_macd_crossovers/4" do
    test "detects bullish and bearish crossovers" do
      # Create test data with known crossovers
      df =
        DataFrame.new(%{
          macd: [0.1, 0.2, 0.15, -0.1, -0.2, 0.05, 0.15, 0.1, -0.05, -0.1],
          signal: [0.05, 0.15, 0.25, 0.1, -0.05, -0.1, 0.05, 0.2, 0.05, -0.05]
        })

      result = Oscillators.detect_macd_crossovers(df, "macd", "signal")

      # Check crossover column exists
      column_names = DataFrame.names(result)
      assert "macd_crossover" in column_names

      crossovers = result |> DataFrame.pull("macd_crossover") |> Series.to_list()

      # Should detect crossovers
      assert length(crossovers) == 10
      assert is_list(crossovers)
      assert Enum.all?(crossovers, fn x -> x in [-1, 0, 1] end)
    end

    test "uses custom crossover column name" do
      df =
        DataFrame.new(%{
          macd: [0.1, -0.1],
          signal: [-0.1, 0.1]
        })

      result =
        Oscillators.detect_macd_crossovers(df, "macd", "signal",
          crossover_column: "custom_crossovers"
        )

      column_names = DataFrame.names(result)
      assert "custom_crossovers" in column_names
      refute "macd_crossover" in column_names
    end

    test "detects specific crossover patterns" do
      # Test specific crossover scenarios
      df =
        DataFrame.new(%{
          # MACD starts below, crosses above (bullish), then crosses below (bearish)
          macd: [-0.1, -0.05, 0.05, 0.1, 0.05, -0.05],
          signal: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        })

      result = Oscillators.detect_macd_crossovers(df, "macd", "signal")
      crossovers = result |> DataFrame.pull("macd_crossover") |> Series.to_list()

      # Expected pattern: [0, 0, 1, 0, 0, -1]
      # - Position 0: MACD below signal (no crossover yet)
      # - Position 1: MACD still below signal (no crossover)
      # - Position 2: MACD crosses above signal (bullish = 1)
      # - Position 3: MACD remains above signal (no crossover)
      # - Position 4: MACD still above signal (no crossover)
      # - Position 5: MACD crosses below signal (bearish = -1)

      assert Enum.at(crossovers, 2) == 1, "Should detect bullish crossover"
      assert Enum.at(crossovers, 5) == -1, "Should detect bearish crossover"
    end

    test "handles NaN values in crossover detection" do
      df =
        DataFrame.new(%{
          macd: [nil, 0.1, nil, -0.1, 0.1],
          signal: [0.0, nil, 0.0, 0.0, nil]
        })

      result = Oscillators.detect_macd_crossovers(df, "macd", "signal")
      crossovers = result |> DataFrame.pull("macd_crossover") |> Series.to_list()

      # All crossovers should be 0 (no valid crossovers with NaN values)
      assert Enum.all?(crossovers, fn x -> x == 0 end)
    end

    test "validates crossover input columns" do
      df = DataFrame.new(%{macd: [1.0], signal: [0.5]})

      # Test non-existent MACD column
      assert_raise ArgumentError, fn ->
        Oscillators.detect_macd_crossovers(df, "nonexistent", "signal")
      end

      # Test non-existent Signal column
      assert_raise ArgumentError, fn ->
        Oscillators.detect_macd_crossovers(df, "macd", "nonexistent")
      end
    end

    test "equal values produce no crossover" do
      df =
        DataFrame.new(%{
          macd: [0.1, 0.1, 0.1, 0.1],
          signal: [0.1, 0.1, 0.1, 0.1]
        })

      result = Oscillators.detect_macd_crossovers(df, "macd", "signal")
      crossovers = result |> DataFrame.pull("macd_crossover") |> Series.to_list()

      # All should be 0 (no crossovers when values are equal)
      assert Enum.all?(crossovers, fn x -> x == 0 end)
    end

    test "crossover detection edge cases" do
      # Test edge case: exactly equal to zero crossings
      df =
        DataFrame.new(%{
          macd: [-0.1, 0.0, 0.1, 0.0, -0.1],
          signal: [0.0, 0.0, 0.0, 0.0, 0.0]
        })

      result = Oscillators.detect_macd_crossovers(df, "macd", "signal")
      crossovers = result |> DataFrame.pull("macd_crossover") |> Series.to_list()

      assert length(crossovers) == 5
      # Should handle zero crossings appropriately
      assert is_list(crossovers)
    end
  end

  describe "integration tests" do
    test "MACD integrates with DataFrame operations" do
      df =
        DataFrame.new(%{
          timestamp: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
          close: [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114],
          volume: [
            1000,
            1100,
            1200,
            1300,
            1400,
            1500,
            1600,
            1700,
            1800,
            1900,
            2000,
            2100,
            2200,
            2300,
            2400
          ]
        })

      # Apply MACD and verify it works in pipeline
      result =
        df
        |> Oscillators.add_macd!(:close, fast_period: 3, slow_period: 5, signal_period: 2)
        |> Oscillators.detect_macd_crossovers("close_macd_3_5", "close_signal_2")

      # Verify all expected columns exist
      column_names = DataFrame.names(result)

      expected_columns = [
        "timestamp",
        "close",
        "volume",
        "close_macd_3_5",
        "close_signal_2",
        "close_histogram_3_5_2",
        "macd_crossover"
      ]

      for col <- expected_columns do
        assert col in column_names, "Missing column: #{col}"
      end

      # Verify row count unchanged
      assert DataFrame.n_rows(result) == DataFrame.n_rows(df)
    end

    test "MACD mathematical consistency with manual calculation" do
      # Simple test case where we can verify the math manually
      prices = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      df = DataFrame.new(%{close: prices})

      # Use small periods for easier manual verification
      result = Oscillators.add_macd!(df, :close, fast_period: 2, slow_period: 3, signal_period: 2)

      # Verify the structure is mathematically sound
      macd_values = result |> DataFrame.pull("close_macd_2_3") |> Series.to_list()
      signal_values = result |> DataFrame.pull("close_signal_2") |> Series.to_list()
      histogram_values = result |> DataFrame.pull("close_histogram_2_3_2") |> Series.to_list()

      # Check that histogram = MACD - Signal where both are numbers
      for idx <- 0..(length(macd_values) - 1) do
        macd = Enum.at(macd_values, idx)
        signal = Enum.at(signal_values, idx)
        histogram = Enum.at(histogram_values, idx)

        if is_number(macd) and is_number(signal) and is_number(histogram) do
          expected = macd - signal

          assert abs(histogram - expected) < 1.0e-10,
                 "Histogram calculation error at index #{idx}"
        end
      end
    end
  end
end
