defmodule Quant.Explorer.RateLimiting.Behaviour do
  @moduledoc """
  Behaviour for rate limiting backends.

  This behaviour defines a flexible interface for rate limiting that can support
  various algorithms and backends (ETS, Redis, GenServer, etc.) and different
  provider-specific requirements.

  ## Supported Rate Limiting Patterns

  ### Simple Rate Limiting
  - Fixed window: N requests per time window
  - Sliding window: N requests in any sliding time window
  - Token bucket: Consume tokens at variable rates

  ### Provider-Specific Patterns
  - **Binance**: Weight-based requests (different endpoints have different weights)
  - **Yahoo Finance**: IP-based limits with burst allowance
  - **Alpha Vantage**: API key-based with daily/monthly quotas
  - **CoinGecko**: Tiered limits based on API plan

  ## Rate Limit Types

  - `:requests_per_minute` - Standard RPM limit
  - `:requests_per_second` - High-frequency limit
  - `:requests_per_hour` - Hourly quotas
  - `:requests_per_day` - Daily quotas
  - `:weighted_requests` - Weight-based limiting (Binance style)
  - `:burst_allowance` - Allow bursts with recovery
  """

  @type provider :: atom()
  @type endpoint :: String.t() | atom()
  @type weight :: pos_integer()
  @type limit_type ::
          :requests_per_minute
          | :requests_per_second
          | :requests_per_hour
          | :requests_per_day
          | :weighted_requests
          | :burst_allowance
  @type limit_config :: %{
          required(:endpoint) => atom(),
          required(:type) => limit_type(),
          required(:limit) => pos_integer(),
          required(:weight) => pos_integer(),
          required(:window_ms) => pos_integer(),
          optional(:burst_size) => pos_integer(),
          optional(:recovery_rate) => pos_integer()
        }
  @type request_info :: %{
          provider: provider(),
          endpoint: endpoint(),
          weight: weight(),
          user_id: String.t() | nil,
          ip_address: String.t() | nil
        }
  @type rate_limit_result :: :ok | {:error, :rate_limited} | {:error, term()}
  @type remaining_info :: %{
          remaining: non_neg_integer(),
          reset_time: DateTime.t(),
          retry_after_ms: pos_integer()
        }

  @doc """
  Initializes the rate limiter backend.

  Returns `{:ok, state}` on success, `{:error, reason}` on failure.
  """
  @callback init(opts :: keyword()) :: {:ok, term()} | {:error, term()}

  @doc """
  Checks if a request is allowed and records it if so.

  This is the primary function that combines check and record operations
  for atomic rate limiting.
  """
  @callback check_and_consume(request_info(), limit_config(), state :: term()) ::
              {rate_limit_result(), remaining_info(), new_state :: term()}

  @doc """
  Checks if a request would be allowed without consuming the limit.

  Useful for pre-flight checks or API exploration.
  """
  @callback check_limit(request_info(), limit_config(), state :: term()) ::
              {rate_limit_result(), remaining_info(), state :: term()}

  @doc """
  Records a request consumption without checking.

  Useful for tracking requests made outside the normal flow.
  """
  @callback consume_limit(request_info(), limit_config(), state :: term()) ::
              {remaining_info(), new_state :: term()}

  @doc """
  Gets current limit status for a provider/endpoint combination.
  """
  @callback get_limit_status(provider(), endpoint(), state :: term()) ::
              {remaining_info(), state :: term()}

  @doc """
  Resets limits for a provider/endpoint (useful for testing or admin operations).
  """
  @callback reset_limits(provider(), endpoint() | :all, state :: term()) ::
              {:ok, new_state :: term()}

  @doc """
  Cleans up expired entries and performs maintenance.
  """
  @callback cleanup(state :: term()) :: {:ok, new_state :: term()}

  @doc """
  Returns statistics about rate limiting (requests, violations, etc.).
  """
  @callback get_stats(provider() | :all, state :: term()) ::
              {map(), state :: term()}

  # Optional callbacks for advanced backends

  @doc """
  Sets up distributed coordination (for Redis, etc.).
  """
  @callback setup_distributed(nodes :: [node()], state :: term()) ::
              {:ok, new_state :: term()} | {:error, term()}

  @doc """
  Handles backend-specific configuration updates.
  """
  @callback update_config(new_config :: keyword(), state :: term()) ::
              {:ok, new_state :: term()} | {:error, term()}

  @optional_callbacks [setup_distributed: 2, update_config: 2]

  @doc """
  Helper function to create a basic request info structure.
  """
  @spec request_info(provider(), endpoint(), keyword()) :: request_info()
  def request_info(provider, endpoint, opts \\ []) do
    %{
      provider: provider,
      endpoint: endpoint,
      weight: Keyword.get(opts, :weight, 1),
      user_id: Keyword.get(opts, :user_id),
      ip_address: Keyword.get(opts, :ip_address)
    }
  end

  @doc """
  Helper function to create rate limit configurations.
  """
  @spec limit_config(limit_type(), pos_integer(), keyword()) :: %{
          required(:type) => limit_type(),
          required(:limit) => pos_integer(),
          required(:weight) => pos_integer(),
          required(:window_ms) => pos_integer(),
          optional(:burst_size) => pos_integer(),
          optional(:recovery_rate) => pos_integer()
        }
  def limit_config(type, limit, opts \\ []) do
    base_config = %{
      type: type,
      limit: limit,
      weight: Keyword.get(opts, :weight, 1)
    }

    case type do
      :requests_per_minute ->
        Map.put(base_config, :window_ms, :timer.minutes(1))

      :requests_per_second ->
        Map.put(base_config, :window_ms, :timer.seconds(1))

      :requests_per_hour ->
        Map.put(base_config, :window_ms, :timer.hours(1))

      :requests_per_day ->
        Map.put(base_config, :window_ms, :timer.hours(24))

      :weighted_requests ->
        base_config
        |> Map.put(:window_ms, Keyword.get(opts, :window_ms, :timer.minutes(1)))

      :burst_allowance ->
        base_config
        |> Map.put(:window_ms, Keyword.get(opts, :window_ms, :timer.minutes(1)))
        |> Map.put(:burst_size, Keyword.get(opts, :burst_size, limit * 2))
        |> Map.put(:recovery_rate, Keyword.get(opts, :recovery_rate, 1))
    end
  end
end
