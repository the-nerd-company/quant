import Config

# Test environment configuration
config :quant_explorer,
  # Higher rate limits for tests (using mocked responses mostly)
  rate_limits: %{
    yahoo_finance: 1000,
    alpha_vantage: 1000,
    binance: 1000,
    coin_gecko: 1000,
    twelve_data: 1000
  },

  # Very short cache TTL for tests
  cache_ttl: :timer.seconds(5),

  # Disable telemetry in tests
  telemetry_enabled: false,

  # Test API keys (use mocked/test values)
  api_keys: %{
    alpha_vantage: "test_key",
    twelve_data: "test_key",
    binance: "test_key",
    coin_gecko: "test_key"
  },

  # Test-specific configuration
  http_timeout: 5_000,

  # Use mock HTTP client for all tests by default
  http_client: Quant.Explorer.HttpClient.Mock

# Set log level to warning to reduce test output noise
config :logger, level: :warning

# Print only warnings and errors during test
config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :warning]
  ]
