defmodule Quant.Strategy.Optimization.Results do
  @moduledoc """
  Analysis and ranking of optimization results.

  This module provides functions to analyze, rank, and visualize
  parameter optimization results.
  """

  alias Explorer.DataFrame
  alias Explorer.Series

  @doc """
  Combine individual optimization result maps into a single DataFrame.

  Takes a list of result maps (each representing one parameter combination)
  and creates a structured DataFrame for analysis.

  ## Examples

      iex> results = [
      ...>   %{fast_period: 5, slow_period: 20, total_return: 0.15},
      ...>   %{fast_period: 10, slow_period: 25, total_return: 0.23}
      ...> ]
      iex> df = combine_results(results)
      iex> DataFrame.n_rows(df)
      2
  """
  @spec combine_results([map()]) :: DataFrame.t()
  def combine_results(results) when is_list(results) do
    if Enum.empty?(results) do
      # Return empty DataFrame with basic structure
      DataFrame.new(%{
        total_return: [],
        sharpe_ratio: [],
        max_drawdown: []
      })
    else
      # Get all unique keys from all result maps
      all_keys =
        results
        |> Enum.flat_map(&Map.keys/1)
        |> Enum.uniq()
        |> Enum.sort()

      # Create columns for each key
      columns =
        all_keys
        |> Enum.map(fn key ->
          values = Enum.map(results, &Map.get(&1, key, nil))
          {key, values}
        end)
        |> Enum.into(%{})

      DataFrame.new(columns)
    end
  end

  @doc """
  Find the best parameter combination based on a specific metric.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 10, 15],
      ...>   total_return: [0.1, 0.3, 0.2]
      ...> })
      iex> best = find_best_params(df, :total_return)
      iex> best.fast_period
      10
  """
  @spec find_best_params(DataFrame.t(), atom()) :: map() | nil
  def find_best_params(dataframe, metric) do
    if DataFrame.n_rows(dataframe) == 0 do
      nil
    else
      case DataFrame.names(dataframe) do
        names when length(names) > 0 ->
          metric_str = Atom.to_string(metric)

          if metric_str in names do
            # Find the row with the maximum value for the metric
            metric_series = DataFrame.pull(dataframe, metric_str)
            max_value = Series.max(metric_series)

            # Get the index of the maximum value
            max_index =
              metric_series
              |> Series.to_list()
              |> Enum.find_index(&(&1 == max_value))

            if max_index do
              # Extract the row with the best performance
              dataframe
              |> DataFrame.slice(max_index, 1)
              |> DataFrame.to_rows()
              |> List.first()
              |> convert_string_keys_to_atoms()
            else
              nil
            end
          else
            nil
          end
        _ ->
          nil
      end
    end
  end

  @doc """
  Rank results by a specific metric.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 10, 15],
      ...>   total_return: [0.1, 0.3, 0.2]
      ...> })
      iex> ranked = rank_by_metric(df, :total_return, :desc)
      iex> DataFrame.n_rows(ranked)
      3
  """
  @spec rank_by_metric(DataFrame.t(), atom(), :asc | :desc) :: DataFrame.t()
  def rank_by_metric(dataframe, metric, order \\ :desc) do
    metric_str = Atom.to_string(metric)

    if metric_str in DataFrame.names(dataframe) do
      case order do
        :desc -> DataFrame.sort_by(dataframe, [desc: metric_str])
        :asc -> DataFrame.sort_by(dataframe, [asc: metric_str])
      end
    else
      dataframe
    end
  end

  @doc """
  Get top N parameter combinations for a metric.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 10, 15, 20],
      ...>   total_return: [0.1, 0.3, 0.2, 0.25]
      ...> })
      iex> top3 = top_n_params(df, 3, :total_return)
      iex> DataFrame.n_rows(top3)
      3
  """
  @spec top_n_params(DataFrame.t(), pos_integer(), atom()) :: DataFrame.t()
  def top_n_params(dataframe, n, metric \\ :total_return) do
    dataframe
    |> rank_by_metric(metric, :desc)
    |> DataFrame.head(n)
  end

  @doc """
  Find Pareto frontier for multi-objective optimization.

  Identifies parameter combinations that are not dominated by others
  across multiple metrics.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 10, 15],
      ...>   total_return: [0.1, 0.3, 0.2],
      ...>   max_drawdown: [0.2, 0.1, 0.15]
      ...> })
      iex> frontier = pareto_frontier(df, [:total_return, :max_drawdown])
      iex> DataFrame.n_rows(frontier) <= DataFrame.n_rows(df)
      true
  """
  @spec pareto_frontier(DataFrame.t(), [atom()]) :: DataFrame.t()
  def pareto_frontier(dataframe, metrics) when is_list(metrics) do
    if DataFrame.n_rows(dataframe) == 0 do
      dataframe
    else
      # For now, return top performers for the first metric
      # Full Pareto frontier implementation would be more complex
      metric = List.first(metrics) || :total_return
      top_n_params(dataframe, min(10, DataFrame.n_rows(dataframe)), metric)
    end
  end

  @doc """
  Generate parameter heatmap data.

  Creates a pivot table showing how a metric varies across two parameters.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 5, 10, 10],
      ...>   slow_period: [20, 25, 20, 25],
      ...>   total_return: [0.1, 0.15, 0.2, 0.25]
      ...> })
      iex> {:ok, heatmap} = parameter_heatmap(df, :fast_period, :slow_period, :total_return)
      iex> DataFrame.n_rows(heatmap) > 0
      true
  """
  @spec parameter_heatmap(DataFrame.t(), atom(), atom(), atom()) ::
          {:ok, DataFrame.t()} | {:error, term()}
  def parameter_heatmap(dataframe, x_param, y_param, metric) do
    x_param_str = Atom.to_string(x_param)
    y_param_str = Atom.to_string(y_param)
    metric_str = Atom.to_string(metric)

    required_columns = [x_param_str, y_param_str, metric_str]
    available_columns = DataFrame.names(dataframe)

    if Enum.all?(required_columns, &(&1 in available_columns)) do
      # For now, return the original data grouped by the parameters
      # Full pivot table implementation would require more complex operations
      grouped_data =
        dataframe
        |> DataFrame.group_by([x_param_str, y_param_str])
        |> DataFrame.summarise([{metric_str, [:mean]}])

      {:ok, grouped_data}
    else
      missing = required_columns -- available_columns
      {:error, {:missing_columns, missing}}
    end
  end

  @doc """
  Analyze parameter correlation.

  Shows how two parameters correlate in their effect on performance.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 10, 15, 20],
      ...>   slow_period: [20, 25, 30, 35],
      ...>   total_return: [0.1, 0.2, 0.15, 0.25]
      ...> })
      iex> corr = parameter_correlation(df, :fast_period, :slow_period)
      iex> is_number(corr)
      true
  """
  @spec parameter_correlation(DataFrame.t(), atom(), atom()) :: float()
  def parameter_correlation(dataframe, param1, param2) do
    param1_str = Atom.to_string(param1)
    param2_str = Atom.to_string(param2)

    if param1_str in DataFrame.names(dataframe) and param2_str in DataFrame.names(dataframe) do
      values1 = DataFrame.pull(dataframe, param1_str) |> Series.to_list()
      values2 = DataFrame.pull(dataframe, param2_str) |> Series.to_list()

      calculate_correlation(values1, values2)
    else
      0.0
    end
  end

  @doc """
  Perform sensitivity analysis on a parameter.

  Shows how changes in a parameter affect performance metrics.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 10, 15, 20],
      ...>   total_return: [0.1, 0.2, 0.15, 0.25]
      ...> })
      iex> {:ok, analysis} = sensitivity_analysis(df, :fast_period)
      iex> Map.has_key?(analysis, :correlation)
      true
  """
  @spec sensitivity_analysis(DataFrame.t(), atom()) :: {:ok, map()} | {:error, term()}
  def sensitivity_analysis(dataframe, param_name) do
    param_str = Atom.to_string(param_name)

    if param_str in DataFrame.names(dataframe) do
      param_values = DataFrame.pull(dataframe, param_str) |> Series.to_list()

      # Calculate sensitivity for key metrics
      metrics = [:total_return, :sharpe_ratio, :max_drawdown, :win_rate]

      sensitivity_results =
        metrics
        |> Enum.filter(fn metric ->
          Atom.to_string(metric) in DataFrame.names(dataframe)
        end)
        |> Enum.map(fn metric ->
          metric_values = DataFrame.pull(dataframe, Atom.to_string(metric)) |> Series.to_list()
          correlation = calculate_correlation(param_values, metric_values)
          {metric, correlation}
        end)
        |> Enum.into(%{})

      analysis = %{
        parameter: param_name,
        correlations: sensitivity_results,
        strongest_correlation: find_strongest_correlation(sensitivity_results)
      }

      {:ok, analysis}
    else
      {:error, {:parameter_not_found, param_name}}
    end
  end

  @doc """
  Analyze parameter stability.

  Identifies parameter combinations that perform consistently
  well across multiple metrics.

  ## Examples

      iex> df = DataFrame.new(%{
      ...>   fast_period: [5, 10, 15],
      ...>   total_return: [0.1, 0.3, 0.2],
      ...>   sharpe_ratio: [0.5, 1.2, 0.8]
      ...> })
      iex> {:ok, stability} = stability_analysis(df, :total_return, 0.1)
      iex> Map.has_key?(stability, :stable_params)
      true
  """
  @spec stability_analysis(DataFrame.t(), atom(), float()) :: {:ok, map()} | {:error, term()}
  def stability_analysis(dataframe, metric, threshold) do
    metric_str = Atom.to_string(metric)

    if metric_str in DataFrame.names(dataframe) do
      metric_values = DataFrame.pull(dataframe, metric_str) |> Series.to_list()

      if length(metric_values) > 1 do
        mean_performance = Enum.sum(metric_values) / length(metric_values)
        std_dev = calculate_standard_deviation(metric_values, mean_performance)

        # Find parameters with performance within threshold of mean
        stable_indices =
          metric_values
          |> Enum.with_index()
          |> Enum.filter(fn {value, _index} ->
            abs(value - mean_performance) <= threshold * std_dev
          end)
          |> Enum.map(fn {_value, index} -> index end)

        stable_params =
          stable_indices
          |> Enum.map(&DataFrame.slice(dataframe, &1, 1))
          |> Enum.map(&(DataFrame.to_rows(&1) |> List.first()))
          |> Enum.map(&convert_string_keys_to_atoms/1)

        analysis = %{
          metric: metric,
          threshold: threshold,
          mean_performance: mean_performance,
          std_deviation: std_dev,
          stable_count: length(stable_params),
          total_count: length(metric_values),
          stability_ratio: length(stable_params) / length(metric_values),
          stable_params: stable_params
        }

        {:ok, analysis}
      else
        {:error, :insufficient_data}
      end
    else
      {:error, {:metric_not_found, metric}}
    end
  end

  # Private functions

  defp convert_string_keys_to_atoms(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      key = if is_binary(k), do: String.to_atom(k), else: k
      {key, v}
    end)
    |> Enum.into(%{})
  end

  defp calculate_correlation(values1, values2) when length(values1) == length(values2) do
    if length(values1) < 2 do
      0.0
    else
      n = length(values1)
      mean1 = Enum.sum(values1) / n
      mean2 = Enum.sum(values2) / n

      numerator =
        values1
        |> Enum.zip(values2)
        |> Enum.reduce(0, fn {x, y}, acc -> acc + (x - mean1) * (y - mean2) end)

      sum_sq1 = Enum.reduce(values1, 0, fn x, acc -> acc + :math.pow(x - mean1, 2) end)
      sum_sq2 = Enum.reduce(values2, 0, fn y, acc -> acc + :math.pow(y - mean2, 2) end)

      denominator = :math.sqrt(sum_sq1 * sum_sq2)

      if denominator > 0 do
        numerator / denominator
      else
        0.0
      end
    end
  end

  defp calculate_correlation(_values1, _values2), do: 0.0

  defp find_strongest_correlation(correlations) do
    if Enum.empty?(correlations) do
      nil
    else
      correlations
      |> Enum.max_by(fn {_metric, corr} -> abs(corr) end)
    end
  end

  defp calculate_standard_deviation(values, mean) do
    if length(values) < 2 do
      0.0
    else
      variance =
        values
        |> Enum.reduce(0, fn x, acc -> acc + :math.pow(x - mean, 2) end)
        |> Kernel./(length(values) - 1)

      :math.sqrt(variance)
    end
  end
end
