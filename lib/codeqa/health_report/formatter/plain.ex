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

    rows =
      Enum.flat_map(metrics, fn {label, group, key} ->
        base_val = get_in(base_agg, [group, key])
        head_val = get_in(head_agg, [group, key])

        if is_number(base_val) and is_number(head_val) do
          diff = Float.round(head_val - base_val, 2)
          diff_str = if diff >= 0, do: "+#{format_num(diff)}", else: "#{format_num(diff)}"
          ["| #{label} | #{format_num(base_val)} | #{format_num(head_val)} | #{diff_str} |"]
        else
          []
        end
      end)

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

  defp blocks_section([]), do: []

  defp blocks_section(top_blocks) do
    total = Enum.sum(Enum.map(top_blocks, fn g -> length(g.blocks) end))

    file_parts =
      Enum.flat_map(top_blocks, fn group ->
        status_str = if group.status, do: "  [#{group.status}]", else: ""

        block_lines =
          Enum.flat_map(group.blocks, fn block ->
            end_line = block.end_line || block.start_line

            header =
              "**lines #{block.start_line}–#{end_line}** · #{block.type} · #{block.token_count} tokens"

            potential_lines =
              Enum.flat_map(block.potentials, fn p ->
                icon = severity_icon(p.severity)
                delta_str = format_num(p.cosine_delta)
                label = "#{String.upcase(to_string(p.severity))}"
                line = "  #{icon} #{label}  #{p.category} / #{p.behavior}  (Δ #{delta_str})"
                fix = if p.fix_hint, do: ["    → #{p.fix_hint}"], else: []
                [line | fix]
              end)

            [header | potential_lines] ++ [""]
          end)

        ["### #{group.path}#{status_str}", "" | block_lines]
      end)

    [
      "## Blocks  (#{total} flagged across #{length(top_blocks)} files)",
      ""
      | file_parts
    ]
  end

  defp severity_icon(:critical), do: "🔴"
  defp severity_icon(:high), do: "🟠"
  defp severity_icon(:medium), do: "🟡"
end
