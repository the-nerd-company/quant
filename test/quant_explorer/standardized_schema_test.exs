defmodule Quant.Explorer.StandardizedSchemaTest do
  @moduledoc """
  Tests to ensure all providers conform to the standardized schemas.
  This is the most critical test suite ensuring cross-provider compatibility.
  """

  use ExUnit.Case
  import Quant.Explorer.TestHelper
  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.{AlphaVantage, Binance, CoinGecko, TwelveData, YahooFinance}

  @moduletag :mocked

  # Expected standardized schemas
  @expected_history_columns ~w[
    symbol timestamp open high low close volume adj_close
    market_cap provider currency timezone
  ]

  @expected_quote_columns ~w[
    symbol price change change_percent volume high_24h low_24h
    market_cap timestamp provider currency market_state
  ]

  @expected_search_columns ~w[
    symbol name type exchange currency country sector industry
    market_cap provider match_score
  ]

  describe "Standardized Historical Data Schema - All Providers" do
    test "Yahoo Finance returns standardized historical schema" do
      yahoo_response = build_yahoo_history_response()

      with_http_mock([{"query1.finance.yahoo.com", yahoo_response}]) do
        assert {:ok, df} = Quant.Explorer.history("AAPL", provider: :yahoo_finance)

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 12,
               "Expected exactly 12 columns, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_history_columns,
               "Column mismatch. Expected: #{inspect(@expected_history_columns)}, Got: #{inspect(DataFrame.names(df))}"

        # Verify column types
        verify_history_column_types(df)

        # Verify metadata columns
        verify_metadata_columns(df, "yahoo_finance", "usd", "America/New_York")
      end
    end

    test "Alpha Vantage returns standardized historical schema" do
      alpha_response = build_alpha_vantage_history_response()

      with_http_mock([{"www.alphavantage.co", alpha_response}]) do
        assert {:ok, df} =
                 Quant.Explorer.history("IBM", provider: :alpha_vantage, api_key: "test_key")

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 12,
               "Expected exactly 12 columns, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_history_columns,
               "Column mismatch. Expected: #{inspect(@expected_history_columns)}, Got: #{inspect(DataFrame.names(df))}"

        # Verify column types
        verify_history_column_types(df)

        # Verify metadata columns
        verify_metadata_columns(df, "alpha_vantage", "usd", "America/New_York")
      end
    end

    test "Binance returns standardized historical schema" do
      binance_response = build_binance_history_response()

      with_http_mock([{"api.binance.com", binance_response}]) do
        assert {:ok, df} =
                 Quant.Explorer.history("BTCUSDT", provider: :binance, interval: "1h", limit: 100)

        # Verify exact column count and names (this was our main issue!)
        assert DataFrame.n_columns(df) == 12,
               "Expected exactly 12 columns, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_history_columns,
               "Column mismatch. Expected: #{inspect(@expected_history_columns)}, Got: #{inspect(DataFrame.names(df))}"

        # Verify column types
        verify_history_column_types(df)

        # Verify metadata columns
        verify_metadata_columns(df, "binance", "usd", "UTC")
      end
    end

    test "CoinGecko returns standardized historical schema" do
      coingecko_response = build_coingecko_history_response()

      with_http_mock([{"api.coingecko.com", coingecko_response}]) do
        assert {:ok, df} =
                 Quant.Explorer.history("bitcoin",
                   provider: :coin_gecko,
                   interval: "1d",
                   period: "1mo"
                 )

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 12,
               "Expected exactly 12 columns, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_history_columns,
               "Column mismatch. Expected: #{inspect(@expected_history_columns)}, Got: #{inspect(DataFrame.names(df))}"

        # Verify column types
        verify_history_column_types(df)

        # Verify metadata columns
        verify_metadata_columns(df, "coin_gecko", "usd", "UTC")
      end
    end

    test "Twelve Data returns standardized historical schema" do
      twelve_data_response = build_twelve_data_history_response()

      with_http_mock([{"api.twelvedata.com", twelve_data_response}]) do
        assert {:ok, df} =
                 Quant.Explorer.history("AAPL", provider: :twelve_data, api_key: "test_key")

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 12,
               "Expected exactly 12 columns, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_history_columns,
               "Column mismatch. Expected: #{inspect(@expected_history_columns)}, Got: #{inspect(DataFrame.names(df))}"

        # Verify column types
        verify_history_column_types(df)

        # Verify metadata columns
        verify_metadata_columns(df, "twelve_data", "usd", "America/New_York")
      end
    end
  end

  describe "Standardized Quote Data Schema - All Providers" do
    test "Yahoo Finance returns standardized quote schema" do
      yahoo_response = build_yahoo_quote_response()

      with_http_mock([{"query1.finance.yahoo.com", yahoo_response}]) do
        assert {:ok, df} = Quant.Explorer.quote("AAPL", provider: :yahoo_finance)

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 12,
               "Expected exactly 12 columns for quotes, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_quote_columns,
               "Quote column mismatch. Expected: #{inspect(@expected_quote_columns)}, Got: #{inspect(DataFrame.names(df))}"

        # Verify quote-specific data
        verify_quote_column_types(df)
      end
    end

    test "Binance returns standardized quote schema" do
      binance_response = build_binance_quote_response()

      with_http_mock([{"api.binance.com", binance_response}]) do
        assert {:ok, df} = Quant.Explorer.quote("BTCUSDT", provider: :binance)

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 12,
               "Expected exactly 12 columns for quotes, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_quote_columns,
               "Quote column mismatch. Expected: #{inspect(@expected_quote_columns)}, Got: #{inspect(DataFrame.names(df))}"
      end
    end
  end

  describe "Standardized Search Results Schema - All Providers" do
    test "Yahoo Finance returns standardized search schema" do
      yahoo_response = build_yahoo_search_response()

      with_http_mock([{"query1.finance.yahoo.com", yahoo_response}]) do
        assert {:ok, df} = Quant.Explorer.search("Apple", provider: :yahoo_finance)

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 11,
               "Expected exactly 11 columns for search, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_search_columns,
               "Search column mismatch. Expected: #{inspect(@expected_search_columns)}, Got: #{inspect(DataFrame.names(df))}"
      end
    end

    test "Binance returns standardized search schema" do
      binance_response = build_binance_search_response()

      with_http_mock([{"api.binance.com", binance_response}]) do
        assert {:ok, df} = Quant.Explorer.search("BTC", provider: :binance)

        # Verify exact column count and names
        assert DataFrame.n_columns(df) == 11,
               "Expected exactly 11 columns for search, got #{DataFrame.n_columns(df)}"

        assert DataFrame.names(df) == @expected_search_columns,
               "Search column mismatch. Expected: #{inspect(@expected_search_columns)}, Got: #{inspect(DataFrame.names(df))}"
      end
    end
  end

  describe "Cross-Provider Schema Consistency" do
    test "all providers return identical historical schemas" do
      schemas = [
        {YahooFinance, build_yahoo_history_response(), "AAPL", "yahoo_finance"},
        {AlphaVantage, build_alpha_vantage_history_response(), "IBM", "alpha_vantage"},
        {Binance, build_binance_history_response(), "BTCUSDT", "binance"},
        {CoinGecko, build_coingecko_history_response(), "bitcoin", "coin_gecko"},
        {TwelveData, build_twelve_data_history_response(), "AAPL", "twelve_data"}
      ]

      results =
        for {_provider_module, response, symbol, provider_name} <- schemas do
          host =
            case provider_name do
              "yahoo_finance" -> "query1.finance.yahoo.com"
              "alpha_vantage" -> "www.alphavantage.co"
              "binance" -> "api.binance.com"
              "coin_gecko" -> "api.coingecko.com"
              "twelve_data" -> "api.twelvedata.com"
            end

          with_http_mock([{host, response}]) do
            case provider_name do
              "yahoo_finance" ->
                Quant.Explorer.history(symbol, provider: :yahoo_finance)

              "alpha_vantage" ->
                Quant.Explorer.history(symbol, provider: :alpha_vantage, api_key: "test")

              "binance" ->
                Quant.Explorer.history(symbol, provider: :binance)

              "coin_gecko" ->
                Quant.Explorer.history(symbol, provider: :coin_gecko)

              "twelve_data" ->
                Quant.Explorer.history(symbol, provider: :twelve_data, api_key: "test")
            end
          end
        end

      # All should succeed
      Enum.each(results, fn result ->
        assert {:ok, _df} = result, "Provider failed to return data"
      end)

      # Extract DataFrames
      dataframes = Enum.map(results, fn {:ok, df} -> df end)

      # Verify all have same column names
      column_sets = Enum.map(dataframes, &DataFrame.names/1)
      first_columns = hd(column_sets)

      Enum.with_index(column_sets, fn columns, index ->
        assert columns == first_columns,
               "Provider #{index} has different columns. Expected: #{inspect(first_columns)}, Got: #{inspect(columns)}"
      end)

      # Verify all have same column count
      column_counts = Enum.map(dataframes, &DataFrame.n_columns/1)

      assert Enum.all?(column_counts, &(&1 == 12)),
             "Not all providers return 12 columns: #{inspect(column_counts)}"
    end

    test "can combine DataFrames from different providers seamlessly" do
      yahoo_response = build_yahoo_history_response()
      binance_response = build_binance_history_response()

      with_http_mock([
        {"query1.finance.yahoo.com", yahoo_response},
        {"api.binance.com", binance_response}
      ]) do
        assert {:ok, yahoo_df} = Quant.Explorer.history("AAPL", provider: :yahoo_finance)
        assert {:ok, binance_df} = Quant.Explorer.history("BTCUSDT", provider: :binance)

        # Should be able to combine without any issues
        combined_df = DataFrame.concat_rows([yahoo_df, binance_df])

        # Verify combined DataFrame
        assert DataFrame.n_columns(combined_df) == 12

        assert DataFrame.n_rows(combined_df) ==
                 DataFrame.n_rows(yahoo_df) + DataFrame.n_rows(binance_df)

        # Should have data from both providers
        providers = combined_df["provider"] |> Explorer.Series.to_list() |> Enum.uniq()
        assert "yahoo_finance" in providers
        assert "binance" in providers
      end
    end
  end

  # Helper functions for building mock responses
  defp build_yahoo_history_response do
    """
    {
      "chart": {
        "result": [
          {
            "meta": {"symbol": "AAPL"},
            "timestamp": [1640908800, 1640995200],
            "indicators": {
              "quote": [{
                "close": [179.38, 177.57],
                "open": [180.16, 177.83],
                "high": [182.13, 180.33],
                "low": [177.0, 176.12],
                "volume": [89182100, 59773000]
              }],
              "adjclose": [{"adjclose": [179.38, 177.57]}]
            }
          }
        ]
      }
    }
    """
  end

  defp build_alpha_vantage_history_response do
    """
    {
      "Time Series (Daily)": {
        "2024-01-02": {
          "1. open": "185.64",
          "2. high": "186.89",
          "3. low": "185.0",
          "4. close": "185.92",
          "5. volume": "32842700"
        },
        "2024-01-01": {
          "1. open": "184.0",
          "2. high": "185.5",
          "3. low": "183.5",
          "4. close": "185.64",
          "5. volume": "28456900"
        }
      }
    }
    """
  end

  defp build_binance_history_response do
    """
    [
      [1640908800000, "47000.00", "47500.00", "46500.00", "47200.00", "1234.56", 1640995199999, "58000000.00", 8500, "600.00", "28000000.00", "0"],
      [1640995200000, "47200.00", "47800.00", "46800.00", "47650.00", "2345.67", 1641081599999, "110000000.00", 12000, "1100.00", "52000000.00", "0"]
    ]
    """
  end

  defp build_coingecko_history_response do
    """
    {
      "prices": [[1640995200000, 47500.00], [1641081600000, 48200.00]],
      "market_caps": [[1640995200000, 900000000000], [1641081600000, 910000000000]],
      "total_volumes": [[1640995200000, 25000000000], [1641081600000, 26000000000]]
    }
    """
  end

  defp build_twelve_data_history_response do
    """
    {
      "meta": {"symbol": "AAPL", "interval": "1day", "currency": "USD", "exchange_timezone": "America/New_York"},
      "values": [
        {"datetime": "2024-01-02", "open": "187.15", "high": "188.44", "low": "183.89", "close": "185.64", "volume": "52742000"},
        {"datetime": "2024-01-03", "open": "184.22", "high": "185.12", "low": "181.5", "close": "184.25", "volume": "58914000"}
      ],
      "status": "ok"
    }
    """
  end

  defp build_yahoo_quote_response do
    """
    {
      "quoteResponse": {
        "result": [{
          "symbol": "AAPL",
          "regularMarketPrice": 177.57,
          "regularMarketChange": -1.81,
          "regularMarketChangePercent": -1.0089283,
          "regularMarketVolume": 59773000,
          "regularMarketDayHigh": 180.33,
          "regularMarketDayLow": 176.12,
          "marketCap": 2800000000000,
          "marketState": "CLOSED"
        }]
      }
    }
    """
  end

  defp build_binance_quote_response do
    """
    [{
      "symbol": "BTCUSDT",
      "priceChange": "1200.00",
      "priceChangePercent": "2.60",
      "lastPrice": "47200.00",
      "volume": "15432.50000000",
      "highPrice": "47800.00",
      "lowPrice": "45500.00",
      "openPrice": "46000.00",
      "quoteVolume": "725000000.00",
      "openTime": 1640908800000,
      "closeTime": 1640995199999,
      "count": 1000000
    }]
    """
  end

  defp build_yahoo_search_response do
    """
    {
      "quotes": [{
        "symbol": "AAPL",
        "shortname": "Apple Inc.",
        "longname": "Apple Inc.",
        "exchDisp": "NASDAQ",
        "exchange": "NMS",
        "sector": "Technology",
        "industry": "Consumer Electronics"
      }]
    }
    """
  end

  defp build_binance_search_response do
    """
    {
      "timezone": "UTC",
      "serverTime": 1640995200000,
      "symbols": [{
        "symbol": "BTCUSDT",
        "status": "TRADING",
        "baseAsset": "BTC",
        "quoteAsset": "USDT",
        "baseAssetPrecision": 8,
        "quotePrecision": 8
      }]
    }
    """
  end

  # Verification helper functions
  defp verify_history_column_types(df) do
    # Verify critical column types
    assert df["symbol"] |> Explorer.Series.dtype() == :string
    # Handle datetime with timezone info
    timestamp_dtype = df["timestamp"] |> Explorer.Series.dtype()

    assert timestamp_dtype == {:datetime, :microsecond} or
             timestamp_dtype == {:datetime, :microsecond, "Etc/UTC"}

    # Handle float type variations
    open_dtype = df["open"] |> Explorer.Series.dtype()
    assert open_dtype == :f64 or open_dtype == {:f, 64}

    high_dtype = df["high"] |> Explorer.Series.dtype()
    assert high_dtype == :f64 or high_dtype == {:f, 64}

    low_dtype = df["low"] |> Explorer.Series.dtype()
    assert low_dtype == :f64 or low_dtype == {:f, 64}

    close_dtype = df["close"] |> Explorer.Series.dtype()
    assert close_dtype == :f64 or close_dtype == {:f, 64}

    volume_dtype = df["volume"] |> Explorer.Series.dtype()
    assert volume_dtype == :s64 or volume_dtype == {:s, 64}

    adj_close_dtype = df["adj_close"] |> Explorer.Series.dtype()
    assert adj_close_dtype == :f64 or adj_close_dtype == {:f, 64}

    assert df["provider"] |> Explorer.Series.dtype() == :string
    assert df["currency"] |> Explorer.Series.dtype() == :string
    assert df["timezone"] |> Explorer.Series.dtype() == :string
    # market_cap can be null or f64
  end

  defp verify_quote_column_types(df) do
    # Verify critical quote column types
    assert df["symbol"] |> Explorer.Series.dtype() == :string

    # Handle float type variations
    price_dtype = df["price"] |> Explorer.Series.dtype()
    assert price_dtype == :f64 or price_dtype == {:f, 64}

    change_dtype = df["change"] |> Explorer.Series.dtype()
    assert change_dtype == :f64 or change_dtype == {:f, 64}

    change_percent_dtype = df["change_percent"] |> Explorer.Series.dtype()
    assert change_percent_dtype == :f64 or change_percent_dtype == {:f, 64}

    volume_dtype = df["volume"] |> Explorer.Series.dtype()
    assert volume_dtype == :s64 or volume_dtype == {:s, 64}
    assert df["provider"] |> Explorer.Series.dtype() == :string
    assert df["currency"] |> Explorer.Series.dtype() == :string
  end

  defp verify_metadata_columns(df, expected_provider, expected_currency, expected_timezone) do
    # Verify metadata column values
    provider_values = df["provider"] |> Explorer.Series.to_list() |> Enum.uniq()

    assert provider_values == [expected_provider],
           "Expected provider #{expected_provider}, got #{inspect(provider_values)}"

    currency_values = df["currency"] |> Explorer.Series.to_list() |> Enum.uniq()

    assert currency_values == [expected_currency],
           "Expected currency #{expected_currency}, got #{inspect(currency_values)}"

    timezone_values = df["timezone"] |> Explorer.Series.to_list() |> Enum.uniq()

    assert timezone_values == [expected_timezone],
           "Expected timezone #{expected_timezone}, got #{inspect(timezone_values)}"
  end
end
