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
      header(report),
      cosine_legend(),
      if(chart?, do: mermaid_chart(display_categories), else: []),
      progress_bars(display_categories),
      top_issues_section(Map.get(report, :top_issues, []), detail),
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
          round(
            Enum.sum(Enum.map(cosine, &(&1.score * &1.impact))) / max(total_impact, 1)
          )

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

  defp grade_letter_from_score(score) do
    cond do
      score >= 97 -> "A+"
      score >= 93 -> "A"
      score >= 90 -> "A-"
      score >= 87 -> "B+"
      score >= 83 -> "B"
      score >= 80 -> "B-"
      score >= 77 -> "C+"
      score >= 73 -> "C"
      score >= 70 -> "C-"
      score >= 67 -> "D+"
      score >= 63 -> "D"
      score >= 60 -> "D-"
      true -> "F"
    end
  end

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
    names = Enum.map(categories, fn c -> ~s("#{c.name}") end) |> Enum.join(", ")
    scores = Enum.map(categories, fn c -> to_string(c.score) end) |> Enum.join(", ")

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
          "<summary>#{emoji} #{cat.name} — #{cat.grade} (#{cat.score}/100)</summary>",
          "",
          inner,
          "",
          "</details>",
          ""
        ]
      end)

    summary_table ++ [""] ++ sub_sections
  end

  defp cosine_section_content(cat, detail) do
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

    offenders_sections = cosine_worst_offenders(cat, detail)

    behaviors_table ++ [""] ++ offenders_sections
  end

  defp cosine_worst_offenders(_cat, :summary), do: []

  defp cosine_worst_offenders(cat, _detail) do
    Enum.flat_map(cat.behaviors, fn b ->
      offenders = Map.get(b, :worst_offenders, [])

      if offenders == [] do
        []
      else
        rows =
          Enum.map(offenders, fn f ->
            "| #{format_path(f.file)} | #{format_num(f.cosine)} |"
          end)

        [
          "**Worst Offenders: #{b.behavior}**",
          "",
          "| File | Cosine |",
          "|------|--------|"
          | rows
        ] ++ [""]
      end
    end)
  end

  defp section_content(cat, _detail) do
    metric_summary =
      cat.metric_scores
      |> Enum.map(fn m -> "#{m.name}=#{format_num(m.value)}" end)
      |> Enum.join(", ")

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
    ] ++ [""] ++ worst_offenders(cat)
  end

  defp worst_offenders(cat) do
    offenders = Map.get(cat, :worst_offenders, [])

    if offenders == [] do
      []
    else
      averages = Map.new(cat.metric_scores, &{&1.name, &1.value})

      rows =
        Enum.map(offenders, fn f ->
          issues =
            f.metric_scores
            |> Enum.map(fn m ->
              avg = Map.get(averages, m.name)
              avg_str = if avg, do: " (avg: #{format_num(avg)})", else: ""
              "#{direction(m.good)}#{m.name}=#{format_num(m.value)}#{avg_str}"
            end)
            |> Enum.join("<br>")

          "| #{format_path(f.path)}<br>#{format_lines(f[:lines])} lines · #{format_size(f[:bytes])} | #{f.grade} (#{f.score}) | #{issues} |"
        end)

      [
        "**Worst Offenders**",
        "",
        "| File | Grade | Issues |",
        "|------|-------|--------|"
        | rows
      ]
    end
  end

  defp top_issues_section([], _detail), do: []
  defp top_issues_section(_issues, :summary), do: []

  defp top_issues_section(issues, _detail) do
    rows =
      issues
      |> Enum.map(fn i ->
        "| `#{i.category}.#{i.behavior}` | #{format_num(i.cosine)} | #{format_num(i.score)} |"
      end)
      |> Enum.join("\n")

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

  defp format_path(path) when byte_size(path) < 80, do: "`#{path}`"

  defp format_path(path) do
    case String.split(path, "/") do
      [file] -> "`#{file}`"
      parts -> Enum.join(Enum.drop(parts, -1), "/") <> "/<br>`#{List.last(parts)}`"
    end
  end

  defp direction(:high), do: "↑ "
  defp direction(_), do: "↓ "

  defp format_lines(nil), do: "—"
  defp format_lines(n), do: to_string(n)

  defp format_size(nil), do: "—"
  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_num(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp format_num(value) when is_integer(value), do: to_string(value)
  defp format_num(value), do: to_string(value)

  defp format_date(timestamp) when is_binary(timestamp), do: String.slice(timestamp, 0, 10)
  defp format_date(_), do: "unknown"
end
