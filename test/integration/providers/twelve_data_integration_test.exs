defmodule Quant.Explorer.Providers.TwelveDataIntegrationTest do
  use ExUnit.Case

  alias Explorer.DataFrame
  alias Quant.Explorer.Providers.TwelveData

  @moduletag :integration

  describe "Twelve Data Integration Tests" do
    test "api_key can be passed as option" do
      # This test demonstrates passing API key directly in function call
      # rather than configuring it globally
      api_key = System.get_env("TWELVE_DATA_API_KEY") || "demo"

      # Test history with api_key
      result = TwelveData.history("AAPL", api_key: api_key, interval: "1day", outputsize: 5)

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
            {:api_key_error, _} -> true
            {:provider_error, _} -> true
            _ -> false
          end
          |> assert
      end

      # Test quote with api_key
      result = TwelveData.quote("AAPL", api_key: api_key)

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
            {:api_key_error, _} -> true
            {:provider_error, _} -> true
            _ -> false
          end
          |> assert
      end

      # Test search with api_key
      result = TwelveData.search("Apple", api_key: api_key)

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
            {:api_key_error, _} -> true
            {:provider_error, _} -> true
            _ -> false
          end
          |> assert
      end

      # Test info with api_key
      result = TwelveData.info("AAPL", api_key: api_key)

      case result do
        {:ok, info} ->
          assert is_map(info)

        {:error, reason} ->
          # For demo keys or rate limits, we expect these specific errors
          case reason do
            :rate_limited -> true
            {:api_key_error, _} -> true
            {:provider_error, _} -> true
            _ -> false
          end
          |> assert
      end
    end
  end
end
