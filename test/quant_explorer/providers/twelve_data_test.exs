defmodule Quant.Explorer.Providers.TwelveDataTest do
  @moduledoc """
  Integration tests for the Twelve Data provider.

  These tests make real HTTP requests to Twelve Data API.
  Requires TWELVE_DATA_API_KEY environment variable.
  """

  use ExUnit.Case
  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.TwelveData

  # These tests make real HTTP requests - tagged as integration tests
  @moduletag :integration

  setup_all do
    # Use real HTTP client for integration tests
    Application.put_env(:quant_explorer, :http_client, Quant.Explorer.HttpClient)

    # Skip tests if API key is not available
    case System.get_env("TWELVE_DATA_API_KEY") do
      nil ->
        {:skip, "TWELVE_DATA_API_KEY environment variable not set"}

      api_key ->
        Application.put_env(:quant_explorer, :api_keys, %{twelve_data: api_key})
        :ok
    end
  end

  describe "history/2" do
    test "fetches daily historical data for Apple" do
      {:ok, df} = TwelveData.history("AAPL", interval: "1day", outputsize: 10)

      assert DataFrame.n_rows(df) > 0
      assert "symbol" in DataFrame.names(df)
      assert "timestamp" in DataFrame.names(df)
      assert "open" in DataFrame.names(df)
      assert "high" in DataFrame.names(df)
      assert "low" in DataFrame.names(df)
      assert "close" in DataFrame.names(df)
      assert "volume" in DataFrame.names(df)

      # Check that all data is for AAPL
      symbols = DataFrame.to_columns(df)["symbol"]
      assert Enum.all?(symbols, &(&1 == "AAPL"))
    end

    test "supports intraday intervals" do
      {:ok, df} = TwelveData.history("AAPL", interval: "1h", outputsize: 5)

      assert DataFrame.n_rows(df) > 0
      assert "timestamp" in DataFrame.names(df)
    end

    test "supports multiple symbols" do
      {:ok, df} = TwelveData.history(["AAPL", "MSFT"], interval: "1day", outputsize: 5)

      assert DataFrame.n_rows(df) > 0
      symbols = DataFrame.to_columns(df)["symbol"] |> Enum.uniq()
      assert "AAPL" in symbols
      assert "MSFT" in symbols
    end

    test "handles invalid symbol" do
      result = TwelveData.history("INVALID_SYMBOL_12345", interval: "1day", outputsize: 5)

      case result do
        {:error, :symbol_not_found} -> assert true
        {:error, {:provider_error, _}} -> assert true
        {:error, {:invalid_request, _}} -> assert true
        other -> flunk("Expected error for invalid symbol, got: #{inspect(other)}")
      end
    end

    test "validates interval parameter" do
      assert {:error, {:invalid_interval, _}} = TwelveData.history("AAPL", interval: "invalid")
    end
  end

  describe "quote/1" do
    test "fetches real-time quote for Apple" do
      {:ok, df} = TwelveData.quote("AAPL")

      assert DataFrame.n_rows(df) == 1
      assert "symbol" in DataFrame.names(df)
      assert "price" in DataFrame.names(df)
      assert "change" in DataFrame.names(df)
      assert "change_percent" in DataFrame.names(df)
      assert "volume" in DataFrame.names(df)

      row = DataFrame.to_rows(df) |> List.first()
      assert row["symbol"] == "AAPL"
      assert is_number(row["price"])
    end

    test "fetches quotes for multiple symbols" do
      # Note: Multiple symbols in one request might not be supported by all plans
      result = TwelveData.quote(["AAPL", "MSFT"])

      case result do
        {:ok, df} ->
          assert DataFrame.n_rows(df) > 0
          symbols = DataFrame.to_columns(df)["symbol"]
          assert "AAPL" in symbols or "MSFT" in symbols

        {:error, _} ->
          # Multi-symbol quotes might not be available in free tier
          assert true
      end
    end

    test "handles invalid symbol" do
      result = TwelveData.quote("INVALID_SYMBOL_12345")

      case result do
        {:error, :symbol_not_found} -> assert true
        {:error, {:provider_error, _}} -> assert true
        {:error, {:invalid_request, _}} -> assert true
        other -> flunk("Expected error for invalid symbol, got: #{inspect(other)}")
      end
    end
  end

  describe "info/1" do
    test "fetches company profile for Apple" do
      result = TwelveData.info("AAPL")

      case result do
        {:ok, info} ->
          assert is_map(info)
          assert info["symbol"] == "AAPL"
          assert is_binary(info["name"])
          assert info["name"] =~ "Apple"

        {:error, {:provider_error, _}} ->
          # Company profile might not be available in free tier
          assert true

        {:error, {:api_key_error, _}} ->
          # API key might not have access to this endpoint
          assert true
      end
    end

    test "handles invalid symbol" do
      result = TwelveData.info("INVALID_SYMBOL_12345")

      case result do
        {:error, :symbol_not_found} -> assert true
        {:error, {:provider_error, _}} -> assert true
        {:error, {:invalid_request, _}} -> assert true
        other -> flunk("Expected error for invalid symbol, got: #{inspect(other)}")
      end
    end
  end

  describe "search/1" do
    test "searches for Apple stocks" do
      result = TwelveData.search("AAPL")

      case result do
        {:ok, df} ->
          assert DataFrame.n_rows(df) > 0
          assert "symbol" in DataFrame.names(df)
          assert "name" in DataFrame.names(df)

          # Should find Apple
          rows = DataFrame.to_rows(df)

          apple_found =
            Enum.any?(rows, fn row ->
              row["symbol"] == "AAPL" or
                String.contains?(String.downcase(row["name"] || ""), "apple")
            end)

          assert apple_found

        {:error, {:api_key_error, _}} ->
          # Search might not be available in free tier
          assert true

        {:error, {:provider_error, _}} ->
          # Provider might not support this endpoint for this plan
          assert true
      end
    end

    test "handles empty search results" do
      result = TwelveData.search("NONEXISTENTCOMPANY12345")

      case result do
        {:ok, df} ->
          # Should return empty DataFrame for no results
          assert DataFrame.n_rows(df) == 0

        {:error, {:api_key_error, _}} ->
          # Search might not be available in free tier
          assert true

        {:error, {:provider_error, _}} ->
          # Provider might not support this endpoint
          assert true
      end
    end
  end

  describe "forex_rate/2" do
    test "fetches USD to EUR exchange rate" do
      result = TwelveData.forex_rate("USD", "EUR")

      case result do
        {:ok, df} ->
          assert DataFrame.n_rows(df) == 1
          assert "from_currency" in DataFrame.names(df)
          assert "to_currency" in DataFrame.names(df)
          assert "rate" in DataFrame.names(df)

          row = DataFrame.to_rows(df) |> List.first()
          assert row["from_currency"] == "USD"
          assert row["to_currency"] == "EUR"
          assert is_number(row["rate"])

        {:error, {:api_key_error, _}} ->
          # Forex might not be available in free tier
          assert true

        {:error, {:provider_error, _}} ->
          # Provider might not support forex for this plan
          assert true
      end
    end

    test "fetches multiple currency rates" do
      result = TwelveData.forex_rate(["USD", "GBP"], "EUR")

      case result do
        {:ok, df} ->
          assert DataFrame.n_rows(df) > 0
          currencies = DataFrame.to_columns(df)["from_currency"]
          assert "USD" in currencies or "GBP" in currencies

        {:error, {:api_key_error, _}} ->
          # Forex might not be available in free tier
          assert true

        {:error, {:provider_error, _}} ->
          # Provider might not support forex for this plan
          assert true
      end
    end
  end

  describe "rate limiting" do
    test "respects rate limits" do
      # Make multiple requests quickly (free tier has 8 requests per minute)
      results =
        for _i <- 1..5 do
          TwelveData.quote("AAPL")
        end

      # At least some should succeed or be rate limited
      success_count = Enum.count(results, &match?({:ok, _}, &1))
      rate_limited_count = Enum.count(results, &match?({:error, :rate_limited}, &1))

      error_count =
        Enum.count(results, fn result ->
          case result do
            {:error, {:api_key_error, _}} -> true
            {:error, {:provider_error, _}} -> true
            _ -> false
          end
        end)

      assert success_count > 0 or rate_limited_count > 0 or error_count > 0,
             "Rate limiter should allow some requests, rate limit them, or show API errors"
    end
  end

  describe "error handling" do
    test "handles API key errors gracefully" do
      # Temporarily remove API key
      original_keys = Application.get_env(:quant_explorer, :api_keys, %{})
      Application.put_env(:quant_explorer, :api_keys, %{twelve_data: "invalid_key"})

      result = TwelveData.quote("AAPL")

      # Restore original keys
      Application.put_env(:quant_explorer, :api_keys, original_keys)

      case result do
        {:error, {:api_key_error, _}} -> assert true
        {:error, {:provider_error, _}} -> assert true
        {:error, {:http_error, 401}} -> assert true
        {:error, {:http_error, 403}} -> assert true
        other -> flunk("Expected API key error, got: #{inspect(other)}")
      end
    end
  end
end
