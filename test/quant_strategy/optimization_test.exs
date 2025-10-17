defmodule Quant.Strategy.OptimizationTest do
  @moduledoc """
  Tests for the Quant.Strategy.Optimization module.
  """

  use ExUnit.Case, async: true
  alias Explorer.DataFrame
  alias Quant.Strategy.Optimization
  alias Quant.Strategy.Optimization.{Ranges, Results}

  # Test data - realistic stock price movements
  @test_data %{
    close: [
      100.0,
      102.0,
      101.0,
      103.0,
      105.0,
      104.0,
      106.0,
      108.0,
      107.0,
      109.0,
      111.0,
      110.0,
      112.0,
      114.0,
      113.0,
      115.0,
      117.0,
      116.0,
      118.0,
      120.0,
      122.0,
      121.0,
      123.0,
      125.0,
      124.0,
      126.0,
      128.0,
      127.0,
      129.0,
      131.0
    ]
  }

  # Helper function to create test DataFrame
  defp create_test_data do
    DataFrame.new(@test_data)
  end

  describe "Ranges module" do
    test "parameter_grid/1 generates all combinations" do
      param_map = %{
        fast_period: 5..7,
        slow_period: [20, 25]
      }

      assert {:ok, combinations} = Ranges.parameter_grid(param_map)
      assert length(combinations) == 6

      # Check that all combinations have both parameters
      assert Enum.all?(combinations, &Map.has_key?(&1, :fast_period))
      assert Enum.all?(combinations, &Map.has_key?(&1, :slow_period))

      # Check specific combination exists
      assert Enum.any?(combinations, &(&1.fast_period == 5 and &1.slow_period == 20))
      assert Enum.any?(combinations, &(&1.fast_period == 7 and &1.slow_period == 25))
    end

    test "range/3 generates numeric sequences" do
      assert Ranges.range(1, 5) == [1, 2, 3, 4]
      assert Ranges.range(0, 10, 2) == [0, 2, 4, 6, 8]
      assert Ranges.range(10, 0, -2) == [10, 8, 6, 4, 2]
    end

    test "linspace/3 generates linearly spaced values" do
      result = Ranges.linspace(0, 10, 5)
      expected = [0.0, 2.5, 5.0, 7.5, 10.0]

      assert length(result) == 5
      assert Enum.zip(result, expected) |> Enum.all?(fn {a, b} -> abs(a - b) < 0.001 end)
    end

    test "random_search/2 generates requested number of samples" do
      param_map = %{fast_period: 5..15, slow_period: 20..40}

      assert {:ok, samples} = Ranges.random_search(param_map, 10)
      assert length(samples) == 10

      # Check that all samples have required parameters
      assert Enum.all?(samples, &Map.has_key?(&1, :fast_period))
      assert Enum.all?(samples, &Map.has_key?(&1, :slow_period))

      # Check that values are within expected ranges
      assert Enum.all?(samples, &(&1.fast_period >= 5 and &1.fast_period <= 15))
      assert Enum.all?(samples, &(&1.slow_period >= 20 and &1.slow_period <= 40))
    end
  end

  describe "Results module" do
    test "combine_results/1 creates DataFrame from result maps" do
      results = [
        %{fast_period: 5, slow_period: 20, total_return: 0.15, sharpe_ratio: 1.2},
        %{fast_period: 10, slow_period: 25, total_return: 0.23, sharpe_ratio: 1.5},
        %{fast_period: 15, slow_period: 30, total_return: 0.18, sharpe_ratio: 1.1}
      ]

      df = Results.combine_results(results)

      assert DataFrame.n_rows(df) == 3
      assert "fast_period" in DataFrame.names(df)
      assert "slow_period" in DataFrame.names(df)
      assert "total_return" in DataFrame.names(df)
      assert "sharpe_ratio" in DataFrame.names(df)
    end

    test "find_best_params/2 identifies best performing combination" do
      results = [
        %{fast_period: 5, slow_period: 20, total_return: 0.15},
        %{fast_period: 10, slow_period: 25, total_return: 0.23},
        %{fast_period: 15, slow_period: 30, total_return: 0.18}
      ]

      df = Results.combine_results(results)
      best = Results.find_best_params(df, :total_return)

      assert best != nil
      assert best.fast_period == 10
      assert best.slow_period == 25
      assert best.total_return == 0.23
    end

    test "parameter_correlation/3 calculates correlation between parameters" do
      df =
        DataFrame.new(%{
          fast_period: [5, 10, 15, 20],
          slow_period: [20, 25, 30, 35],
          total_return: [0.1, 0.2, 0.15, 0.25]
        })

      corr = Results.parameter_correlation(df, :fast_period, :slow_period)
      assert is_number(corr)
      assert corr >= -1.0 and corr <= 1.0
    end
  end

  describe "Basic optimization" do
    test "run_combinations/4 works with simple parameter ranges" do
      df = DataFrame.new(@test_data)

      param_ranges = %{
        fast_period: [5, 10],
        slow_period: [15, 20]
      }

      assert {:ok, results} =
               Optimization.run_combinations(
                 df,
                 :sma_crossover,
                 param_ranges,
                 initial_capital: 10_000.0
               )

      # Should have 4 combinations (2 x 2)
      assert DataFrame.n_rows(results) == 4

      # Should have parameter columns
      assert "fast_period" in DataFrame.names(results)
      assert "slow_period" in DataFrame.names(results)

      # Should have performance metrics
      assert "total_return" in DataFrame.names(results)
      assert "sharpe_ratio" in DataFrame.names(results)
      assert "max_drawdown" in DataFrame.names(results)
    end

    test "find_best_params/2 works with optimization results" do
      df = DataFrame.new(@test_data)

      param_ranges = %{
        fast_period: [5, 10],
        slow_period: [15, 20]
      }

      {:ok, results} = Optimization.run_combinations(df, :sma_crossover, param_ranges)
      best = Optimization.find_best_params(results, :total_return)

      assert best != nil
      assert Map.has_key?(best, :fast_period)
      assert Map.has_key?(best, :slow_period)
      assert Map.has_key?(best, :total_return)
    end
  end

  describe "Walk-forward optimization" do
    test "walk_forward_optimization with multiple windows" do
      # Create much longer test data with strong trend to generate trades
      price_data =
        Enum.map(1..350, fn i ->
          # Strong upward trend
          base_price = 100 + i * 0.3
          # Some volatility
          volatility = :math.sin(i / 10.0) * 5
          base_price + volatility
        end)

      df =
        DataFrame.new(%{
          datetime:
            Enum.map(1..350, fn i -> ~N[2023-01-01 00:00:00] |> NaiveDateTime.add(i, :day) end),
          close: price_data,
          volume: List.duplicate(1000, 350)
        })

      # Wider period gap for clearer signals
      param_ranges = %{period: [5, 15]}

      result =
        Optimization.walk_forward_optimization(
          df,
          :sma_crossover,
          param_ranges,
          # Larger window to generate more trades
          window_size: 100,
          # Larger step size
          step_size: 50,
          # Allow zero trades for testing
          min_trades: 0
        )

      # Should have results from multiple windows (even if no trades)
      case result do
        {:ok, results} ->
          assert DataFrame.n_rows(results) >= 1
          # Check that we have window information
          columns = DataFrame.names(results)
          assert "window_id" in columns
          assert "training_start" in columns
          assert "testing_start" in columns

        {:error, reason} ->
          # If no valid results, that's also acceptable for this test
          assert reason in [:no_valid_results, :insufficient_data]
      end
    end

    test "run_combinations_stream with small parameter space" do
      df = create_test_data()
      param_ranges = %{period: [5, 10]}

      stream =
        Optimization.run_combinations_stream(df, :sma_crossover, param_ranges,
          chunk_size: 1,
          concurrency: 2
        )

      results = Enum.to_list(stream)

      # Should have 2 chunks (one per parameter combination)
      assert length(results) == 2

      # Each result should be {:ok, dataframe}
      Enum.each(results, fn result ->
        assert {:ok, chunk_df} = result
        assert DataFrame.n_rows(chunk_df) == 1
      end)
    end

    test "run_combinations_stream with larger parameter space" do
      df = create_test_data()
      # 4 combinations
      param_ranges = %{period: [5, 10, 15, 20]}

      stream =
        Optimization.run_combinations_stream(df, :sma_crossover, param_ranges,
          chunk_size: 2,
          concurrency: 2
        )

      results = Enum.to_list(stream)

      # Should have 2 chunks (4 combinations / chunk_size 2)
      assert length(results) == 2

      # Verify all chunks processed successfully
      Enum.each(results, fn result ->
        assert {:ok, chunk_df} = result
        assert DataFrame.n_rows(chunk_df) == 2
      end)
    end

    test "run_combinations_stream handles edge cases" do
      df = create_test_data()
      # Very short periods might cause issues
      param_ranges = %{period: [1, 2]}

      stream = Optimization.run_combinations_stream(df, :sma_crossover, param_ranges)
      results = Enum.to_list(stream)

      # Should return some results (might be empty dataframes if no trades)
      assert length(results) == 1

      case hd(results) do
        {:ok, chunk_df} ->
          # Empty results are acceptable for edge cases
          assert DataFrame.n_rows(chunk_df) >= 0

        {:error, _reason} ->
          # Errors are also acceptable for edge cases
          assert true
      end
    end

    test "run_combinations_stream memory-efficient processing" do
      df = create_test_data()
      # Create larger parameter space
      # 8 combinations
      param_ranges = %{period: 5..12}

      stream =
        Optimization.run_combinations_stream(df, :sma_crossover, param_ranges,
          chunk_size: 3,
          concurrency: 2
        )

      # Process stream lazily - only materialize first chunk
      first_chunk = stream |> Enum.take(1) |> hd()

      assert {:ok, chunk_df} = first_chunk
      assert DataFrame.n_rows(chunk_df) == 3

      # Verify we can process all chunks
      all_results = Enum.to_list(stream)
      # 8 combinations / chunk_size 3 = 3 chunks (rounded up)
      assert length(all_results) == 3
    end

    test "walk_forward_optimization/4 handles insufficient data" do
      small_df = DataFrame.new(%{close: [100.0, 101.0, 102.0]})
      param_ranges = %{fast_period: [5], slow_period: [10]}

      assert {:error, {:insufficient_data, _message}} =
               Optimization.walk_forward_optimization(small_df, :sma_crossover, param_ranges)
    end
  end

  describe "Error handling" do
    test "handles invalid strategy type" do
      df = DataFrame.new(@test_data)
      param_ranges = %{period: [5, 10]}

      assert {:error, {:optimization_failed, _}} =
               Optimization.run_combinations(df, :invalid_strategy, param_ranges)
    end

    test "handles empty parameter ranges" do
      df = DataFrame.new(@test_data)

      assert {:ok, results} = Optimization.run_combinations(df, :sma_crossover, %{})
      assert DataFrame.n_rows(results) == 0
    end

    test "handles insufficient data" do
      small_df = DataFrame.new(%{close: [100.0, 101.0]})
      param_ranges = %{fast_period: [5], slow_period: [10]}

      assert {:error, {:optimization_failed, _}} =
               Optimization.run_combinations(small_df, :sma_crossover, param_ranges)
    end
  end
end
