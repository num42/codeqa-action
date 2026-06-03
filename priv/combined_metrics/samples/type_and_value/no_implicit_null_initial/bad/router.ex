defmodule Router.Bad do
  @moduledoc """
  Request routing — BAD: handler starts nil and is set in branch after branch.
  """

  def dispatch(request) do
    handler = nil

    if request.method == :get and request.path == "/health" do
      handler = &health/1
    end

    if request.method == :get and request.path == "/users" do
      handler = &list_users/1
    end

    if request.method == :post and request.path == "/users" do
      handler = &create_user/1
    end

    if handler == nil do
      handler = &not_found/1
    end

    handler.(request)
  end

  def status_for(result) do
    status = nil

    if match?({:ok, _}, result) do
      status = 200
    end

    if result == {:error, :not_found} do
      status = 404
    end

    if status == nil do
      status = 500
    end

    status
  end

  defp health(_request), do: {:ok, %{status: "up"}}
  defp list_users(_request), do: {:ok, []}
  defp create_user(_request), do: {:ok, %{id: 1}}
  defp not_found(_request), do: {:error, :not_found}
end
