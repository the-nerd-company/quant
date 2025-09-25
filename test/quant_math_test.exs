defmodule Quant.MathTest do
  @moduledoc """
  Tests for the Quant.Math module, focusing on technical indicators
  and mathematical operations for financial data analysis.
  """
  use ExUnit.Case, async: true
  doctest Quant.Math

  alias Explorer.DataFrame
  alias Quant.Math

  describe "add_sma!/3" do
    test "calculates simple moving average correctly" do
      # Test data: [1.0, 2.0, 3.0, 4.0, 5.0]
      # SMA(3): [NaN, NaN, 2.0, 3.0, 4.0]
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      result = Math.add_sma!(df, :close, period: 3)

      # Check that the new column exists
      assert "close_sma_3" in Map.keys(result.dtypes)

      # Extract the SMA values
      sma_values = DataFrame.pull(result, "close_sma_3") |> Explorer.Series.to_list()

      # First two values should be NaN
      assert nan?(Enum.at(sma_values, 0))
      assert nan?(Enum.at(sma_values, 1))

      # Check calculated values (with floating point tolerance)
      assert_in_delta(Enum.at(sma_values, 2), 2.0, 1.0e-10)
      assert_in_delta(Enum.at(sma_values, 3), 3.0, 1.0e-10)
      assert_in_delta(Enum.at(sma_values, 4), 4.0, 1.0e-10)
    end

    test "works with period of 1" do
      df = DataFrame.new(%{price: [10.0, 20.0, 30.0]})

      result = Math.add_sma!(df, :price, period: 1)

      sma_values = DataFrame.pull(result, "price_sma_1") |> Explorer.Series.to_list()

      # All values should equal the original values
      assert_in_delta(Enum.at(sma_values, 0), 10.0, 1.0e-10)
      assert_in_delta(Enum.at(sma_values, 1), 20.0, 1.0e-10)
      assert_in_delta(Enum.at(sma_values, 2), 30.0, 1.0e-10)
    end

    test "handles custom column name" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      result = Math.add_sma!(df, :close, period: 2, name: "custom_ma")

      assert "custom_ma" in Map.keys(result.dtypes)
      refute "close_sma_2" in Map.keys(result.dtypes)
    end

    test "handles atom column names" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      result = Math.add_sma!(df, :close, period: 2, name: :my_sma)

      assert "my_sma" in Map.keys(result.dtypes)
    end

    test "supports method chaining" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]})

      result =
        df
        |> Math.add_sma!(:close, period: 2, name: "sma_2")
        |> Math.add_sma!(:close, period: 3, name: "sma_3")

      assert "sma_2" in Map.keys(result.dtypes)
      assert "sma_3" in Map.keys(result.dtypes)

      # Verify both calculations are correct
      sma_2_values = DataFrame.pull(result, "sma_2") |> Explorer.Series.to_list()
      sma_3_values = DataFrame.pull(result, "sma_3") |> Explorer.Series.to_list()

      # SMA(2) second value should be (1+2)/2 = 1.5
      assert_in_delta(Enum.at(sma_2_values, 1), 1.5, 1.0e-10)

      # SMA(3) third value should be (1+2+3)/3 = 2.0
      assert_in_delta(Enum.at(sma_3_values, 2), 2.0, 1.0e-10)
    end

    test "raises error for invalid column" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      assert_raise ArgumentError, ~r/Column :nonexistent not found in DataFrame/, fn ->
        Math.add_sma!(df, :nonexistent, period: 2)
      end
    end

    test "raises error for invalid period" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      assert_raise ArgumentError, ~r/Period must be a positive integer/, fn ->
        Math.add_sma!(df, :close, period: 0)
      end

      assert_raise ArgumentError, ~r/Period must be a positive integer/, fn ->
        Math.add_sma!(df, :close, period: -1)
      end
    end

    test "handles edge case with empty dataframe" do
      df = DataFrame.new(%{close: []})

      result = Math.add_sma!(df, :close, period: 5)

      assert "close_sma_5" in Map.keys(result.dtypes)
      sma_values = DataFrame.pull(result, "close_sma_5") |> Explorer.Series.to_list()
      assert sma_values == []
    end

    test "handles edge case with single value" do
      df = DataFrame.new(%{close: [42.0]})

      result = Math.add_sma!(df, :close, period: 1)

      sma_values = DataFrame.pull(result, "close_sma_1") |> Explorer.Series.to_list()
      assert_in_delta(Enum.at(sma_values, 0), 42.0, 1.0e-10)

      # Period > data length should result in NaN
      result2 = Math.add_sma!(df, :close, period: 2)
      sma_values2 = DataFrame.pull(result2, "close_sma_2") |> Explorer.Series.to_list()
      assert nan?(Enum.at(sma_values2, 0))
    end

    test "reference calculation with known values" do
      # Using well-known stock price pattern
      # Prices: [100, 102, 101, 103, 104, 106, 105, 107, 108, 110]
      # SMA(5): [NaN, NaN, NaN, NaN, 102.0, 103.2, 103.8, 105.0, 106.0, 107.2]
      df =
        DataFrame.new(%{
          price: [100.0, 102.0, 101.0, 103.0, 104.0, 106.0, 105.0, 107.0, 108.0, 110.0]
        })

      result = Math.add_sma!(df, :price, period: 5, name: "sma_5")

      sma_values = DataFrame.pull(result, "sma_5") |> Explorer.Series.to_list()

      # First 4 values should be NaN
      for i <- 0..3 do
        assert nan?(Enum.at(sma_values, i))
      end

      # Check calculated values
      expected_values = [102.0, 103.2, 103.8, 105.0, 106.0, 107.2]

      for {expected, i} <- Enum.with_index(expected_values, 4) do
        assert_in_delta(Enum.at(sma_values, i), expected, 1.0e-10)
      end
    end
  end

  # Helper function to check for NaN values
  # Helper function to check for NaN values
  defp nan?(value) when is_float(value) do
    # Use Float.to_string to check for "nan" representation
    # This avoids the comparison warning while still being correct
    case Float.to_string(value) do
      "nan" -> true
      _ -> false
    end
  end

  # Handle :nan atoms from NX
  defp nan?(:nan), do: true
  defp nan?(_), do: false
end
