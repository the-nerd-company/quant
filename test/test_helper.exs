# Configure logging for tests - suppress warnings to clean up output
require Logger
Logger.configure(level: :error)

ExUnit.start(capture_log: true)

# Exclude integration tests by default (they make real HTTP calls)
# To run them: mix test --include integration
ExUnit.configure(exclude: [integration: true])

# Check if we're running integration tests and configure accordingly
integration_mode = "--include" in System.argv() and "integration" in System.argv()

if integration_mode do
  # Use real HTTP client for integration tests
  IO.puts("Running in integration test mode - using real HTTP client")
  Application.put_env(:quant, :http_client, Quant.Explorer.HttpClient)
  Logger.configure(level: :info)

  # Still load test helper for integration tests
  Code.require_file("support/test_helper.exs", __DIR__)
  Code.require_file("support/python_helpers.ex", __DIR__)
else
  # Load test support modules for mocked tests
  Code.require_file("support/http_mock.ex", __DIR__)
  Code.require_file("support/http_client_mock.ex", __DIR__)
  Code.require_file("support/test_helper.exs", __DIR__)
  Code.require_file("support/python_helpers.ex", __DIR__)

  # Start HTTP mock for tests
  {:ok, _} = Quant.Explorer.HttpMock.start_link()

  # Use mock HTTP client for fast tests
  Application.put_env(:quant, :http_client, Quant.Explorer.HttpClient.Mock)
end

# Configure test environment
# Configure test environment
Application.put_env(:quant, :cache_ttl, :timer.seconds(1))
Application.put_env(:quant, :telemetry_enabled, false)

if not integration_mode do
  # Start HTTP mock for mocked tests only
  case Quant.Explorer.HttpMock.start_link() do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
    error -> raise "Failed to start HttpMock: #{inspect(error)}"
  end
end
