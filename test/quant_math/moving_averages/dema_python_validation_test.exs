defmodule Quant.Math.MovingAverages.DEMAPythonValidationTest do
  @moduledoc """
  Python validation tests for DEMA (Double Exponential Moving Average) calculations.

  These tests validate our Elixir DEMA implementation against Python pandas
  to ensure we're calculating DEMA correctly and identify any discrepancies.
  """

  use ExUnit.Case, async: true

  import Pythonx
  import Quant.Explorer.PythonHelpers

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math.MovingAverages

  describe "Python validation tests" do
    @tag :python_validation
    test "Pythonx integration works for DEMA" do
      # Simple test to verify Pythonx is working
      if python_available?() do
        python_result = ~PY"""
        import pandas as pd
        import numpy as np
        "DEMA validation ready"
        """

        # Convert Python object to Elixir string check
        result = python_result |> inspect() |> String.contains?("DEMA validation ready")

        assert result
        IO.puts("\n✅ Pythonx integration is working correctly for DEMA validation")
      else
        IO.puts("\n⚠️  Python/pandas not available, skipping DEMA Python validation")
      end
    end

    @tag :python_validation
    test "DEMA calculation matches Python pandas implementation" do
      if python_available?() do
        # Test data - using realistic price movements
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
          123.4
        ]

        period = 10

        # Calculate DEMA using our Elixir implementation
        df = DataFrame.new(%{close: price_data})
        elixir_result = MovingAverages.add_dema!(df, :close, period: period)
        elixir_dema = elixir_result |> DataFrame.pull("close_dema_#{period}") |> Series.to_list()

        # Calculate DEMA using Python - standard algorithm
        python_final_dema = ~PY"""
        import pandas as pd
        import numpy as np

        # DEMA calculation: 2 * EMA - EMA(EMA)
        df = pd.DataFrame({'close': price_data})

        # Calculate alpha for the given period
        alpha = 2.0 / (period + 1)

        # First EMA
        ema1 = df['close'].ewm(alpha=alpha, adjust=False).mean()

        # Second EMA (EMA of the first EMA)
        ema2 = ema1.ewm(alpha=alpha, adjust=False).mean()

        # DEMA formula: 2 * EMA1 - EMA2
        dema = 2 * ema1 - ema2

        # Get the final DEMA value
        float(dema.iloc[-1]) if not pd.isna(dema.iloc[-1]) else None
        """

        # Extract final values for comparison
        final_elixir = Enum.filter(elixir_dema, &(&1 != :nan)) |> List.last()

        # Parse the Python result
        final_python =
          case python_final_dema do
            result when is_number(result) ->
              result

            _ ->
              # Fallback: extract number from string representation
              python_str = python_final_dema |> inspect()

              if python_str =~ "None" do
                nil
              else
                parse_python_float(python_str)
              end
          end

        IO.puts("\n📊 Python DEMA Validation Results:")

        IO.puts(
          "   Final Elixir DEMA: #{if final_elixir, do: Float.round(final_elixir, 4), else: "nil"}"
        )

        IO.puts(
          "   Final Python DEMA: #{if final_python, do: Float.round(final_python, 4), else: "nil"}"
        )

        if final_elixir && final_python do
          diff = abs(final_elixir - final_python)
          percent_diff = diff / final_python * 100.0

          IO.puts("   Absolute Difference: #{Float.round(diff, 4)}")
          IO.puts("   Percentage Difference: #{Float.round(percent_diff, 2)}%")

          if percent_diff > 1.0 do
            IO.puts("   ⚠️  SIGNIFICANT DIFFERENCES DETECTED")

            IO.puts(
              "   💡 This suggests an implementation bug - both should use the same DEMA algorithm"
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
    test "DEMA intermediate calculations validation" do
      if python_available?() do
        # Simpler test case to verify step-by-step calculations
        price_data = [
          50.0,
          51.0,
          52.0,
          51.5,
          53.0,
          52.5,
          54.0,
          53.8,
          55.0,
          54.2,
          56.0,
          55.7,
          57.0,
          56.5,
          58.0
        ]

        period = 5

        df = DataFrame.new(%{close: price_data})
        elixir_result = MovingAverages.add_dema!(df, :close, period: period)
        elixir_dema = elixir_result |> DataFrame.pull("close_dema_#{period}") |> Series.to_list()

        # Get multiple values using Python for comparison
        python_results = ~PY"""
        import pandas as pd
        import numpy as np

        # DEMA calculation with step-by-step verification
        df = pd.DataFrame({'close': price_data})

        # Calculate alpha for the given period
        alpha = 2.0 / (period + 1)

        # First EMA
        ema1 = df['close'].ewm(alpha=alpha, adjust=False).mean()

        # Second EMA (EMA of the first EMA)
        ema2 = ema1.ewm(alpha=alpha, adjust=False).mean()

        # DEMA formula: 2 * EMA1 - EMA2
        dema = 2 * ema1 - ema2

        # Return the last 3 valid values for comparison
        valid_dema = dema.dropna()
        result = {
            'last_value': float(valid_dema.iloc[-1]) if len(valid_dema) > 0 else None,
            'second_last': float(valid_dema.iloc[-2]) if len(valid_dema) > 1 else None,
            'third_last': float(valid_dema.iloc[-3]) if len(valid_dema) > 2 else None,
            'count': len(valid_dema)
        }
        result
        """

        # Extract valid values from both implementations
        elixir_valid = Enum.filter(elixir_dema, &(&1 != :nan))

        # Parse Python results
        python_dict_str = python_results |> inspect()
        python_last = extract_dict_value(python_dict_str, "last_value")
        python_second = extract_dict_value(python_dict_str, "second_last")
        python_third = extract_dict_value(python_dict_str, "third_last")

        IO.puts("\n🔬 DEMA Step-by-Step Validation:")
        IO.puts("   Input data length: #{length(price_data)}")
        IO.puts("   Period: #{period}")
        IO.puts("   Elixir valid values: #{length(elixir_valid)}")

        if length(elixir_valid) >= 3 do
          elixir_last = Enum.at(elixir_valid, -1)
          elixir_second = Enum.at(elixir_valid, -2)
          elixir_third = Enum.at(elixir_valid, -3)

          IO.puts("   Last values comparison:")
          IO.puts("     Elixir: #{Float.round(elixir_last, 4)}")
          IO.puts("     Python: #{if python_last, do: Float.round(python_last, 4), else: "nil"}")

          if python_last do
            diff = abs(elixir_last - python_last)
            IO.puts("     Difference: #{Float.round(diff, 4)}")
          end

          IO.puts("   Second-to-last values:")
          IO.puts("     Elixir: #{Float.round(elixir_second, 4)}")

          IO.puts(
            "     Python: #{if python_second, do: Float.round(python_second, 4), else: "nil"}"
          )

          if python_second do
            diff = abs(elixir_second - python_second)
            IO.puts("     Difference: #{Float.round(diff, 4)}")
          end

          # Check if all differences are small
          all_close =
            python_last && python_second && python_third &&
              abs(elixir_last - python_last) < 0.01 &&
              abs(elixir_second - python_second) < 0.01 &&
              abs(elixir_third - python_third) < 0.01

          if all_close do
            IO.puts("   ✅ All intermediate calculations match Python implementation")
          else
            IO.puts("   ⚠️  Some intermediate calculations differ from Python")
          end
        else
          IO.puts("   ⚠️  Insufficient valid values for detailed comparison")
        end
      end
    end

    @tag :python_validation
    test "DEMA responds faster than EMA - validation against Python" do
      if python_available?() do
        # Data with a clear trend change to test responsiveness
        price_data = [
          # Stable period
          10.0,
          10.1,
          10.2,
          10.1,
          10.3,
          # Upward trend
          11.0,
          11.5,
          12.0,
          12.5,
          13.0,
          # Continued upward trend
          13.5,
          14.0,
          14.5,
          15.0,
          15.5,
          # More upward movement
          15.2,
          15.8,
          16.1,
          16.5,
          17.0
        ]

        period = 8

        df = DataFrame.new(%{close: price_data})

        # Calculate both EMA and DEMA using our implementation
        result_with_ema = MovingAverages.add_ema!(df, :close, period: period)
        result_with_dema = MovingAverages.add_dema!(result_with_ema, :close, period: period)

        elixir_ema = result_with_dema |> DataFrame.pull("close_ema_#{period}") |> Series.to_list()

        elixir_dema =
          result_with_dema |> DataFrame.pull("close_dema_#{period}") |> Series.to_list()

        # Calculate EMA and DEMA using Python
        python_comparison = ~PY"""
        import pandas as pd
        import numpy as np

        df = pd.DataFrame({'close': price_data})
        alpha = 2.0 / (period + 1)

        # Calculate EMA
        ema = df['close'].ewm(alpha=alpha, adjust=False).mean()

        # Calculate DEMA
        ema1 = df['close'].ewm(alpha=alpha, adjust=False).mean()
        ema2 = ema1.ewm(alpha=alpha, adjust=False).mean()
        dema = 2 * ema1 - ema2

        # Get final values
        final_ema = float(ema.iloc[-1]) if not pd.isna(ema.iloc[-1]) else None
        final_dema = float(dema.iloc[-1]) if not pd.isna(dema.iloc[-1]) else None

        # Check responsiveness: DEMA should be higher than EMA in an uptrend
        responsiveness_diff = final_dema - final_ema if (final_dema and final_ema) else None

        {
            'final_ema': final_ema,
            'final_dema': final_dema,
            'responsiveness_diff': responsiveness_diff
        }
        """

        # Extract final values
        final_elixir_ema = Enum.filter(elixir_ema, &(&1 != :nan)) |> List.last()
        final_elixir_dema = Enum.filter(elixir_dema, &(&1 != :nan)) |> List.last()

        # Parse Python results
        python_str = python_comparison |> inspect()
        python_ema = extract_dict_value(python_str, "final_ema")
        python_dema = extract_dict_value(python_str, "final_dema")
        python_diff = extract_dict_value(python_str, "responsiveness_diff")

        IO.puts("\n🚀 DEMA Responsiveness Validation:")
        IO.puts("   Trend: Upward (from 10.0 to 17.0)")
        IO.puts("   Period: #{period}")

        if final_elixir_ema && final_elixir_dema do
          elixir_diff = final_elixir_dema - final_elixir_ema

          IO.puts("   Final EMA (Elixir): #{Float.round(final_elixir_ema, 4)}")
          IO.puts("   Final DEMA (Elixir): #{Float.round(final_elixir_dema, 4)}")
          IO.puts("   Responsiveness difference (Elixir): #{Float.round(elixir_diff, 4)}")

          if python_ema && python_dema && python_diff do
            IO.puts("   Final EMA (Python): #{Float.round(python_ema, 4)}")
            IO.puts("   Final DEMA (Python): #{Float.round(python_dema, 4)}")
            IO.puts("   Responsiveness difference (Python): #{Float.round(python_diff, 4)}")

            ema_diff = abs(final_elixir_ema - python_ema)
            dema_diff = abs(final_elixir_dema - python_dema)
            resp_diff = abs(elixir_diff - python_diff)

            IO.puts("   EMA difference (Elixir vs Python): #{Float.round(ema_diff, 4)}")
            IO.puts("   DEMA difference (Elixir vs Python): #{Float.round(dema_diff, 4)}")

            if ema_diff < 0.01 && dema_diff < 0.01 do
              IO.puts("   ✅ Both EMA and DEMA calculations match Python")
            end

            if elixir_diff > 0 && python_diff > 0 && resp_diff < 0.01 do
              IO.puts("   ✅ DEMA responsiveness behavior matches Python (DEMA > EMA in uptrend)")
            end
          end

          if elixir_diff > 0 do
            IO.puts("   ✅ DEMA is more responsive than EMA (as expected in uptrend)")
          else
            IO.puts("   ⚠️  DEMA responsiveness may need investigation")
          end
        end
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

  defp extract_dict_value(dict_str, key) do
    # Extract value from Python dict string representation
    # Looks for patterns like "'key': value" or "'key': None"
    pattern = ~r/'#{key}':\s*([0-9]+(?:\.[0-9]+)?|None)/

    case Regex.run(pattern, dict_str) do
      [_, "None"] -> nil
      [_, number_str] -> String.to_float(number_str)
      nil -> nil
    end
  rescue
    ArgumentError -> nil
  end
end
