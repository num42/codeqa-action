defmodule HttpClient.Good do
  @moduledoc """
  HTTP response handling with positive boolean names.
  GOOD: is_success, has_body, should_retry — direct, affirmative reads.
  """

  @spec handle(map()) :: {:ok, term()} | {:retry, integer()} | {:error, term()}
  def handle(response) do
    is_success = response.status in 200..299
    has_body = response.body != nil and response.body != ""

    cond do
      is_success and has_body -> {:ok, response.body}
      is_success -> {:ok, :empty}
      should_retry?(response) -> {:retry, backoff(response)}
      true -> {:error, response.status}
    end
  end

  @spec should_retry?(map()) :: boolean()
  def should_retry?(response) do
    is_transient = response.status in [502, 503, 504]
    has_budget = response.attempt < 3

    is_transient and has_budget
  end

  @spec cacheable?(map()) :: boolean()
  def cacheable?(response) do
    is_get = response.method == :get
    is_fresh = response.max_age > 0
    is_public = response.cache_control == :public

    is_get and is_fresh and is_public
  end

  defp backoff(response), do: :math.pow(2, response.attempt) |> round()
end
