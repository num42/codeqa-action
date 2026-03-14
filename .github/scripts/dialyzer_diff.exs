#!/usr/bin/env elixir

# Compares two dialyzer short-format output files and fails if new warnings
# were introduced.
#
# Usage: elixir dialyzer_diff.exs <base_file> <head_file>
#
# Short format line: "file:line:col:warning_name message"
# We normalize by stripping line:col so that moved code doesn't cause false positives.

defmodule DialyzerDiff do
  @marker "<!-- dialyzer-diff-comment -->"

  def run([base_path, head_path | rest]) do
    summary_path = List.first(rest)
    base_warnings = parse(base_path)
    head_warnings = parse(head_path)

    new_warnings = multiset_diff(head_warnings, base_warnings)
    fixed_warnings = multiset_diff(base_warnings, head_warnings)

    IO.puts("Dialyzer diff: #{length(base_warnings)} base, #{length(head_warnings)} head")
    IO.puts("  Fixed: #{length(fixed_warnings)}")
    IO.puts("  New:   #{length(new_warnings)}")

    if fixed_warnings != [] do
      IO.puts("\nFixed warnings:")

      Enum.each(fixed_warnings, fn w -> IO.puts("  - #{w}") end)
    end

    if new_warnings != [] do
      IO.puts("\nNew warnings:")

      Enum.each(new_warnings, fn w -> IO.puts("  ::error::#{w}") end)
    else
      IO.puts("\nNo new dialyzer warnings introduced.")
    end

    if summary_path do
      markdown = build_markdown(base_warnings, head_warnings, new_warnings, fixed_warnings)
      File.write!(summary_path, markdown)
    end

    if new_warnings != [], do: System.halt(1)
  end

  def run(_) do
    IO.puts("Usage: elixir dialyzer_diff.exs <base_file> <head_file> [summary_output_path]")
    System.halt(2)
  end

  defp build_markdown(base_warnings, head_warnings, new_warnings, fixed_warnings) do
    status = if new_warnings == [], do: ":white_check_mark:", else: ":x:"

    lines = [
      @marker,
      "## #{status} Dialyzer Diff",
      "",
      "| | Count |",
      "|---|---:|",
      "| Base warnings | #{length(base_warnings)} |",
      "| Head warnings | #{length(head_warnings)} |",
      "| New | #{length(new_warnings)} |",
      "| Fixed | #{length(fixed_warnings)} |"
    ]

    lines =
      if new_warnings != [] do
        lines ++
          [
            "",
            "### New warnings",
            "",
            Enum.map_join(new_warnings, "\n", &"- `#{&1}`")
          ]
      else
        lines
      end

    lines =
      if fixed_warnings != [] do
        lines ++
          [
            "",
            "### Fixed warnings",
            "",
            Enum.map_join(fixed_warnings, "\n", &"- `#{&1}`")
          ]
      else
        lines
      end

    Enum.join(lines, "\n") <> "\n"
  end

  # Parse short-format lines, normalize by stripping line:col
  defp parse(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.filter(&dialyzer_warning?/1)
    |> Enum.map(&normalize/1)
  end

  # Short format: "lib/foo.ex:10:5:warning_name The message"
  # Normalize to: "lib/foo.ex:warning_name The message"
  defp normalize(line) do
    case Regex.run(~r/^(.+?):(\d+):(\d+:)?(\w+ .+)$/, line) do
      [_, file, _line, _col, rest] -> "#{file}:#{rest}"
      _ -> line
    end
  end

  defp dialyzer_warning?(line) do
    Regex.match?(~r/^lib\/.*:\d+:/, line)
  end

  # Multiset difference: elements in a not in b (respecting counts)
  defp multiset_diff(a, b) do
    b_counts = Enum.frequencies(b)

    {result, _} =
      Enum.reduce(a, {[], b_counts}, fn item, {acc, counts} ->
        case Map.get(counts, item, 0) do
          0 -> {[item | acc], counts}
          n -> {acc, Map.put(counts, item, n - 1)}
        end
      end)

    Enum.reverse(result)
  end
end

DialyzerDiff.run(System.argv())
