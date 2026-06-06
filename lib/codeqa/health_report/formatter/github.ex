defmodule CodeQA.HealthReport.Formatter.Github do
  @moduledoc "Renders health report as rich GitHub-flavored markdown."

  alias CodeQA.HealthReport.Formatter.AgentActions

  import CodeQA.HealthReport.Formatter.Shared, only: [pr_summary_section: 1]

  @bar_width 20
  @filled "█"
  @empty "░"

  @spec render(map(), atom(), keyword(), atom()) :: String.t()
  def render(report, detail, opts \\ [], view \\ :both) do
    chart? = Keyword.get(opts, :chart, true)
    categories = merge_cosine_categories(report.categories)

    [
      pr_summary_section(Map.get(report, :pr_summary)),
      header(report),
      cosine_legend(),
      delta_section(Map.get(report, :codebase_delta)),
      if(chart?, do: mermaid_chart(categories), else: []),
      progress_bars(categories),
      top_issues_section(Map.get(report, :top_issues, []), detail),
      category_sections(categories, detail),
      actions_section(report, view),
      footer()
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp actions_section(_report, :metrics), do: []
  defp actions_section(report, _view), do: ["", AgentActions.render(report)]

  @doc """
  Renders Part 1: header, summary table, PR summary, delta, mermaid chart, progress bars.
  Each part ends with a sentinel HTML comment for sticky comment identification.
  """
  @spec render_part_1(map(), keyword()) :: String.t()
  def render_part_1(report, opts \\ []) do
    chart? = Keyword.get(opts, :chart, true)
    categories = merge_cosine_categories(report.categories)

    [
      pr_summary_section(Map.get(report, :pr_summary)),
      header(report),
      cosine_legend(),
      delta_section(Map.get(report, :codebase_delta)),
      if(chart?, do: mermaid_chart(categories), else: []),
      progress_bars(categories),
      sentinel(1)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  @doc """
  Renders Part 2: top issues + all category detail sections.
  """
  @spec render_part_2(map(), keyword()) :: String.t()
  def render_part_2(report, opts \\ []) do
    detail = Keyword.get(opts, :detail, :default)
    display_categories = merge_cosine_categories(report.categories)

    [
      top_issues_section(Map.get(report, :top_issues, []), detail),
      category_sections(display_categories, detail),
      sentinel(2)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp sentinel(n), do: ["<!-- codeqa-health-report-#{n} -->"]

  defp merge_cosine_categories(categories) do
    {cosine, threshold} = categories |> Enum.split_with(&(&1.type == :cosine))

    case cosine do
      [] ->
        threshold

      _ ->
        total_impact = cosine |> Enum.map(& &1.impact) |> Enum.sum()

        combined_score =
          round(Enum.sum(cosine |> Enum.map(&(&1.score * &1.impact))) / max(total_impact, 1))

        combined = %{
          categories: cosine,
          grade: grade_letter_from_score(combined_score),
          key: "combined_metrics",
          name: "Combined Metrics",
          score: combined_score,
          type: :cosine_group
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

  defp cosine_legend,
    do: [
      "> *Combined metric scores use cosine similarity: +1 = metric profile perfectly matches healthy pattern for this behavior, 0 = no signal, −1 = anti-pattern detected. Mapped to 0–100 using breakpoints (approx: ≥0.5→A, ≥0.2→B, ≥0.0→C, ≥−0.3→D, <−0.3→F); actual letter grades use the full 15-step scale.*",
      ""
    ]

  defp mermaid_chart(categories) do
    names = categories |> Enum.map_join(", ", fn c -> ~s("#{c.name}") end)
    scores = categories |> Enum.map_join(", ", fn c -> to_string(c.score) end)

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
      categories
      |> Enum.reduce(0, fn cat, acc ->
        max(acc, String.length(cat.name))
      end)

    rows =
      categories
      |> Enum.map(fn cat ->
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

  defp category_sections(categories, detail),
    do: categories |> Enum.flat_map(&render_category(&1, detail))

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
      group.categories
      |> Enum.map(fn cat ->
        emoji = grade_emoji(cat.grade)
        "| #{cat.name} | #{cat.score} | #{emoji} #{cat.grade} |"
      end)

    summary_table = [
      "| Category | Score | Grade |",
      "|----------|-------|-------|"
      | rows
    ]

    sub_sections =
      group.categories
      |> Enum.flat_map(fn cat ->
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
      cat.behaviors
      |> Enum.map(&"| #{&1.behavior} | #{format_num(&1.cosine)} | #{&1.score} | #{&1.grade} |")

    [
      "> Cosine similarity scores for #{n} behaviors.",
      "",
      "| Behavior | Cosine | Score | Grade |",
      "|----------|--------|-------|-------|"
      | behaviors_rows
    ] ++ [""]
  end

  defp section_content(cat, _detail) do
    metric_summary =
      cat.metric_scores |> Enum.map_join(", ", fn m -> "#{m.name}=#{format_num(m.value)}" end)

    metrics_table =
      if cat.metric_scores != [] do
        rows =
          cat.metric_scores
          |> Enum.map(&"| #{&1.source}.#{&1.name} | #{format_num(&1.value)} | #{&1.score} |")

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
      issues
      |> Enum.map_join("\n", fn i ->
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

  defp footer, do: ["<!-- Sticky Pull Request Commentcodeqa-health-report -->", ""]

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
