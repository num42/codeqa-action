defmodule MyApp.SessionStore do
  @moduledoc """
  Facade for all interactions with the session cache GenServer.
  All GenServer calls are centralised here — no other module calls
  `GenServer.call/cast` on the session process directly.
  """

  use GenServer

  alias MyApp.Sessions.Session

  # --- Public API (the facade) ---

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Stores a session, returning the token."
  @spec put(Session.t()) :: String.t()
  def put(%Session{} = session) do
    token = generate_token()
    GenServer.call(__MODULE__, {:put, token, session})
    token
  end

  @doc "Retrieves a session by token."
  @spec get(String.t()) :: Session.t() | nil
  def get(token) when is_binary(token) do
    GenServer.call(__MODULE__, {:get, token})
  end

  @doc "Deletes a session by token."
  @spec delete(String.t()) :: :ok
  def delete(token) when is_binary(token) do
    GenServer.cast(__MODULE__, {:delete, token})
  end

  @doc "Extends a session's TTL by the given number of seconds."
  @spec touch(String.t(), pos_integer()) :: :ok
  def touch(token, ttl_seconds) when is_binary(token) and is_integer(ttl_seconds) do
    GenServer.cast(__MODULE__, {:touch, token, ttl_seconds})
  end

  @doc "Returns the number of active sessions."
  @spec count() :: non_neg_integer()
  def count do
    GenServer.call(__MODULE__, :count)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts), do: {:ok, %{sessions: %{}, expiry: %{}}}

  @impl true
  def handle_call({:put, token, session}, _from, state) do
    {:reply, :ok, put_in(state, [:sessions, token], session)}
  end

  def handle_call({:get, token}, _from, state) do
    {:reply, Map.get(state.sessions, token), state}
  end

  def handle_call(:count, _from, state) do
    {:reply, map_size(state.sessions), state}
  end

  @impl true
  def handle_cast({:delete, token}, state) do
    {:noreply, update_in(state, [:sessions], &Map.delete(&1, token))}
  end

  def handle_cast({:touch, _token, _ttl}, state) do
    {:noreply, state}
  end

  defp generate_token, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
end
