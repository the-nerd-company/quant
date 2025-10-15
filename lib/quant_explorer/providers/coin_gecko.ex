defmodule Quant.Explorer.Providers.CoinGecko do
  @moduledoc """
  CoinGecko cryptocurrency data provider.

  Provides access to CoinGecko's comprehensive cryptocurrency data including:
  - Historical price data (OHLCV)
  - Current market prices and statistics
  - Coin information and metadata
  - Market cap rankings

  ## Rate Limits

  CoinGecko API has the following rate limits:
  - Demo API: 10-30 calls/minute
  - Pro API: 500+ calls/minute

  ## Configuration

  ```elixir
  config :quant_explorer,
    api_keys: %{
      coin_gecko: "your_api_key_here"  # Optional for demo tier
    }
  ```

  ## Examples

      # Get Bitcoin historical data
      {:ok, df} = CoinGecko.history("bitcoin", days: 30)

      # Get current prices for multiple coins
      {:ok, df} = CoinGecko.quote(["bitcoin", "ethereum", "cardano"])

      # Search for coins
      {:ok, df} = CoinGecko.search("chainlink")

      # Get coin information
      {:ok, info} = CoinGecko.info("bitcoin")
  """

  @behaviour Quant.Explorer.Providers.Behaviour

  require Logger

  alias Explorer.DataFrame
  alias Quant.Explorer.{HttpClientConfig, RateLimiter}

  @base_url "https://api.coingecko.com/api/v3"
  @pro_base_url "https://pro-api.coingecko.com/api/v3"

  @user_agent "Quant.Explorer/1.0"
  @default_timeout 15_000

  # Supported vs_currencies for price data
  @supported_currencies [
    "usd",
    "eur",
    "jpy",
    "btc",
    "eth",
    "ltc",
    "bch",
    "bnb",
    "eos",
    "xrp",
    "xlm",
    "link",
    "dot",
    "yfi"
  ]

  @doc """
  Fetches historical market data for a cryptocurrency.

  ## Options

  - `:days` - Number of days of data to fetch (1, 7, 14, 30, 90, 180, 365, "max")
  - `:vs_currency` - Target currency (default: "usd")
  - `:interval` - Data interval ("daily" for > 1 day, "hourly" for <= 1 day)

  ## Examples

      # Get Bitcoin data for last 30 days
      {:ok, df} = CoinGecko.history("bitcoin", days: 30)

      # Get Ethereum data in EUR
      {:ok, df} = CoinGecko.history("ethereum", days: 7, vs_currency: "eur")
  """
  @impl true
  @spec history(String.t() | [String.t()], keyword()) :: {:ok, DataFrame.t()} | {:error, term()}
  def history(coin_ids, opts \\ []) when is_binary(coin_ids) or is_list(coin_ids) do
    case RateLimiter.check_and_consume(:coin_gecko, :market_chart) do
      :ok ->
        fetch_historical_data(coin_ids, opts)

      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  @doc """
  Fetches current market data for cryptocurrencies.

  ## Examples

      # Single coin
      {:ok, df} = CoinGecko.quote("bitcoin")

      # Multiple coins
      {:ok, df} = CoinGecko.quote(["bitcoin", "ethereum"])
  """
  @impl true
  @spec quote(String.t() | [String.t()]) :: {:ok, DataFrame.t()} | {:error, term()}
  def quote(coin_ids, _opts \\ []) when is_binary(coin_ids) or is_list(coin_ids) do
    case RateLimiter.check_and_consume(:coin_gecko, :simple_price) do
      :ok ->
        fetch_current_prices(coin_ids)

      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  @doc """
  Fetches detailed information about a cryptocurrency.

  ## Examples

      {:ok, info} = CoinGecko.info("bitcoin")
  """
  @impl true
  @spec info(String.t()) :: {:ok, map()} | {:error, term()}
  def info(coin_id, _opts \\ []) when is_binary(coin_id) do
    case RateLimiter.check_and_consume(:coin_gecko, :coins_info) do
      :ok ->
        fetch_coin_info(coin_id)

      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  @doc """
  Searches for cryptocurrencies by name or symbol.

  ## Examples

      {:ok, df} = CoinGecko.search("bitcoin")
      {:ok, df} = CoinGecko.search("BTC")
  """
  @impl true
  @spec search(String.t()) :: {:ok, DataFrame.t()} | {:error, term()}
  def search(query, _opts \\ []) when is_binary(query) do
    case RateLimiter.check_and_consume(:coin_gecko, :search) do
      :ok ->
        fetch_search_results(query)

      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  @doc """
  Gets the top cryptocurrencies by market cap.

  ## Options

  - `:vs_currency` - Target currency (default: "usd")
  - `:per_page` - Results per page (default: 100, max: 250)
  - `:page` - Page number (default: 1)
  - `:order` - Sort order (default: "market_cap_desc")

  ## Examples

      {:ok, df} = CoinGecko.top_coins()
      {:ok, df} = CoinGecko.top_coins(per_page: 50, vs_currency: "eur")
  """
  @spec top_coins(keyword()) :: {:ok, DataFrame.t()} | {:error, term()}
  def top_coins(opts \\ []) do
    case RateLimiter.check_and_consume(:coin_gecko, :coins_markets) do
      :ok ->
        fetch_top_coins(opts)

      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  # Private Implementation

  defp fetch_historical_data(coin_id, opts) when is_binary(coin_id) do
    days = Keyword.get(opts, :days, 30)
    vs_currency = Keyword.get(opts, :vs_currency, "usd")

    with :ok <- validate_vs_currency(vs_currency),
         :ok <- validate_days(days) do
      url = build_market_chart_url(coin_id, days, vs_currency)
      headers = build_headers()

      case HttpClientConfig.get(url, %{}, headers: headers, timeout: @default_timeout) do
        {:ok, %{status: 200, body: body}} ->
          parse_market_chart_response(body, coin_id)

        {:ok, %{status: 404}} ->
          {:error, :symbol_not_found}

        {:ok, %{status: 429}} ->
          {:error, :rate_limited}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("CoinGecko API error: #{status} - #{body}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end
  end

  defp fetch_historical_data(coin_ids, opts) when is_list(coin_ids) do
    # For multiple coins, fetch sequentially to avoid rate limits
    results =
      Enum.map(coin_ids, fn coin_id ->
        case fetch_historical_data(coin_id, opts) do
          {:ok, df} -> df
          {:error, _} = error -> error
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        # All successful, combine DataFrames
        combined_df =
          Enum.reduce(results, fn df, acc ->
            DataFrame.concat_rows([acc, df])
          end)

        {:ok, combined_df}

      error ->
        error
    end
  end

  defp fetch_current_prices(coin_ids) do
    coin_list = if is_binary(coin_ids), do: [coin_ids], else: coin_ids
    ids = Enum.join(coin_list, ",")

    url = "#{get_base_url()}/simple/price"

    params = %{
      "ids" => ids,
      "vs_currencies" => "usd",
      "include_24hr_change" => "true",
      "include_24hr_vol" => "true",
      "include_market_cap" => "true"
    }

    headers = build_headers()

    case HttpClientConfig.get(url, params, headers: headers, timeout: @default_timeout) do
      {:ok, %{status: 200, body: body}} ->
        parse_simple_price_response(body, coin_list)

      {:ok, %{status: 404}} ->
        {:error, :symbol_not_found}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("CoinGecko price API error: #{status} - #{body}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp fetch_coin_info(coin_id) do
    url = "#{get_base_url()}/coins/#{coin_id}"

    params = %{
      "localization" => "false",
      "tickers" => "false",
      "market_data" => "true",
      "community_data" => "false",
      "developer_data" => "false",
      "sparkline" => "false"
    }

    headers = build_headers()

    case HttpClientConfig.get(url, params, headers: headers, timeout: @default_timeout) do
      {:ok, %{status: 200, body: body}} ->
        parse_coin_info_response(body)

      {:ok, %{status: 404}} ->
        {:error, :symbol_not_found}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("CoinGecko info API error: #{status} - #{body}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp fetch_search_results(query) do
    url = "#{get_base_url()}/search"
    params = %{"query" => query}
    headers = build_headers()

    case HttpClientConfig.get(url, params, headers: headers, timeout: @default_timeout) do
      {:ok, %{status: 200, body: body}} ->
        parse_search_response(body)

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("CoinGecko search API error: #{status} - #{body}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp fetch_top_coins(opts) do
    vs_currency = Keyword.get(opts, :vs_currency, "usd")
    per_page = Keyword.get(opts, :per_page, 100)
    page = Keyword.get(opts, :page, 1)
    order = Keyword.get(opts, :order, "market_cap_desc")

    url = "#{get_base_url()}/coins/markets"

    params = %{
      "vs_currency" => vs_currency,
      "order" => order,
      "per_page" => min(per_page, 250),
      "page" => page,
      "sparkline" => "false"
    }

    headers = build_headers()

    case HttpClientConfig.get(url, params, headers: headers, timeout: @default_timeout) do
      {:ok, %{status: 200, body: body}} ->
        parse_markets_response(body)

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("CoinGecko markets API error: #{status} - #{body}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  # Response Parsers

  defp parse_market_chart_response(body, coin_id) do
    case HttpClientConfig.decode_json(body) do
      {:ok, %{"prices" => prices, "market_caps" => market_caps, "total_volumes" => volumes}} ->
        data =
          Enum.zip([prices, market_caps, volumes])
          |> Enum.map(fn {[timestamp, price], [_, market_cap], [_, volume]} ->
            datetime = DateTime.from_unix!(div(timestamp, 1000), :second)

            %{
              "symbol" => coin_id,
              "timestamp" => datetime,
              # CoinGecko doesn't provide OHLC, so we use price for all
              "open" => price,
              "high" => price,
              "low" => price,
              "close" => price,
              "volume" => trunc(volume),
              "adj_close" => price,
              "market_cap" => trunc(market_cap)
            }
          end)

        {:ok, DataFrame.new(data)}

      {:ok, %{"error" => error}} ->
        {:error, {:provider_error, error}}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp parse_simple_price_response(body, coin_ids) do
    case HttpClientConfig.decode_json(body) do
      {:ok, price_data} when is_map(price_data) ->
        data =
          Enum.map(coin_ids, fn coin_id ->
            coin_data = Map.get(price_data, coin_id, %{})

            %{
              "symbol" => coin_id,
              "price" => Map.get(coin_data, "usd", 0.0),
              "change" => Map.get(coin_data, "usd_24h_change", 0.0),
              "change_percent" => Map.get(coin_data, "usd_24h_change", 0.0),
              "volume" => trunc(Map.get(coin_data, "usd_24h_vol", 0.0)),
              "market_cap" => trunc(Map.get(coin_data, "usd_market_cap", 0.0)),
              "timestamp" => DateTime.utc_now()
            }
          end)

        {:ok, DataFrame.new(data)}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp parse_coin_info_response(body) do
    case HttpClientConfig.decode_json(body) do
      {:ok, coin_data} ->
        market_data = Map.get(coin_data, "market_data", %{})

        info = %{
          "id" => Map.get(coin_data, "id"),
          "symbol" => Map.get(coin_data, "symbol"),
          "name" => Map.get(coin_data, "name"),
          "description" => get_in(coin_data, ["description", "en"]),
          "homepage" => get_in(coin_data, ["links", "homepage"]) |> List.first(),
          "blockchain_site" => get_in(coin_data, ["links", "blockchain_site"]) |> List.first(),
          "market_cap_rank" => Map.get(coin_data, "market_cap_rank"),
          "current_price" => get_in(market_data, ["current_price", "usd"]),
          "market_cap" => get_in(market_data, ["market_cap", "usd"]),
          "total_volume" => get_in(market_data, ["total_volume", "usd"]),
          "high_24h" => get_in(market_data, ["high_24h", "usd"]),
          "low_24h" => get_in(market_data, ["low_24h", "usd"]),
          "price_change_24h" => Map.get(market_data, "price_change_24h"),
          "price_change_percentage_24h" => Map.get(market_data, "price_change_percentage_24h"),
          "circulating_supply" => Map.get(market_data, "circulating_supply"),
          "total_supply" => Map.get(market_data, "total_supply"),
          "max_supply" => Map.get(market_data, "max_supply")
        }

        {:ok, info}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp parse_search_response(body) do
    case HttpClientConfig.decode_json(body) do
      {:ok, %{"coins" => coins}} ->
        data =
          Enum.map(coins, fn coin ->
            %{
              "id" => Map.get(coin, "id"),
              "name" => Map.get(coin, "name"),
              "symbol" => Map.get(coin, "symbol"),
              "market_cap_rank" => Map.get(coin, "market_cap_rank"),
              "thumb" => Map.get(coin, "thumb")
            }
          end)

        {:ok, DataFrame.new(data)}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  defp parse_markets_response(body) do
    case HttpClientConfig.decode_json(body) do
      {:ok, markets_data} when is_list(markets_data) ->
        data =
          Enum.map(markets_data, fn coin ->
            %{
              "symbol" => Map.get(coin, "id"),
              "name" => Map.get(coin, "name"),
              "price" => Map.get(coin, "current_price", 0.0),
              "change" => Map.get(coin, "price_change_24h", 0.0),
              "change_percent" => Map.get(coin, "price_change_percentage_24h", 0.0),
              "volume" => trunc(Map.get(coin, "total_volume", 0.0)),
              "market_cap" => trunc(Map.get(coin, "market_cap", 0.0)),
              "market_cap_rank" => Map.get(coin, "market_cap_rank"),
              "timestamp" => DateTime.utc_now()
            }
          end)

        {:ok, DataFrame.new(data)}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  # Utility Functions

  defp build_market_chart_url(coin_id, days, vs_currency) do
    "#{get_base_url()}/coins/#{coin_id}/market_chart?vs_currency=#{vs_currency}&days=#{days}"
  end

  defp build_headers do
    base_headers = [{"User-Agent", @user_agent}]

    case get_api_key() do
      nil -> base_headers
      api_key -> [{"x-cg-pro-api-key", api_key} | base_headers]
    end
  end

  defp get_base_url do
    case get_api_key() do
      nil -> @base_url
      _api_key -> @pro_base_url
    end
  end

  defp get_api_key do
    case Application.get_env(:quant_explorer, :api_keys, %{}) do
      %{coin_gecko: api_key} when is_binary(api_key) -> api_key
      _ -> nil
    end
  end

  defp validate_vs_currency(currency) do
    if currency in @supported_currencies do
      :ok
    else
      {:error,
       {:invalid_currency, "Supported currencies: #{Enum.join(@supported_currencies, ", ")}"}}
    end
  end

  defp validate_days(days) when days in [1, 7, 14, 30, 90, 180, 365] or days == "max", do: :ok

  defp validate_days(_),
    do: {:error, {:invalid_period, "Supported days: 1, 7, 14, 30, 90, 180, 365, 'max'"}}
end
