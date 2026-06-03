defmodule Session.Good do
  @moduledoc """
  Session building — GOOD: values bound once from with/case results.
  """

  def build(conn, store) do
    with {:ok, token} <- read_token(conn),
         {:ok, user} <- store.lookup(token),
         {:ok, prefs} <- store.preferences(user.id) do
      {:ok, %{user: user, token: token, preferences: prefs}}
    else
      :no_token -> {:error, :unauthenticated}
      {:error, reason} -> {:error, reason}
    end
  end

  def current_role(session) do
    case session do
      %{user: %{role: role}} -> role
      _ -> :guest
    end
  end

  def expires_at(session, now) do
    ttl = ttl_for(current_role(session))
    now + ttl
  end

  defp ttl_for(:admin), do: 3_600
  defp ttl_for(:guest), do: 300
  defp ttl_for(_), do: 1_800

  defp read_token(conn) do
    case conn.cookies["session"] do
      nil -> :no_token
      token -> {:ok, token}
    end
  end
end
