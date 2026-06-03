defmodule Router.Good do
  @moduledoc """
  Request routing — GOOD: the handler is the value of a single case expression.
  """

  def dispatch(request) do
    handler =
      case {request.method, request.path} do
        {:get, "/health"} -> &health/1
        {:get, "/users"} -> &list_users/1
        {:post, "/users"} -> &create_user/1
        {_, _} -> &not_found/1
      end

    handler.(request)
  end

  def status_for(result) do
    case result do
      {:ok, _} -> 200
      {:error, :not_found} -> 404
      {:error, :invalid} -> 422
      {:error, _} -> 500
    end
  end

  def content_type(request) do
    Map.get(request.headers, "accept", "application/json")
  end

  defp health(_request), do: {:ok, %{status: "up"}}
  defp list_users(_request), do: {:ok, []}
  defp create_user(_request), do: {:ok, %{id: 1}}
  defp not_found(_request), do: {:error, :not_found}
end
