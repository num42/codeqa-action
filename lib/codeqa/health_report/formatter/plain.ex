defmodule CodeQA.HealthReport.Formatter.Plain do
  @moduledoc "Renders health report as plain markdown."

  alias CodeQA.HealthReport.Formatter.AgentActions

  import CodeQA.HealthReport.Formatter.Shared, only: [pr_summary_section: 1]

  @spec render(map(), atom(), atom()) :: String.t()
  def render(report, detail, view \\ :both) do
    [metrics_sections(report, detail), actions_section(report, view)]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp metrics_sections(report, detail),
    do: [
      pr_summary_section(Map.get(report, :pr_summary)),
      header(report),
      cosine_legend(),
      delta_section(Map.get(report, :codebase_delta)),
      overall_table(report),
      top_issues_section(Map.get(report, :top_issues, []), detail),
      category_sections(report.categories, detail)
    ]

  defp actions_section(_report, :metrics), do: []
  defp actions_section(report, _view), do: ["", AgentActions.render(report)]

  defp header(report),
    do: [
      "# Code Health Report",
      "",
      "> #{report.metadata.path} — #{format_date(report.metadata.timestamp)} — #{report.metadata.total_files} files analyzed",
      "",
      "## Overall: #{report.overall_grade}",
      ""
    ]

  defp cosine_legend,
    do: [
      "> *Combined metric scores use cosine similarity: +1 = metric profile perfectly matches healthy pattern for this behavior, 0 = no signal, −1 = anti-pattern detected. Mapped to 0–100 using breakpoints (approx: ≥0.5→A, ≥0.2→B, ≥0.0→C, ≥−0.3→D, <−0.3→F); actual letter grades use the full 15-step scale.*",
      ""
    ]

  defp overall_table(report) do
    rows =
      report.categories
      |> Enum.map(fn cat ->
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

  defp category_sections(categories, detail),
    do:
      categories
      |> Enum.flat_map(
        &render_category(
          &1,
          detail
        )
      )

  defp render_category(%{type: :cosine} = cat, _detail),
    do: cosine_section_header(cat) ++ cosine_behaviors_table(cat)

  defp render_category(cat, _detail), do: section_header(cat) ++ metric_detail(cat)

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
      cat.behaviors
      |> Enum.map(&"| #{&1.behavior} | #{format_num(&1.cosine)} | #{&1.score} | #{&1.grade} |")

    [
      "| Behavior | Cosine | Score | Grade |",
      "|----------|--------|-------|-------|"
      | rows
    ] ++ [""]
  end

  defp section_header(cat) do
    metric_summary =
      cat.metric_scores |> Enum.map_join(", ", fn m -> "#{m.name}=#{format_num(m.value)}" end)

    [
      "## #{cat.name} — #{cat.grade}",
      "",
      "Codebase averages: #{metric_summary}",
      ""
    ]
  end

  defp metric_detail(cat) do
    rows =
      cat.metric_scores
      |> Enum.map(&"| #{&1.source}.#{&1.name} | #{format_num(&1.value)} | #{&1.score} |")

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
      issues
      |> Enum.map(
        &"| #{&1.category}.#{&1.behavior} | #{format_num(&1.cosine)} | #{format_num(&1.score)} |"
      )

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

    rows = metrics |> Enum.flat_map(&format_metric_row(&1, base_agg, head_agg))

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
    base_value = get_in(base_agg, [group, key])
    head_value = get_in(head_agg, [group, key])

    if is_number(base_value) and is_number(head_value) do
      diff = Float.round(head_value - base_value, 2)
      diff_str = if diff >= 0, do: "+#{format_num(diff)}", else: "#{format_num(diff)}"
      ["| #{label} | #{format_num(base_value)} | #{format_num(head_value)} | #{diff_str} |"]
    else
      []
    end
  end
end
