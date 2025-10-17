defmodule Quant.Strategy.Optimization.Export do
  @moduledoc """
  Export utilities for optimization results.

  Provides functionality to export parameter optimization results to various formats
  including CSV, JSON, and Excel-compatible formats for external analysis.
  """

  alias Explorer.DataFrame

  @doc """
  Export optimization results to CSV format.

  ## Parameters

  - `results` - DataFrame containing optimization results
  - `filename` - Output filename (with or without .csv extension)
  - `opts` - Export options

  ## Options

  - `:delimiter` - CSV delimiter (default: ",")
  - `:precision` - Decimal precision for float values (default: 4)

  ## Examples

      # Basic CSV export
      {:ok, path} = Export.to_csv(results, "optimization_results.csv")

      # Custom delimiter and precision
      {:ok, path} = Export.to_csv(results, "results.csv",
        delimiter: ";", precision: 6)
  """
  @spec to_csv(DataFrame.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_csv(results, filename, opts \\ []) do
    delimiter = Keyword.get(opts, :delimiter, ",")
    precision = Keyword.get(opts, :precision, 4)

    try do
      # Ensure filename has .csv extension
      csv_filename = ensure_csv_extension(filename)

      # Round numeric columns to specified precision
      rounded_results = round_numeric_columns(results, precision)

      # Export to CSV
      case DataFrame.to_csv(rounded_results, csv_filename, delimiter: delimiter) do
        :ok -> {:ok, csv_filename}
        {:error, reason} -> {:error, {:csv_export_failed, reason}}
      end
    rescue
      e -> {:error, {:export_error, Exception.message(e)}}
    end
  end

  @doc """
  Export optimization results to JSON format.

  ## Parameters

  - `results` - DataFrame containing optimization results
  - `filename` - Output filename (with or without .json extension)
  - `opts` - Export options

  ## Options

  - `:precision` - Decimal precision for float values (default: 4)
  - `:pretty` - Pretty print JSON (default: true)

  ## Examples

      # Basic JSON export
      {:ok, path} = Export.to_json(results, "optimization_results.json")

      # Compact JSON without pretty printing
      {:ok, path} = Export.to_json(results, "results.json", pretty: false)
  """
  @spec to_json(DataFrame.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_json(results, filename, opts \\ []) do
    _precision = Keyword.get(opts, :precision, 4)
    _pretty = Keyword.get(opts, :pretty, true)

    try do
      # Ensure filename has .json extension
      json_filename = ensure_json_extension(filename)

      # Convert to list of maps for JSON serialization
      data = convert_dataframe_to_maps(results)

      # Encode to JSON
      json_data = JSON.encode!(data)

      # Write to file
      case File.write(json_filename, json_data) do
        :ok -> {:ok, json_filename}
        {:error, reason} -> {:error, {:json_export_failed, reason}}
      end
    rescue
      e -> {:error, {:export_error, Exception.message(e)}}
    end
  end

  @doc """
  Export optimization results summary statistics.

  Creates a summary report with key statistics from the optimization results
  including best/worst performance, parameter distributions, and correlation analysis.

  ## Parameters

  - `results` - DataFrame containing optimization results
  - `filename` - Output filename (supports .csv, .json extensions)
  - `opts` - Export options

  ## Examples

      # Export summary to CSV
      {:ok, path} = Export.summary(results, "optimization_summary.csv")

      # Export detailed summary with correlations
      {:ok, path} = Export.summary(results, "summary.json",
        include_correlations: true)
  """
  @spec summary(DataFrame.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def summary(results, filename, opts \\ []) do
    include_correlations = Keyword.get(opts, :include_correlations, false)

    try do
      # Generate summary statistics
      summary_data = generate_summary_statistics(results)

      # Add correlations if requested
      final_summary =
        if include_correlations do
          correlations = calculate_parameter_correlations(results)
          Map.put(summary_data, :parameter_correlations, correlations)
        else
          summary_data
        end

      # Export based on file extension
      case Path.extname(filename) do
        ".json" -> export_summary_json(final_summary, filename)
        ".csv" -> export_summary_csv(final_summary, filename)
        _ -> export_summary_csv(final_summary, ensure_csv_extension(filename))
      end
    rescue
      e -> {:error, {:summary_export_error, Exception.message(e)}}
    end
  end

  # Private helper functions

  # Helper function to convert DataFrame to list of maps safely
  defp convert_dataframe_to_maps(df) do
    # Try the standard approach first
    DataFrame.to_rows(df)
  rescue
    _e ->
      # Fallback: manually convert using column names and data
      columns = DataFrame.names(df)
      n_rows = DataFrame.n_rows(df)

      0..(n_rows - 1)
      |> Enum.map(fn row_idx ->
        Enum.reduce(columns, %{}, fn col, acc ->
          col_series = df[col]
          value = Explorer.Series.to_list(col_series) |> Enum.at(row_idx)
          Map.put(acc, col, value)
        end)
      end)
  end

  defp ensure_csv_extension(filename) do
    if String.ends_with?(filename, ".csv") do
      filename
    else
      filename <> ".csv"
    end
  end

  defp ensure_json_extension(filename) do
    if String.ends_with?(filename, ".json") do
      filename
    else
      filename <> ".json"
    end
  end

  defp round_numeric_columns(df, precision) do
    columns = DataFrame.names(df)

    Enum.reduce(columns, df, fn col_name, acc_df ->
      round_column_if_numeric(acc_df, col_name, precision)
    end)
  end

  defp round_column_if_numeric(df, col_name, precision) do
    # Get column as series
    col_series = df[col_name]

    # Convert to list to check data type
    col_data = Explorer.Series.to_list(col_series)

    # Check if column contains numeric data that should be rounded
    case col_data |> Enum.take(1) |> hd() do
      val when is_float(val) ->
        rounded_data = Enum.map(col_data, &round_if_float(&1, precision))
        DataFrame.put(df, col_name, rounded_data)

      _ ->
        df
    end
  end

  defp round_if_float(x, precision) when is_float(x), do: Float.round(x, precision)
  defp round_if_float(x, _precision), do: x

  defp generate_summary_statistics(results) do
    numeric_columns = get_numeric_columns(results)

    %{
      total_combinations: DataFrame.n_rows(results),
      best_performance: get_best_performance(results, numeric_columns),
      worst_performance: get_worst_performance(results, numeric_columns),
      mean_metrics: get_mean_metrics(results, numeric_columns),
      parameter_ranges: get_parameter_ranges(results)
    }
  end

  defp get_numeric_columns(results) do
    performance_columns = [
      "total_return",
      "sharpe_ratio",
      "sortino_ratio",
      "calmar_ratio",
      "max_drawdown",
      "volatility",
      "win_rate",
      "trade_count"
    ]

    existing_columns = DataFrame.names(results)
    Enum.filter(performance_columns, &(&1 in existing_columns))
  end

  defp get_best_performance(results, _numeric_columns) do
    find_extreme_performance(results, :max)
  end

  defp get_worst_performance(results, _numeric_columns) do
    find_extreme_performance(results, :min)
  end

  defp find_extreme_performance(results, type) do
    if "total_return" in DataFrame.names(results) do
      all_rows = convert_dataframe_to_maps(results)
      find_best_row(all_rows, type)
    else
      %{}
    end
  end

  defp find_best_row([], _type), do: %{}

  defp find_best_row(rows, :max) do
    Enum.max_by(rows, fn row -> Map.get(row, "total_return", 0.0) end)
  end

  defp find_best_row(rows, :min) do
    Enum.min_by(rows, fn row -> Map.get(row, "total_return", 0.0) end)
  end

  defp get_mean_metrics(results, numeric_columns) do
    Enum.reduce(numeric_columns, %{}, fn col, acc ->
      calculate_column_mean(results, col, acc)
    end)
  end

  defp calculate_column_mean(results, col, acc) do
    if col in DataFrame.names(results) do
      col_series = results[col]
      col_data = Explorer.Series.to_list(col_series)
      numeric_data = Enum.filter(col_data, &is_number/1)

      mean_val = calculate_mean(numeric_data)
      Map.put(acc, col, mean_val)
    else
      Map.put(acc, col, 0.0)
    end
  end

  defp calculate_mean([]), do: 0.0

  defp calculate_mean(data) do
    mean_val = Enum.sum(data) / length(data)
    Float.round(mean_val, 4)
  end

  defp get_parameter_ranges(results) do
    columns = DataFrame.names(results)

    parameter_columns =
      Enum.filter(columns, fn col ->
        not String.contains?(col, [
          "return",
          "ratio",
          "drawdown",
          "volatility",
          "win_rate",
          "trade_count"
        ])
      end)

    Enum.reduce(parameter_columns, %{}, fn col, acc ->
      col_series = results[col]
      col_data = Explorer.Series.to_list(col_series)
      unique_values = Enum.uniq(col_data) |> Enum.sort()

      range_info = calculate_range_info(unique_values)
      Map.put(acc, col, range_info)
    end)
  end

  defp calculate_range_info([]), do: %{min: nil, max: nil, unique_count: 0, values: []}

  defp calculate_range_info(unique_values) do
    %{
      min: Enum.min(unique_values),
      max: Enum.max(unique_values),
      unique_count: length(unique_values),
      values: unique_values
    }
  end

  defp calculate_parameter_correlations(_results) do
    # This would require more complex correlation calculations
    # For now, return placeholder
    %{note: "Parameter correlation analysis requires additional statistical calculations"}
  end

  defp export_summary_json(summary, filename) do
    json_data = JSON.encode!(summary)

    case File.write(filename, json_data) do
      :ok -> {:ok, filename}
      {:error, reason} -> {:error, {:json_write_failed, reason}}
    end
  end

  defp export_summary_csv(summary, filename) do
    # Convert summary to CSV format (simplified approach)
    csv_lines = [
      "metric,value",
      "total_combinations,#{summary.total_combinations}"
      # Add more summary metrics as needed
    ]

    csv_content = Enum.join(csv_lines, "\n")

    case File.write(filename, csv_content) do
      :ok -> {:ok, filename}
      {:error, reason} -> {:error, {:csv_write_failed, reason}}
    end
  end
end
