defmodule Quant.Explorer.Config do
  @moduledoc """
  Centralized configuration management for Quant.Explorer.

  This module provides a consistent interface for accessing configuration
  values from application environment, with sensible defaults and runtime
  value resolution (e.g., from system environment variables).
  """

  @app :quant

  @doc """
  Gets a configuration value for the given key.

  Supports nested keys using dot notation as atoms:
  - `get(:api_keys)`
  - `get([:rate_limits, :yahoo_finance])`
  - `get(:http_timeout)`

  Returns the default value if the configuration is not found.
  """
  @spec get(atom() | [atom()], term()) :: term()
  def get(key, default \\ nil)

  def get(key, default) when is_atom(key) do
    case Application.get_env(@app, key, default) do
      {:system, env_var} -> System.get_env(env_var)
      {:system, env_var, default_val} -> System.get_env(env_var, default_val)
      value -> value
    end
  end

  def get([key], default) when is_atom(key) do
    get(key, default)
  end

  def get([head | tail], default) when is_atom(head) do
    case get(head) do
      nil -> default
      config when is_map(config) -> get_in(config, tail) || default
      _other -> default
    end
  end

  @doc """
  Gets the rate limiting configuration including backend and provider-specific settings.
  """
  @spec rate_limiting_config() :: map()
  def rate_limiting_config do
    %{
      backend: get(:rate_limiting_backend, :ets),
      backend_opts: get(:rate_limiting_backend_opts, []),
      cleanup_interval: get(:rate_limiting_cleanup_interval, :timer.minutes(5)),
      enable_stats: get(:rate_limiting_enable_stats, true),
      redis_opts: get(:redis_opts, []),
      distributed_nodes: get(:distributed_nodes, [])
    }
  end

  @doc """
  Gets the rate limit for a specific provider (requests per minute).
  This is kept for backwards compatibility but new code should use
  the provider-specific configurations.
  """
  @spec rate_limit(atom()) :: pos_integer()
  def rate_limit(provider) do
    rate_limits = get(:rate_limits, %{})
    # Default: 60 RPM
    Map.get(rate_limits, provider, 60)
  end

  @doc """
  Gets the HTTP timeout in milliseconds.
  """
  @spec http_timeout() :: pos_integer()
  def http_timeout do
    get(:http_timeout, 10_000)
  end

  @doc """
  Gets the cache TTL (time-to-live) in milliseconds.
  """
  @spec cache_ttl() :: pos_integer()
  def cache_ttl do
    get(:cache_ttl, :timer.minutes(5))
  end

  @doc """
  Gets an API key for a specific provider.

  Handles runtime resolution of system environment variables.
  """
  @spec api_key(atom()) :: String.t() | nil
  def api_key(provider) do
    api_keys = get(:api_keys, %{})

    case Map.get(api_keys, provider) do
      {:system, env_var} -> System.get_env(env_var)
      {:system, env_var, default} -> System.get_env(env_var, default)
      key when is_binary(key) -> key
      _ -> nil
    end
  end

  @doc """
  Gets all API keys as a map, resolving system environment variables.
  """
  @spec api_keys() :: map()
  def api_keys do
    api_keys = get(:api_keys, %{})

    Enum.reduce(api_keys, %{}, fn {provider, config}, acc ->
      case extract_api_key(config) do
        nil -> acc
        key -> Map.put(acc, provider, key)
      end
    end)
  end

  defp extract_api_key({:system, env_var}) do
    System.get_env(env_var)
  end

  defp extract_api_key({:system, env_var, default}) do
    System.get_env(env_var, default)
  end

  defp extract_api_key(key) when is_binary(key) do
    key
  end

  defp extract_api_key(_) do
    nil
  end

  @doc """
  Validates that required configuration is present.

  Returns `:ok` if all required config is present, or
  `{:error, missing_keys}` if anything is missing.
  """
  @spec validate_config() :: :ok | {:error, [atom()]}
  def validate_config do
    missing_keys =
      []
      # Add validation for critical config keys
      |> validate_key(:rate_limits)
      |> validate_key(:http_timeout)
      |> validate_key(:cache_ttl)

    case missing_keys do
      [] -> :ok
      keys -> {:error, keys}
    end
  end

  defp validate_key(missing_keys, key) do
    case get(key) do
      nil -> [key | missing_keys]
      _ -> missing_keys
    end
  end

  @doc """
  Gets the configuration for a specific provider.

  Returns a map with provider-specific configuration including
  rate limits, API keys, base URLs, etc.
  """
  @spec provider_config(atom()) :: map()
  def provider_config(provider) do
    base_config = %{
      rate_limit: rate_limit(provider),
      api_key: api_key(provider),
      timeout: http_timeout()
    }

    # Merge with provider-specific config if available
    provider_specific = get([:providers, provider], %{})
    Map.merge(base_config, provider_specific)
  end

  @doc """
  Gets the caching configuration.
  """
  @spec cache_config() :: keyword()
  def cache_config do
    [
      ttl: cache_ttl(),
      limit: get(:cache_limit, 10_000),
      stats: get(:cache_stats, true)
    ]
  end

  @doc """
  Checks if telemetry is enabled.
  """
  @spec telemetry_enabled?() :: boolean()
  def telemetry_enabled? do
    get(:telemetry_enabled, true)
  end

  @doc """
  Gets the log level for the application.
  """
  @spec log_level() :: atom()
  def log_level do
    get(:log_level, :info)
  end

  @doc """
  Gets the user agent string for HTTP requests.
  """
  @spec user_agent() :: String.t()
  def user_agent do
    version = Application.spec(@app, :vsn) |> List.to_string()
    get(:user_agent, "Quant.Explorer/#{version} (Elixir)")
  end
end
