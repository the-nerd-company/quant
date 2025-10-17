defmodule Quant.Strategy.Optimization.Ranges do
  @moduledoc """
  Utilities for generating parameter ranges and combinations.

  This module provides functions to generate parameter grids similar to
  numpy's meshgrid functionality, supporting various range types and
  sampling strategies.
  """

  @doc """
  Generate all combinations of parameters from a parameter map.

  Takes a map where keys are parameter names and values are either:
  - Ranges (e.g., 1..10)
  - Lists of specific values (e.g., [5, 10, 15, 20])
  - Single values (treated as a list with one element)

  ## Examples

      iex> param_map = %{fast_period: 5..7, slow_period: [20, 25]}
      iex> {:ok, combinations} = parameter_grid(param_map)
      iex> length(combinations)
      6
      iex> Enum.all?(combinations, &Map.has_key?(&1, :fast_period))
      true
  """
  @spec parameter_grid(%{atom() => Range.t() | [any()] | any()}) ::
          {:ok, [%{atom() => any()}]} | {:error, term()}
  def parameter_grid(param_map) when is_map(param_map) do
    try do
      # Handle empty parameter map
      if Enum.empty?(param_map) do
        {:ok, []}
      else
        # Convert all parameter values to lists
        param_lists =
          param_map
          |> Enum.map(fn {key, value} -> {key, expand_parameter_value(value)} end)
          |> Enum.into(%{})

        # Generate all combinations
        param_keys = Map.keys(param_lists)
        param_values = Map.values(param_lists)

        combinations = cartesian_product(param_values)

        # Convert back to maps
        result =
          combinations
          |> Enum.map(fn combination ->
            param_keys
            |> Enum.zip(combination)
            |> Enum.into(%{})
          end)

        {:ok, result}
      end
    rescue
      e -> {:error, {:parameter_grid_failed, Exception.message(e)}}
    end
  end

  def parameter_grid(_), do: {:error, :invalid_parameter_map}

  @doc """
  Generate a range similar to numpy.arange.

  ## Examples

      iex> range(1, 5)
      [1, 2, 3, 4]

      iex> range(0, 10, 2)
      [0, 2, 4, 6, 8]
  """
  @spec range(number(), number(), number()) :: [number()]
  def range(start, stop, step \\ 1) when step != 0 do
    if step > 0 do
      start |> Stream.iterate(&(&1 + step)) |> Stream.take_while(&(&1 < stop)) |> Enum.to_list()
    else
      start |> Stream.iterate(&(&1 + step)) |> Stream.take_while(&(&1 > stop)) |> Enum.to_list()
    end
  end

  @doc """
  Generate linearly spaced values similar to numpy.linspace.

  ## Examples

      iex> linspace(0, 10, 5)
      [0.0, 2.5, 5.0, 7.5, 10.0]
  """
  @spec linspace(number(), number(), pos_integer()) :: [float()]
  def linspace(start, stop, num) when num > 0 do
    if num == 1 do
      [start / 1.0]
    else
      step = (stop - start) / (num - 1)
      0..(num - 1)
      |> Enum.map(fn i -> start + i * step end)
    end
  end

  @doc """
  Generate random parameter combinations.

  Useful for large parameter spaces where exhaustive search is impractical.

  ## Examples

      iex> param_map = %{fast_period: 5..50, slow_period: 20..100}
      iex> {:ok, samples} = random_search(param_map, 10)
      iex> length(samples)
      10
  """
  @spec random_search(%{atom() => Range.t() | [any()]}, pos_integer()) ::
          {:ok, [%{atom() => any()}]} | {:error, term()}
  def random_search(param_map, n_samples) when is_map(param_map) and n_samples > 0 do
    try do
      samples =
        1..n_samples
        |> Enum.map(fn _ ->
          param_map
          |> Enum.map(fn {key, value} -> {key, sample_random_value(value)} end)
          |> Enum.into(%{})
        end)

      {:ok, samples}
    rescue
      e -> {:error, {:random_search_failed, Exception.message(e)}}
    end
  end

  def random_search(_, _), do: {:error, :invalid_parameters}

  @doc """
  Generate Fibonacci sequence within a range.

  Useful for parameter values that benefit from Fibonacci spacing.

  ## Examples

      iex> fibonacci_sequence(1, 100)
      [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]
  """
  @spec fibonacci_sequence(pos_integer(), pos_integer()) :: [pos_integer()]
  def fibonacci_sequence(start, stop) when start > 0 and stop >= start do
    Stream.unfold({1, 1}, fn {a, b} ->
      if a <= stop do
        {a, {b, a + b}}
      else
        nil
      end
    end)
    |> Stream.filter(&(&1 >= start))
    |> Enum.to_list()
  end

  @doc """
  Generate logarithmic range.

  Creates exponentially spaced values, useful for parameters like
  periods or thresholds that work better on a log scale.

  ## Examples

      iex> logarithmic_range(1, 64, 2)
      [1, 2, 4, 8, 16, 32]
  """
  @spec logarithmic_range(pos_integer(), pos_integer(), pos_integer()) :: [pos_integer()]
  def logarithmic_range(start, stop, base \\ 2) when start > 0 and stop >= start and base > 1 do
    Stream.unfold(start, fn current ->
      if current <= stop do
        {current, current * base}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  # Private functions

  defp expand_parameter_value(value) do
    case value do
      %Range{} = range -> Enum.to_list(range)
      list when is_list(list) -> list
      single_value -> [single_value]
    end
  end

  defp cartesian_product([]), do: [[]]
  defp cartesian_product([head | tail]) do
    for h <- head, t <- cartesian_product(tail), do: [h | t]
  end

  defp sample_random_value(value) do
    case value do
      %Range{first: first, last: last} ->
        :rand.uniform(last - first + 1) + first - 1
      list when is_list(list) ->
        Enum.random(list)
      single_value ->
        single_value
    end
  end
end
