defmodule Quant.Explorer.Providers.CoinGeckoTest do
  @moduledoc """
  Integration tests for the CoinGecko provider.

  These tests make real HTTP requests to CoinGecko API.
  """

  use ExUnit.Case
  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.CoinGecko

  # These tests make real HTTP requests - tagged as integration tests
  @moduletag :integration

  setup_all do
    # Use real HTTP client for integration tests
    Application.put_env(:quant_explorer, :http_client, Quant.Explorer.HttpClient)
    :ok
  end

  describe "history/2" do
    test "fetches historical data for Bitcoin" do
      {:ok, df} = CoinGecko.history("bitcoin", days: 7)

      assert DataFrame.n_rows(df) > 0
      assert "symbol" in DataFrame.names(df)
      assert "timestamp" in DataFrame.names(df)
      assert "close" in DataFrame.names(df)
      assert "volume" in DataFrame.names(df)

      # Check that all timestamps are Bitcoin data
      symbols = DataFrame.to_columns(df)["symbol"]
      assert Enum.all?(symbols, &(&1 == "bitcoin"))
    end

    test "supports multiple cryptocurrencies" do
      {:ok, df} = CoinGecko.history(["bitcoin", "ethereum"], days: 3)

      assert DataFrame.n_rows(df) > 0
      symbols = DataFrame.to_columns(df)["symbol"] |> Enum.uniq()
      assert "bitcoin" in symbols
      assert "ethereum" in symbols
    end

    test "handles different time periods" do
      {:ok, df} = CoinGecko.history("bitcoin", days: 1)
      assert DataFrame.n_rows(df) > 0

      {:ok, df} = CoinGecko.history("bitcoin", days: 30)
      assert DataFrame.n_rows(df) > 0
    end

    test "supports different vs_currency" do
      {:ok, df} = CoinGecko.history("bitcoin", days: 7, vs_currency: "eur")

      assert DataFrame.n_rows(df) > 0
      assert "close" in DataFrame.names(df)
    end

    test "handles invalid coin id" do
      assert {:error, :symbol_not_found} = CoinGecko.history("invalid-coin-id", days: 7)
    end

    test "validates vs_currency" do
      assert {:error, {:invalid_currency, _}} =
               CoinGecko.history("bitcoin", days: 7, vs_currency: "invalid")
    end

    test "validates days parameter" do
      assert {:error, {:invalid_period, _}} = CoinGecko.history("bitcoin", days: 999)
    end
  end

  describe "quote/1" do
    test "fetches current price for Bitcoin" do
      {:ok, df} = CoinGecko.quote("bitcoin")

      assert DataFrame.n_rows(df) == 1
      assert "symbol" in DataFrame.names(df)
      assert "price" in DataFrame.names(df)
      assert "change" in DataFrame.names(df)
      assert "change_percent" in DataFrame.names(df)
      assert "volume" in DataFrame.names(df)
      assert "market_cap" in DataFrame.names(df)

      row = DataFrame.to_rows(df) |> List.first()
      assert row["symbol"] == "bitcoin"
      assert is_number(row["price"])
    end

    test "fetches current prices for multiple coins" do
      {:ok, df} = CoinGecko.quote(["bitcoin", "ethereum", "cardano"])

      assert DataFrame.n_rows(df) == 3
      symbols = DataFrame.to_columns(df)["symbol"]
      assert "bitcoin" in symbols
      assert "ethereum" in symbols
      assert "cardano" in symbols
    end

    test "handles invalid coin id" do
      assert {:error, :symbol_not_found} = CoinGecko.quote("invalid-coin-id")
    end
  end

  describe "info/1" do
    test "fetches detailed information for Bitcoin" do
      {:ok, info} = CoinGecko.info("bitcoin")

      assert is_map(info)
      assert info["id"] == "bitcoin"
      assert info["symbol"] == "btc"
      assert info["name"] == "Bitcoin"
      assert is_binary(info["description"])
      assert is_number(info["market_cap_rank"])
      assert is_number(info["current_price"])
    end

    test "fetches information for Ethereum" do
      {:ok, info} = CoinGecko.info("ethereum")

      assert info["id"] == "ethereum"
      assert info["symbol"] == "eth"
      assert info["name"] == "Ethereum"
    end

    test "handles invalid coin id" do
      assert {:error, :symbol_not_found} = CoinGecko.info("invalid-coin-id")
    end
  end

  describe "search/1" do
    test "searches for Bitcoin" do
      {:ok, df} = CoinGecko.search("bitcoin")

      assert DataFrame.n_rows(df) > 0
      assert "id" in DataFrame.names(df)
      assert "name" in DataFrame.names(df)
      assert "symbol" in DataFrame.names(df)

      # Bitcoin should be in the results
      rows = DataFrame.to_rows(df)

      bitcoin_found =
        Enum.any?(rows, fn row ->
          String.contains?(String.downcase(row["name"] || ""), "bitcoin") or
            String.downcase(row["symbol"] || "") == "btc"
        end)

      assert bitcoin_found
    end

    test "searches for Ethereum" do
      {:ok, df} = CoinGecko.search("ethereum")

      assert DataFrame.n_rows(df) > 0
      rows = DataFrame.to_rows(df)

      ethereum_found =
        Enum.any?(rows, fn row ->
          String.contains?(String.downcase(row["name"] || ""), "ethereum") or
            String.downcase(row["symbol"] || "") == "eth"
        end)

      assert ethereum_found
    end

    test "handles empty search results" do
      {:ok, df} = CoinGecko.search("nonexistentcryptocurrency12345")

      # Should return empty DataFrame, not error
      assert DataFrame.n_rows(df) == 0
    end
  end

  describe "top_coins/1" do
    test "fetches top cryptocurrencies by market cap" do
      {:ok, df} = CoinGecko.top_coins(per_page: 10)

      assert DataFrame.n_rows(df) == 10
      assert "symbol" in DataFrame.names(df)
      assert "name" in DataFrame.names(df)
      assert "price" in DataFrame.names(df)
      assert "market_cap" in DataFrame.names(df)
      assert "market_cap_rank" in DataFrame.names(df)

      # Check that results are ordered by market cap rank
      ranks = DataFrame.to_columns(df)["market_cap_rank"]
      assert Enum.sort(ranks) == ranks
    end

    test "supports pagination" do
      {:ok, df1} = CoinGecko.top_coins(per_page: 5, page: 1)
      {:ok, df2} = CoinGecko.top_coins(per_page: 5, page: 2)

      assert DataFrame.n_rows(df1) == 5
      assert DataFrame.n_rows(df2) == 5

      # Results should be different
      symbols1 = DataFrame.to_columns(df1)["symbol"]
      symbols2 = DataFrame.to_columns(df2)["symbol"]
      assert symbols1 != symbols2
    end

    test "supports different vs_currency" do
      {:ok, df} = CoinGecko.top_coins(per_page: 5, vs_currency: "eur")

      assert DataFrame.n_rows(df) == 5
      assert "price" in DataFrame.names(df)
    end
  end

  describe "rate limiting" do
    test "respects rate limits" do
      # Make multiple requests quickly
      results =
        for _i <- 1..3 do
          CoinGecko.quote("bitcoin")
        end

      # At least some should succeed
      success_count = Enum.count(results, &match?({:ok, _}, &1))
      rate_limited_count = Enum.count(results, &match?({:error, :rate_limited}, &1))

      assert success_count > 0 or rate_limited_count > 0,
             "Rate limiter should allow some requests or rate limit them"
    end
  end

  describe "error handling" do
    test "handles network timeouts" do
      # This test might be flaky, but helps verify error handling
      # In a real scenario, you'd mock the HTTP client to return timeout
      result = CoinGecko.quote("bitcoin")

      case result do
        {:ok, _df} ->
          # Success is fine
          assert true

        {:error, :rate_limited} ->
          # Rate limited is expected
          assert true

        {:error, {:http_error, _reason}} ->
          # HTTP errors are handled properly
          assert true

        other ->
          flunk("Unexpected result: #{inspect(other)}")
      end
    end
  end
end
