defmodule MyApp.SessionStore do
  @moduledoc "Holds session state."

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: {:ok, %{sessions: %{}}}

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
end

# Bad: MyApp.AuthController calls GenServer directly instead of going through a facade
defmodule MyApp.AuthController do
  def login(conn, %{"token" => token}) do
    # Bad: direct GenServer call scattered in a controller
    session = GenServer.call(MyApp.SessionStore, {:get, token})
    # ...
  end
end

# Bad: MyApp.Plugs.LoadSession also calls GenServer directly — duplication
defmodule MyApp.Plugs.LoadSession do
  def call(conn, _opts) do
    token = get_session_token(conn)
    # Bad: same GenServer call repeated here — no single facade
    session = GenServer.call(MyApp.SessionStore, {:get, token})
    assign(conn, :current_session, session)
  end

  defp get_session_token(conn), do: Plug.Conn.get_req_header(conn, "x-session-token") |> List.first()
  defp assign(conn, key, value), do: Map.put(conn, key, value)
end

# Bad: yet another module talking directly to the GenServer
defmodule MyApp.SessionCleanup do
  def delete_expired(tokens) do
    Enum.each(tokens, fn token ->
      # Bad: direct cast, not going through any facade
      GenServer.cast(MyApp.SessionStore, {:delete, token})
    end)
  end
end
