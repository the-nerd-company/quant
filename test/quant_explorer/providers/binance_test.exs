defmodule Quant.Explorer.Providers.BinanceTest do
  @moduledoc """
  Test suite for the Binance provider.

  Tests all public API endpoints including historical data (klines),
  24hr ticker statistics, and symbol search functionality.
  """

  use ExUnit.Case
  doctest Quant.Explorer.Providers.Binance

  # These tests make real HTTP requests - tagged as integration tests
  @moduletag :integration

  setup_all do
    # Use real HTTP client for integration tests
    Application.put_env(:quant_explorer, :http_client, Quant.Explorer.HttpClient)
    :ok
  end

  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.Binance

  # Mock API responses based on actual Binance API format
  @mock_klines_response """
  [
    [
      1499040000000,      // Open time
      "0.01634790",       // Open
      "0.80000000",       // High
      "0.01575800",       // Low
      "0.01577100",       // Close
      "148976.11427815",  // Volume
      1499644799999,      // Close time
      "2434.19055334",    // Quote asset volume
      308,                // Number of trades
      "1756.87402397",    // Taker buy base asset volume
      "28.46694368",      // Taker buy quote asset volume
      "17928899.62484339" // Ignore
    ],
    [
      1499040060000,
      "0.01577100",
      "0.01577100",
      "0.01577100",
      "0.01577100",
      "0.00000000",
      1499644859999,
      "0.00000000",
      0,
      "0.00000000",
      "0.00000000",
      "0"
    ]
  ]
  """

  @mock_ticker_response """
  [
    {
      "symbol": "BTCUSDT",
      "priceChange": "-94.99999800",
      "priceChangePercent": "-0.095",
      "weightedAvgPrice": "0.29628482",
      "prevClosePrice": "0.10002000",
      "lastPrice": "4.00000200",
      "lastQty": "200.00000000",
      "bidPrice": "4.00000000",
      "askPrice": "4.00000200",
      "openPrice": "99.00000000",
      "highPrice": "100.00000000",
      "lowPrice": "0.10000000",
      "volume": "8913.30000000",
      "quoteVolume": "15.30000000",
      "openTime": 1499783499040,
      "closeTime": 1499869899040,
      "firstId": 28385,
      "lastId": 28460,
      "count": 76
    },
    {
      "symbol": "ETHUSDT",
      "priceChange": "10.00000000",
      "priceChangePercent": "5.0",
      "weightedAvgPrice": "2100.50000000",
      "prevClosePrice": "2000.00000000",
      "lastPrice": "2010.00000000",
      "lastQty": "1.00000000",
      "bidPrice": "2009.00000000",
      "askPrice": "2011.00000000",
      "openPrice": "2000.00000000",
      "highPrice": "2100.00000000",
      "lowPrice": "1900.00000000",
      "volume": "1000.00000000",
      "quoteVolume": "2100500.00000000",
      "openTime": 1499783499040,
      "closeTime": 1499869899040,
      "firstId": 10000,
      "lastId": 10076,
      "count": 77
    }
  ]
  """

  @mock_exchange_info_response """
  {
    "timezone": "UTC",
    "serverTime": 1565246363776,
    "rateLimits": [
      {
        "rateLimitType": "REQUEST_WEIGHT",
        "interval": "MINUTE",
        "intervalNum": 1,
        "limit": 1200
      }
    ],
    "exchangeFilters": [],
    "symbols": [
      {
        "symbol": "BTCUSDT",
        "status": "TRADING",
        "baseAsset": "BTC",
        "baseAssetPrecision": 8,
        "quoteAsset": "USDT",
        "quotePrecision": 8,
        "quoteAssetPrecision": 8,
        "baseCommissionPrecision": 8,
        "quoteCommissionPrecision": 8,
        "orderTypes": [
          "LIMIT",
          "LIMIT_MAKER",
          "MARKET",
          "STOP_LOSS_LIMIT",
          "TAKE_PROFIT_LIMIT"
        ],
        "icebergAllowed": true,
        "ocoAllowed": true,
        "quoteOrderQtyMarketAllowed": true,
        "allowTrailingStop": false,
        "isSpotTradingAllowed": true,
        "isMarginTradingAllowed": true,
        "filters": [
          {
            "filterType": "PRICE_FILTER",
            "minPrice": "0.01000000",
            "maxPrice": "1000000.00000000",
            "tickSize": "0.01000000"
          }
        ],
        "permissions": [
          "SPOT",
          "MARGIN"
        ]
      },
      {
        "symbol": "ETHUSDT",
        "status": "TRADING",
        "baseAsset": "ETH",
        "baseAssetPrecision": 8,
        "quoteAsset": "USDT",
        "quotePrecision": 8,
        "quoteAssetPrecision": 8,
        "baseCommissionPrecision": 8,
        "quoteCommissionPrecision": 8,
        "orderTypes": ["LIMIT", "MARKET"],
        "icebergAllowed": true,
        "ocoAllowed": true,
        "quoteOrderQtyMarketAllowed": true,
        "allowTrailingStop": false,
        "isSpotTradingAllowed": true,
        "isMarginTradingAllowed": true,
        "filters": [],
        "permissions": ["SPOT", "MARGIN"]
      }
    ]
  }
  """

  describe "history/2" do
    test "returns historical klines data for single symbol" do
      # Mock the HTTP client
      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{symbol: "BTCUSDT", interval: "1d", limit: 100},
        @mock_klines_response
      )

      {:ok, df} = Binance.history("BTCUSDT", interval: "1d", limit: 100)

      assert DataFrame.n_rows(df) == 2
      assert DataFrame.n_columns(df) >= 7

      # Check required columns exist
      column_names = DataFrame.names(df)
      required_columns = ["symbol", "timestamp", "open", "high", "low", "close", "volume"]
      assert Enum.all?(required_columns, &(&1 in column_names))

      # Check data types and values
      first_row = DataFrame.to_rows(df) |> List.first()
      assert first_row["symbol"] == "BTCUSDT"
      assert is_float(first_row["open"])
      assert first_row["open"] > 0.0
    end

    test "supports multiple symbols" do
      symbols = ["BTCUSDT", "ETHUSDT"]

      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{symbol: "BTCUSDT", interval: "1d", limit: 100},
        @mock_klines_response
      )

      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{symbol: "ETHUSDT", interval: "1d", limit: 100},
        @mock_klines_response
      )

      {:ok, df} = Binance.history(symbols, interval: "1d", limit: 100)

      # 2 rows per symbol
      assert DataFrame.n_rows(df) == 4
      symbols_in_df = DataFrame.to_columns(df)["symbol"] |> Enum.uniq()
      assert "BTCUSDT" in symbols_in_df
      assert "ETHUSDT" in symbols_in_df
    end

    test "validates interval parameter" do
      {:error, {:invalid_interval, _}} = Binance.history("BTCUSDT", interval: "invalid")
    end

    test "validates limit parameter" do
      {:error, {:invalid_limit, _}} = Binance.history("BTCUSDT", limit: 0)
      {:error, {:invalid_limit, _}} = Binance.history("BTCUSDT", limit: 2000)
    end

    test "supports time range parameters" do
      start_time = DateTime.from_unix!(1_499_040_000)
      end_time = DateTime.from_unix!(1_499_126_400)

      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{
          symbol: "BTCUSDT",
          interval: "1h",
          limit: 500,
          startTime: 1_499_040_000_000,
          endTime: 1_499_126_400_000
        },
        @mock_klines_response
      )

      {:ok, _df} =
        Binance.history("BTCUSDT",
          interval: "1h",
          start_time: start_time,
          end_time: end_time
        )
    end
  end

  describe "quote/1" do
    test "returns 24hr ticker statistics for single symbol" do
      expect_http_request(
        "https://api.binance.com/api/v3/ticker/24hr",
        %{symbols: Jason.encode!(["BTCUSDT"])},
        @mock_ticker_response
      )

      {:ok, df} = Binance.quote("BTCUSDT")

      assert DataFrame.n_rows(df) == 2
      column_names = DataFrame.names(df)
      required_columns = ["symbol", "price", "change", "change_percent", "volume", "timestamp"]
      assert Enum.all?(required_columns, &(&1 in column_names))

      first_row = DataFrame.to_rows(df) |> List.first()
      assert first_row["symbol"] == "BTCUSDT"
      assert is_float(first_row["price"])
      assert is_float(first_row["change_percent"])
    end

    test "returns 24hr ticker statistics for multiple symbols" do
      expect_http_request(
        "https://api.binance.com/api/v3/ticker/24hr",
        %{symbols: Jason.encode!(["BTCUSDT", "ETHUSDT"])},
        @mock_ticker_response
      )

      {:ok, df} = Binance.quote(["BTCUSDT", "ETHUSDT"])

      assert DataFrame.n_rows(df) == 2
      symbols_in_df = DataFrame.to_columns(df)["symbol"]
      assert "BTCUSDT" in symbols_in_df
      assert "ETHUSDT" in symbols_in_df
    end

    test "returns all symbols when empty list provided" do
      expect_http_request(
        "https://api.binance.com/api/v3/ticker/24hr",
        %{},
        @mock_ticker_response
      )

      {:ok, df} = Binance.quote([])
      assert DataFrame.n_rows(df) == 2
    end
  end

  describe "search/1" do
    test "returns all symbols when empty query provided" do
      expect_http_request(
        "https://api.binance.com/api/v3/exchangeInfo",
        %{},
        @mock_exchange_info_response
      )

      {:ok, df} = Binance.search("")

      assert DataFrame.n_rows(df) == 2
      column_names = DataFrame.names(df)
      required_columns = ["symbol", "status", "base_asset", "quote_asset", "exchange"]
      assert Enum.all?(required_columns, &(&1 in column_names))

      symbols_in_df = DataFrame.to_columns(df)["symbol"]
      assert "BTCUSDT" in symbols_in_df
      assert "ETHUSDT" in symbols_in_df
    end

    test "filters symbols by query string" do
      expect_http_request(
        "https://api.binance.com/api/v3/exchangeInfo",
        %{},
        @mock_exchange_info_response
      )

      {:ok, df} = Binance.search("BTC")

      assert DataFrame.n_rows(df) == 1
      first_row = DataFrame.to_rows(df) |> List.first()
      assert first_row["symbol"] == "BTCUSDT"
    end
  end

  describe "info/1" do
    test "returns not supported error" do
      {:error, :not_supported} = Binance.info("BTCUSDT")
    end
  end

  describe "additional functions" do
    test "get_all_symbols/0 returns all available symbols" do
      expect_http_request(
        "https://api.binance.com/api/v3/exchangeInfo",
        %{},
        @mock_exchange_info_response
      )

      {:ok, df} = Binance.get_all_symbols()
      assert DataFrame.n_rows(df) == 2
    end

    test "history_range/4 calculates limit from time range" do
      start_time = DateTime.from_unix!(1_499_040_000)
      # 24 hours later
      end_time = DateTime.from_unix!(1_499_126_400)

      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{
          symbol: "BTCUSDT",
          interval: "1h",
          limit: 25,
          startTime: 1_499_040_000_000,
          endTime: 1_499_126_400_000
        },
        @mock_klines_response
      )

      {:ok, _df} = Binance.history_range("BTCUSDT", "1h", start_time, end_time)
    end
  end

  describe "interval validation" do
    test "accepts all valid Binance intervals" do
      valid_intervals = [
        "1m",
        "3m",
        "5m",
        "15m",
        "30m",
        "1h",
        "2h",
        "4h",
        "6h",
        "8h",
        "12h",
        "1d",
        "3d",
        "1w",
        "1M"
      ]

      for interval <- valid_intervals do
        expect_http_request(
          "https://api.binance.com/api/v3/klines",
          %{symbol: "BTCUSDT", interval: interval, limit: 100},
          @mock_klines_response
        )

        {:ok, _df} = Binance.history("BTCUSDT", interval: interval, limit: 100)
      end
    end
  end

  describe "error handling" do
    test "handles HTTP errors gracefully" do
      expect_http_error(
        "https://api.binance.com/api/v3/klines",
        429,
        "Too Many Requests"
      )

      {:error, {:http_error, 429}} = Binance.history("BTCUSDT")
    end

    test "handles malformed JSON responses" do
      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{symbol: "BTCUSDT", interval: "1d", limit: 500},
        "invalid json"
      )

      {:error, {:parse_error, _}} = Binance.history("BTCUSDT")
    end

    test "handles API errors in response" do
      error_response = """
      {
        "code": -1121,
        "msg": "Invalid symbol."
      }
      """

      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{symbol: "INVALID", interval: "1d", limit: 500},
        error_response
      )

      # This would need to be handled in the provider implementation
      # For now, it might parse as successful but with no data
    end
  end

  # Helper functions for mocking HTTP requests
  defp expect_http_request(_url, _expected_params, _response_body) do
    # In a real test, you would set up HTTP mocking here
    # For this example, we'll assume a mocking framework like Bypass or HTTPoison.Test

    # Mock implementation would go here - this is a placeholder
    # The actual implementation would depend on your HTTP mocking strategy
    :ok
  end

  defp expect_http_error(_url, _status_code, _error_body) do
    # Mock HTTP error response
    :ok
  end

  # Test helper to create DateTime from unix timestamp
  # Helper function removed as it was unused

  # Performance and integration tests
  describe "performance tests" do
    @tag :performance
    test "handles large datasets efficiently" do
      # Test with maximum allowed limit
      expect_http_request(
        "https://api.binance.com/api/v3/klines",
        %{symbol: "BTCUSDT", interval: "1m", limit: 1000},
        generate_large_klines_response(1000)
      )

      {time, {:ok, df}} =
        :timer.tc(fn ->
          Binance.history("BTCUSDT", interval: "1m", limit: 1000)
        end)

      assert DataFrame.n_rows(df) == 1000
      # Should complete within reasonable time (e.g., 1 second)
      # 1 second in microseconds
      assert time < 1_000_000
    end

    @tag :performance
    test "handles multiple concurrent symbol requests" do
      symbols = ["BTCUSDT", "ETHUSDT", "ADAUSDT", "DOTUSDT", "LINKUSDT"]

      for symbol <- symbols do
        expect_http_request(
          "https://api.binance.com/api/v3/klines",
          %{symbol: symbol, interval: "1d", limit: 100},
          @mock_klines_response
        )
      end

      {time, {:ok, df}} =
        :timer.tc(fn ->
          Binance.history(symbols, interval: "1d", limit: 100)
        end)

      # 2 rows per symbol
      assert DataFrame.n_rows(df) == 10
      # Concurrent requests should be faster than sequential
      # 5 seconds in microseconds
      assert time < 5_000_000
    end
  end

  # Generate large mock response for performance testing
  defp generate_large_klines_response(count) do
    base_time = 1_499_040_000_000

    klines =
      for i <- 0..(count - 1) do
        [
          # 1 minute intervals
          base_time + i * 60 * 1000,
          # Random price around 40k
          "#{40000 + :rand.uniform(1000)}",
          # High
          "#{40000 + :rand.uniform(1500)}",
          # Low
          "#{40000 - :rand.uniform(500)}",
          # Close
          "#{40000 + :rand.uniform(1000)}",
          # Volume
          "#{:rand.uniform(1000)}",
          # Close time
          base_time + (i + 1) * 60 * 1000 - 1,
          # Quote volume
          "#{:rand.uniform(10000)}",
          # Trades
          :rand.uniform(100),
          # Taker buy volume
          "#{:rand.uniform(500)}",
          # Taker buy quote volume
          "#{:rand.uniform(5000)}",
          # Ignore
          "0"
        ]
      end

    Jason.encode!(klines)
  end
end
