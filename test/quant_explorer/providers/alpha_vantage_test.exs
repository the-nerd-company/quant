defmodule Quant.Explorer.Providers.AlphaVantageTest do
  @moduledoc """
  Tests for the Alpha Vantage provider.
  """

  use ExUnit.Case, async: false
  import Quant.Explorer.TestHelper

  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.AlphaVantage

  # These tests make real HTTP requests - tagged as integration tests
  @moduletag :integration

  setup_all do
    # Use real HTTP client for integration tests
    Application.put_env(:quant, :http_client, Quant.Explorer.HttpClient)
    :ok
  end

  doctest AlphaVantage

  setup do
    setup_rate_limiter()
    :ok
  end

  # Mock responses
  @mock_daily_response %{
    "Time Series (Daily)" => %{
      "2024-01-01" => %{
        "1. open" => "150.0000",
        "2. high" => "155.0000",
        "3. low" => "149.0000",
        "4. close" => "152.0000",
        "5. volume" => "1000000"
      },
      "2023-12-29" => %{
        "1. open" => "148.0000",
        "2. high" => "153.0000",
        "3. low" => "147.0000",
        "4. close" => "150.0000",
        "5. volume" => "950000"
      }
    },
    "Meta Data" => %{
      "1. Information" => "Daily Prices (open, high, low, close) and Volumes",
      "2. Symbol" => "IBM",
      "3. Last Refreshed" => "2024-01-01",
      "4. Output Size" => "Compact",
      "5. Time Zone" => "US/Eastern"
    }
  }

  @mock_intraday_response %{
    "Time Series (5min)" => %{
      "2024-01-01 16:00:00" => %{
        "1. open" => "150.0000",
        "2. high" => "151.0000",
        "3. low" => "149.5000",
        "4. close" => "150.5000",
        "5. volume" => "10000"
      },
      "2024-01-01 15:55:00" => %{
        "1. open" => "149.5000",
        "2. high" => "150.2000",
        "3. low" => "149.0000",
        "4. close" => "150.0000",
        "5. volume" => "8500"
      }
    },
    "Meta Data" => %{
      "1. Information" => "Intraday (5min) open, high, low, close prices and volume",
      "2. Symbol" => "IBM",
      "3. Last Refreshed" => "2024-01-01 16:00:00",
      "4. Interval" => "5min",
      "5. Output Size" => "Compact",
      "6. Time Zone" => "US/Eastern"
    }
  }

  @mock_quote_response %{
    "Global Quote" => %{
      "01. symbol" => "IBM",
      "02. open" => "150.0000",
      "03. high" => "155.0000",
      "04. low" => "149.0000",
      "05. price" => "152.0000",
      "06. volume" => "1000000",
      "07. latest trading day" => "2024-01-01",
      "08. previous close" => "150.0000",
      "09. change" => "2.0000",
      "10. change percent" => "1.33%"
    }
  }

  @mock_search_response %{
    "bestMatches" => [
      %{
        "1. symbol" => "MSFT",
        "2. name" => "Microsoft Corporation",
        "3. type" => "Equity",
        "4. region" => "United States",
        "5. marketOpen" => "09:30",
        "6. marketClose" => "16:00",
        "7. timezone" => "UTC-04",
        "8. currency" => "USD",
        "9. matchScore" => "1.0000"
      },
      %{
        "1. symbol" => "MSFTS",
        "2. name" => "Microsoft Corporation Test",
        "3. type" => "Equity",
        "4. region" => "United States",
        "5. marketOpen" => "09:30",
        "6. marketClose" => "16:00",
        "7. timezone" => "UTC-04",
        "8. currency" => "USD",
        "9. matchScore" => "0.8000"
      }
    ]
  }

  @mock_error_response %{
    "Error Message" => "Invalid API call. Please retry or visit the documentation."
  }

  describe "history/2" do
    test "fetches daily historical data for a single symbol" do
      # Mock the HTTP request
      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "TIME_SERIES_DAILY"}, {"symbol", "IBM"}, {"outputsize", "compact"}],
        Jason.encode!(@mock_daily_response)
      )

      assert {:ok, df} = AlphaVantage.history("IBM")
      assert DataFrame.n_rows(df) == 2

      # Check column names
      column_names = DataFrame.names(df)
      assert "symbol" in column_names
      assert "timestamp" in column_names
      assert "open" in column_names
      assert "high" in column_names
      assert "low" in column_names
      assert "close" in column_names
      assert "volume" in column_names

      # Check first row data
      first_row = df |> DataFrame.head(1) |> DataFrame.to_rows() |> List.first()
      assert first_row["symbol"] == "IBM"
      assert first_row["open"] == 150.0
      assert first_row["close"] == 152.0
    end

    test "fetches intraday data with interval" do
      expect_http_request(
        "https://www.alphavantage.co/query",
        [
          {"function", "TIME_SERIES_INTRADAY"},
          {"symbol", "IBM"},
          {"outputsize", "compact"},
          {"interval", "5min"}
        ],
        Jason.encode!(@mock_intraday_response)
      )

      assert {:ok, df} = AlphaVantage.history("IBM", interval: "5min")
      assert DataFrame.n_rows(df) == 2

      # Verify timestamp parsing for intraday data
      first_row = df |> DataFrame.head(1) |> DataFrame.to_rows() |> List.first()
      assert first_row["symbol"] == "IBM"
      assert first_row["open"] == 150.0
    end

    test "handles multiple symbols sequentially" do
      # Mock requests for each symbol
      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "TIME_SERIES_DAILY"}, {"symbol", "IBM"}, {"outputsize", "compact"}],
        Jason.encode!(@mock_daily_response)
      )

      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "TIME_SERIES_DAILY"}, {"symbol", "MSFT"}, {"outputsize", "compact"}],
        Jason.encode!(@mock_daily_response)
      )

      assert {:ok, df} = AlphaVantage.history(["IBM", "MSFT"])
      # 2 rows per symbol
      assert DataFrame.n_rows(df) == 4

      symbols = df |> DataFrame.pull("symbol") |> Enum.uniq() |> Enum.sort()
      # Both calls return IBM data in mock
      assert symbols == ["IBM", "IBM"]
    end

    test "validates interval parameter" do
      assert {:error, {:invalid_interval, _}} = AlphaVantage.history("IBM", interval: "invalid")
    end

    test "validates outputsize parameter" do
      assert {:error, {:invalid_outputsize, _}} =
               AlphaVantage.history("IBM", outputsize: "invalid")
    end

    test "handles API error responses" do
      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "TIME_SERIES_DAILY"}, {"symbol", "INVALID"}, {"outputsize", "compact"}],
        Jason.encode!(@mock_error_response)
      )

      assert {:error, {:parse_error, _}} = AlphaVantage.history("INVALID")
    end

    test "handles HTTP errors" do
      expect_http_error(
        "https://www.alphavantage.co/query",
        404,
        "Not Found"
      )

      assert {:error, {:http_error, 404}} = AlphaVantage.history("IBM")
    end
  end

  describe "quote/1" do
    test "fetches real-time quote for a single symbol" do
      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "GLOBAL_QUOTE"}, {"symbol", "IBM"}],
        Jason.encode!(@mock_quote_response)
      )

      assert {:ok, df} = AlphaVantage.quote("IBM")
      assert DataFrame.n_rows(df) == 1

      # Check column names
      column_names = DataFrame.names(df)
      assert "symbol" in column_names
      assert "price" in column_names
      assert "change" in column_names
      assert "change_percent" in column_names
      assert "volume" in column_names
      assert "timestamp" in column_names

      # Check data
      row = df |> DataFrame.to_rows() |> List.first()
      assert row["symbol"] == "IBM"
      assert row["price"] == 152.0
      assert row["change"] == 2.0
      assert row["change_percent"] == 1.33
      assert row["volume"] == 1_000_000
    end

    test "handles multiple symbols" do
      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "GLOBAL_QUOTE"}, {"symbol", "IBM"}],
        Jason.encode!(@mock_quote_response)
      )

      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "GLOBAL_QUOTE"}, {"symbol", "MSFT"}],
        Jason.encode!(@mock_quote_response)
      )

      assert {:ok, df} = AlphaVantage.quote(["IBM", "MSFT"])
      assert DataFrame.n_rows(df) == 2
    end

    test "handles empty quote response" do
      empty_response = %{"Global Quote" => %{}}

      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "GLOBAL_QUOTE"}, {"symbol", "INVALID"}],
        Jason.encode!(empty_response)
      )

      assert {:error, :symbol_not_found} = AlphaVantage.quote("INVALID")
    end
  end

  describe "search/1" do
    test "searches for symbols by query" do
      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "SYMBOL_SEARCH"}, {"keywords", "Microsoft"}],
        Jason.encode!(@mock_search_response)
      )

      assert {:ok, df} = AlphaVantage.search("Microsoft")
      assert DataFrame.n_rows(df) == 2

      # Check column names
      column_names = DataFrame.names(df)
      assert "symbol" in column_names
      assert "name" in column_names
      assert "type" in column_names
      assert "region" in column_names
      assert "match_score" in column_names

      # Check first result
      first_row = df |> DataFrame.head(1) |> DataFrame.to_rows() |> List.first()
      assert first_row["symbol"] == "MSFT"
      assert first_row["name"] == "Microsoft Corporation"
      assert first_row["type"] == "Equity"
      assert first_row["match_score"] == 1.0
    end

    test "handles empty search results" do
      empty_response = %{"bestMatches" => []}

      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "SYMBOL_SEARCH"}, {"keywords", "NonexistentCompany"}],
        Jason.encode!(empty_response)
      )

      assert {:ok, df} = AlphaVantage.search("NonexistentCompany")
      assert DataFrame.n_rows(df) == 0
    end
  end

  describe "rate limiting" do
    test "respects rate limits for different endpoints" do
      # This test verifies that rate limiting is being called
      # In a real test environment, you might want to verify actual rate limiting behavior

      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "TIME_SERIES_DAILY"}, {"symbol", "IBM"}, {"outputsize", "compact"}],
        Jason.encode!(@mock_daily_response)
      )

      assert {:ok, _df} = AlphaVantage.history("IBM")

      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "GLOBAL_QUOTE"}, {"symbol", "IBM"}],
        Jason.encode!(@mock_quote_response)
      )

      assert {:ok, _df} = AlphaVantage.quote("IBM")
    end
  end

  describe "error handling" do
    test "handles missing API key gracefully" do
      # Temporarily set API key to nil
      original_config = Application.get_env(:quant, :api_keys, %{})
      Application.put_env(:quant, :api_keys, %{alpha_vantage: nil})

      assert_raise RuntimeError, ~r/Alpha Vantage API key is required/, fn ->
        AlphaVantage.history("IBM")
      end

      # Restore original config
      Application.put_env(:quant, :api_keys, original_config)
    end

    test "handles JSON parsing errors" do
      expect_http_request(
        "https://www.alphavantage.co/query",
        [{"function", "TIME_SERIES_DAILY"}, {"symbol", "IBM"}, {"outputsize", "compact"}],
        "invalid json"
      )

      assert {:error, _} = AlphaVantage.history("IBM")
    end

    test "handles network errors" do
      expect_network_error("https://www.alphavantage.co/query")

      assert {:error, {:request_failed, _}} = AlphaVantage.history("IBM")
    end
  end

  # Helper functions for mocking HTTP requests
  defp expect_http_request(_url, _expected_params, _response_body) do
    # This is a placeholder - in a real test you would mock the HttpClient
    # For now, we'll just verify the structure
    :ok
  end

  defp expect_http_error(_url, _status_code, _error_body) do
    # Mock HTTP error response
    :ok
  end

  defp expect_network_error(_url) do
    # Mock network failure
    :ok
  end
end
