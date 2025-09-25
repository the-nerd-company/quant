import Config

# Runtime configuration (for production and deployed environments)
# This configuration is loaded during runtime and can access system environment variables.

if config_env() == :prod do
  config :quant_explorer,
    # Production rate limits (more conservative)
    rate_limits: %{
      yahoo_finance: 100,
      alpha_vantage: 5,
      binance: 1200,
      coin_gecko: 50,
      twelve_data: 8
    },

    # Longer cache TTL for production
    cache_ttl: :timer.minutes(15),

    # Production logging
    log_level: :info,

    # Production API keys from environment variables
    api_keys: %{
      alpha_vantage: {:system, "ALPHA_VANTAGE_API_KEY"},
      twelve_data: {:system, "TWELVE_DATA_API_KEY"},
      binance: {:system, "BINANCE_API_KEY"},
      coin_gecko: {:system, "COINGECKO_API_KEY"}
    }

  # Configure logger for production
  config :logger,
    level: :info,
    compile_time_purge_matching: [
      [level_lower_than: :info]
    ]
end

# Runtime configuration can also read from system environment for any environment
# This allows for easy deployment configuration without rebuilding

if System.get_env("FIN_EXPLORER_LOG_LEVEL") do
  log_level = System.get_env("FIN_EXPLORER_LOG_LEVEL") |> String.to_existing_atom()
  config :quant_explorer, log_level: log_level
  config :logger, level: log_level
end

if System.get_env("FIN_EXPLORER_HTTP_TIMEOUT") do
  timeout = System.get_env("FIN_EXPLORER_HTTP_TIMEOUT") |> String.to_integer()
  config :quant_explorer, http_timeout: timeout
end

if System.get_env("FIN_EXPLORER_CACHE_TTL") do
  ttl = System.get_env("FIN_EXPLORER_CACHE_TTL") |> String.to_integer()
  config :quant_explorer, cache_ttl: ttl
end
