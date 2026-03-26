defmodule MyApp.Sessions do
  @moduledoc """
  Session store operations.
  """

  alias MyApp.Sessions.Session

  @sessions_table :sessions_cache

  # Bad: `get_session` raises instead of returning nil/default
  @spec get_session(String.t()) :: Session.t()
  def get_session(token) when is_binary(token) do
    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] -> session
      [] -> raise KeyError, key: token, term: @sessions_table
    end
  end

  # Bad: `fetch_session` returns nil instead of `{:ok, value}` or `:error`
  @spec fetch_session(String.t()) :: Session.t() | nil
  def fetch_session(token) when is_binary(token) do
    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] -> session
      [] -> nil
    end
  end

  # Bad: `fetch_session!` returns a tuple like fetch, not raising
  @spec fetch_session!(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  def fetch_session!(token) when is_binary(token) do
    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] -> {:ok, session}
      [] -> {:error, :not_found}
    end
  end

  # Bad: `get_value` returns `{:ok, val}` or `:error` like fetch_*
  @spec get_value(Session.t(), atom()) :: {:ok, any()} | :error
  def get_value(%Session{data: data}, key), do: Map.fetch(data, key)

  # Bad: `fetch_value` returns nil (should be `{:ok, val}` or `:error`)
  @spec fetch_value(Session.t(), atom()) :: any() | nil
  def fetch_value(%Session{data: data}, key), do: Map.get(data, key)

  # Bad: `fetch_value!` swallows the error and returns nil
  @spec fetch_value!(Session.t(), atom()) :: any()
  def fetch_value!(%Session{data: data}, key) do
    case Map.fetch(data, key) do
      {:ok, v} -> v
      :error -> nil
    end
  end
end
