defmodule Quant.Explorer.Providers.YahooFinanceIntegrationTest do
  use ExUnit.Case

  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.YahooFinance

  @moduletag :integration

  # Helper function to validate historical data schema
  defp validate_history_schema(df) do
    expected_columns = [
      "symbol",
      "timestamp",
      "open",
      "high",
      "low",
      "close",
      "volume",
      "adj_close",
      "currency",
      "exchange",
      "timezone",
      "data_source"
    ]

    actual_columns = DataFrame.names(df)

    if actual_columns == expected_columns do
      :ok
    else
      {:error,
       "Schema mismatch. Expected: #{inspect(expected_columns)}, Got: #{inspect(actual_columns)}"}
    end
  end

  describe "Yahoo Finance Integration Tests" do
    test "real API - fetch AAPL data" do
      # Only run if YAHOO_FINANCE_INTEGRATION_TEST env var is set
      if System.get_env("YAHOO_FINANCE_INTEGRATION_TEST") do
        assert {:ok, df} = YahooFinance.history("AAPL", period: "5d", interval: "1d")
        assert DataFrame.n_rows(df) > 0
        assert :ok == validate_history_schema(df)
      else
        # Skip integration test
        :ok
      end
    end

    test "real API - fetch multiple symbols" do
      if System.get_env("YAHOO_FINANCE_INTEGRATION_TEST") do
        assert {:ok, df} = YahooFinance.history(["AAPL", "MSFT"], period: "1d", interval: "5m")
        assert DataFrame.n_rows(df) > 0

        symbols = df |> DataFrame.pull("symbol") |> Enum.uniq() |> Enum.sort()
        assert "AAPL" in symbols
        assert "MSFT" in symbols
      else
        :ok
      end
    end

    test "real API - streaming large dataset" do
      if System.get_env("YAHOO_FINANCE_INTEGRATION_TEST") do
        stream = YahooFinance.history_stream("AAPL", period: "1y", interval: "1d")
        df = stream |> Enum.to_list() |> List.first()

        case df do
          {:ok, dataframe} ->
            # About 252 trading days per year
            assert DataFrame.n_rows(dataframe) > 200

          _ ->
            flunk("Expected successful DataFrame from stream")
        end
      else
        :ok
      end
    end
  end
end
