defmodule Quant.Strategy.SignalTest do
  @moduledoc """
  Tests for trading signal generation functionality.
  """

  use ExUnit.Case, async: true
  alias Explorer.DataFrame
  alias Explorer.Series
  alias Quant.Math
  alias Quant.Strategy.Signal

  # Test data that should generate clear crossover signals
  @crossover_data %{
    close: [98.0, 99.0, 100.0, 101.0, 102.0, 103.0, 104.0, 105.0, 106.0, 107.0]
  }

  describe "generate/3 for SMA crossover" do
    test "generates crossover signals correctly" do
      # Create DataFrame with pre-calculated SMAs for easier testing
      df =
        DataFrame.new(@crossover_data)
        |> Math.add_sma!(:close, period: 3)
        |> Math.add_sma!(:close, period: 5)

      strategy = %{
        type: :sma_crossover,
        indicator: :sma,
        fast_period: 3,
        slow_period: 5,
        column: :close
      }

      assert {:ok, result_df} = Signal.generate(df, strategy)

      # Check signal columns were added
      assert "signal" in DataFrame.names(result_df)
      assert "signal_strength" in DataFrame.names(result_df)
      assert "signal_reason" in DataFrame.names(result_df)

      # Verify signal values are valid
      signals = DataFrame.pull(result_df, "signal") |> Series.to_list()
      assert Enum.all?(signals, fn s -> s in [-1, 0, 1] end)

      # Verify signal strength is between 0 and 1
      strengths = DataFrame.pull(result_df, "signal_strength") |> Series.to_list()
      assert Enum.all?(strengths, fn s -> is_number(s) and s >= 0.0 and s <= 1.0 end)
    end

    test "handles missing moving average columns" do
      # No SMA columns added
      df = DataFrame.new(@crossover_data)

      strategy = %{
        type: :sma_crossover,
        indicator: :sma,
        fast_period: 3,
        slow_period: 5,
        column: :close
      }

      assert {:error, {:signal_generation_failed, _}} = Signal.generate(df, strategy)
    end
  end

  describe "generate/3 for RSI threshold" do
    test "generates RSI threshold signals" do
      # Create test data with RSI that should trigger signals
      extended_data = %{
        close: [100.0] ++ Enum.to_list(95..105) ++ [105.0, 104.0, 103.0, 102.0, 101.0]
      }

      df =
        DataFrame.new(extended_data)
        |> Math.add_rsi!(:close, period: 14)

      strategy = %{
        type: :rsi_threshold,
        period: 14,
        oversold: 30,
        overbought: 70,
        column: :close
      }

      assert {:ok, result_df} = Signal.generate(df, strategy)

      # Check signal columns
      assert "signal" in DataFrame.names(result_df)
      assert "signal_strength" in DataFrame.names(result_df)
      assert "signal_reason" in DataFrame.names(result_df)

      # Verify signal values
      signals = DataFrame.pull(result_df, "signal") |> Series.to_list()
      assert Enum.all?(signals, fn s -> s in [-1, 0, 1] end)
    end

    test "handles custom RSI thresholds" do
      extended_data = %{
        # Flat data for predictable RSI
        close: List.duplicate(100.0, 20)
      }

      df =
        DataFrame.new(extended_data)
        |> Math.add_rsi!(:close, period: 14)

      strategy = %{
        type: :rsi_threshold,
        period: 14,
        # Custom threshold
        oversold: 25,
        # Custom threshold
        overbought: 75,
        column: :close
      }

      assert {:ok, result_df} = Signal.generate(df, strategy)

      # Most signals should be 0 (hold) for flat price data
      signals = DataFrame.pull(result_df, "signal") |> Series.to_list()
      hold_signals = Enum.count(signals, &(&1 == 0))
      # Majority should be hold signals
      assert hold_signals > length(signals) / 2
    end
  end

  describe "generate/3 for MACD crossover" do
    test "generates MACD crossover signals" do
      df =
        DataFrame.new(@crossover_data)
        |> Math.add_macd!(:close, fast_period: 3, slow_period: 5, signal_period: 3)
        |> Math.detect_macd_crossovers("close_macd_3_5", "close_signal_3")

      strategy = %{
        type: :macd_crossover,
        fast_period: 3,
        slow_period: 5,
        signal_period: 3,
        column: :close
      }

      assert {:ok, result_df} = Signal.generate(df, strategy)

      # Check signal columns
      assert "signal" in DataFrame.names(result_df)
      assert "signal_strength" in DataFrame.names(result_df)
      assert "signal_reason" in DataFrame.names(result_df)
    end

    test "handles missing MACD crossover column" do
      df =
        DataFrame.new(@crossover_data)
        |> Math.add_macd!(:close, fast_period: 3, slow_period: 5, signal_period: 3)

      # Intentionally not adding crossover detection

      strategy = %{
        type: :macd_crossover,
        fast_period: 3,
        slow_period: 5,
        signal_period: 3,
        column: :close
      }

      assert {:error, :missing_macd_crossover_column} = Signal.generate(df, strategy)
    end
  end

  describe "generate/3 for unsupported strategies" do
    test "returns error for unsupported strategy type" do
      df = DataFrame.new(@crossover_data)

      invalid_strategy = %{
        type: :invalid_strategy,
        column: :close
      }

      assert {:error, {:unsupported_strategy_type, :invalid_strategy}} =
               Signal.generate(df, invalid_strategy)
    end
  end

  describe "generate/3 for Bollinger Bands (placeholder)" do
    test "handles Bollinger Bands strategy (not implemented)" do
      df = DataFrame.new(@crossover_data)

      strategy = %{
        type: :bollinger_bands,
        period: 20,
        std_mult: 2.0,
        column: :close
      }

      assert {:ok, result_df} = Signal.generate(df, strategy)

      # Should return placeholder signals (all zeros)
      signals = DataFrame.pull(result_df, "signal") |> Series.to_list()
      assert Enum.all?(signals, &(&1 == 0))

      reasons = DataFrame.pull(result_df, "signal_reason") |> Series.to_list()
      assert Enum.all?(reasons, &(&1 == "bollinger_not_implemented"))
    end
  end
end
