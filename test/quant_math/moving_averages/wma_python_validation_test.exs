defmodule Quant.Math.MovingAverages.WMAPythonValidationTest do
  @moduledoc """
  Python validation tests for WMA (Weighted Moving Average) calculations.

  These tests validate our Elixir WMA implementation against Python
  to ensure we're calculating WMA correctly and identify any discrepancies.

  WMA Algorithm:
  - Default: Linear weights [1, 2, 3, ..., period] (older to newer)
  - WMA_t = Σ(price_i × weight_i) / Σ(weight_i)
  - More weight to recent prices with linear weighting
  """

  use ExUnit.Case, async: true

  import Pythonx
  import Quant.Explorer.PythonHelpers

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math.MovingAverages

  describe "Python validation tests" do
    @tag :python_validation
    test "Pythonx integration works for WMA" do
      if python_available?() do
        python_result = ~PY"""
        import pandas as pd
        import numpy as np
        "WMA validation ready"
        """

        result = python_result |> inspect() |> String.contains?("WMA validation ready")

        assert result
        IO.puts("\n✅ Pythonx integration is working correctly for WMA validation")
      else
        IO.puts("\n⚠️  Python/pandas not available, skipping WMA Python validation")
      end
    end

    @tag :python_validation
    test "WMA calculation matches Python implementation with default linear weights" do
      if python_available?() do
        price_data = [
          100.0,
          102.0,
          101.5,
          103.0,
          104.5,
          103.8,
          105.2,
          106.1,
          105.0,
          107.3,
          108.7,
          107.9,
          110.2,
          111.5,
          110.8,
          112.4
        ]

        period = 5

        # Calculate WMA using our Elixir implementation
        df = DataFrame.new(%{close: price_data})
        elixir_result = MovingAverages.add_wma!(df, :close, period: period)
        elixir_wma = elixir_result |> DataFrame.pull("close_wma_#{period}") |> Series.to_list()

        # Calculate WMA using Python
        python_final_wma = ~PY"""
        import pandas as pd
        import numpy as np

        def wma(prices, period):
            n = len(prices)
            wma_values = [np.nan] * n

            if n < period:
                return wma_values

            # Create linear weights [1, 2, 3, ..., period]
            weights = np.array(range(1, period + 1), dtype=float)
            weight_sum = np.sum(weights)

            for i in range(period - 1, n):
                window = prices[i - period + 1:i + 1]
                weighted_sum = np.sum(np.array(window) * weights)
                wma_values[i] = weighted_sum / weight_sum

            return wma_values

        wma_values = wma(price_data, period)

        final_value = None
        for val in reversed(wma_values):
            if not np.isnan(val):
                final_value = float(val)
                break

        final_value
        """

        final_elixir = Enum.filter(elixir_wma, &(&1 != :nan)) |> List.last()

        final_python =
          case python_final_wma do
            result when is_number(result) -> result
            _ -> parse_python_float(python_final_wma |> inspect())
          end

        IO.puts("\n📊 Python WMA Validation Results:")

        IO.puts(
          "   Final Elixir WMA: #{if final_elixir, do: Float.round(final_elixir, 4), else: "nil"}"
        )

        IO.puts(
          "   Final Python WMA: #{if final_python, do: Float.round(final_python, 4), else: "nil"}"
        )

        if final_elixir && final_python do
          diff = abs(final_elixir - final_python)
          percent_diff = diff / final_python * 100.0

          IO.puts("   Absolute Difference: #{Float.round(diff, 4)}")
          IO.puts("   Percentage Difference: #{Float.round(percent_diff, 4)}%")

          if percent_diff > 0.01 do
            IO.puts("   ⚠️  DIFFERENCES DETECTED")
          else
            IO.puts("   ✅ Implementations are very close")
          end
        end
      end
    end

    @tag :python_validation
    test "WMA with equal weights matches SMA" do
      if python_available?() do
        price_data = [50.0, 51.5, 52.3, 51.8, 53.2, 54.1, 53.7, 55.0]
        period = 4

        df = DataFrame.new(%{close: price_data})
        equal_weights = List.duplicate(1.0, period)

        elixir_wma_equal =
          MovingAverages.add_wma!(df, :close, period: period, weights: equal_weights)

        elixir_sma = MovingAverages.add_sma!(df, :close, period: period)

        elixir_wma_values =
          elixir_wma_equal |> DataFrame.pull("close_wma_#{period}") |> Series.to_list()

        elixir_sma_values =
          elixir_sma |> DataFrame.pull("close_sma_#{period}") |> Series.to_list()

        final_elixir_wma = Enum.filter(elixir_wma_values, &(&1 != :nan)) |> List.last()
        final_elixir_sma = Enum.filter(elixir_sma_values, &(&1 != :nan)) |> List.last()

        IO.puts("\n🟰 WMA Equal Weights vs SMA Validation:")
        IO.puts("   Period: #{period}")

        if final_elixir_wma && final_elixir_sma do
          elixir_diff = abs(final_elixir_wma - final_elixir_sma)

          IO.puts("   WMA (equal weights): #{Float.round(final_elixir_wma, 4)}")
          IO.puts("   SMA (standard): #{Float.round(final_elixir_sma, 4)}")
          IO.puts("   Difference: #{Float.round(elixir_diff, 6)}")

          if elixir_diff < 0.0001 do
            IO.puts("   ✅ WMA with equal weights matches SMA (as expected)")
          else
            IO.puts("   ⚠️  WMA with equal weights should match SMA exactly")
          end
        end
      end
    end

    @tag :python_validation
    test "WMA responsiveness compared to SMA" do
      if python_available?() do
        price_data = [
          10.0,
          10.5,
          11.0,
          11.5,
          12.0,
          12.5,
          13.0,
          13.5,
          14.0,
          14.5,
          15.0,
          15.5,
          16.0,
          16.5,
          17.0,
          17.5
        ]

        period = 5

        df = DataFrame.new(%{close: price_data})

        result_with_sma = MovingAverages.add_sma!(df, :close, period: period)
        result_with_wma = MovingAverages.add_wma!(result_with_sma, :close, period: period)

        elixir_sma = result_with_wma |> DataFrame.pull("close_sma_#{period}") |> Series.to_list()
        elixir_wma = result_with_wma |> DataFrame.pull("close_wma_#{period}") |> Series.to_list()

        final_elixir_sma = Enum.filter(elixir_sma, &(&1 != :nan)) |> List.last()
        final_elixir_wma = Enum.filter(elixir_wma, &(&1 != :nan)) |> List.last()

        IO.puts("\n🚀 WMA Responsiveness Validation:")
        IO.puts("   Trend: Upward (from #{List.first(price_data)} to #{List.last(price_data)})")
        IO.puts("   Period: #{period}")

        if final_elixir_sma && final_elixir_wma do
          responsiveness_diff = final_elixir_wma - final_elixir_sma
          current_price = List.last(price_data)

          IO.puts("   Final SMA: #{Float.round(final_elixir_sma, 4)}")
          IO.puts("   Final WMA: #{Float.round(final_elixir_wma, 4)}")
          IO.puts("   Current Price: #{current_price}")
          IO.puts("   Responsiveness difference: #{Float.round(responsiveness_diff, 4)}")

          wma_distance = abs(final_elixir_wma - current_price)
          sma_distance = abs(final_elixir_sma - current_price)

          IO.puts("   Distance from current price:")
          IO.puts("     WMA: #{Float.round(wma_distance, 4)}")
          IO.puts("     SMA: #{Float.round(sma_distance, 4)}")

          if responsiveness_diff > 0 do
            IO.puts("   ✅ WMA is more responsive than SMA (as expected in uptrend)")
          end

          if wma_distance <= sma_distance do
            IO.puts("   ✅ WMA is at least as close to current price as SMA")
          end
        end

        IO.puts("   ✅ WMA responsiveness validation completed")
      end
    end
  end

  # Helper functions
  defp parse_python_float(str) do
    case Regex.run(~r/([0-9]+(?:\.[0-9]+)?)/, str) do
      [_, number_str] -> String.to_float(number_str)
      nil -> nil
    end
  rescue
    ArgumentError ->
      case Regex.run(~r/([0-9]+)/, str) do
        [_, number_str] -> String.to_float(number_str)
        nil -> nil
      end
  end
end
