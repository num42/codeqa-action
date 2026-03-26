defmodule CodeQA.CLI.Progress do
  @moduledoc false

  alias CodeQA.CLI.UI

  @spec callback(integer(), integer(), String.t(), integer()) :: :ok
  def callback(completed, total, path, start_time) do
    now = System.monotonic_time(:millisecond)
    elapsed = max(now - start_time, 1)
    avg_time = elapsed / completed
    eta_ms = round((total - completed) * avg_time)

    label = if String.length(path) > 30, do: "..." <> String.slice(path, -27..-1), else: path

    output =
      UI.progress_bar(completed, total,
        eta: UI.format_eta(eta_ms),
        label: label
      )

    IO.write(:stderr, "\r" <> output)

    if completed == total, do: IO.puts(:stderr, "")
  end
end
