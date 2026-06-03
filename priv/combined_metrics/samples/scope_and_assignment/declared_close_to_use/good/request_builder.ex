defmodule HttpClient.RequestBuilder do
  @moduledoc """
  HTTP request building — GOOD: variables declared immediately before use.
  """

  def build(path, params) do
    base = "https://api.example.com"
    url = base <> path

    query =
      params
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")

    full_url = if query == "", do: url, else: url <> "?" <> query

    token = System.get_env("API_TOKEN") || ""
    auth = "Bearer " <> token
    accept = "application/json"
    headers = [{"authorization", auth}, {"accept", accept}]

    timeout = 5_000
    %{url: full_url, headers: headers, timeout: timeout}
  end

  def parse_response(status, body) do
    decoded = decode_body(body)

    success_min = 200
    success_max = 299
    ok? = status >= success_min and status <= success_max

    if ok? do
      {:ok, decoded}
    else
      fallback = %{"error" => "unknown"}
      {:error, Map.get(decoded, "error", fallback)}
    end
  end

  defp decode_body(body) when is_map(body), do: body
  defp decode_body(_), do: %{}
end
