defmodule CodeQA.HealthReport.Formatter.AgentActions do
  @moduledoc """
  Renders the top blocks as an agent-consumable refactoring prompt.

  Output is a single Markdown document with a YAML frontmatter block, optimized
  to be piped directly into an AI coding agent. Only blocks whose top potential
  is `:critical` or `:high` become tasks — `:medium` is dropped.
  """

  alias CodeQA.HealthReport.BehaviorLabels

  @severity_rank %{critical: 0, high: 1}

  @spec render(map()) :: String.t()
  def render(report) do
    tasks = actionable_tasks(Map.get(report, :top_blocks, []))

    [frontmatter(report, tasks), "", body(tasks)]
    |> Enum.join("\n")
  end

  # Ordered critical-first to match the frontmatter instruction; cosine_delta
  # (the incoming order) breaks ties within a severity.
  defp actionable_tasks(top_blocks) do
    top_blocks
    |> Enum.filter(&actionable?/1)
    |> Enum.sort_by(&@severity_rank[top_severity(&1)])
    |> Enum.with_index(1)
  end

  defp actionable?(block), do: Map.has_key?(@severity_rank, top_severity(block))

  defp top_severity(block) do
    case List.first(block.potentials) do
      %{severity: severity} -> severity
      _ -> nil
    end
  end

  defp frontmatter(report, tasks) do
    meta = Map.get(report, :metadata, %{})
    counts = severity_counts(tasks)

    [
      "---",
      "kind: refactoring-tasks",
      kv("path", meta[:path]),
      kv("timestamp", meta[:timestamp]),
      kv("overall_grade", Map.get(report, :overall_grade)),
      kv("overall_score", Map.get(report, :overall_score)),
      "task_count: #{length(tasks)}",
      "critical: #{Map.get(counts, :critical, 0)}",
      "high: #{Map.get(counts, :high, 0)}",
      "instructions: >-",
      "  Address the tasks below in order of severity (critical first).",
      "  After each fix, run the project's test suite and confirm it passes",
      "  before moving on.",
      "---"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp kv(_key, nil), do: nil
  defp kv(key, value), do: "#{key}: #{value}"

  defp severity_counts(tasks) do
    tasks
    |> Enum.map(fn {block, _} -> top_severity(block) end)
    |> Enum.frequencies()
  end

  defp body([]), do: "No critical or high-severity blocks need attention. ✅"

  defp body(tasks) do
    ["# Refactoring Tasks", "" | Enum.flat_map(tasks, &task/1)]
    |> Enum.join("\n")
  end

  defp task({block, index}) do
    top = List.first(block.potentials)
    label = BehaviorLabels.label(top.category, top.behavior)
    action = top.fix_hint || BehaviorLabels.action(top.category, top.behavior)

    [
      "## #{index}. #{location(block)} — #{label}",
      "",
      "**Severity:** #{top.severity} · `#{top.category}/#{top.behavior}`",
      "",
      action,
      "" | source_block(block)
    ] ++ [""]
  end

  defp location(block),
    do: "#{block.path}:#{block.start_line}-#{block.end_line || block.start_line}"

  defp source_block(%{source: nil}), do: ["_Source code not available._"]

  defp source_block(%{source: source} = block) do
    ["```#{block.language || ""}", source, "```"]
  end
end
