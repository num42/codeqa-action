defmodule CodeQA.HealthReport.Formatter.Github do
  @moduledoc "Renders health report as rich GitHub-flavored markdown."

  @bar_width 20
  @filled "█"
  @empty "░"

  @spec render(map(), atom(), keyword()) :: String.t()
  def render(report, detail, opts \\ []) do
    chart? = Keyword.get(opts, :chart, true)

    [
      header(report),
      if(chart?, do: mermaid_chart(report.categories), else: []),
      progress_bars(report.categories),
      category_sections(report.categories, detail),
      footer()
    ]
    |> List.flatten()
    |> Enum.join("\n")
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
    Enum.flat_map(categories, fn cat ->
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
      rows =
        Enum.map(offenders, fn f ->
          issues =
            f.metric_scores
            |> Enum.map(fn m -> "#{m.name}=#{format_num(m.value)}" end)
            |> Enum.join(", ")

          "| `#{f.path}` | #{f.grade} | #{f.score} | #{format_lines(f[:lines])} | #{format_size(f[:bytes])} | #{issues} |"
        end)

      [
        "**Worst Offenders**",
        "",
        "| File | Grade | Score | Lines | Size | Issues |",
        "|------|-------|-------|-------|------|--------|"
        | rows
      ]
    end
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
