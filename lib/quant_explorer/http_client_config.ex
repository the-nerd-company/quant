defmodule Quant.Explorer.HttpClientConfig do
  @moduledoc """
  Configuration module for selecting the appropriate HTTP client based on environment.
  """

  @doc """
  Returns the HTTP client module to use based on the current environment.
  In test environment with mocking enabled, returns the test client.
  Otherwise returns the standard HTTP client.
  """
  def http_client do
    case Application.get_env(:quant_explorer, :http_client) do
      nil -> Quant.Explorer.HttpClient
      module when is_atom(module) -> module
    end
  end

  @doc """
  Makes an HTTP GET request using the configured client.
  """
  def get(url, params \\ %{}, opts \\ []) do
    http_client().get(url, params, opts)
  end

  @doc """
  Makes an HTTP POST request using the configured client.
  """
  def post(url, body, opts \\ []) do
    http_client().post(url, body, opts)
  end

  @doc """
  Decodes JSON using the configured client.
  """
  def decode_json(body) do
    http_client().decode_json(body)
  end
end
