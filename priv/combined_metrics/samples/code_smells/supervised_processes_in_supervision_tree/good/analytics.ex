defmodule MyApp.Analytics.EventBuffer do
  @moduledoc """
  Buffers analytics events before flushing to the database.
  Started under the application supervisor — never spawned bare.
  """

  use GenServer, restart: :permanent

  @flush_interval_ms 5_000
  @max_buffer_size 500

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Adds an event to the buffer."
  @spec push(map()) :: :ok
  def push(event) when is_map(event) do
    GenServer.cast(__MODULE__, {:push, event})
  end

  @impl true
  def init(_opts) do
    schedule_flush()
    {:ok, %{buffer: [], count: 0}}
  end

  @impl true
  def handle_cast({:push, event}, %{buffer: buf, count: count} = state) do
    new_state = %{state | buffer: [event | buf], count: count + 1}

    if new_state.count >= @max_buffer_size do
      flush(new_state.buffer)
      {:noreply, %{new_state | buffer: [], count: 0}}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:flush, %{buffer: []} = state) do
    schedule_flush()
    {:noreply, state}
  end

  def handle_info(:flush, %{buffer: buf} = state) do
    flush(buf)
    schedule_flush()
    {:noreply, %{state | buffer: [], count: 0}}
  end

  defp flush(events) do
    MyApp.Analytics.Store.insert_all(Enum.reverse(events))
  end

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval_ms)
  end
end

defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      # Good: EventBuffer is started as a supervised child, not with spawn/1
      MyApp.Analytics.EventBuffer
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
