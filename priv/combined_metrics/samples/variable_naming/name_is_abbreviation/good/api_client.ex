defmodule ApiClient.Good do
  @moduledoc """
  HTTP API client using descriptive variable names.
  GOOD: variables like user, config, request, response, address, message are clear.
  """

  @spec send_request(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def send_request(config, user) do
    request = build_request(config, user)
    url = config.base_url <> request.path

    case HTTPoison.post(url, request.body, request.headers) do
      {:ok, response} ->
        message = parse_response(response)
        {:ok, message}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @spec fetch_product(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch_product(config, product_id) do
    url = "#{config.base_url}/products/#{product_id}"
    headers = auth_headers(config)

    case HTTPoison.get(url, headers) do
      {:ok, response} when response.status_code == 200 ->
        product = Jason.decode!(response.body)
        {:ok, product}

      {:ok, response} ->
        message = "Unexpected status: #{response.status_code}"
        {:error, message}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end

  @spec create_order(map(), map(), integer()) :: {:ok, map()} | {:error, String.t()}
  def create_order(config, user, quantity) do
    url = "#{config.base_url}/orders"
    body = Jason.encode!(%{user_id: user.id, quantity: quantity})
    headers = auth_headers(config) ++ [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, response} when response.status_code in [200, 201] ->
        {:ok, Jason.decode!(response.body)}

      {:ok, response} ->
        message = extract_error_message(response)
        {:error, message}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end

  @spec paginate(map(), map()) :: {:ok, list()} | {:error, String.t()}
  def paginate(config, params) do
    url = "#{config.base_url}/items"
    headers = auth_headers(config)

    case HTTPoison.get(url, headers, params: params) do
      {:ok, response} ->
        {:ok, Jason.decode!(response.body)}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end

  defp build_request(config, user) do
    %{
      path: "/requests",
      body: Jason.encode!(%{user_id: user.id}),
      headers: auth_headers(config)
    }
  end

  defp auth_headers(config) do
    [{"Authorization", "Bearer #{config.api_key}"}]
  end

  defp parse_response(response), do: Jason.decode!(response.body)
  defp extract_error_message(response), do: "Error #{response.status_code}: #{response.body}"
end
