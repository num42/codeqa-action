defmodule CodeQA.HealthReport.Formatter.Plain do
  @moduledoc "Renders health report as plain markdown."

  @spec render(map(), atom()) :: String.t()
  def render(report, detail) do
    [
      header(report),
      overall_table(report),
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

  defp overall_table(report) do
    rows =
      Enum.map(report.categories, fn cat ->
        summary = Map.get(cat, :summary, "")
        "| #{cat.name} | #{cat.grade} | #{cat.score} | #{summary} |"
      end)

    [
      "| Category | Grade | Score | Summary |",
      "|----------|-------|-------|---------|"
      | rows
    ] ++ [""]
  end

  defp category_sections(_categories, :summary), do: []

  defp category_sections(categories, detail) do
    Enum.flat_map(categories, fn cat ->
      section_header(cat) ++ metric_detail(cat) ++ worst_offenders_section(cat, detail)
    end)
  end

  defp section_header(cat) do
    metric_summary =
      cat.metric_scores
      |> Enum.map(fn m -> "#{m.name}=#{format_num(m.value)}" end)
      |> Enum.join(", ")

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

  defp worst_offenders_section(_cat, :summary), do: []

  defp worst_offenders_section(cat, _detail) do
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

          "| `#{f.path}` | #{f.grade} | #{issues} |"
        end)

      [
        "### Worst Offenders",
        "",
        "| File | Grade | Issues |",
        "|------|-------|--------|"
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
end
