defmodule CodeQA.CLI.UI do
  @moduledoc "Beautiful CLI components using Unicode and ANSI."

  def progress_bar(completed, total, opts \\ []) do
    width = opts[:width] || 30
    label = opts[:label] || ""
    eta = opts[:eta] || ""

    percent = if total > 0, do: completed / total, else: 1.0
    filled = round(percent * width)
    empty = width - filled

    # Using Unicode block characters for a smooth bar
    # Full block: █, Empty: ░ or space
    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)

    pct_str = (percent * 100) |> round() |> Integer.to_string() |> String.pad_leading(3)
    counts = "(#{completed}/#{total})" |> String.pad_trailing(12)

    # On completion, we hide the label (e.g. filename) to leave a clean final state
    label_to_show =
      if completed == total and Keyword.get(opts, :clear_label_on_done, true), do: "", else: label

    eta_str = if eta != "", do: " | ETA: #{String.pad_trailing(eta, 6)}", else: ""
    label_str = if label_to_show != "", do: " | #{label_to_show}", else: ""

    "  #{pct_str}% [#{bar}] #{counts}#{eta_str}#{label_str}"
    # Pad trailing to wipe out any leftover characters from previous longer lines
    |> String.pad_trailing(120)
  end

  def format_eta(ms) do
    cond do
      ms < 1000 -> "0s"
      ms < 60_000 -> "#{div(ms, 1000)}s"
      true -> "#{div(ms, 60_000)}m #{div(rem(ms, 60_000), 1000)}s"
    end
  end
end
