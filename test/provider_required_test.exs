defmodule Quant.Explorer.ProviderRequiredTest do
  @moduledoc """
  Tests to ensure that all main Quant.Explorer functions require an explicit provider
  when none is set as default, and that they accept the provider parameter correctly.
  """
  use ExUnit.Case

  describe "explicit provider requirement" do
    test "returns :provider_required error when no provider specified" do
      # Test all main functions require explicit provider
      assert {:error, :provider_required} = Quant.Explorer.history("AAPL")
      assert {:error, :provider_required} = Quant.Explorer.quote("AAPL")
      assert {:error, :provider_required} = Quant.Explorer.search("Apple")
      assert {:error, :provider_required} = Quant.Explorer.info("AAPL")
      assert {:error, :provider_required} = Quant.Explorer.fetch("AAPL")
    end

    test "accepts explicit provider parameter" do
      # Test that explicit providers are accepted
      # In integration mode, this should work; in mocked mode, expect HTTP errors
      case Quant.Explorer.history("AAPL", provider: :yahoo_finance, period: "1d") do
        # Integration tests - Yahoo Finance works
        {:ok, _df} -> :ok
        # Mocked tests - HTTP client not configured
        {:error, {:http_error, _}} -> :ok
        other -> flunk("Expected success or HTTP error, got: #{inspect(other)}")
      end

      case Quant.Explorer.quote("AAPL", provider: :yahoo_finance) do
        {:ok, _df} -> :ok
        {:error, {:http_error, _}} -> :ok
        other -> flunk("Expected success or HTTP error, got: #{inspect(other)}")
      end

      case Quant.Explorer.search("Apple", provider: :yahoo_finance) do
        {:ok, _df} -> :ok
        {:error, {:http_error, _}} -> :ok
        other -> flunk("Expected success or HTTP error, got: #{inspect(other)}")
      end

      assert {:error, {:http_error, _}} = Quant.Explorer.info("AAPL", provider: :yahoo_finance)

      assert {:error, {:http_error, _}} =
               Quant.Explorer.fetch("AAPL", provider: :yahoo_finance, period: "1d")
    end
  end
end
