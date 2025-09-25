defmodule Quant.Explorer.Providers.Behaviour do
  @moduledoc """
  Behaviour that all data providers must implement.

  This behaviour defines the standard interface for financial data providers,
  ensuring consistent API across different data sources like Yahoo Finance,
  Alpha Vantage, Binance, CoinGecko, etc.

  All providers must return data as Explorer DataFrames with standardized
  column names and data types for interoperability.
  """

  alias Explorer.DataFrame

  @type symbol :: String.t()
  @type symbols :: [symbol()]
  @type options :: keyword()
  @type period :: String.t()
  @type interval :: String.t()

  @doc """
  Fetches historical price data for one or more symbols.

  Returns a DataFrame with standardized columns:
  - symbol (string): Stock/crypto symbol
  - timestamp (datetime): Data timestamp
  - open (f64): Opening price
  - high (f64): High price
  - low (f64): Low price
  - close (f64): Closing price
  - volume (s64): Trading volume
  - adj_close (f64): Adjusted closing price (optional)

  ## Options

  - `:api_key` - API key for providers that require authentication (optional, will use config if not provided)
  - `:period` - Time period (e.g., "1d", "5d", "1mo", "3mo", "6mo", "1y", "2y", "5y", "10y", "ytd", "max")
  - `:interval` - Data interval (e.g., "1m", "2m", "5m", "15m", "30m", "60m", "90m", "1h", "1d", "5d", "1wk", "1mo", "3mo")
  - `:start_date` - Start date as Date struct or ISO string
  - `:end_date` - End date as Date struct or ISO string
  """
  @callback history(symbol() | symbols(), options()) ::
              {:ok, DataFrame.t()} | {:error, term()}

  @doc """
  Fetches current quote data for one or more symbols.

  Returns a DataFrame with standardized columns:
  - symbol (string): Stock/crypto symbol
  - price (f64): Current price
  - change (f64): Price change
  - change_percent (f64): Percentage change
  - volume (s64): Current volume
  - timestamp (datetime): Quote timestamp

  ## Options

  - `:api_key` - API key for providers that require authentication (optional, will use config if not provided)
  """
  @callback quote(symbol() | symbols(), options()) ::
              {:ok, DataFrame.t()} | {:error, term()}

  @doc """
  Fetches company/asset information for a symbol.

  Returns a map containing available metadata like:
  - name, sector, industry, description
  - market_cap, shares_outstanding
  - financial ratios and metrics

  Structure may vary by provider.

  ## Options

  - `:api_key` - API key for providers that require authentication (optional, will use config if not provided)
  """
  @callback info(symbol(), options()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Searches for symbols matching a query string.

  Returns a DataFrame with columns:
  - symbol (string): Trading symbol
  - name (string): Company/asset name
  - type (string): Asset type (stock, etf, crypto, etc.)
  - exchange (string): Trading exchange (optional)

  ## Options

  - `:api_key` - API key for providers that require authentication (optional, will use config if not provided)
  """
  @callback search(String.t(), options()) ::
              {:ok, DataFrame.t()} | {:error, term()}

  @optional_callbacks [info: 2, search: 2]
end
