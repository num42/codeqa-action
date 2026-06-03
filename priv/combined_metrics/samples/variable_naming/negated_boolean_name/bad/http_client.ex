defmodule HttpClient.Bad do
  @moduledoc """
  HTTP response handling with negated boolean names.
  BAD: is_not_success, no_body, should_not_retry — negations force mental inversion.
  """

  @spec handle(map()) :: {:ok, term()} | {:retry, integer()} | {:error, term()}
  def handle(response) do
    is_not_success = response.status not in 200..299
    no_body = response.body == nil or response.body == ""

    cond do
      not is_not_success and not no_body -> {:ok, response.body}
      not is_not_success -> {:ok, :empty}
      not should_not_retry?(response) -> {:retry, backoff(response)}
      true -> {:error, response.status}
    end
  end

  @spec should_not_retry?(map()) :: boolean()
  def should_not_retry?(response) do
    is_not_transient = response.status not in [502, 503, 504]
    no_budget = response.attempt >= 3

    is_not_transient or no_budget
  end

  @spec cacheable?(map()) :: boolean()
  def cacheable?(response) do
    is_not_get = response.method != :get
    is_not_fresh = response.max_age <= 0
    is_not_public = response.cache_control != :public

    not (is_not_get or is_not_fresh or is_not_public)
  end

  defp backoff(response), do: :math.pow(2, response.attempt) |> round()
end
