defmodule Quant.Math.WMATest do
  @moduledoc """
  Test module for Weighted Moving Average (WMA) functionality.
  """
  use ExUnit.Case, async: true
  alias Explorer.DataFrame
  alias Quant.Math

  describe "Weighted Moving Average (WMA)" do
    test "calculates WMA with default linear weights" do
      # Test data: [1, 2, 3, 4, 5, 6]
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]})

      result = Math.add_wma!(df, :close, period: 3)
      values = DataFrame.pull(result, "close_wma_3") |> Explorer.Series.to_list()

      # Manual calculation for period 3 with linear weights [1, 2, 3]:
      # Position 2 (index 2): (1×1 + 2×2 + 3×3) / (1+2+3) = (1+4+9)/6 = 14/6 ≈ 2.333
      # Position 3 (index 3): (2×1 + 3×2 + 4×3) / (1+2+3) = (2+6+12)/6 = 20/6 ≈ 3.333
      # Position 4 (index 4): (3×1 + 4×2 + 5×3) / (1+2+3) = (3+8+15)/6 = 26/6 ≈ 4.333
      # Position 5 (index 5): (4×1 + 5×2 + 6×3) / (1+2+3) = (4+10+18)/6 = 32/6 ≈ 5.333

      assert length(values) == 6
      # First 2 values are NaN
      assert Enum.take(values, 2) |> Enum.all?(&(&1 == :nan))

      # Check calculated values with tolerance
      [_, _, wma1, wma2, wma3, wma4] = values
      assert_in_delta wma1, 14.0 / 6.0, 1.0e-10
      assert_in_delta wma2, 20.0 / 6.0, 1.0e-10
      assert_in_delta wma3, 26.0 / 6.0, 1.0e-10
      assert_in_delta wma4, 32.0 / 6.0, 1.0e-10
    end

    test "calculates WMA with custom equal weights (equivalent to SMA)" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]})

      # Use equal weights [1, 1, 1] - should give same result as SMA
      result = Math.add_wma!(df, :close, period: 3, weights: [1, 1, 1])
      values = DataFrame.pull(result, "close_wma_3") |> Explorer.Series.to_list()

      # With equal weights, WMA = SMA
      # Position 2: (1+2+3)/3 = 2.0
      # Position 3: (2+3+4)/3 = 3.0
      # Position 4: (3+4+5)/3 = 4.0
      # Position 5: (4+5+6)/3 = 5.0

      [_, _, wma1, wma2, wma3, wma4] = values
      assert_in_delta wma1, 2.0, 1.0e-10
      assert_in_delta wma2, 3.0, 1.0e-10
      assert_in_delta wma3, 4.0, 1.0e-10
      assert_in_delta wma4, 5.0, 1.0e-10
    end

    test "calculates WMA with custom column name" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      result = Math.add_wma!(df, :close, period: 3, column_name: :my_wma)

      assert "my_wma" in DataFrame.names(result)
      refute "close_wma_3" in DataFrame.names(result)
    end

    test "handles insufficient data correctly" do
      # Only 2 data points
      df = DataFrame.new(%{close: [1.0, 2.0]})

      result = Math.add_wma!(df, :close, period: 3, validate: false)
      values = DataFrame.pull(result, "close_wma_3") |> Explorer.Series.to_list()

      # All values should be NaN because we need 3 points for period 3
      assert Enum.all?(values, &(&1 == :nan))
    end

    test "handles empty DataFrame" do
      df = DataFrame.new(%{close: []})

      result = Math.add_wma!(df, :close, period: 3, validate: false)
      values = DataFrame.pull(result, "close_wma_3") |> Explorer.Series.to_list()

      assert values == []
    end

    test "validates required parameters" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0]})

      # Missing period
      assert_raise ArgumentError, "Period is required", fn ->
        Math.add_wma!(df, :close, [])
      end

      # Invalid period (zero)
      assert_raise ArgumentError, "Period must be a positive integer, got: 0", fn ->
        Math.add_wma!(df, :close, period: 0)
      end

      # Invalid period (negative)
      assert_raise ArgumentError, "Period must be a positive integer, got: -1", fn ->
        Math.add_wma!(df, :close, period: -1)
      end
    end

    test "validates DataFrame and column existence" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      # Non-existent column
      assert_raise ArgumentError, "Column :price not found in DataFrame", fn ->
        Math.add_wma!(df, :price, period: 2)
      end
    end

    test "validates custom weights" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      # Weights length mismatch
      assert_raise ArgumentError, "Weight vector length 2 must match period 3", fn ->
        Math.add_wma!(df, :close, period: 3, weights: [1, 2])
      end
    end

    test "handles custom weights with different distributions" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]})

      # Reverse linear weights [3, 2, 1] - older prices get more weight
      result = Math.add_wma!(df, :close, period: 3, weights: [3, 2, 1])
      values = DataFrame.pull(result, "close_wma_3") |> Explorer.Series.to_list()

      # Manual calculation:
      # Position 2: (1×3 + 2×2 + 3×1) / (3+2+1) = (3+4+3)/6 = 10/6
      # Position 3: (2×3 + 3×2 + 4×1) / (3+2+1) = (6+6+4)/6 = 16/6

      [_, _, wma1, wma2, _, _] = values
      assert_in_delta wma1, 10.0 / 6.0, 1.0e-10
      assert_in_delta wma2, 16.0 / 6.0, 1.0e-10
    end

    test "supports method chaining" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]})

      df_with_sma = Math.add_sma!(df, :close, period: 3)
      result = Math.add_wma!(df_with_sma, :close, period: 3)

      # Should have both SMA and WMA columns
      assert "close_sma_3" in DataFrame.names(result)
      assert "close_wma_3" in DataFrame.names(result)
    end

    test "delegation through main Quant.Math module" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      # Test that delegation works
      result1 = Math.add_wma!(df, :close, period: 3)
      result2 = Math.MovingAverages.add_wma!(df, :close, period: 3)

      # Results should be identical
      values1 = DataFrame.pull(result1, "close_wma_3") |> Explorer.Series.to_list()
      values2 = DataFrame.pull(result2, "close_wma_3") |> Explorer.Series.to_list()

      assert values1 == values2
    end
  end

  describe "WMA edge cases" do
    test "handles single data point" do
      df = DataFrame.new(%{close: [100.0]})

      result = Math.add_wma!(df, :close, period: 1)
      values = DataFrame.pull(result, "close_wma_1") |> Explorer.Series.to_list()

      # With period 1, WMA should equal the original value
      assert values == [100.0]
    end

    test "handles very large periods gracefully" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      result = Math.add_wma!(df, :close, period: 1000, validate: false)
      values = DataFrame.pull(result, "close_wma_1000") |> Explorer.Series.to_list()

      # All values should be NaN
      assert Enum.all?(values, &(&1 == :nan))
    end

    test "different price columns work correctly" do
      df =
        DataFrame.new(%{
          open: [1.0, 2.0, 3.0, 4.0, 5.0],
          high: [1.5, 2.5, 3.5, 4.5, 5.5],
          low: [0.5, 1.5, 2.5, 3.5, 4.5],
          close: [1.2, 2.2, 3.2, 4.2, 5.2]
        })

      # Test WMA on different columns
      temp_result = Math.add_wma!(df, :open, period: 3, column_name: :wma_open)
      result = Math.add_wma!(temp_result, :high, period: 3, column_name: :wma_high)

      assert "wma_open" in DataFrame.names(result)
      assert "wma_high" in DataFrame.names(result)

      # Values should be different for different source columns
      wma_open = DataFrame.pull(result, :wma_open) |> Explorer.Series.to_list()
      wma_high = DataFrame.pull(result, :wma_high) |> Explorer.Series.to_list()

      refute wma_open == wma_high
    end

    test "real-world price data example" do
      # Simulate realistic stock price data
      prices = [100.0, 102.5, 101.3, 103.7, 105.2, 104.8, 106.1, 107.9, 106.5, 108.3]
      df = DataFrame.new(%{close: prices})

      result = Math.add_wma!(df, :close, period: 5)
      values = DataFrame.pull(result, "close_wma_5") |> Explorer.Series.to_list()

      # Check that we get reasonable values
      assert length(values) == 10
      # First 4 values are NaN
      assert Enum.take(values, 4) |> Enum.all?(&(&1 == :nan))

      # Valid WMA values should be within reasonable range of the input prices
      valid_values = Enum.drop(values, 4) |> Enum.filter(&(&1 != :nan))
      assert Enum.all?(valid_values, &(&1 >= 100.0 and &1 <= 110.0))
      assert length(valid_values) == 6
    end
  end
end
