import Config

{project_path, 0} = System.cmd("pwd", [])
project_path = String.replace(project_path, ~r/\n/, "/")

config :git_hooks,
  hooks: [
    pre_commit: [
      tasks: [
        {:mix_task, :format},
        {:mix_task, :credo, ["--strict"]}
      ]
    ],
    pre_push: [
      tasks: [
        {:cmd, "mix compile --force --warnings-as-errors"},
        {:mix_task, :format, ["--check-formatted"]},
        {:mix_task, :dialyzer, ["--force-check"]},
        {:mix_task, :credo, ["--strict"]},
        {:cmd, "mix compile --force --warnings-as-errors", env: [{"MIX_ENV", "test"}]},
        {:cmd, "make test"},
        {:cmd, "mix coveralls.cobertura", env: [{"MIX_ENV", "test"}]},
        {:cmd, "echo 'success!' 🎉"}
      ]
    ]
  ],
  project_path: project_path

# Development environment configuration
config :quant,
  # Lower rate limits for development to avoid hitting API limits during testing
  rate_limits: %{
    yahoo_finance: 60,
    alpha_vantage: 5,
    binance: 600,
    coin_gecko: 30,
    twelve_data: 8
  },

  # Shorter cache TTL for development
  cache_ttl: :timer.minutes(1),

  # Enable more verbose logging
  log_level: :debug,

  # Development API keys (still from environment for security)
  api_keys: %{
    alpha_vantage: {:system, "ALPHA_VANTAGE_API_KEY_DEV", "demo"},
    twelve_data: {:system, "TWELVE_DATA_API_KEY_DEV"},
    binance: {:system, "BINANCE_API_KEY_DEV"},
    coin_gecko: {:system, "COINGECKO_API_KEY_DEV"}
  }

# Enable development-time logging
config :logger,
  level: :debug,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]
