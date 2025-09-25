defmodule Quant.Explorer.RateLimiter do
  @moduledoc """
  Advanced rate limiter with pluggable backends and provider-specific configurations.

  This module provides a high-level interface for rate limiting that supports:
  - Multiple backends (ETS, Redis, GenServer)
  - Provider-specific rate limiting patterns
  - Complex algorithms (sliding window, token bucket, weighted requests)
  - Distributed rate limiting capabilities

  ## Usage

      # Basic usage with default backend
      {:ok, _} = Quant.Explorer.RateLimiter.start_link()

      # Check and consume rate limit
      case Quant.Explorer.RateLimiter.check_and_consume(:yahoo_finance, :history) do
        :ok ->
          # Request allowed, proceed
        {:error, :rate_limited} ->
          # Rate limited, wait or handle error
      end

      # Check limit without consuming
      case Quant.Explorer.RateLimiter.check_limit(:binance, :klines, weight: 5) do
        :ok -> # Would be allowed
        {:error, :rate_limited} -> # Would be rate limited
      end
  """

  use GenServer

  alias Quant.Explorer.RateLimiting.{Behaviour, EtsBackend, ProviderConfig}
  require Logger

  @default_backend EtsBackend
  @cleanup_interval :timer.minutes(5)

  defstruct [:backend, :backend_state, :config, :cleanup_timer, :stats]

  # Client API

  @doc """
  Starts the rate limiter with the specified backend.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Checks if a request is allowed and consumes the rate limit if so.

  This is the main function to use for rate limiting API requests.
  """
  @spec check_and_consume(atom(), atom() | String.t(), keyword()) :: :ok | {:error, term()}
  def check_and_consume(provider, endpoint, opts \\ []) do
    GenServer.call(__MODULE__, {:check_and_consume, provider, endpoint, opts})
  end

  @doc """
  Checks if a request would be allowed without consuming the limit.
  """
  @spec check_limit(atom(), atom() | String.t(), keyword()) :: :ok | {:error, term()}
  def check_limit(provider, endpoint, opts \\ []) do
    GenServer.call(__MODULE__, {:check_limit, provider, endpoint, opts})
  end

  @doc """
  Consumes a rate limit without checking (for external request tracking).
  """
  @spec consume_limit(atom(), atom() | String.t(), keyword()) :: :ok
  def consume_limit(provider, endpoint, opts \\ []) do
    GenServer.cast(__MODULE__, {:consume_limit, provider, endpoint, opts})
  end

  @doc """
  Gets the current rate limit status for a provider/endpoint.
  """
  @spec get_limit_status(atom(), atom() | String.t()) :: map()
  def get_limit_status(provider, endpoint) do
    GenServer.call(__MODULE__, {:get_limit_status, provider, endpoint})
  end

  @doc """
  Resets rate limits for a provider/endpoint.
  """
  @spec reset_limits(atom(), atom() | String.t() | :all) :: :ok
  def reset_limits(provider, endpoint_or_all \\ :all) do
    GenServer.cast(__MODULE__, {:reset_limits, provider, endpoint_or_all})
  end

  @doc """
  Gets rate limiting statistics.
  """
  @spec get_stats(atom() | :all) :: map()
  def get_stats(provider_or_all \\ :all) do
    GenServer.call(__MODULE__, {:get_stats, provider_or_all})
  end

  @doc """
  Waits until a request is allowed, with exponential backoff.
  """
  @spec wait_for_rate_limit(atom(), atom() | String.t(), keyword()) :: :ok
  def wait_for_rate_limit(provider, endpoint, opts \\ []) do
    max_wait = Keyword.get(opts, :max_wait_ms, :timer.minutes(5))
    initial_delay = Keyword.get(opts, :initial_delay_ms, 1000)

    do_wait_for_rate_limit(provider, endpoint, opts, initial_delay, max_wait, 0)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    backend_module = Keyword.get(opts, :backend, @default_backend)
    backend_opts = Keyword.get(opts, :backend_opts, [])

    case backend_module.init(backend_opts) do
      {:ok, backend_state} ->
        cleanup_timer = Process.send_after(self(), :cleanup, @cleanup_interval)

        state = %__MODULE__{
          backend: backend_module,
          backend_state: backend_state,
          config: %{},
          cleanup_timer: cleanup_timer,
          stats: %{start_time: System.system_time(:millisecond)}
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:check_and_consume, provider, endpoint, opts}, _from, state) do
    request_info = build_request_info(provider, endpoint, opts)
    limit_config = get_limit_config(provider, endpoint, opts)

    {result, _remaining_info, new_backend_state} =
      state.backend.check_and_consume(request_info, limit_config, state.backend_state)

    new_state = %{state | backend_state: new_backend_state}

    case result do
      :ok -> {:reply, :ok, new_state}
      {:error, _} = error -> {:reply, error, new_state}
    end
  end

  @impl true
  def handle_call({:check_limit, provider, endpoint, opts}, _from, state) do
    request_info = build_request_info(provider, endpoint, opts)
    limit_config = get_limit_config(provider, endpoint, opts)

    {result, _remaining_info, new_backend_state} =
      state.backend.check_limit(request_info, limit_config, state.backend_state)

    new_state = %{state | backend_state: new_backend_state}

    case result do
      :ok -> {:reply, :ok, new_state}
      {:error, _} = error -> {:reply, error, new_state}
    end
  end

  @impl true
  def handle_call({:get_limit_status, provider, endpoint}, _from, state) do
    {status, new_backend_state} =
      state.backend.get_limit_status(provider, endpoint, state.backend_state)

    new_state = %{state | backend_state: new_backend_state}
    {:reply, status, new_state}
  end

  @impl true
  def handle_call({:get_stats, provider_or_all}, _from, state) do
    {stats, new_backend_state} =
      state.backend.get_stats(provider_or_all, state.backend_state)

    new_state = %{state | backend_state: new_backend_state}
    {:reply, stats, new_state}
  end

  def handle_call({:reset_limits, provider, endpoint_or_all}, _from, state) do
    {:ok, new_backend_state} =
      state.backend.reset_limits(provider, endpoint_or_all, state.backend_state)

    new_state = %{state | backend_state: new_backend_state}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:consume_limit, provider, endpoint, opts}, state) do
    request_info = build_request_info(provider, endpoint, opts)
    limit_config = get_limit_config(provider, endpoint, opts)

    {_remaining_info, new_backend_state} =
      state.backend.consume_limit(request_info, limit_config, state.backend_state)

    new_state = %{state | backend_state: new_backend_state}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:reset_limits, provider, endpoint_or_all}, state) do
    {:ok, new_backend_state} =
      state.backend.reset_limits(provider, endpoint_or_all, state.backend_state)

    new_state = %{state | backend_state: new_backend_state}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    {:ok, new_backend_state} = state.backend.cleanup(state.backend_state)

    # Reschedule cleanup
    _ = Process.cancel_timer(state.cleanup_timer)
    cleanup_timer = Process.send_after(self(), :cleanup, @cleanup_interval)

    new_state = %{state | backend_state: new_backend_state, cleanup_timer: cleanup_timer}

    {:noreply, new_state}
  end

  # Private functions

  defp build_request_info(provider, endpoint, opts) do
    # Calculate weight for specific providers
    weight =
      case provider do
        :binance ->
          params = Keyword.get(opts, :params, [])
          ProviderConfig.calculate_binance_weight(endpoint, params)

        _ ->
          Keyword.get(opts, :weight, 1)
      end

    Behaviour.request_info(provider, endpoint,
      weight: weight,
      user_id: Keyword.get(opts, :user_id),
      ip_address: Keyword.get(opts, :ip_address)
    )
  end

  defp get_limit_config(provider, endpoint, opts) do
    # Check if premium limits should be used
    api_key = Keyword.get(opts, :api_key)
    use_premium = ProviderConfig.should_use_premium_limits?(provider, api_key: api_key)

    base_config =
      if use_premium do
        configs = ProviderConfig.get_premium_config(provider)
        find_endpoint_config(configs, endpoint)
      else
        ProviderConfig.get_endpoint_config(provider, endpoint)
      end

    # Calculate dynamic weight for providers that use it (like Binance)
    weight =
      case provider do
        :binance ->
          ProviderConfig.calculate_binance_weight(endpoint, opts)

        _ ->
          Map.get(base_config, :weight, 1)
      end

    Map.put(base_config, :weight, weight)
  end

  defp find_endpoint_config(configs, endpoint) do
    Enum.find(configs, List.last(configs), fn config ->
      Map.get(config, :endpoint) == endpoint
    end)
  end

  defp do_wait_for_rate_limit(provider, endpoint, opts, current_delay, max_wait, total_wait) do
    if total_wait >= max_wait do
      Logger.warning("Rate limit wait timeout for #{provider}/#{endpoint}")
      {:error, :timeout}
    else
      case check_limit(provider, endpoint, opts) do
        :ok ->
          # Now consume the limit and return
          consume_limit(provider, endpoint, opts)
          :ok

        {:error, :rate_limited} ->
          Logger.debug("Rate limited for #{provider}/#{endpoint}, waiting #{current_delay}ms")
          :timer.sleep(current_delay)

          # Exponential backoff with jitter
          next_delay = min(current_delay * 2, :timer.seconds(30))
          jitter = :rand.uniform(div(next_delay, 10))
          actual_delay = next_delay + jitter

          do_wait_for_rate_limit(
            provider,
            endpoint,
            opts,
            actual_delay,
            max_wait,
            total_wait + current_delay
          )
      end
    end
  end
end
