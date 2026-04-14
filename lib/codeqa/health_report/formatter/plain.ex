defmodule CodeQA.HealthReport.Formatter.Plain do
  @moduledoc "Renders health report as plain markdown."

  @spec render(map(), atom()) :: String.t()
  def render(report, detail) do
    [
      pr_summary_section(Map.get(report, :pr_summary)),
      header(report),
      cosine_legend(),
      delta_section(Map.get(report, :codebase_delta)),
      overall_table(report),
      top_issues_section(Map.get(report, :top_issues, []), detail),
      blocks_section(Map.get(report, :top_blocks, [])),
      category_sections(report.categories, detail)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp header(report) do
    [
      "# Code Health Report",
      "",
      "> #{report.metadata.path} — #{format_date(report.metadata.timestamp)} — #{report.metadata.total_files} files analyzed",
      "",
      "## Overall: #{report.overall_grade}",
      ""
    ]
  end

  defp cosine_legend do
    [
      "> *Combined metric scores use cosine similarity: +1 = metric profile perfectly matches healthy pattern for this behavior, 0 = no signal, −1 = anti-pattern detected. Mapped to 0–100 using breakpoints (approx: ≥0.5→A, ≥0.2→B, ≥0.0→C, ≥−0.3→D, <−0.3→F); actual letter grades use the full 15-step scale.*",
      ""
    ]
  end

  defp overall_table(report) do
    rows =
      Enum.map(report.categories, fn cat ->
        summary = Map.get(cat, :summary, "")
        impact = Map.get(cat, :impact, "")
        "| #{cat.name} | #{cat.grade} | #{cat.score} | #{impact} | #{summary} |"
      end)

    [
      "| Category | Grade | Score | Impact | Summary |",
      "|----------|-------|-------|--------|---------|"
      | rows
    ] ++ [""]
  end

  defp category_sections(_categories, :summary), do: []

  defp category_sections(categories, detail) do
    Enum.flat_map(categories, fn cat ->
      render_category(cat, detail)
    end)
  end

  defp render_category(%{type: :cosine} = cat, _detail) do
    cosine_section_header(cat) ++ cosine_behaviors_table(cat)
  end

  defp render_category(cat, _detail) do
    section_header(cat) ++ metric_detail(cat)
  end

  defp cosine_section_header(cat) do
    n = length(cat.behaviors)

    [
      "## #{cat.name} — #{cat.grade}",
      "",
      "> Cosine similarity scores for #{n} behaviors.",
      ""
    ]
  end

  defp cosine_behaviors_table(cat) do
    rows =
      Enum.map(cat.behaviors, fn b ->
        "| #{b.behavior} | #{format_num(b.cosine)} | #{b.score} | #{b.grade} |"
      end)

    [
      "| Behavior | Cosine | Score | Grade |",
      "|----------|--------|-------|-------|"
      | rows
    ] ++ [""]
  end

  defp section_header(cat) do
    metric_summary =
      Enum.map_join(cat.metric_scores, ", ", fn m -> "#{m.name}=#{format_num(m.value)}" end)

    [
      "## #{cat.name} — #{cat.grade}",
      "",
      "Codebase averages: #{metric_summary}",
      ""
    ]
  end

  defp metric_detail(cat) do
    rows =
      Enum.map(cat.metric_scores, fn m ->
        "| #{m.source}.#{m.name} | #{format_num(m.value)} | #{m.score} |"
      end)

    if rows == [] do
      []
    else
      [
        "| Metric | Value | Score |",
        "|--------|-------|-------|"
        | rows
      ] ++ [""]
    end
  end

  defp format_num(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp format_num(value) when is_integer(value), do: to_string(value)
  defp format_num(value), do: to_string(value)

  defp format_date(timestamp) when is_binary(timestamp) do
    timestamp |> String.slice(0, 10)
  end

  defp format_date(_), do: "unknown"

  defp top_issues_section([], _detail), do: []
  defp top_issues_section(_issues, :summary), do: []

  defp top_issues_section(issues, _detail) do
    rows =
      Enum.map(issues, fn i ->
        "| #{i.category}.#{i.behavior} | #{format_num(i.cosine)} | #{format_num(i.score)} |"
      end)

    [
      "## Top Likely Issues",
      "",
      "> Ranked by cosine similarity — most negative means the file's metric profile best matches this anti-pattern.",
      "",
      "| Behavior | Cosine | Score |",
      "|----------|--------|-------|"
      | rows
    ] ++ [""]
  end

  defp pr_summary_section(nil), do: []

  defp pr_summary_section(summary) do
    delta_str =
      if summary.score_delta >= 0,
        do: "+#{summary.score_delta}",
        else: "#{summary.score_delta}"

    status_str = "#{summary.files_modified} modified, #{summary.files_added} added"

    [
      "> **Score:** #{summary.base_grade} → #{summary.head_grade}  |  **Δ** #{delta_str} pts  |  **#{summary.blocks_flagged}** blocks flagged across #{summary.files_changed} files  |  #{status_str}",
      ""
    ]
  end

  defp delta_section(nil), do: []

  defp delta_section(delta) do
    base_agg = delta.base.aggregate
    head_agg = delta.head.aggregate

    metrics = [
      {"Readability", "readability", "mean_flesch_adapted"},
      {"Complexity", "halstead", "mean_difficulty"},
      {"Duplication", "compression", "mean_redundancy"},
      {"Structure", "branching", "mean_branch_count"}
    ]

    rows = Enum.flat_map(metrics, &format_metric_row(&1, base_agg, head_agg))

    if rows == [] do
      []
    else
      [
        "## Metric Changes",
        "",
        "| Category | Base | Head | Δ |",
        "|----------|------|------|---|"
        | rows
      ] ++ [""]
    end
  end

  defp format_metric_row({label, group, key}, base_agg, head_agg) do
    base_val = get_in(base_agg, [group, key])
    head_val = get_in(head_agg, [group, key])

    if is_number(base_val) and is_number(head_val) do
      diff = Float.round(head_val - base_val, 2)
      diff_str = if diff >= 0, do: "+#{format_num(diff)}", else: "#{format_num(diff)}"
      ["| #{label} | #{format_num(base_val)} | #{format_num(head_val)} | #{diff_str} |"]
    else
      []
    end
  end

  defp blocks_section([]), do: ["## Code Blocks: 🟢 No block-level issues detected", ""]

  defp blocks_section(top_blocks) do
    alias CodeQA.HealthReport.BehaviorLabels

    severity_counts = count_severities(top_blocks)
    worst = worst_severity(severity_counts)
    {icon, verdict} = verdict_text(worst, severity_counts)

    {actionable, medium_blocks} =
      Enum.split_with(top_blocks, fn b ->
        top = List.first(b.potentials)
        top && top.severity in [:critical, :high]
      end)

    header = ["## Code Blocks: #{icon} #{verdict}", ""]

    action_table =
      if actionable != [] do
        rows =
          Enum.map(actionable, fn block ->
            top = List.first(block.potentials)
            label = BehaviorLabels.label(top.category, top.behavior)
            location = "#{block.path}:#{block.start_line}-#{block.end_line || block.start_line}"
            action = BehaviorLabels.action(top.category, top.behavior)
            "| #{label} | #{location} | #{action} |"
          end)

        [
          "| What | Where | Action |",
          "|------|-------|--------|"
          | rows
        ] ++ [""]
      else
        []
      end

    block_details = Enum.flat_map(actionable ++ medium_blocks, &format_block/1)

    header ++ action_table ++ block_details
  end

  defp count_severities(blocks) do
    blocks
    |> Enum.map(fn b -> (List.first(b.potentials) || %{severity: :medium}).severity end)
    |> Enum.frequencies()
  end

  defp worst_severity(counts) do
    cond do
      Map.get(counts, :critical, 0) > 0 -> :critical
      Map.get(counts, :high, 0) > 0 -> :high
      Map.get(counts, :medium, 0) > 0 -> :medium
      true -> :none
    end
  end

  defp verdict_text(:critical, counts) do
    n = Map.get(counts, :critical, 0)
    {"🔴", "#{n} critical #{pl(n, "block")} — review required before merge"}
  end

  defp verdict_text(:high, counts) do
    n = Map.get(counts, :high, 0) + Map.get(counts, :critical, 0)
    {"🟠", "#{n} #{pl(n, "block")} need attention before merge"}
  end

  defp verdict_text(:medium, counts) do
    n = Map.get(counts, :medium, 0)
    {"🟡", "#{n} #{pl(n, "block")} with minor issues (safe to merge)"}
  end

  defp verdict_text(:none, _), do: {"🟢", "No block-level issues detected"}

  defp pl(1, word), do: word
  defp pl(_, word), do: word <> "s"

  defp format_block(block) do
    end_line = block.end_line || block.start_line
    status_str = if block.status, do: " [#{block.status}]", else: ""

    header =
      "### #{block.path}:#{block.start_line}-#{end_line}#{status_str}"

    subheader =
      "#{block.type} · #{block.token_count} tokens"

    potential_lines = Enum.flat_map(block.potentials, &format_potential/1)
    code_lines = format_code_block(block)
    [header, subheader, "" | potential_lines] ++ ["" | code_lines] ++ [""]
  end

  defp format_code_block(%{source: nil}), do: ["_Source code not available_"]

  defp format_code_block(%{source: source, start_line: start_line}) do
    lines = String.split(source, "\n")

    numbered_lines =
      lines
      |> Enum.with_index(start_line)
      |> Enum.map(fn {line, num} -> "  #{String.pad_leading(to_string(num), 4)} │ #{line}" end)

    ["```" | numbered_lines] ++ ["```"]
  end

  defp format_potential(p) do
    icon = severity_icon(p.severity)
    delta_str = format_num(p.cosine_delta)
    label = String.upcase(to_string(p.severity))
    line = "  #{icon} #{label}  #{p.category} / #{p.behavior}  (Δ #{delta_str})"
    fix = if p.fix_hint, do: ["    → #{p.fix_hint}"], else: []
    [line | fix]
  end

  defp severity_icon(:critical), do: "🔴"
  defp severity_icon(:high), do: "🟠"
  defp severity_icon(:medium), do: "🟡"
  defp severity_icon(_), do: "⚪"
end
