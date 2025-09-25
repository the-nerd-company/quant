defmodule Quant.Explorer.Providers.AlphaVantageIntegrationTest do
  use ExUnit.Case

  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.AlphaVantage

  @moduletag :integration

  describe "Alpha Vantage Integration Tests" do
    test "api_key can be passed as option" do
      # This test demonstrates passing API key directly in function call
      # rather than configuring it globally
      api_key = System.get_env("ALPHA_VANTAGE_API_KEY") || "demo"

      # Test history with api_key
      result =
        AlphaVantage.history("IBM", api_key: api_key, interval: "daily", outputsize: "compact")

      case result do
        {:ok, df} ->
          assert %DataFrame{} = df
          columns = DataFrame.names(df)
          assert "symbol" in columns
          assert "timestamp" in columns

        {:error, reason} ->
          # For demo keys or rate limits, we expect these specific errors
          case reason do
            :rate_limited -> true
            :symbol_not_found -> true
            {:api_key_error, _} -> true
            _ -> false
          end
          |> assert
      end

      # Test quote with api_key
      result = AlphaVantage.quote("IBM", api_key: api_key)

      case result do
        {:ok, df} ->
          assert %DataFrame{} = df
          columns = DataFrame.names(df)
          assert "symbol" in columns
          assert "price" in columns

        {:error, reason} ->
          # For demo keys or rate limits, we expect these specific errors
          case reason do
            :rate_limited -> true
            :symbol_not_found -> true
            {:api_key_error, _} -> true
            _ -> false
          end
          |> assert
      end

      # Test search with api_key
      result = AlphaVantage.search("IBM", api_key: api_key)

      case result do
        {:ok, df} ->
          assert %DataFrame{} = df
          columns = DataFrame.names(df)
          assert "symbol" in columns
          assert "name" in columns

        {:error, reason} ->
          # For demo keys or rate limits, we expect these specific errors
          case reason do
            :rate_limited -> true
            :symbol_not_found -> true
            {:api_key_error, _} -> true
            _ -> false
          end
          |> assert
      end
    end
  end
end
