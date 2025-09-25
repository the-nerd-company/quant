defmodule Quant.Explorer.RateLimiting.EtsBackend do
  @moduledoc """
  ETS-based rate limiting backend implementation.

  This backend uses ETS tables for high-performance, local rate limiting.
  It supports multiple rate limiting algorithms and provides automatic
  cleanup of expired entries.

  ## Features
  - Multiple rate limiting algorithms (sliding window, token bucket, weighted)
  - Automatic cleanup of expired data
  - Statistics tracking
  - High performance with ETS
  """

  @behaviour Quant.Explorer.RateLimiting.Behaviour

  alias Quant.Explorer.RateLimiting.ProviderConfig
  require Logger

  @table_name :quant_explorer_rate_limits
  @stats_table_name :quant_explorer_rate_limit_stats
  @cleanup_interval :timer.minutes(1)

  defstruct [:table, :stats_table, :cleanup_timer, :start_time]

  @impl true
  def init(opts \\ []) do
    table_opts = Keyword.get(opts, :table_opts, [:set, :public, :named_table])

    # Create main rate limiting table: {provider, endpoint} -> rate_limit_data
    table =
      case :ets.whereis(@table_name) do
        :undefined -> :ets.new(@table_name, table_opts)
        tid -> tid
      end

    # Create stats table: {provider} -> stats_data
    stats_table =
      case :ets.whereis(@stats_table_name) do
        :undefined -> :ets.new(@stats_table_name, table_opts)
        tid -> tid
      end

    # Schedule cleanup
    cleanup_timer = Process.send_after(self(), :cleanup, @cleanup_interval)

    state = %__MODULE__{
      table: table,
      stats_table: stats_table,
      cleanup_timer: cleanup_timer,
      start_time: System.system_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def check_and_consume(request_info, limit_config, state) do
    key = {request_info.provider, request_info.endpoint}
    now = System.system_time(:millisecond)

    case check_limit_internal(key, request_info, limit_config, now, state) do
      :ok ->
        # Consume the limit
        new_state = consume_limit_internal(key, request_info, limit_config, now, state)
        remaining_info = get_remaining_info(key, limit_config, now, new_state)
        update_stats(request_info.provider, :allowed, state)
        {:ok, remaining_info, new_state}

      {:error, _reason} = error ->
        update_stats(request_info.provider, :denied, state)
        {error, get_remaining_info(key, limit_config, now, state), state}
    end
  end

  @impl true
  def check_limit(request_info, limit_config, state) do
    key = {request_info.provider, request_info.endpoint}
    now = System.system_time(:millisecond)

    result = check_limit_internal(key, request_info, limit_config, now, state)
    remaining_info = get_remaining_info(key, limit_config, now, state)

    {result, remaining_info, state}
  end

  @impl true
  def consume_limit(request_info, limit_config, state) do
    key = {request_info.provider, request_info.endpoint}
    now = System.system_time(:millisecond)

    new_state = consume_limit_internal(key, request_info, limit_config, now, state)
    remaining_info = get_remaining_info(key, limit_config, now, new_state)

    {remaining_info, new_state}
  end

  @impl true
  def get_limit_status(provider, endpoint, state) do
    key = {provider, endpoint}
    now = System.system_time(:millisecond)

    # Get the actual provider config instead of using default
    provider_config = ProviderConfig.get_provider_config(provider)

    limit_config =
      case Enum.find(provider_config, &(&1.endpoint == endpoint)) do
        nil ->
          # Fallback to the first config for this provider
          [first_config | _] = provider_config
          first_config

        config ->
          config
      end

    remaining_info = get_remaining_info(key, limit_config, now, state)

    {remaining_info, state}
  end

  @impl true
  def reset_limits(provider, endpoint_or_all, state) do
    case endpoint_or_all do
      :all ->
        # Reset all limits for the provider
        pattern = {provider, :_}
        :ets.match_delete(state.table, {pattern, :_})

      endpoint ->
        key = {provider, endpoint}
        :ets.delete(state.table, key)
    end

    {:ok, state}
  end

  @impl true
  def cleanup(state) do
    now = System.system_time(:millisecond)

    # Clean up expired entries
    cleanup_count =
      :ets.foldl(
        fn {key, data}, acc ->
          if should_cleanup_entry?(data, now) do
            :ets.delete(state.table, key)
            acc + 1
          else
            acc
          end
        end,
        0,
        state.table
      )

    Logger.debug("Cleaned up #{cleanup_count} expired rate limit entries")

    # Reschedule cleanup
    _ = Process.cancel_timer(state.cleanup_timer)
    new_timer = Process.send_after(self(), :cleanup, @cleanup_interval)

    new_state = %{state | cleanup_timer: new_timer}
    {:ok, new_state}
  end

  @impl true
  def get_stats(provider_or_all, state) do
    stats =
      case provider_or_all do
        :all ->
          :ets.foldl(
            fn {provider, data}, acc ->
              Map.put(acc, provider, data)
            end,
            %{},
            state.stats_table
          )

        provider ->
          case :ets.lookup(state.stats_table, provider) do
            [{^provider, data}] -> data
            [] -> %{allowed: 0, denied: 0, last_request: nil}
          end
      end

    {stats, state}
  end

  # Private functions

  defp check_limit_internal(key, request_info, limit_config, now, state) do
    case :ets.lookup(state.table, key) do
      [{^key, rate_data}] ->
        check_rate_data(rate_data, request_info, limit_config, now)

      [] ->
        # No previous requests, allow this one
        :ok
    end
  end

  defp check_rate_data(rate_data, request_info, limit_config, now) do
    case limit_config.type do
      :requests_per_minute -> check_sliding_window(rate_data, limit_config, now)
      :requests_per_second -> check_sliding_window(rate_data, limit_config, now)
      :requests_per_hour -> check_sliding_window(rate_data, limit_config, now)
      :requests_per_day -> check_sliding_window(rate_data, limit_config, now)
      :weighted_requests -> check_weighted_requests(rate_data, request_info, limit_config, now)
      :burst_allowance -> check_burst_allowance(rate_data, request_info, limit_config, now)
    end
  end

  defp check_sliding_window(rate_data, limit_config, now) do
    window_start = now - limit_config.window_ms

    # Count requests in the current window
    recent_requests = Enum.filter(rate_data.timestamps || [], &(&1 >= window_start))

    if length(recent_requests) < limit_config.limit do
      :ok
    else
      {:error, :rate_limited}
    end
  end

  defp check_weighted_requests(rate_data, request_info, limit_config, now) do
    window_start = now - limit_config.window_ms

    # Calculate total weight in the current window
    recent_weights = rate_data.weighted_requests || []

    current_weight =
      Enum.reduce(recent_weights, 0, fn {timestamp, weight}, acc ->
        if timestamp >= window_start, do: acc + weight, else: acc
      end)

    if current_weight + request_info.weight <= limit_config.limit do
      :ok
    else
      {:error, :rate_limited}
    end
  end

  defp check_burst_allowance(rate_data, request_info, limit_config, now) do
    # Token bucket implementation
    tokens_data = rate_data.tokens || %{tokens: limit_config.burst_size, last_refill: now}

    # Calculate token refill
    time_passed = now - tokens_data.last_refill
    tokens_to_add = div(time_passed, div(limit_config.window_ms, limit_config.recovery_rate))
    current_tokens = min(tokens_data.tokens + tokens_to_add, limit_config.burst_size)

    if current_tokens >= request_info.weight do
      :ok
    else
      {:error, :rate_limited}
    end
  end

  defp consume_limit_internal(key, request_info, limit_config, now, state) do
    case :ets.lookup(state.table, key) do
      [{^key, rate_data}] ->
        new_data = update_rate_data(rate_data, request_info, limit_config, now)
        :ets.insert(state.table, {key, new_data})

      [] ->
        new_data = create_rate_data(request_info, limit_config, now)
        :ets.insert(state.table, {key, new_data})
    end

    state
  end

  defp update_rate_data(rate_data, request_info, limit_config, now) do
    case limit_config.type do
      type
      when type in [
             :requests_per_minute,
             :requests_per_second,
             :requests_per_hour,
             :requests_per_day
           ] ->
        timestamps = [now | rate_data.timestamps || []]
        %{rate_data | timestamps: timestamps, last_request: now}

      :weighted_requests ->
        weighted_requests = [{now, request_info.weight} | rate_data.weighted_requests || []]
        %{rate_data | weighted_requests: weighted_requests, last_request: now}

      :burst_allowance ->
        tokens_data = rate_data.tokens || %{tokens: limit_config.burst_size, last_refill: now}
        time_passed = now - tokens_data.last_refill
        tokens_to_add = div(time_passed, div(limit_config.window_ms, limit_config.recovery_rate))
        current_tokens = min(tokens_data.tokens + tokens_to_add, limit_config.burst_size)
        new_tokens = current_tokens - request_info.weight

        new_tokens_data = %{tokens: new_tokens, last_refill: now}
        %{rate_data | tokens: new_tokens_data, last_request: now}
    end
  end

  defp create_rate_data(request_info, limit_config, now) do
    case limit_config.type do
      type
      when type in [
             :requests_per_minute,
             :requests_per_second,
             :requests_per_hour,
             :requests_per_day
           ] ->
        %{timestamps: [now], last_request: now}

      :weighted_requests ->
        %{weighted_requests: [{now, request_info.weight}], last_request: now}

      :burst_allowance ->
        tokens_data = %{tokens: limit_config.burst_size - request_info.weight, last_refill: now}
        %{tokens: tokens_data, last_request: now}
    end
  end

  defp get_remaining_info(key, limit_config, now, state) do
    case :ets.lookup(state.table, key) do
      [{^key, rate_data}] ->
        calculate_remaining_info(rate_data, limit_config, now)

      [] ->
        %{
          remaining: limit_config.limit,
          reset_time:
            DateTime.add(DateTime.utc_now(), div(limit_config.window_ms, 1000), :second),
          retry_after_ms: 0
        }
    end
  end

  defp calculate_remaining_info(rate_data, limit_config, now) do
    window_start = now - limit_config.window_ms

    {remaining, oldest_request} =
      calculate_remaining_by_type(rate_data, limit_config, window_start, now)

    reset_time = build_reset_time(now, oldest_request, limit_config.window_ms)

    retry_after_ms =
      calculate_retry_after_ms(remaining, now, oldest_request, limit_config.window_ms)

    %{
      remaining: max(0, remaining),
      reset_time: reset_time,
      retry_after_ms: max(0, retry_after_ms)
    }
  end

  defp calculate_remaining_by_type(rate_data, limit_config, window_start, now) do
    case limit_config.type do
      type
      when type in [
             :requests_per_minute,
             :requests_per_second,
             :requests_per_hour,
             :requests_per_day
           ] ->
        calculate_time_based_remaining(rate_data, limit_config, window_start, now)

      :weighted_requests ->
        calculate_weighted_remaining(rate_data, limit_config, window_start, now)

      :burst_allowance ->
        calculate_burst_remaining(rate_data, limit_config, now)
    end
  end

  defp calculate_time_based_remaining(rate_data, limit_config, window_start, now) do
    recent_requests = Enum.filter(rate_data.timestamps || [], &(&1 >= window_start))
    oldest = Enum.min(recent_requests, fn -> now end)
    {limit_config.limit - length(recent_requests), oldest}
  end

  defp calculate_weighted_remaining(rate_data, limit_config, window_start, now) do
    recent_weights = filter_recent_weights(rate_data.weighted_requests || [], window_start)
    total_weight = sum_weights(recent_weights)
    oldest_timestamp = find_oldest_weight_timestamp(recent_weights, now)

    {limit_config.limit - total_weight, oldest_timestamp}
  end

  defp calculate_burst_remaining(rate_data, limit_config, now) do
    tokens_data = rate_data.tokens || %{tokens: limit_config.burst_size, last_refill: now}
    time_passed = now - tokens_data.last_refill
    tokens_to_add = div(time_passed, div(limit_config.window_ms, limit_config.recovery_rate))
    current_tokens = min(tokens_data.tokens + tokens_to_add, limit_config.burst_size)

    {current_tokens, tokens_data.last_refill}
  end

  defp filter_recent_weights(weighted_requests, window_start) do
    Enum.filter(weighted_requests, fn {timestamp, _} -> timestamp >= window_start end)
  end

  defp sum_weights(recent_weights) do
    Enum.reduce(recent_weights, 0, fn {_, weight}, acc -> acc + weight end)
  end

  defp find_oldest_weight_timestamp([], now), do: now

  defp find_oldest_weight_timestamp(weights, _now) do
    weights |> Enum.map(fn {ts, _} -> ts end) |> Enum.min()
  end

  defp build_reset_time(now, oldest_request, window_ms) do
    DateTime.add(
      DateTime.utc_now(),
      div(window_ms - (now - oldest_request), 1000),
      :second
    )
  end

  defp calculate_retry_after_ms(remaining, now, oldest_request, window_ms) do
    if remaining <= 0 do
      window_ms - (now - oldest_request)
    else
      0
    end
  end

  defp should_cleanup_entry?(rate_data, now) do
    last_request = rate_data.last_request || 0
    # Clean up entries older than 1 hour
    now - last_request > :timer.hours(1)
  end

  defp update_stats(provider, result, state) do
    current_stats =
      case :ets.lookup(state.stats_table, provider) do
        [{^provider, stats}] -> stats
        [] -> %{allowed: 0, denied: 0, last_request: nil}
      end

    new_stats =
      case result do
        :allowed ->
          current_stats
          |> Map.update(:allowed, 1, &(&1 + 1))
          |> Map.put(:last_request, DateTime.utc_now())

        :denied ->
          current_stats
          |> Map.update(:denied, 1, &(&1 + 1))
      end

    :ets.insert(state.stats_table, {provider, new_stats})
  end
end
