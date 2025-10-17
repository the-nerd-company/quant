# Quant.Explorer Standardization Guide

## Complete Parameter and Schema Standardization

Quant.Explorer now provides **complete standardization** for both query parameters and output schemas across all financial data providers. This ensures total interoperability for financial data analysis.

## 🎯 Key Benefits

1. **Universal Parameters**: Same parameter names work with ALL providers
2. **Identical Schemas**: All DataFrames have identical column structures  
3. **Automatic Translation**: Provider-specific formats handled internally
4. **Rich Metadata**: Additional columns for provider, currency, timezone info
5. **Type Safety**: Strong typing and validation throughout
6. **Seamless Analysis**: Combine data from multiple providers effortlessly

## 📊 Standardized Parameters

### Time Intervals (`:interval`)

Use these **standard intervals** with any provider:

- `"1m"`, `"5m"`, `"15m"`, `"30m"`, `"1h"` - Intraday intervals
- `"1d"`, `"1w"`, `"1mo"` - Daily and longer intervals

**Automatic Translation:**

```elixir
# Your Code (standardized)
interval: "1d"

# Translated automatically per provider:
# Yahoo Finance: "1d"  
# Alpha Vantage: "daily"
# Binance: "1d"
# Twelve Data: "1day"
# CoinGecko: "daily"
```

### Time Periods (`:period`)

Use these **standard periods** with any provider:

- `"1d"`, `"5d"`, `"1mo"`, `"3mo"`, `"6mo"`
- `"1y"`, `"2y"`, `"5y"`, `"10y"`, `"max"`

**Automatic Translation:**

```elixir  
# Your Code (standardized)
period: "1y"

# Translated automatically per provider:
# Yahoo Finance: period="1y"
# Alpha Vantage: converted to date range  
# Binance: converted to date range
# CoinGecko: days=365
```

### Other Standard Parameters

- `:limit` - Number of data points (1-5000)
- `:currency` - Base currency: `"usd"`, `"eur"`, `"btc"`, `"eth"` 
- `:adjusted` - Use adjusted prices (boolean, default: true)
- `:start_date`/`:end_date` - Date range (Date, DateTime, or ISO string)
- `:api_key` - API key for authentication

## 📈 Standardized Output Schemas

### Historical Data Schema

**ALL providers return identical columns:**

```elixir
[
  "symbol",        # Stock/crypto symbol (string)
  "timestamp",     # UTC timestamp (datetime)  
  "open",          # Opening price (f64)
  "high",          # High price (f64)
  "low",           # Low price (f64)
  "close",         # Closing price (f64)  
  "volume",        # Trading volume (s64)
  "adj_close",     # Adjusted close (f64) - when available
  "market_cap",    # Market cap (f64) - crypto only
  "provider",      # Data source (string)
  "currency",      # Price currency (string)
  "timezone"       # Original timezone (string)
]
```

### Quote Data Schema

**ALL providers return identical columns:**

```elixir
[
  "symbol",        # Stock/crypto symbol (string)
  "price",         # Current price (f64)
  "change",        # Price change (f64)
  "change_percent",# Percentage change (f64)
  "volume",        # Current volume (s64)
  "high_24h",      # 24-hour high (f64)
  "low_24h",       # 24-hour low (f64)
  "market_cap",    # Market cap (f64) - when available
  "timestamp",     # UTC timestamp (datetime)
  "provider",      # Data source (string)
  "currency",      # Quote currency (string)  
  "market_state"   # Market state (string)
]
```

### Search Results Schema

**ALL providers return identical columns:**

```elixir
[
  "symbol",        # Trading symbol (string)
  "name",          # Company/asset name (string)
  "type",          # Asset type (string): stock, etf, crypto, etc.
  "exchange",      # Primary exchange (string)
  "currency",      # Trading currency (string)
  "country",       # Country/region (string)
  "sector",        # Business sector (string) - when available
  "industry",      # Industry classification (string) - when available
  "market_cap",    # Market capitalization (f64) - when available
  "provider",      # Data source (string)
  "match_score"    # Search relevance (f64): 0.0 - 1.0
]
```

## 🚀 Usage Examples

### Basic Standardized Usage

