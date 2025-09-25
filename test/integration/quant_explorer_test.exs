defmodule FinExplorerTest do
  use ExUnit.Case
  import Quant.Explorer.TestHelper

  doctest Quant.Explorer

  # These tests make real HTTP requests - tagged as integration tests
  @moduletag :integration

  setup_all do
    # Use real HTTP client for integration tests
    Application.put_env(:quant_explorer, :http_client, Quant.Explorer.HttpClient)
    :ok
  end

  setup do
    setup_rate_limiter()
    :ok
  end

  describe "config/0" do
    test "returns configuration information" do
      config = Quant.Explorer.config()

      assert is_map(config)
      assert Map.has_key?(config, :http_timeout)
      assert Map.has_key?(config, :cache_ttl)
      assert Map.has_key?(config, :telemetry_enabled)
      assert Map.has_key?(config, :user_agent)
      # Note: default_provider removed - providers must be specified explicitly
    end
  end

  describe "providers/0" do
    test "returns provider information" do
      providers = Quant.Explorer.providers()

      assert is_map(providers)
      assert Map.has_key?(providers, :yahoo_finance)
      assert Map.has_key?(providers, :alpha_vantage)
      assert Map.has_key?(providers, :binance)
      assert Map.has_key?(providers, :coin_gecko)
      assert Map.has_key?(providers, :twelve_data)

      # Check provider info structure
      yahoo_info = providers[:yahoo_finance]
      assert Map.has_key?(yahoo_info, :rate_limit)
      assert Map.has_key?(yahoo_info, :api_key_configured)
      assert Map.has_key?(yahoo_info, :current_request_count)
    end
  end

  describe "fetch/2" do
    test "returns error for unknown provider" do
      assert {:error, {:unknown_provider, :unknown}} =
               Quant.Explorer.fetch("AAPL", provider: :unknown)
    end

    test "validates single symbol input" do
      # Test with actual working provider
      result = Quant.Explorer.fetch("AAPL", provider: :yahoo_finance)

      # Should get either success or rate limited (both are valid)
      case result do
        # Success - provider working
        {:ok, _df} -> assert true
        # Rate limited - expected
        {:error, {:http_error, 429}} -> assert true
        # Rate limited - expected
        {:error, :rate_limited} -> assert true
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "validates multiple symbols input" do
      result = Quant.Explorer.fetch(["AAPL", "MSFT"], provider: :yahoo_finance)

      # Should get either success or rate limited (both are valid)
      case result do
        # Success - provider working
        {:ok, _df} -> assert true
        # Rate limited - expected
        {:error, {:http_error, 429}} -> assert true
        # Rate limited - expected
        {:error, :rate_limited} -> assert true
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end
  end

  describe "quote/2" do
    test "returns error for unknown provider" do
      assert {:error, {:unknown_provider, :unknown}} =
               Quant.Explorer.quote("AAPL", provider: :unknown)
    end
  end

  describe "info/2" do
    test "returns error for unknown provider" do
      assert {:error, {:unknown_provider, :unknown}} =
               Quant.Explorer.info("AAPL", provider: :unknown)
    end
  end

  describe "search/2" do
    test "returns error for unknown provider" do
      assert {:error, {:unknown_provider, :unknown}} =
               Quant.Explorer.search("Apple", provider: :unknown)
    end
  end
end
