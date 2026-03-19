defmodule MyApp.Sessions do
  @moduledoc """
  Session store operations. Follows the `get_*` / `fetch_*` / `fetch_*!` contract:
  - `get_*` returns a value or a default (nil by default)
  - `fetch_*` returns `{:ok, value}` or `:error`
  - `fetch_*!` raises `KeyError` on missing key
  """

  alias MyApp.Sessions.Session

  @sessions_table :sessions_cache

  @doc """
  Returns the session for the given token, or `nil` if not found.
  Safe to call when the session may or may not exist.
  """
  @spec get_session(String.t()) :: Session.t() | nil
  def get_session(token) when is_binary(token) do
    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] -> session
      [] -> nil
    end
  end

  @doc """
  Returns the session for the given token, or the `default` value
  when no session is found.
  """
  @spec get_session(String.t(), any()) :: Session.t() | any()
  def get_session(token, default) when is_binary(token) do
    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] -> session
      [] -> default
    end
  end

  @doc """
  Fetches a session by token. Returns `{:ok, session}` if found,
  or `:error` if not found. Use when the caller handles the missing case.
  """
  @spec fetch_session(String.t()) :: {:ok, Session.t()} | :error
  def fetch_session(token) when is_binary(token) do
    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] -> {:ok, session}
      [] -> :error
    end
  end

  @doc """
  Fetches a session by token. Raises `KeyError` if not found.
  Use when the session must exist and absence is a programming error.
  """
  @spec fetch_session!(String.t()) :: Session.t()
  def fetch_session!(token) when is_binary(token) do
    case fetch_session(token) do
      {:ok, session} -> session
      :error -> raise KeyError, key: token, term: @sessions_table
    end
  end

  @doc """
  Returns the value for `key` in the session data, or `nil` if absent.
  """
  @spec get_value(Session.t(), atom()) :: any()
  def get_value(%Session{data: data}, key), do: Map.get(data, key)

  @doc """
  Fetches `key` from session data. Returns `{:ok, value}` or `:error`.
  """
  @spec fetch_value(Session.t(), atom()) :: {:ok, any()} | :error
  def fetch_value(%Session{data: data}, key), do: Map.fetch(data, key)

  @doc """
  Fetches `key` from session data. Raises `KeyError` if absent.
  """
  @spec fetch_value!(Session.t(), atom()) :: any()
  def fetch_value!(%Session{data: data}, key), do: Map.fetch!(data, key)
end