```elixir
# Same parameters work with ANY provider
standard_params = [
  interval: "1d",
  period: "1y", 
  currency: "usd"
]

# Yahoo Finance
{:ok, yahoo_df} = Quant.Explorer.StandardizedAPI.history("AAPL", 
  [provider: :yahoo_finance] ++ standard_params)

# Alpha Vantage (parameters automatically translated)
{:ok, alpha_df} = Quant.Explorer.StandardizedAPI.history("AAPL",
  [provider: :alpha_vantage, api_key: "your_key"] ++ standard_params)
  
# Binance (parameters automatically translated)  
{:ok, binance_df} = Quant.Explorer.StandardizedAPI.history("BTCUSDT",
  [provider: :binance] ++ standard_params)
  
# ALL DataFrames have IDENTICAL schemas!
IO.inspect(DataFrame.names(yahoo_df))   # Same columns
IO.inspect(DataFrame.names(alpha_df))   # Same columns  
IO.inspect(DataFrame.names(binance_df)) # Same columns
```

### Cross-Provider Analysis

```elixir
# Fetch AAPL data from multiple providers
providers_data = [
  {:yahoo_finance, []},
  {:alpha_vantage, [api_key: "your_alpha_key"]},
  {:twelve_data, [api_key: "your_twelve_key"]}
]

dataframes = Enum.map(providers_data, fn {provider, extra_opts} ->
  opts = [provider: provider, interval: "1d", period: "1mo"] ++ extra_opts
  
  case Quant.Explorer.StandardizedAPI.history("AAPL", opts) do
    {:ok, df} -> df
    {:error, _} -> nil
  end
end) |> Enum.reject(&is_nil/1)

# Combine all data for comprehensive analysis
combined_df = Enum.reduce(dataframes, &DataFrame.concat_rows/2)

# Analyze by provider
analysis = combined_df
|> DataFrame.group_by("provider") 
|> DataFrame.summarise(
  avg_price: mean(close),
  total_volume: sum(volume),
  data_points: count()
)

IO.inspect(analysis)
```

### Multi-Asset Portfolio Analysis

```elixir
# Define portfolio with mixed asset types
portfolio = [
  # Stocks
  {"AAPL", :yahoo_finance, []},
  {"MSFT", :alpha_vantage, [api_key: "key"]},
  
  # Crypto  
  {"BTCUSDT", :binance, []},
  {"bitcoin", :coin_gecko, [currency: "usd"]}
]

# Fetch standardized data for all assets
portfolio_data = Enum.map(portfolio, fn {symbol, provider, extra_opts} ->
  opts = [provider: provider, interval: "1d", period: "1mo"] ++ extra_opts
  
  case Quant.Explorer.StandardizedAPI.history(symbol, opts) do
    {:ok, df} -> df
    {:error, reason} -> 
      IO.puts("Failed to fetch #{symbol}: #{inspect(reason)}")
      nil
  end
end) |> Enum.reject(&is_nil/1)

# Combine and analyze entire portfolio
if Enum.any?(portfolio_data) do
  portfolio_df = Enum.reduce(portfolio_data, &DataFrame.concat_rows/2)
  
  # Calculate portfolio metrics with identical schema
  portfolio_summary = portfolio_df
  |> DataFrame.group_by(["symbol", "provider"])
  |> DataFrame.summarise(
    avg_price: mean(close),
    volatility: std(close), 
    total_volume: sum(volume),
    return_pct: (last(close) - first(close)) / first(close) * 100
  )
  |> DataFrame.arrange(desc: return_pct)
  
  IO.inspect(portfolio_summary, limit: :infinity)
end
```

### Real-time Multi-Provider Quotes

```elixir
# Get real-time quotes from multiple providers
symbols_providers = [
  {"AAPL", :yahoo_finance, []},
  {"AAPL", :alpha_vantage, [api_key: "key"]}, 
  {"AAPL", :twelve_data, [api_key: "key"]}
]

quote_comparison = Enum.map(symbols_providers, fn {symbol, provider, opts} ->
  case Quant.Explorer.StandardizedAPI.quote(symbol, [provider: provider] ++ opts) do
    {:ok, df} -> df
    {:error, _} -> nil  
  end
end) |> Enum.reject(&is_nil/1)

if Enum.any?(quote_comparison) do
  # Compare quotes across providers - identical schema enables easy comparison
  comparison_df = Enum.reduce(quote_comparison, &DataFrame.concat_rows/2)
  
  price_comparison = comparison_df
  |> DataFrame.group_by("provider")
  |> DataFrame.summarise(
    current_price: first(price),
    change_percent: first(change_percent),
    volume: first(volume),
    timestamp: first(timestamp)
  )
  
  IO.puts("\nPrice Comparison Across Providers:")
  IO.inspect(price_comparison, limit: :infinity)
end
```

### Livebook Integration

