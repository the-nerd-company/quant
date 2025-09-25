defmodule Quant.Explorer.HttpClient.Mock do
  @moduledoc """
  Mock version of HttpClient that uses mocked responses instead of making real HTTP requests.
  """

  alias Quant.Explorer.HttpMock
  require Logger

  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type params :: keyword() | map()
  @type options :: keyword()
  @type response ::
          {:ok, %{status: integer(), body: binary(), headers: headers()}} | {:error, term()}

  @doc """
  Mock version of HttpClient.get/3 that returns mocked responses.
  """
  @spec get(url(), params(), options()) :: response()
  def get(url, params \\ %{}, _opts \\ []) do
    final_url = build_url_with_params(url, params)

    case HttpMock.get_mocked_response(final_url) do
      nil ->
        Logger.warning("No mock found for URL: #{final_url}")
        {:error, {:no_mock, "No mock response found for #{final_url}"}}

      %{status: status, body: body, headers: headers} ->
        {:ok, %{status: status, body: body, headers: headers || []}}

      %{status: status, body: body} ->
        {:ok, %{status: status, body: body, headers: []}}

      body when is_binary(body) ->
        {:ok, %{status: 200, body: body, headers: [{"content-type", "application/json"}]}}

      other ->
        Logger.warning("Invalid mock response format: #{inspect(other)}")
        {:error, {:invalid_mock, "Invalid mock response format"}}
    end
  end

  @doc """
  Mock version of HttpClient.post/3 that returns mocked responses.
  """
  @spec post(url(), binary(), options()) :: response()
  def post(url, _body, _opts \\ []) do
    case HttpMock.get_mocked_response(url) do
      nil ->
        {:error, {:no_mock, "No mock response found for #{url}"}}

      %{status: status, body: body, headers: headers} ->
        {:ok, %{status: status, body: body, headers: headers || []}}

      body when is_binary(body) ->
        {:ok, %{status: 200, body: body, headers: [{"content-type", "application/json"}]}}

      other ->
        {:error, {:invalid_mock, "Invalid mock response format: #{inspect(other)}"}}
    end
  end

  @doc """
  Decode JSON response body.
  """
  def decode_json(body) do
    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:json_decode_error, reason}}
    end
  end

  defp build_url_with_params(url, params) when params == %{} or params == [], do: url

  defp build_url_with_params(url, params) do
    query_string =
      params
      |> Enum.map_join("&", fn {k, v} ->
        "#{URI.encode_www_form(to_string(k))}=#{URI.encode_www_form(to_string(v))}"
      end)

    case String.contains?(url, "?") do
      true -> "#{url}&#{query_string}"
      false -> "#{url}?#{query_string}"
    end
  end
end
