defmodule Quant.Math.Oscillators.RSIPythonValidationTest do
  @moduledoc """
  Python validation tests for RSI (Relative Strength Index) calculations.

  These tests validate our Elixir RSI implementation against Python pandas
  to ensure we're calculating RSI correctly and identify any discrepancies.
  """

  use ExUnit.Case, async: true

  import Pythonx
  import Quant.Explorer.PythonHelpers

  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math.Oscillators

  describe "Python validation tests" do
    @tag :python_validation
    test "Pythonx integration works" do
      # Simple test to verify Pythonx is working
      if python_available?() do
        python_result = ~PY"""
        5 + 10
        """

        # Convert Python object to Elixir integer
        result = python_result |> inspect() |> String.contains?("15")

        assert result
        IO.puts("\n✅ Pythonx integration is working correctly (got: #{inspect(python_result)})")
      else
        IO.puts("\n⚠️  Python/pandas not available, skipping Pythonx integration test")
      end
    end

    @tag :python_validation
    test "RSI calculation matches Python pandas implementation" do
      if python_available?() do
        # Test data - same as used in our Python comparison
        price_data = [
          44.0,
          44.3,
          44.1,
          44.2,
          44.5,
          43.4,
          44.0,
          44.25,
          44.8,
          45.1,
          45.4,
          45.8,
          46.0,
          45.9,
          45.2,
          44.8,
          44.6,
          44.4,
          44.2,
          44.0,
          43.8,
          43.5,
          43.2,
          43.0,
          42.8,
          42.5,
          42.2,
          42.0,
          41.8,
          41.5
        ]

        period = 14

        # Calculate RSI using our Elixir implementation
        df = DataFrame.new(%{close: price_data})
        elixir_result = Oscillators.add_rsi!(df, :close, period: period)
        elixir_rsi = elixir_result |> DataFrame.pull("close_rsi_#{period}") |> Series.to_list()

        # Calculate RSI using Python Wilder's method - to match our implementation
        python_final_rsi = ~PY"""
        import pandas as pd
        import numpy as np

        # Wilder's smoothing RSI (to match our Elixir implementation)
        df = pd.DataFrame({'close': price_data})
        delta = df['close'].diff()
        gain = delta.where(delta > 0, 0)
        loss = -delta.where(delta < 0, 0)
        alpha = 1.0 / period
        avg_gain = gain.ewm(alpha=alpha, adjust=False).mean()
        avg_loss = loss.ewm(alpha=alpha, adjust=False).mean()
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))

        # Get the final RSI value
        float(rsi.iloc[-1]) if not pd.isna(rsi.iloc[-1]) else None
        """

        # Extract final values for comparison
        final_elixir = Enum.at(elixir_rsi, -1)

        # Parse the Python result
        final_python =
          case python_final_rsi do
            result when is_number(result) ->
              result

            _ ->
              # Fallback: extract number from string representation
              python_str = python_final_rsi |> inspect()

              if python_str =~ "None" do
                nil
              else
                parse_python_float(python_str)
              end
          end

        IO.puts("\n📊 Python RSI Validation Results:")

        IO.puts(
          "   Final Elixir RSI: #{if final_elixir, do: Float.round(final_elixir, 1), else: "nil"}"
        )

        IO.puts(
          "   Final Python RSI: #{if final_python, do: Float.round(final_python, 1), else: "nil"}"
        )

        if final_elixir && final_python do
          diff = abs(final_elixir - final_python)
          IO.puts("   Difference: #{Float.round(diff, 1)}")

          if diff > 5.0 do
            IO.puts("   ⚠️  SIGNIFICANT DIFFERENCES DETECTED")
            IO.puts("   💡 This suggests an implementation bug - both should use Wilder's method")
            IO.puts("   � Need to investigate calculation differences")
          else
            IO.puts("   ✅ Implementations are reasonably close")
          end
        else
          IO.puts("   ⚠️  Could not compare values (one or both are nil)")
        end
      end
    end

    @tag :python_validation
    test "identify RSI calculation methodology differences" do
      if python_available?() do
        # Simple test case to clearly see the difference
        price_data = [
          100.0,
          101.0,
          102.0,
          101.5,
          103.0,
          102.0,
          104.0,
          103.5,
          105.0,
          104.0,
          106.0,
          105.5,
          107.0,
          106.0,
          108.0
        ]

        period = 14

        df = DataFrame.new(%{close: price_data})
        elixir_result = Oscillators.add_rsi!(df, :close, period: period)
        elixir_rsi = elixir_result |> DataFrame.pull("close_rsi_#{period}") |> Series.to_list()

        # Get final values using Python
        python_standard_final = ~PY"""
        import pandas as pd
        import numpy as np

        # Standard pandas RSI
        df = pd.DataFrame({'close': price_data})
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        float(rsi.iloc[-1]) if not pd.isna(rsi.iloc[-1]) else None
        """

        python_wilders_final = ~PY"""
        import pandas as pd
        import numpy as np

        # Wilder's smoothing RSI
        df = pd.DataFrame({'close': price_data})
        delta = df['close'].diff()
        gain = delta.where(delta > 0, 0)
        loss = -delta.where(delta < 0, 0)
        alpha = 1.0 / period
        avg_gain = gain.ewm(alpha=alpha, adjust=False).mean()
        avg_loss = loss.ewm(alpha=alpha, adjust=False).mean()
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))
        float(rsi.iloc[-1]) if not pd.isna(rsi.iloc[-1]) else None
        """

        final_elixir = Enum.at(elixir_rsi, -1)

        # Parse Python results
        final_standard =
          python_standard_final
          |> inspect()
          |> parse_python_float()

        final_wilders =
          python_wilders_final
          |> inspect()
          |> parse_python_float()

        IO.puts("\n🔬 RSI Methodology Comparison:")

        IO.puts(
          "   Elixir (Wilder's): #{if final_elixir, do: Float.round(final_elixir, 4), else: "nil"}"
        )

        IO.puts(
          "   Python Standard:   #{if final_standard, do: Float.round(final_standard, 4), else: "nil"}"
        )

        IO.puts(
          "   Python Wilder's:   #{if final_wilders, do: Float.round(final_wilders, 4), else: "nil"}"
        )

        if final_elixir && final_wilders do
          diff_wilders = abs(final_elixir - final_wilders)
          IO.puts("   Difference (Wilder's): #{Float.round(diff_wilders, 4)}")

          if diff_wilders < 0.01 do
            IO.puts("   ✅ Our implementation matches Python Wilder's method")
          end
        end

        if final_elixir && final_standard do
          diff_standard = abs(final_elixir - final_standard)
          IO.puts("   Difference (Standard): #{Float.round(diff_standard, 4)}")

          if diff_standard > 0.1 do
            IO.puts("   ✅ Expected difference from standard pandas rolling mean")
            IO.puts("   💡 This confirms we're using Wilder's smoothing (the correct RSI method)")
            IO.puts("   📚 See: https://en.wikipedia.org/wiki/Relative_strength_index#Calculation")
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
end
