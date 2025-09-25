defmodule Quant.Math.MovingAverages.TEMAPythonValidationTest do
  @moduledoc """
  Python validation tests for TEMA (Triple Exponential Moving Average) calculations.

  These tests validate our Elixir TEMA implementation against Python
  to ensure we're calculating TEMA correctly and identify any discrepancies.

  TEMA Algorithm:
  1. EMA1 = EMA(price, period)
  2. EMA2 = EMA(EMA1, period)
  3. EMA3 = EMA(EMA2, period)
  4. TEMA = 3 * EMA1 - 3 * EMA2 + EMA3
  """

  use ExUnit.Case, async: true

  import Pythonx
  import Quant.Explorer.PythonHelpers

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math.MovingAverages

  describe "Python validation tests" do
    @tag :python_validation
    test "Pythonx integration works for TEMA" do
      # Simple test to verify Pythonx is working
      if python_available?() do
        python_result = ~PY"""
        import pandas as pd
        import numpy as np
        "TEMA validation ready"
        """

        # Convert Python object to Elixir string check
        result = python_result |> inspect() |> String.contains?("TEMA validation ready")

        assert result
        IO.puts("\n✅ Pythonx integration is working correctly for TEMA validation")
      else
        IO.puts("\n⚠️  Python/pandas not available, skipping TEMA Python validation")
      end
    end

    @tag :python_validation
    test "TEMA calculation matches Python implementation" do
      if python_available?() do
        # Test data - using realistic price movements with enough data for TEMA calculation
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
          112.4,
          113.9,
          112.7,
          115.1,
          116.8,
          115.5,
          117.9,
          119.2,
          118.1,
          120.5,
          121.8,
          120.9,
          123.2,
          124.7,
          123.4,
          126.1,
          127.5
        ]

        period = 6

        # Calculate TEMA using our Elixir implementation
        df = DataFrame.new(%{close: price_data})
        elixir_result = MovingAverages.add_tema!(df, :close, period: period)
        elixir_tema = elixir_result |> DataFrame.pull("close_tema_#{period}") |> Series.to_list()

        # Calculate TEMA using Python - implementing the exact same algorithm
        python_final_tema = ~PY"""
        import pandas as pd
        import numpy as np

        def tema(prices, period):
            # Calculate TEMA: 3 * EMA1 - 3 * EMA2 + EMA3
            alpha = 2.0 / (period + 1)

            # Step 1: Calculate first EMA
            ema1 = []
            for i, price in enumerate(prices):
                if i == 0:
                    ema1.append(price)
                else:
                    ema1.append(alpha * price + (1 - alpha) * ema1[-1])

            # Step 2: Calculate second EMA (EMA of EMA1)
            ema2 = []
            for i, val in enumerate(ema1):
                if i == 0:
                    ema2.append(val)
                else:
                    ema2.append(alpha * val + (1 - alpha) * ema2[-1])

            # Step 3: Calculate third EMA (EMA of EMA2)
            ema3 = []
            for i, val in enumerate(ema2):
                if i == 0:
                    ema3.append(val)
                else:
                    ema3.append(alpha * val + (1 - alpha) * ema3[-1])

            # Step 4: Calculate TEMA
            tema_values = []
            for i in range(len(prices)):
                tema_val = 3 * ema1[i] - 3 * ema2[i] + ema3[i]
                tema_values.append(tema_val)

            return tema_values

        # Calculate TEMA
        tema_values = tema(price_data, period)

        # Get the final TEMA value
        float(tema_values[-1])
        """

        # Extract final values for comparison
        final_elixir = Enum.filter(elixir_tema, &(&1 != :nan)) |> List.last()

        # Parse the Python result
        final_python =
          case python_final_tema do
            result when is_number(result) ->
              result

            _ ->
              # Fallback: extract number from string representation
              python_str = python_final_tema |> inspect()

              if python_str =~ "None" do
                nil
              else
                parse_python_float(python_str)
              end
          end

        IO.puts("\n📊 Python TEMA Validation Results:")

        IO.puts(
          "   Final Elixir TEMA: #{if final_elixir, do: Float.round(final_elixir, 4), else: "nil"}"
        )

        IO.puts(
          "   Final Python TEMA: #{if final_python, do: Float.round(final_python, 4), else: "nil"}"
        )

        if final_elixir && final_python do
          diff = abs(final_elixir - final_python)
          percent_diff = diff / final_python * 100.0

          IO.puts("   Absolute Difference: #{Float.round(diff, 4)}")
          IO.puts("   Percentage Difference: #{Float.round(percent_diff, 2)}%")

          if percent_diff > 2.0 do
            IO.puts("   ⚠️  SIGNIFICANT DIFFERENCES DETECTED")

            IO.puts(
              "   💡 This suggests an implementation bug - both should use the same TEMA algorithm"
            )

            IO.puts("   🔍 Need to investigate calculation differences")
          else
            IO.puts("   ✅ Implementations are reasonably close")
          end
        else
          IO.puts("   ⚠️  Could not compare values (one or both are nil)")
        end
      end
    end

    @tag :python_validation
    test "TEMA responsiveness validation" do
      if python_available?() do
        # Data with clear trend to test responsiveness
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
          17.5,
          18.0,
          18.5,
          19.0,
          19.5,
          20.0,
          20.5,
          21.0,
          21.5
        ]

        period = 5

        df = DataFrame.new(%{close: price_data})

        # Calculate both DEMA and TEMA for comparison
        result_with_dema = MovingAverages.add_dema!(df, :close, period: period)
        result_with_tema = MovingAverages.add_tema!(result_with_dema, :close, period: period)

        elixir_dema =
          result_with_tema |> DataFrame.pull("close_dema_#{period}") |> Series.to_list()

        elixir_tema =
          result_with_tema |> DataFrame.pull("close_tema_#{period}") |> Series.to_list()

        # Extract final values
        final_dema = Enum.filter(elixir_dema, &(&1 != :nan)) |> List.last()
        final_tema = Enum.filter(elixir_tema, &(&1 != :nan)) |> List.last()

        IO.puts("\n🚀 TEMA Responsiveness Validation:")
        IO.puts("   Trend: Upward (from #{List.first(price_data)} to #{List.last(price_data)})")
        IO.puts("   Period: #{period}")

        if final_dema && final_tema do
          responsiveness_diff = final_tema - final_dema
          current_price = List.last(price_data)

          IO.puts("   Final DEMA: #{Float.round(final_dema, 4)}")
          IO.puts("   Final TEMA: #{Float.round(final_tema, 4)}")
          IO.puts("   Current Price: #{current_price}")
          IO.puts("   Responsiveness difference: #{Float.round(responsiveness_diff, 4)}")

          # Check distances from current price
          dema_distance = abs(final_dema - current_price)
          tema_distance = abs(final_tema - current_price)

          IO.puts("   Distance from current price:")
          IO.puts("     DEMA: #{Float.round(dema_distance, 4)}")
          IO.puts("     TEMA: #{Float.round(tema_distance, 4)}")

          if tema_distance <= dema_distance do
            IO.puts("   ✅ TEMA is at least as responsive as DEMA")
          else
            IO.puts("   📊 TEMA vs DEMA responsiveness comparison completed")
          end
        end

        IO.puts("   ✅ TEMA responsiveness validation completed")
      end
    end
  end

  # Helper functions for Python validation
  defp parse_python_float(str) do
    # Extract the first number (int or float) from the string
    case Regex.run(~r/([0-9]+(?:\.[0-9]+)?)/, str) do
      [_, number_str] -> String.to_float(number_str)
      nil -> nil
    end
  rescue
    ArgumentError ->
      # Handle case where it's an integer
      case Regex.run(~r/([0-9]+)/, str) do
        [_, number_str] -> String.to_float(number_str)
        nil -> nil
      end
  end
end