Perfect for financial analysis in Livebook notebooks:

```elixir
# Livebook Cell 1: Setup
Mix.install([{:quant, github: "the-nerd-company/quant"}])

# Livebook Cell 2: Multi-Provider Data Collection  
alpha_key = System.fetch_env!("ALPHA_VANTAGE_API_KEY")
twelve_key = System.fetch_env!("TWELVE_DATA_API_KEY")

# Collect standardized data from multiple sources
{:ok, yahoo_aapl} = Quant.Explorer.StandardizedAPI.history("AAPL",
  provider: :yahoo_finance, interval: "1d", period: "1y")

{:ok, alpha_aapl} = Quant.Explorer.StandardizedAPI.history("AAPL", 
  provider: :alpha_vantage, interval: "1d", period: "1y", api_key: alpha_key)

{:ok, twelve_aapl} = Quant.Explorer.StandardizedAPI.history("AAPL",
  provider: :twelve_data, interval: "1d", period: "1y", api_key: twelve_key)

# Livebook Cell 3: Analysis with Identical Schemas
all_data = DataFrame.concat_rows([yahoo_aapl, alpha_aapl, twelve_aapl])

# Analyze data quality across providers
data_quality = all_data
|> DataFrame.group_by("provider")
|> DataFrame.summarise(
  records: count(),
  avg_volume: mean(volume),
  price_std: std(close),
  date_range: [min(timestamp), max(timestamp)]
)

# Livebook Cell 4: Visualizations
all_data 
|> DataFrame.select(["timestamp", "close", "provider"])
|> VegaLite.from_dataframe()
|> VegaLite.mark(:line)
|> VegaLite.encode_field(:x, "timestamp", type: :temporal)
|> VegaLite.encode_field(:y, "close", type: :quantitative) 
|> VegaLite.encode_field(:color, "provider", type: :nominal)
```

## 🔧 Migration from Original API

Migrating to standardized API is straightforward:

```elixir
# Original API (still works)
{:ok, df} = Quant.Explorer.fetch("AAPL", provider: :yahoo_finance, period: "1y", interval: "1d")

# Standardized API (better for analysis)
{:ok, df} = Quant.Explorer.StandardizedAPI.history("AAPL", 
  provider: :yahoo_finance, period: "1y", interval: "1d")

# Benefits of standardized API:
# 1. Identical schemas across providers
# 2. Rich metadata (provider, currency, timezone)
# 3. Better type safety and validation
# 4. Universal parameter translation
```

## 📚 API Reference

### Core Functions

```elixir
# Historical data with universal parameters
Quant.Explorer.StandardizedAPI.history(symbols, opts)

# Real-time quotes with universal parameters  
Quant.Explorer.StandardizedAPI.quote(symbols, opts)

# Symbol search with standardized results
Quant.Explorer.StandardizedAPI.search(query, opts)

# Company info (not standardized due to high variation)
Quant.Explorer.StandardizedAPI.info(symbol, opts)
```

### Helper Functions

```elixir
# List supported standard intervals
Quant.Explorer.StandardizedAPI.supported_intervals()
# => ["1m", "5m", "15m", "30m", "1h", "1d", "1w", "1mo"]

# List supported standard periods
Quant.Explorer.StandardizedAPI.supported_periods()  
# => ["1d", "5d", "1mo", "3mo", "6mo", "1y", "2y", "5y", "10y", "max"]

# List supported currencies
Quant.Explorer.StandardizedAPI.supported_currencies()
# => ["usd", "eur", "btc", "eth"]

# Validate parameters for provider
Quant.Explorer.StandardizedAPI.validate_params(opts, :yahoo_finance)

# Demo schema compatibility
Quant.Explorer.StandardizedAPI.demo_schema_compatibility()
```

## 🎯 Best Practices

1. **Use Standardized API for Analysis**: Always use `Quant.Explorer.StandardizedAPI` when combining data from multiple providers

2. **Leverage Identical Schemas**: Take advantage of identical column structures for seamless data operations

3. **Include Provider Metadata**: Use the `provider`, `currency`, and `timezone` columns for data provenance

4. **Handle API Keys Gracefully**: Pass API keys directly in function calls for better flexibility

5. **Validate Parameters**: Use the validation functions to catch parameter issues early

6. **Cache Results**: Consider caching standardized DataFrames for repeated analysis

This standardization system makes Quant.Explorer the most interoperable financial data library in the Elixir ecosystem, enabling sophisticated cross-provider analysis with consistent, type-safe interfaces.