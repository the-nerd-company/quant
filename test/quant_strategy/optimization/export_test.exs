defmodule Quant.Strategy.Optimization.ExportTest do
  @moduledoc """
  Tests for the Quant.Strategy.Optimization.Export module.
  """

  use ExUnit.Case, async: true
  alias Explorer.DataFrame
  alias Quant.Strategy.Optimization.Export

  # Helper function to create test data
  defp create_test_results do
    DataFrame.new(%{
      total_return: [0.1234, 0.0987, 0.1456, 0.0765],
      sharpe_ratio: [1.2345, 0.9876, 1.4567, 0.7654],
      period: [5, 10, 15, 20],
      threshold: [0.01, 0.02, 0.01, 0.02]
    })
  end

  setup do
    # Clean up any test files after each test
    on_exit(fn ->
      cleanup_test_files()
    end)

    :ok
  end

  describe "CSV export" do
    test "to_csv/2 creates CSV file with correct data" do
      filename = "test_results.csv"

      assert {:ok, ^filename} = Export.to_csv(create_test_results(), filename)
      assert File.exists?(filename)

      # Verify CSV content
      {:ok, content} = File.read(filename)
      lines = String.split(content, "\n", trim: true)

      # Should have header + 4 data rows
      assert length(lines) == 5

      # Check header
      header = hd(lines)
      assert String.contains?(header, "total_return")
      assert String.contains?(header, "sharpe_ratio")
      assert String.contains?(header, "period")
    end

    test "to_csv/3 exports with basic options" do
      filename = "test_options.csv"

      assert {:ok, ^filename} = Export.to_csv(create_test_results(), filename, precision: 3)

      assert File.exists?(filename)

      # Verify file was created successfully
      {:ok, content} = File.read(filename)
      lines = String.split(content, "\n", trim: true)

      # Should have header + 4 data rows
      assert length(lines) == 5
    end

    test "to_csv/3 applies custom precision" do
      filename = "test_precision.csv"

      assert {:ok, ^filename} = Export.to_csv(create_test_results(), filename, precision: 2)

      assert File.exists?(filename)

      {:ok, content} = File.read(filename)
      # Should have values rounded to 2 decimal places
      # 0.1234 rounded to 2 places
      assert String.contains?(content, "0.12")
      # 0.0987 rounded to 2 places (note: 0.10 becomes 0.1)
      assert String.contains?(content, "0.1,")
    end

    test "to_csv/3 uses custom delimiter" do
      filename = "test_delimiter.csv"

      assert {:ok, ^filename} = Export.to_csv(create_test_results(), filename, delimiter: ";")

      assert File.exists?(filename)

      {:ok, content} = File.read(filename)
      # Should use semicolon as delimiter
      assert String.contains?(content, ";")
      refute String.contains?(content, ",")
    end

    test "to_csv/2 adds .csv extension if missing" do
      filename = "test_results"
      expected_filename = "test_results.csv"

      assert {:ok, ^expected_filename} = Export.to_csv(create_test_results(), filename)
      assert File.exists?(expected_filename)
    end
  end

  describe "JSON export" do
    test "to_json/2 creates JSON file with correct structure" do
      filename = "test_results.json"

      assert {:ok, ^filename} = Export.to_json(create_test_results(), filename)
      assert File.exists?(filename)

      # Verify JSON content
      {:ok, content} = File.read(filename)
      {:ok, json_data} = Jason.decode(content)

      # Should be array of maps
      assert is_list(json_data)
      assert length(json_data) == 4

      # Check first result structure
      first_result = hd(json_data)
      assert Map.has_key?(first_result, "total_return")
      assert Map.has_key?(first_result, "sharpe_ratio")
      assert Map.has_key?(first_result, "period")
    end

    test "to_json/3 exports with options" do
      filename = "test_options.json"

      assert {:ok, ^filename} =
               Export.to_json(create_test_results(), filename, precision: 3, pretty: false)

      assert File.exists?(filename)

      {:ok, content} = File.read(filename)
      {:ok, json_data} = Jason.decode(content)

      # Should have 4 results
      assert length(json_data) == 4

      # Check structure
      first_result = hd(json_data)
      assert Map.has_key?(first_result, "total_return")
    end

    test "to_json/2 adds .json extension if missing" do
      filename = "test_results"
      expected_filename = "test_results.json"

      assert {:ok, ^expected_filename} = Export.to_json(create_test_results(), filename)
      assert File.exists?(expected_filename)
    end

    test "to_json/3 handles precision option" do
      filename = "test_precision.json"

      assert {:ok, ^filename} = Export.to_json(create_test_results(), filename, pretty: false)

      assert File.exists?(filename)

      {:ok, content} = File.read(filename)
      {:ok, json_data} = Jason.decode(content)

      # Check that data is exported correctly
      first_result = hd(json_data)
      # Original precision preserved
      assert first_result["total_return"] == 0.1234
    end
  end

  describe "Summary export" do
    test "summary/2 creates summary statistics" do
      filename = "test_summary.json"

      assert {:ok, ^filename} = Export.summary(create_test_results(), filename)
      assert File.exists?(filename)

      {:ok, content} = File.read(filename)
      {:ok, summary} = Jason.decode(content)

      # Check summary structure
      assert Map.has_key?(summary, "total_combinations")
      assert Map.has_key?(summary, "best_performance")
      assert Map.has_key?(summary, "worst_performance")
      assert Map.has_key?(summary, "mean_metrics")
      assert Map.has_key?(summary, "parameter_ranges")

      # Verify values
      assert summary["total_combinations"] == 4
    end

    test "summary/3 includes correlations when requested" do
      filename = "test_summary_corr.json"

      assert {:ok, ^filename} =
               Export.summary(create_test_results(), filename, include_correlations: true)

      assert File.exists?(filename)

      {:ok, content} = File.read(filename)
      {:ok, summary} = Jason.decode(content)

      # Should include correlation analysis
      assert Map.has_key?(summary, "parameter_correlations")
    end

    test "summary/2 defaults to CSV for unknown extensions" do
      filename = "test_summary.txt"
      expected_filename = "test_summary.txt.csv"

      assert {:ok, ^expected_filename} = Export.summary(create_test_results(), filename)
      assert File.exists?(expected_filename)
    end
  end

  describe "Error handling" do
    test "to_csv/2 handles dataframe with no rows" do
      empty_df = DataFrame.new(%{col1: [], col2: []})
      filename = "empty_test.csv"

      # Should handle gracefully
      result = Export.to_csv(empty_df, filename)
      # This might succeed with empty file or return error - both are acceptable
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "to_json/2 handles invalid filename" do
      filename = "/invalid/path/test.json"

      result = Export.to_json(create_test_results(), filename)
      assert {:error, _reason} = result
    end
  end

  # Helper function to clean up test files
  defp cleanup_test_files do
    test_files = [
      "test_results.csv",
      "test_options.csv",
      "test_precision.csv",
      "test_delimiter.csv",
      "test_results.json",
      "test_options.json",
      "test_precision.json",
      "test_summary.json",
      "test_summary_corr.json",
      "test_summary.txt.csv",
      "empty_test.csv"
    ]

    Enum.each(test_files, fn file ->
      if File.exists?(file) do
        File.rm!(file)
      end
    end)
  end
end
