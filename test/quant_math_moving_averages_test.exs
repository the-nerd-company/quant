defmodule Quant.Math.MovingAveragesTest do
  @moduledoc """
  Tests for the Quant.Math.MovingAverages module, focusing on moving average
  indicators including SMA and EMA implementations.
  """
  use ExUnit.Case, async: true
  doctest Quant.Math.MovingAverages

  alias Explorer.DataFrame
  alias Quant.Math.MovingAverages

  describe "add_ema!/3" do
    test "calculates exponential moving average correctly" do
      # Test data: [1.0, 2.0, 3.0, 4.0, 5.0]
      # EMA(3) with alpha=0.5: [NaN, NaN, 2.0, 3.0, 4.0]
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      result = MovingAverages.add_ema!(df, :close, period: 3, alpha: 0.5)

      # Check that the new column exists
      assert "close_ema_3" in Map.keys(result.dtypes)

      # Extract the EMA values
      ema_values = DataFrame.pull(result, "close_ema_3") |> Explorer.Series.to_list()

      # First two values should be NaN
      assert nan?(Enum.at(ema_values, 0))
      assert nan?(Enum.at(ema_values, 1))

      # Check calculated values (with floating point tolerance)
      # First EMA = SMA of first 3 values = (1+2+3)/3 = 2.0
      assert_in_delta(Enum.at(ema_values, 2), 2.0, 1.0e-6)
      # Second EMA = 0.5 * 4 + 0.5 * 2 = 3.0
      assert_in_delta(Enum.at(ema_values, 3), 3.0, 1.0e-6)
      # Third EMA = 0.5 * 5 + 0.5 * 3 = 4.0
      assert_in_delta(Enum.at(ema_values, 4), 4.0, 1.0e-6)
    end

    test "works with default alpha (2/(period+1))" do
      df = DataFrame.new(%{price: [10.0, 20.0, 30.0, 40.0, 50.0]})

      result = MovingAverages.add_ema!(df, :price, period: 2)

      ema_values = DataFrame.pull(result, "price_ema_2") |> Explorer.Series.to_list()

      # With period=2, alpha = 2/(2+1) = 2/3 ≈ 0.6667
      # First EMA = (10+20)/2 = 15.0
      assert_in_delta(Enum.at(ema_values, 1), 15.0, 1.0e-6)

      # Second EMA = (2/3) * 30 + (1/3) * 15 = 20 + 5 = 25.0
      assert_in_delta(Enum.at(ema_values, 2), 25.0, 1.0e-6)
    end

    test "handles custom column name" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      result = MovingAverages.add_ema!(df, :close, period: 2, name: "custom_ema")

      assert "custom_ema" in Map.keys(result.dtypes)
      refute "close_ema_2" in Map.keys(result.dtypes)
    end

    test "handles atom column names" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0]})

      result = MovingAverages.add_ema!(df, :close, period: 2, name: :my_ema)

      assert "my_ema" in Map.keys(result.dtypes)
    end

    test "supports method chaining with SMA" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]})

      result =
        df
        |> MovingAverages.add_sma!(:close, period: 2, name: "sma_2")
        |> MovingAverages.add_ema!(:close, period: 3, name: "ema_3")

      assert "sma_2" in Map.keys(result.dtypes)
      assert "ema_3" in Map.keys(result.dtypes)
    end

    test "raises error for invalid column" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      assert_raise ArgumentError, ~r/Column :nonexistent not found in DataFrame/, fn ->
        MovingAverages.add_ema!(df, :nonexistent, period: 2)
      end
    end

    test "raises error for invalid period" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      assert_raise ArgumentError, ~r/Period must be a positive integer/, fn ->
        MovingAverages.add_ema!(df, :close, period: 0)
      end

      assert_raise ArgumentError, ~r/Period must be a positive integer/, fn ->
        MovingAverages.add_ema!(df, :close, period: -1)
      end
    end

    test "raises error for invalid alpha" do
      df = DataFrame.new(%{close: [1.0, 2.0, 3.0]})

      assert_raise ArgumentError, ~r/Alpha must be between 0.0 and 1.0/, fn ->
        MovingAverages.add_ema!(df, :close, period: 2, alpha: 0.0)
      end

      assert_raise ArgumentError, ~r/Alpha must be between 0.0 and 1.0/, fn ->
        MovingAverages.add_ema!(df, :close, period: 2, alpha: 1.5)
      end
    end

    test "handles edge case with empty dataframe" do
      df = DataFrame.new(%{close: []})

      result = MovingAverages.add_ema!(df, :close, period: 5)

      assert "close_ema_5" in Map.keys(result.dtypes)
      ema_values = DataFrame.pull(result, "close_ema_5") |> Explorer.Series.to_list()
      assert ema_values == []
    end

    test "handles edge case with single value" do
      df = DataFrame.new(%{close: [42.0]})

      result = MovingAverages.add_ema!(df, :close, period: 1)

      ema_values = DataFrame.pull(result, "close_ema_1") |> Explorer.Series.to_list()
      assert_in_delta(Enum.at(ema_values, 0), 42.0, 1.0e-6)

      # Period > data length should result in NaN
      result2 = MovingAverages.add_ema!(df, :close, period: 2)
      ema_values2 = DataFrame.pull(result2, "close_ema_2") |> Explorer.Series.to_list()
      assert nan?(Enum.at(ema_values2, 0))
    end

    test "reference calculation with known financial data" do
      # Using typical stock prices
      # Prices: [100, 102, 101, 103, 104, 106, 105]
      # EMA(3) with default alpha = 2/4 = 0.5
      df =
        DataFrame.new(%{
          price: [100.0, 102.0, 101.0, 103.0, 104.0, 106.0, 105.0]
        })

      result = MovingAverages.add_ema!(df, :price, period: 3, alpha: 0.5, name: "ema_3")

      ema_values = DataFrame.pull(result, "ema_3") |> Explorer.Series.to_list()

      # First 2 values should be NaN
      assert nan?(Enum.at(ema_values, 0))
      assert nan?(Enum.at(ema_values, 1))

      # First EMA = SMA(100, 102, 101) = 101.0
      assert_in_delta(Enum.at(ema_values, 2), 101.0, 1.0e-6)

      # Second EMA = 0.5 * 103 + 0.5 * 101 = 102.0
      assert_in_delta(Enum.at(ema_values, 3), 102.0, 1.0e-6)

      # Third EMA = 0.5 * 104 + 0.5 * 102 = 103.0
      assert_in_delta(Enum.at(ema_values, 4), 103.0, 1.0e-6)
    end
  end

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
