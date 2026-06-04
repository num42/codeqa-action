defmodule Auth.SessionStore do
  @moduledoc """
  Stores and validates user sessions. BAD: mixed 2-space, 4-space and tab indentation.
  """

  def put(store, token, user_id) do
    expires = System.system_time(:second) + 3600
      entry = %{user_id: user_id, expires: expires}
    Map.put(store, token, entry)
  end

  def fetch(store, token) do
      case Map.get(store, token) do
        nil ->
        {:error, :not_found}
      %{expires: expires} = entry ->
		if expires > System.system_time(:second) do
          {:ok, entry}
		else
              {:error, :expired}
        end
    end
  end

  def revoke(store, token) do
	Map.delete(store, token)
  end

  def cleanup(store) do
    now = System.system_time(:second)
      store
    |> Enum.reject(fn {_token, %{expires: e}} -> e <= now end)
	  |> Map.new()
  end
end
