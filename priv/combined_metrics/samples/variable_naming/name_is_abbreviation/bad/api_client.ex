defmodule ApiClient.Bad do
  @moduledoc """
  HTTP API client using abbreviated variable names.
  BAD: variables like usr, cfg, req, res, addr, msg obscure intent.
  """

  @spec send_request(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def send_request(cfg, usr) do
    req = build_req(cfg, usr)
    addr = cfg.base_url <> req.path

    case HTTPoison.post(addr, req.body, req.headers) do
      {:ok, res} ->
        msg = parse_res(res)
        {:ok, msg}

      {:error, err} ->
        {:error, "Request failed: #{inspect(err)}"}
    end
  end

  @spec fetch_product(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch_product(cfg, prd_id) do
    addr = "#{cfg.base_url}/products/#{prd_id}"
    req = %{method: :get, path: "/products/#{prd_id}", headers: auth_headers(cfg)}

    case HTTPoison.get(addr, req.headers) do
      {:ok, res} when res.status_code == 200 ->
        prd = Jason.decode!(res.body)
        {:ok, prd}

      {:ok, res} ->
        msg = "Unexpected status: #{res.status_code}"
        {:error, msg}

      {:error, err} ->
        {:error, inspect(err)}
    end
  end

  @spec create_order(map(), map(), integer()) :: {:ok, map()} | {:error, String.t()}
  def create_order(cfg, usr, qty) do
    addr = "#{cfg.base_url}/orders"
    req_body = Jason.encode!(%{user_id: usr.id, quantity: qty})
    req_headers = auth_headers(cfg) ++ [{"Content-Type", "application/json"}]

    case HTTPoison.post(addr, req_body, req_headers) do
      {:ok, res} when res.status_code in [200, 201] ->
        {:ok, Jason.decode!(res.body)}

      {:ok, res} ->
        msg = extract_error_msg(res)
        {:error, msg}

      {:error, err} ->
        {:error, inspect(err)}
    end
  end

  @spec paginate(map(), map()) :: {:ok, list()} | {:error, String.t()}
  def paginate(cfg, params) do
    addr = "#{cfg.base_url}/items"
    req = %{path: "/items", headers: auth_headers(cfg), query: params}

    case HTTPoison.get(addr, req.headers, params: req.query) do
      {:ok, res} ->
        {:ok, Jason.decode!(res.body)}

      {:error, err} ->
        {:error, inspect(err)}
    end
  end

  defp build_req(cfg, usr) do
    %{
      path: "/requests",
      body: Jason.encode!(%{user_id: usr.id}),
      headers: auth_headers(cfg)
    }
  end

  defp auth_headers(cfg) do
    [{"Authorization", "Bearer #{cfg.api_key}"}]
  end

  defp parse_res(res), do: Jason.decode!(res.body)
  defp extract_error_msg(res), do: "Error #{res.status_code}: #{res.body}"
end
