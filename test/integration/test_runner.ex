defmodule Quant.Explorer.Integration.TestRunner do
  @moduledoc """
  Helper module for running integration tests with proper setup and environment checks.
  """

  def check_environment do
    """
    Integration Test Environment Check:

    Required Environment Variables:
    - ALPHA_VANTAGE_API_KEY: #{env_status("ALPHA_VANTAGE_API_KEY")}
    - TWELVE_DATA_API_KEY: #{env_status("TWELVE_DATA_API_KEY")}
    - YAHOO_FINANCE_INTEGRATION_TEST: #{env_status("YAHOO_FINANCE_INTEGRATION_TEST")} (optional, for Yahoo tests)

    To run integration tests:
    mix test test/integration --include integration

    To run specific provider integration tests:
    mix test test/integration/providers/yahoo_finance_integration_test.exs --include integration
    mix test test/integration/providers/alpha_vantage_integration_test.exs --include integration
    mix test test/integration/providers/twelve_data_integration_test.exs --include integration
    """
    |> IO.puts()
  end

  defp env_status(var) do
    case System.get_env(var) do
      nil -> "❌ Not set"
      "" -> "❌ Empty"
      _value -> "✅ Set"
    end
  end
end
