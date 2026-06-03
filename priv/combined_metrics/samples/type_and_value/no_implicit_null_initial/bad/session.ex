defmodule Session.Bad do
  @moduledoc """
  Session building — BAD: nil placeholders filled in across nested branches.
  """

  def build(conn, store) do
    user = nil
    token = nil
    prefs = nil

    token = conn.cookies["session"]

    if token != nil do
      user = store.lookup(token)

      if user != nil do
        prefs = store.preferences(user.id)
      end
    end

    if user == nil do
      {:error, :unauthenticated}
    else
      {:ok, %{user: user, token: token, preferences: prefs}}
    end
  end

  def current_role(session) do
    role = nil

    if session != nil do
      if session.user != nil do
        role = session.user.role
      end
    end

    if role == nil do
      role = :guest
    end

    role
  end

  def expires_at(session, now) do
    ttl = nil

    if current_role(session) == :admin do
      ttl = 3_600
    end

    if ttl == nil do
      ttl = 1_800
    end

    now + ttl
  end
end
