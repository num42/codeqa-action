defmodule MyApp.Analytics.EventBuffer do
  @moduledoc """
  Buffers analytics events.
  """

  @flush_interval_ms 5_000

  # Bad: starts the background loop with a bare spawn/1 call.
  # If this process crashes it will not be restarted, and no crash report
  # is linked to any supervisor — it silently disappears.
  @spec start() :: pid()
  def start do
    state = %{buffer: [], count: 0}
    spawn(fn -> loop(state) end)
  end

  @spec push(pid(), map()) :: :ok
  def push(pid, event) when is_map(event) do
    send(pid, {:push, event})
    :ok
  end

  defp loop(state) do
    receive do
      {:push, event} ->
        new_state = %{state | buffer: [event | state.buffer], count: state.count + 1}

        if new_state.count >= 500 do
          flush(new_state.buffer)
          loop(%{buffer: [], count: 0})
        else
          loop(new_state)
        end

      :flush ->
        flush(state.buffer)
        schedule_flush(self())
        loop(%{buffer: [], count: 0})
    end
  end

  defp flush(events), do: MyApp.Analytics.Store.insert_all(Enum.reverse(events))

  defp schedule_flush(pid) do
    Process.send_after(pid, :flush, @flush_interval_ms)
  end
end

defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [MyApp.Repo]

    result = Supervisor.start_link(children, strategy: :one_for_one)

    # Bad: EventBuffer is started with spawn/1 outside the supervision tree.
    # It will not be restarted on crash and the PID is hard to track.
    pid = MyApp.Analytics.EventBuffer.start()
    Process.register(pid, :event_buffer)

    result
  end
end
