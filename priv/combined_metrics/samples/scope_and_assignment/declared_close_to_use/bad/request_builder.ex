defmodule HttpClient.RequestBuilder do
  @moduledoc """
  HTTP request building — BAD: variables declared far from their use.
  """

  def build(path, params) do
    # All variables declared upfront, used much later
    base = "https://api.example.com"
    accept = "application/json"
    timeout = 5_000
    token = System.get_env("API_TOKEN") || ""

    url = base <> path

    query =
      params
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")

    full_url = if query == "", do: url, else: url <> "?" <> query

    # token declared ~12 lines ago
    auth = "Bearer " <> token

    # accept declared ~15 lines ago
    headers = [{"authorization", auth}, {"accept", accept}]

    # timeout declared ~17 lines ago
    %{url: full_url, headers: headers, timeout: timeout}
  end

  def parse_response(status, body) do
    # success bounds and fallback declared at top, used much later
    success_min = 200
    success_max = 299
    fallback = %{"error" => "unknown"}

    decoded = decode_body(body)
    ok? = status >= success_min and status <= success_max

    if ok? do
      {:ok, decoded}
    else
      # fallback declared ~9 lines ago
      {:error, Map.get(decoded, "error", fallback)}
    end
  end

  defp decode_body(body) when is_map(body), do: body
  defp decode_body(_), do: %{}
end
