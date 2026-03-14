defmodule CodeQA.HealthReport.Formatter.Plain do
  @moduledoc "Renders health report as plain markdown."

  @spec render(map(), atom(), keyword()) :: String.t()
  def render(report, detail, opts \\ []) do
    watch_files = Keyword.get(opts, :watch_files, MapSet.new())
    alerts = collect_alerts(report.categories, watch_files)

    [
      header(report),
      overall_table(report),
      alerts_section(alerts),
      category_sections(report.categories, detail, watch_files)
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

  defp alerts_section([]), do: []

  defp alerts_section(alerts) do
    rows = Enum.map(alerts, fn a ->
      "| `#{a.path}` | #{a.category} | #{a.grade} |"
    end)

    [
      "## ⚠️ File Alerts",
      "",
      "#{length(alerts)} watched file(s) found in worst offenders:",
      "",
      "| File | Category | Grade |",
      "|------|----------|-------|"
      | rows
    ] ++ [""]
  end

  defp category_sections(_categories, :summary, _watch_files), do: []

  defp category_sections(categories, detail, watch_files) do
    Enum.flat_map(categories, fn cat ->
      section_header(cat) ++ metric_detail(cat) ++ worst_offenders_section(cat, detail, watch_files)
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

  defp worst_offenders_section(_cat, :summary, _watch_files), do: []

  defp worst_offenders_section(cat, _detail, watch_files) do
    offenders = Map.get(cat, :worst_offenders, [])

    if offenders == [] do
      []
    else
      averages = Map.new(cat.metric_scores, &{&1.name, &1.value})

      rows =
        Enum.map(offenders, fn f ->
          alert = if MapSet.member?(watch_files, f.path), do: "⚠️ ", else: ""

          issues =
            f.metric_scores
            |> Enum.map(fn m ->
              avg = Map.get(averages, m.name)
              avg_str = if avg, do: " (avg: #{format_num(avg)})", else: ""
              "#{direction(m.good)}#{m.name}=#{format_num(m.value)}#{avg_str}"
            end)
            |> Enum.join("<br>")

          "| #{alert}#{format_path(f.path)}<br>#{format_lines(f[:lines])} lines · #{format_size(f[:bytes])} | #{f.grade} | #{issues} |"
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

  defp collect_alerts(_categories, watch_files) when watch_files == %MapSet{}, do: []

  defp collect_alerts(categories, watch_files) do
    Enum.flat_map(categories, fn cat ->
      cat.worst_offenders
      |> Enum.filter(fn f -> MapSet.member?(watch_files, f.path) end)
      |> Enum.map(fn f -> %{path: f.path, category: cat.name, grade: f.grade} end)
    end)
  end

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

  defp format_date(timestamp) when is_binary(timestamp) do
    timestamp |> String.slice(0, 10)
  end

  defp format_date(_), do: "unknown"
end
