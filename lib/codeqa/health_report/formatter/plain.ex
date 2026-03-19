defmodule CodeQA.HealthReport.Formatter.Plain do
  @moduledoc "Renders health report as plain markdown."

  @spec render(map(), atom()) :: String.t()
  def render(report, detail) do
    [
      header(report),
      cosine_legend(),
      overall_table(report),
      top_issues_section(Map.get(report, :top_issues, []), detail),
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

  defp render_category(%{type: :cosine} = cat, detail) do
    cosine_section_header(cat) ++
      cosine_behaviors_table(cat) ++ cosine_worst_offenders(cat, detail)
  end

  defp render_category(cat, detail) do
    section_header(cat) ++ metric_detail(cat) ++ worst_offenders_section(cat, detail)
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

  defp cosine_worst_offenders(_cat, :summary), do: []

  defp cosine_worst_offenders(cat, _detail) do
    Enum.flat_map(cat.behaviors, fn b ->
      offenders = Map.get(b, :worst_offenders, [])

      if offenders == [] do
        []
      else
        fix_hint = cosine_fix_hint(cat.key, b.behavior)

        rows =
          Enum.map(offenders, fn f ->
            details = format_cosine_details(f, fix_hint)
            "| #{format_path(f.file)} | #{format_num(f.cosine)} | #{details} |"
          end)

        [
          "### Worst Offenders: #{b.behavior}",
          "",
          "| File | Cosine | Details |",
          "|------|--------|---------|"
          | rows
        ] ++ [""]
      end
    end)
  end

  defp format_cosine_details(f, fix_hint) do
    why_part = format_why_part(Map.get(f, :top_metrics, []))
    where_part = format_where_part(Map.get(f, :top_nodes, []))
    fix_part = if fix_hint, do: "**Fix:** #{fix_hint}", else: nil

    [why_part, where_part, fix_part]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("<br>")
  end

  defp format_why_part([]), do: nil

  defp format_why_part(top_metrics) do
    parts =
      Enum.map(top_metrics, fn %{metric: metric, contribution: contribution} ->
        sign = if contribution < 0, do: "↓", else: "↑"
        abs_val = abs(contribution)

        value_str =
          if contribution < 0,
            do: "−#{format_num(abs_val)}",
            else: "+#{format_num(abs_val)}"

        "#{sign} #{metric} (#{value_str})"
      end)

    "**Why:** #{Enum.join(parts, ", ")}"
  end

  defp format_where_part([]), do: nil

  defp format_where_part(top_nodes) do
    parts =
      Enum.map(top_nodes, fn node ->
        line = node["start_line"] || "?"
        type = node["type"] || "unknown"
        "line #{line} (#{type})"
      end)

    "**Where:** #{Enum.join(parts, ", ")}"
  end

  defp cosine_fix_hint(category_key, behavior) do
    yaml_path = "priv/combined_metrics/#{category_key}.yml"

    case YamlElixir.read_from_file(yaml_path) do
      {:ok, data} ->
        get_in(data, [behavior, "_fix_hint"])

      {:error, reason} ->
        require Logger
        Logger.debug("cosine_fix_hint: could not read #{yaml_path}: #{inspect(reason)}")
        nil
    end
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

  defp worst_offenders_section(_cat, :summary), do: []

  defp worst_offenders_section(cat, _detail) do
    offenders = Map.get(cat, :worst_offenders, [])

    if offenders == [] do
      []
    else
      averages = Map.new(cat.metric_scores, &{&1.name, &1.value})

      rows =
        Enum.map(offenders, fn f ->
          metric_issues =
            Enum.map_join(f.metric_scores, "<br>", fn m ->
              avg = Map.get(averages, m.name)
              avg_str = if avg, do: " (avg: #{format_num(avg)})", else: ""
              "#{direction(m.good)}#{m.name}=#{format_num(m.value)}#{avg_str}"
            end)

          where_part = format_where_part(Map.get(f, :top_nodes, []))
          fix_hint = threshold_fix_hint(f.metric_scores)
          fix_part = if fix_hint, do: "**Fix:** #{fix_hint}", else: nil

          extra =
            [where_part, fix_part]
            |> Enum.reject(&is_nil/1)
            |> Enum.map_join("", &"<br>#{&1}")

          issues = metric_issues <> extra

          "| #{format_path(f.path)}<br>#{format_lines(f[:lines])} lines · #{format_size(f[:bytes])} | #{f.grade} | #{issues} |"
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

  defp threshold_fix_hint(metric_scores) do
    worst = Enum.min_by(metric_scores, & &1.score, fn -> nil end)

    if worst do
      categories = CodeQA.HealthReport.Categories.defaults()
      all_metrics = Enum.flat_map(categories, & &1.metrics)

      found =
        Enum.find(all_metrics, fn m ->
          m.name == worst.name and m.source == worst.source
        end)

      if found, do: Map.get(found, :fix_hint), else: nil
    end
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
end
