defmodule CodeQA.HealthReport.Formatter.Github do
  @moduledoc "Renders health report as rich GitHub-flavored markdown."

  @bar_width 20
  @filled "█"
  @empty "░"

  @spec render(map(), atom(), keyword()) :: String.t()
  def render(report, detail, opts \\ []) do
    chart? = Keyword.get(opts, :chart, true)
    display_categories = merge_cosine_categories(report.categories)

    [
      pr_summary_section(Map.get(report, :pr_summary)),
      header(report),
      cosine_legend(),
      delta_section(Map.get(report, :codebase_delta)),
      if(chart?, do: mermaid_chart(display_categories), else: []),
      progress_bars(display_categories),
      top_issues_section(Map.get(report, :top_issues, []), detail),
      blocks_section(Map.get(report, :top_blocks, [])),
      category_sections(display_categories, detail),
      footer()
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp merge_cosine_categories(categories) do
    {cosine, threshold} = Enum.split_with(categories, &(&1.type == :cosine))

    case cosine do
      [] ->
        threshold

      _ ->
        total_impact = Enum.sum(Enum.map(cosine, & &1.impact))

        combined_score =
          round(Enum.sum(Enum.map(cosine, &(&1.score * &1.impact))) / max(total_impact, 1))

        combined = %{
          type: :cosine_group,
          key: "combined_metrics",
          name: "Combined Metrics",
          score: combined_score,
          grade: grade_letter_from_score(combined_score),
          categories: cosine
        }

        threshold ++ [combined]
    end
  end

  defp grade_letter_from_score(score) when score >= 97, do: "A+"
  defp grade_letter_from_score(score) when score >= 93, do: "A"
  defp grade_letter_from_score(score) when score >= 90, do: "A-"
  defp grade_letter_from_score(score) when score >= 87, do: "B+"
  defp grade_letter_from_score(score) when score >= 83, do: "B"
  defp grade_letter_from_score(score) when score >= 80, do: "B-"
  defp grade_letter_from_score(score) when score >= 77, do: "C+"
  defp grade_letter_from_score(score) when score >= 73, do: "C"
  defp grade_letter_from_score(score) when score >= 70, do: "C-"
  defp grade_letter_from_score(score) when score >= 67, do: "D+"
  defp grade_letter_from_score(score) when score >= 63, do: "D"
  defp grade_letter_from_score(score) when score >= 60, do: "D-"
  defp grade_letter_from_score(_score), do: "F"

  defp header(report) do
    emoji = grade_emoji(report.overall_grade)

    [
      "## #{emoji} Code Health: #{report.overall_grade} (#{report.overall_score}/100)",
      "",
      "> #{report.metadata.total_files} files · #{extract_project_name(report.metadata.path)} · #{format_date(report.metadata.timestamp)}",
      ""
    ]
  end

  defp cosine_legend do
    [
      "> *Combined metric scores use cosine similarity: +1 = metric profile perfectly matches healthy pattern for this behavior, 0 = no signal, −1 = anti-pattern detected. Mapped to 0–100 using breakpoints (approx: ≥0.5→A, ≥0.2→B, ≥0.0→C, ≥−0.3→D, <−0.3→F); actual letter grades use the full 15-step scale.*",
      ""
    ]
  end

  defp mermaid_chart(categories) do
    names = Enum.map_join(categories, ", ", fn c -> ~s("#{c.name}") end)
    scores = Enum.map_join(categories, ", ", fn c -> to_string(c.score) end)

    [
      "```mermaid",
      "%%{init: {'theme': 'neutral'}}%%",
      "xychart-beta",
      "    title \"Code Health Scores\"",
      "    x-axis [#{names}]",
      "    y-axis \"Score\" 0 --> 100",
      "    bar [#{scores}]",
      "```",
      ""
    ]
  end

  defp progress_bars(categories) do
    max_name_len =
      Enum.reduce(categories, 0, fn cat, acc ->
        max(acc, String.length(cat.name))
      end)

    rows =
      Enum.map(categories, fn cat ->
        name = String.pad_trailing(cat.name, max_name_len)
        bar = build_bar(cat.score)
        score_str = cat.score |> to_string() |> String.pad_leading(3)
        emoji = grade_emoji(cat.grade)
        "#{name}  #{bar}  #{score_str}  #{emoji} #{cat.grade}"
      end)

    ["```"] ++ rows ++ ["```", ""]
  end

  defp build_bar(score) do
    filled = round(score / 100 * @bar_width)
    filled = min(max(filled, 0), @bar_width)
    empty = @bar_width - filled

    String.duplicate(@filled, filled) <> String.duplicate(@empty, empty)
  end

  defp category_sections(_categories, :summary), do: []

  defp category_sections(categories, detail) do
    Enum.flat_map(categories, &render_category(&1, detail))
  end

  defp render_category(%{type: :cosine_group} = group, detail) do
    emoji = grade_emoji(group.grade)
    summary_line = "#{emoji} #{group.name} — #{group.grade} (#{group.score}/100)"

    inner =
      cosine_group_content(group, detail)
      |> List.flatten()
      |> Enum.join("\n")

    [
      "<details>",
      "<summary><strong>#{summary_line}</strong></summary>",
      "",
      inner,
      "",
      "</details>",
      ""
    ]
  end

  defp render_category(%{type: :cosine} = cat, detail) do
    emoji = grade_emoji(cat.grade)
    summary_line = "#{emoji} #{cat.name} — #{cat.grade} (#{cat.score}/100)"

    inner =
      cosine_section_content(cat, detail)
      |> List.flatten()
      |> Enum.join("\n")

    [
      "<details>",
      "<summary><strong>#{summary_line}</strong></summary>",
      "",
      inner,
      "",
      "</details>",
      ""
    ]
  end

  defp render_category(cat, detail) do
    emoji = grade_emoji(cat.grade)
    summary_line = "#{emoji} #{cat.name} — #{cat.grade} (#{cat.score}/100)"

    inner =
      section_content(cat, detail)
      |> List.flatten()
      |> Enum.join("\n")

    [
      "<details>",
      "<summary><strong>#{summary_line}</strong></summary>",
      "",
      inner,
      "",
      "</details>",
      ""
    ]
  end

  defp cosine_group_content(group, detail) do
    rows =
      Enum.map(group.categories, fn cat ->
        emoji = grade_emoji(cat.grade)
        "| #{cat.name} | #{cat.score} | #{emoji} #{cat.grade} |"
      end)

    summary_table = [
      "| Category | Score | Grade |",
      "|----------|-------|-------|"
      | rows
    ]

    sub_sections =
      Enum.flat_map(group.categories, fn cat ->
        emoji = grade_emoji(cat.grade)

        inner =
          cosine_section_content(cat, detail)
          |> List.flatten()
          |> Enum.join("\n")

        [
          "<details>",
          "<summary><strong>#{emoji} #{cat.name} — #{cat.grade} (#{cat.score}/100)</strong></summary>",
          "",
          inner,
          "",
          "</details>",
          ""
        ]
      end)

    summary_table ++ [""] ++ sub_sections
  end

  defp cosine_section_content(cat, _detail) do
    n = length(cat.behaviors)

    behaviors_rows =
      Enum.map(cat.behaviors, fn b ->
        "| #{b.behavior} | #{format_num(b.cosine)} | #{b.score} | #{b.grade} |"
      end)

    behaviors_table = [
      "> Cosine similarity scores for #{n} behaviors.",
      "",
      "| Behavior | Cosine | Score | Grade |",
      "|----------|--------|-------|-------|"
      | behaviors_rows
    ]

    behaviors_table ++ [""]
  end

  defp section_content(cat, _detail) do
    metric_summary =
      Enum.map_join(cat.metric_scores, ", ", fn m -> "#{m.name}=#{format_num(m.value)}" end)

    metrics_table =
      if cat.metric_scores != [] do
        rows =
          Enum.map(cat.metric_scores, fn m ->
            "| #{m.source}.#{m.name} | #{format_num(m.value)} | #{m.score} |"
          end)

        [
          "| Metric | Value | Score |",
          "|--------|-------|-------|"
          | rows
        ]
      else
        []
      end

    [
      "Codebase averages: #{metric_summary}",
      ""
      | metrics_table
    ] ++ [""]
  end

  defp top_issues_section([], _detail), do: []
  defp top_issues_section(_issues, :summary), do: []

  defp top_issues_section(issues, _detail) do
    rows =
      Enum.map_join(issues, "\n", fn i ->
        "| `#{i.category}.#{i.behavior}` | #{format_num(i.cosine)} | #{format_num(i.score)} |"
      end)

    table = "| Behavior | Cosine | Score |\n|----------|--------|-------|\n#{rows}"

    [
      "<details>",
      "<summary><strong>🔍 Top Likely Issues (cosine similarity)</strong></summary>",
      "",
      "> Most negative cosine = file's metric profile best matches this anti-pattern.",
      "",
      table,
      "",
      "</details>",
      ""
    ]
  end

  defp footer do
    ["<!-- Sticky Pull Request Commentcodeqa-health-report -->", ""]
  end

  @doc false
  def grade_emoji(grade) do
    cond do
      grade in ["A", "A-"] -> "🟢"
      grade in ["B+", "B", "B-"] -> "🟡"
      grade in ["C+", "C", "C-"] -> "🟠"
      true -> "🔴"
    end
  end

  defp extract_project_name(path) when is_binary(path) do
    Path.basename(path)
  end

  defp extract_project_name(_), do: "unknown"

  defp format_num(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp format_num(value) when is_integer(value), do: to_string(value)
  defp format_num(value), do: to_string(value)

  defp format_date(timestamp) when is_binary(timestamp), do: String.slice(timestamp, 0, 10)
  defp format_date(_), do: "unknown"

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

  defp blocks_section([]), do: []

  defp blocks_section(top_blocks) do
    total = Enum.sum(Enum.map(top_blocks, fn g -> length(g.blocks) end))

    file_cards =
      Enum.flat_map(top_blocks, fn group ->
        status_str = if group.status, do: " [#{group.status}]", else: ""
        summary_line = "🔍 #{group.path}#{status_str} — #{length(group.blocks)} block(s)"

        inner =
          group.blocks |> Enum.flat_map(&format_block/1) |> List.flatten() |> Enum.join("\n")

        [
          "<details>",
          "<summary>#{summary_line}</summary>",
          "",
          inner,
          "</details>",
          ""
        ]
      end)

    [
      "## 🔍 Blocks  (#{total} flagged across #{length(top_blocks)} files)",
      ""
      | file_cards
    ]
  end

  defp format_block(block) do
    end_line = block.end_line || block.start_line

    header =
      "**lines #{block.start_line}–#{end_line}** · #{block.type} · #{block.token_count} tokens"

    potential_lines = Enum.flat_map(block.potentials, &format_potential/1)
    [header] ++ potential_lines ++ [""]
  end

  defp format_potential(p) do
    icon = severity_icon(p.severity)
    delta_str = format_num(p.cosine_delta)
    label = String.upcase(to_string(p.severity))
    line = "**#{icon} #{label}** `#{p.category}/#{p.behavior}` (Δ #{delta_str})"
    fix = if p.fix_hint, do: ["> #{p.fix_hint}"], else: []
    [line | fix]
  end

  defp severity_icon(:critical), do: "🔴"
  defp severity_icon(:high), do: "🟠"
  defp severity_icon(:medium), do: "🟡"
  defp severity_icon(_), do: "⚪"
end
