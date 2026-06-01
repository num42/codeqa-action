defmodule Config.Bad do
  @moduledoc """
  Application config and HTTP client using incorrectly-cased module constants.
  BAD: module-level constants use camelCase or lowercase instead of SCREAMING_SNAKE_CASE.
  """

  @maxRetries 3
  @defaultTimeout 5_000
  @apiBaseUrl "https://api.example.com/v1"
  @pageSize 25
  @retryDelay 1_000
  @maxPageSize 100
  @connectTimeout 2_000
  @defaultHeaders [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  @spec fetch(String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch(path) do
    url = @apiBaseUrl <> path
    do_request_with_retry(url, @maxRetries, @defaultTimeout)
  end

  @spec fetch_page(String.t(), integer()) :: {:ok, map()} | {:error, String.t()}
  def fetch_page(path, page) do
    size = min(page, @maxPageSize)
    url = "#{@apiBaseUrl}#{path}?page=#{page}&size=#{size}"
    do_request_with_retry(url, @maxRetries, @defaultTimeout)
  end

  @spec paginate_all(String.t()) :: {:ok, list()} | {:error, String.t()}
  def paginate_all(path) do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn page ->
      fetch_page(path, page)
    end)
    |> Stream.take_while(fn
      {:ok, %{items: items}} -> length(items) == @pageSize
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
    url = @apiBaseUrl <> path
    do_post_with_retry(url, body, @maxRetries)
  end

  defp do_request_with_retry(url, retries_left, timeout) do
    case HTTPoison.get(url, @defaultHeaders, recv_timeout: timeout, connect_timeout: @connectTimeout) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status}} when status >= 500 and retries_left > 0 ->
        Process.sleep(@retryDelay)
        do_request_with_retry(url, retries_left - 1, timeout)

      {:ok, %{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, err} when retries_left > 0 ->
        Process.sleep(@retryDelay)
        do_request_with_retry(url, retries_left - 1, timeout)

      {:error, err} ->
        {:error, inspect(err)}
    end
  end

  defp do_post_with_retry(url, body, retries_left) do
    case HTTPoison.post(url, Jason.encode!(body), @defaultHeaders, recv_timeout: @defaultTimeout) do
      {:ok, %{status_code: code, body: resp}} when code in [200, 201] ->
        {:ok, Jason.decode!(resp)}

      {:ok, _} when retries_left > 0 ->
        Process.sleep(@retryDelay)
        do_post_with_retry(url, body, retries_left - 1)

      {:ok, %{status_code: code}} ->
        {:error, "HTTP #{code}"}

      {:error, _} ->
        {:error, "Request failed"}
    end
  end
end
