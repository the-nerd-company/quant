defmodule Quant.Explorer.RateLimiting.ProviderConfig do
  @moduledoc """
  Provider-specific rate limiting configurations.

  This module contains rate limiting configurations tailored to specific
  financial data providers, handling their unique requirements and patterns.
  """

  alias Quant.Explorer.RateLimiting.Behaviour

  @doc """
  Gets the rate limiting configuration for a specific provider.
  """
  @spec get_provider_config(atom()) :: [Behaviour.limit_config()]
  def get_provider_config(provider) do
    case provider do
      :yahoo_finance -> yahoo_finance_config()
      :binance -> binance_config()
      :alpha_vantage -> alpha_vantage_config()
      :coin_gecko -> coin_gecko_config()
      :twelve_data -> twelve_data_config()
      _ -> default_config()
    end
  end

  @doc """
  Gets the rate limiting configuration for a specific provider endpoint.
  """
  @spec get_endpoint_config(atom(), atom() | String.t()) :: Behaviour.limit_config()
  def get_endpoint_config(provider, endpoint) do
    configs = get_provider_config(provider)

    # Find specific endpoint config or use default
    Enum.find(configs, List.last(configs), fn config ->
      Map.get(config, :endpoint) == endpoint
    end)
  end

  # Yahoo Finance Configuration
  # - Generally lenient but has IP-based limits
  # - Allows bursts but with recovery periods
  # - Different limits for different data types
  defp yahoo_finance_config do
    [
      # Historical data endpoint - moderate limits
      %{
        endpoint: :history,
        type: :burst_allowance,
        limit: 100,
        window_ms: :timer.minutes(1),
        burst_size: 200,
        recovery_rate: 2,
        weight: 1
      },

      # Quote data endpoint - higher frequency allowed
      %{
        endpoint: :quote,
        type: :requests_per_minute,
        limit: 200,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Search endpoint - lower limits
      %{
        endpoint: :search,
        type: :requests_per_minute,
        limit: 60,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Default for other endpoints
      %{
        endpoint: :default,
        type: :requests_per_minute,
        limit: 100,
        window_ms: :timer.minutes(1),
        weight: 1
      }
    ]
  end

  # Binance Configuration
  # - Uses weight-based system where different endpoints have different weights
  # - Has both per-second and per-minute limits
  # - Very strict enforcement
  defp binance_config do
    [
      # General API endpoints - weight-based limiting
      %{
        endpoint: :klines,
        type: :weighted_requests,
        # Total weight limit per minute
        limit: 1200,
        window_ms: :timer.minutes(1),
        # Base weight, can be overridden per request
        weight: 1
      },

      # Ticker endpoints - higher weight
      %{
        endpoint: :ticker_24hr,
        type: :weighted_requests,
        limit: 1200,
        window_ms: :timer.minutes(1),
        # Weight varies: 1 for single symbol, 40 for all symbols
        weight: 1
      },

      # Order book endpoints - very high weight
      %{
        endpoint: :depth,
        type: :weighted_requests,
        limit: 1200,
        window_ms: :timer.minutes(1),
        # Weight: 1-50 depending on limit parameter
        weight: 1
      },

      # Per-second limit for high-frequency endpoints
      %{
        endpoint: :exchange_info,
        type: :requests_per_second,
        limit: 10,
        window_ms: :timer.seconds(1),
        weight: 1
      },

      # Default configuration
      %{
        endpoint: :default,
        type: :weighted_requests,
        limit: 1200,
        window_ms: :timer.minutes(1),
        weight: 1
      }
    ]
  end

  # Alpha Vantage Configuration
  # - Has very strict limits (5 requests per minute for free tier)
  # - Also has daily/monthly quotas
  # - Premium tiers have higher limits (75 requests/minute)
  # - Different endpoints may have different effective limits
  defp alpha_vantage_config do
    [
      # Time series endpoints (historical data)
      %{
        endpoint: :time_series,
        type: :requests_per_minute,
        # Free tier limit
        limit: 5,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Quote endpoints (real-time data)
      %{
        endpoint: :quote,
        type: :requests_per_minute,
        # Same limit as other endpoints
        limit: 5,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Search endpoints
      %{
        endpoint: :search,
        type: :requests_per_minute,
        # Same limit as other endpoints
        limit: 5,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Daily quota check (free tier)
      %{
        endpoint: :daily_quota,
        type: :requests_per_day,
        # Free tier daily limit
        limit: 25,
        window_ms: :timer.hours(24),
        weight: 1
      },

      # Default configuration
      %{
        endpoint: :default,
        type: :requests_per_minute,
        # Free tier limit
        limit: 5,
        window_ms: :timer.minutes(1),
        weight: 1
      }
    ]
  end

  # CoinGecko Configuration
  # - Tiered system based on API plan
  # - Demo: 30 requests/minute
  # - Pro: 500 requests/minute
  defp coin_gecko_config do
    [
      # Public API endpoints
      %{
        endpoint: :ping,
        type: :requests_per_minute,
        # Higher limit for ping
        limit: 100,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Price endpoints
      %{
        endpoint: :simple_price,
        type: :requests_per_minute,
        limit: 50,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Historical market chart data
      %{
        endpoint: :market_chart,
        type: :requests_per_minute,
        limit: 30,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Coin information
      %{
        endpoint: :coins_info,
        type: :requests_per_minute,
        limit: 30,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Search endpoint
      %{
        endpoint: :search,
        type: :requests_per_minute,
        limit: 30,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Markets/rankings endpoint
      %{
        endpoint: :coins_markets,
        type: :requests_per_minute,
        limit: 30,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Historical data (legacy)
      %{
        endpoint: :history,
        type: :requests_per_minute,
        limit: 30,
        window_ms: :timer.minutes(1),
        weight: 1
      },

      # Default configuration (demo tier)
      %{
        endpoint: :default,
        type: :requests_per_minute,
        limit: 30,
        window_ms: :timer.minutes(1),
        weight: 1
      }
    ]
  end

  # Twelve Data Configuration
  # - 8 requests per minute for free tier
  # - Higher tiers have more requests
  defp twelve_data_config do
    [
      %{
        endpoint: :default,
        type: :requests_per_minute,
        # Free tier limit
        limit: 8,
        window_ms: :timer.minutes(1),
        weight: 1
      }
    ]
  end

  # Default configuration for unknown providers
  defp default_config do
    [
      %{
        endpoint: :default,
        type: :requests_per_minute,
        limit: 60,
        window_ms: :timer.minutes(1),
        weight: 1
      }
    ]
  end

  @doc """
  Calculates the appropriate weight for a Binance request based on parameters.

  Different Binance endpoints have different weight calculations:
  - Single symbol requests: weight 1
  - All symbols requests: weight 40+
  - Depth with limit: weight based on limit parameter
  """
  @spec calculate_binance_weight(atom(), keyword()) :: pos_integer()
  def calculate_binance_weight(endpoint, params \\ []) do
    case endpoint do
      :ticker_24hr -> calculate_ticker_weight(params)
      :depth -> calculate_depth_weight(params)
      :klines -> calculate_klines_weight(params)
      :exchange_info -> 20
      _ -> 1
    end
  end

  defp calculate_ticker_weight(params) do
    symbols = Keyword.get(params, :symbols, [])

    case symbols do
      # All symbols
      [] -> 40
      # Single symbol
      [_] -> 2
      # Multiple specific symbols
      _ -> 2 * length(symbols)
    end
  end

  defp calculate_depth_weight(params) do
    limit = Keyword.get(params, :limit, 100)

    cond do
      limit <= 100 -> 1
      limit <= 500 -> 5
      limit <= 1000 -> 10
      true -> 50
    end
  end

  defp calculate_klines_weight(params) do
    limit = Keyword.get(params, :limit, 500)

    cond do
      limit <= 100 -> 1
      limit <= 500 -> 2
      limit <= 1000 -> 5
      true -> 10
    end
  end

  @doc """
  Determines if a request should use a higher tier configuration.

  This can be based on API key tier, user subscription, etc.
  """
  @spec should_use_premium_limits?(atom(), keyword()) :: boolean()
  def should_use_premium_limits?(provider, opts \\ []) do
    api_key = Keyword.get(opts, :api_key)

    case provider do
      :alpha_vantage ->
        # Check if premium API key based on key format or external config
        api_key != nil and String.length(api_key) > 20

      :coin_gecko ->
        # Check for pro API key
        api_key != nil and String.contains?(api_key, "CG-")

      _ ->
        false
    end
  end

  @doc """
  Gets adjusted limits for premium/pro tiers.
  """
  @spec get_premium_config(atom()) :: [Behaviour.limit_config()]
  def get_premium_config(provider) do
    case provider do
      :alpha_vantage ->
        [
          # Time series endpoints (premium)
          %{
            endpoint: :time_series,
            type: :requests_per_minute,
            # Premium tier
            limit: 75,
            window_ms: :timer.minutes(1),
            weight: 1
          },

          # Quote endpoints (premium)
          %{
            endpoint: :quote,
            type: :requests_per_minute,
            # Premium tier
            limit: 75,
            window_ms: :timer.minutes(1),
            weight: 1
          },

          # Search endpoints (premium)
          %{
            endpoint: :search,
            type: :requests_per_minute,
            # Premium tier
            limit: 75,
            window_ms: :timer.minutes(1),
            weight: 1
          },

          # Premium daily quota
          %{
            endpoint: :daily_quota,
            type: :requests_per_day,
            # Premium daily limit
            limit: 75_000,
            window_ms: :timer.hours(24),
            weight: 1
          },

          # Default configuration (premium)
          %{
            endpoint: :default,
            type: :requests_per_minute,
            # Premium tier
            limit: 75,
            window_ms: :timer.minutes(1),
            weight: 1
          }
        ]

      :coin_gecko ->
        [
          %{
            endpoint: :default,
            type: :requests_per_minute,
            # Pro tier
            limit: 500,
            window_ms: :timer.minutes(1),
            weight: 1
          }
        ]

      _ ->
        get_provider_config(provider)
    end
  end
end
