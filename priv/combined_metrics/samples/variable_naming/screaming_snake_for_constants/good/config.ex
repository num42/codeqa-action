defmodule Config.Good do
  @moduledoc """
  Application config and HTTP client using correctly-cased module constants.
  GOOD: module-level constants use SCREAMING_SNAKE_CASE as Elixir convention.
  """

  @MAX_RETRIES 3
  @DEFAULT_TIMEOUT 5_000
  @API_BASE_URL "https://api.example.com/v1"
  @PAGE_SIZE 25
  @RETRY_DELAY 1_000
  @MAX_PAGE_SIZE 100
  @CONNECT_TIMEOUT 2_000
  @DEFAULT_HEADERS [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  @spec fetch(String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch(path) do
    url = @API_BASE_URL <> path
    do_request_with_retry(url, @MAX_RETRIES, @DEFAULT_TIMEOUT)
  end

  @spec fetch_page(String.t(), integer()) :: {:ok, map()} | {:error, String.t()}
  def fetch_page(path, page) do
    size = min(page, @MAX_PAGE_SIZE)
    url = "#{@API_BASE_URL}#{path}?page=#{page}&size=#{size}"
    do_request_with_retry(url, @MAX_RETRIES, @DEFAULT_TIMEOUT)
  end

  @spec paginate_all(String.t()) :: {:ok, list()} | {:error, String.t()}
  def paginate_all(path) do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn page ->
      fetch_page(path, page)
    end)
    |> Stream.take_while(fn
      {:ok, %{items: items}} -> length(items) == @PAGE_SIZE
      _ -> false
    end)
    |> Enum.to_list()
    |> then(fn results ->
      if Enum.all?(results, &match?({:ok, _}, &1)),
        do: {:ok, Enum.flat_map(results, fn {:ok, %{items: i}} -> i end)},
        else: {:error, "Pagination failed"}
    end)
  end

  @spec post(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def post(path, body) do
    url = @API_BASE_URL <> path
    do_post_with_retry(url, body, @MAX_RETRIES)
  end

  defp do_request_with_retry(url, retries_left, timeout) do
    case HTTPoison.get(url, @DEFAULT_HEADERS, recv_timeout: timeout, connect_timeout: @CONNECT_TIMEOUT) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status}} when status >= 500 and retries_left > 0 ->
        Process.sleep(@RETRY_DELAY)
        do_request_with_retry(url, retries_left - 1, timeout)

      {:ok, %{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, err} when retries_left > 0 ->
        Process.sleep(@RETRY_DELAY)
        do_request_with_retry(url, retries_left - 1, timeout)

      {:error, err} ->
        {:error, inspect(err)}
    end
  end

  defp do_post_with_retry(url, body, retries_left) do
    case HTTPoison.post(url, Jason.encode!(body), @DEFAULT_HEADERS, recv_timeout: @DEFAULT_TIMEOUT) do
      {:ok, %{status_code: code, body: resp}} when code in [200, 201] ->
        {:ok, Jason.decode!(resp)}

      {:ok, _} when retries_left > 0 ->
        Process.sleep(@RETRY_DELAY)
        do_post_with_retry(url, body, retries_left - 1)

      {:ok, %{status_code: code}} ->
        {:error, "HTTP #{code}"}

      {:error, _} ->
        {:error, "Request failed"}
    end
  end
end
