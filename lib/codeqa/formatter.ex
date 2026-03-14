defmodule CodeQA.Formatter do
  @moduledoc false

  @summary_metrics [
    {"entropy", "char_entropy", "Entropy"},
    {"halstead", "volume", "Halstead Vol."},
    {"halstead", "difficulty", "Difficulty"},
    {"readability", "flesch_adapted", "Readability"},
    {"compression", "redundancy", "Redundancy"}
  ]

  @bar_width 20
  @filled "█"
  @empty "░"

  def format_github(comparison, output_mode \\ "auto") do
    metadata = comparison["metadata"]
    files = comparison["files"] || %{}
    codebase = comparison["codebase"] || %{}

    if metadata["total_files_compared"] == 0 do
      "## Code Quality: PR Comparison\n\nNo file changes detected."
    else
      build_github_report(metadata, files, codebase, output_mode)
    end
  end

  defp build_github_report(metadata, files, codebase, output_mode) do
    categories = CodeQA.HealthReport.Categories.defaults()
    scale = CodeQA.HealthReport.Categories.default_grade_scale()

    base_agg = get_in(codebase, ["base", "aggregate"]) || %{}
    head_agg = get_in(codebase, ["head", "aggregate"]) || %{}

    base_grades = CodeQA.HealthReport.Grader.grade_aggregate(categories, base_agg, scale)
    head_grades = CodeQA.HealthReport.Grader.grade_aggregate(categories, head_agg, scale)

    paired = Enum.zip(base_grades, head_grades)

    lines =
      [
        "## Code Quality: PR Comparison",
        "",
        "**#{metadata["total_files_compared"]} files compared** (#{metadata["summary"]})",
        ""
      ] ++
        mermaid_chart(head_grades) ++
        progress_bars(paired) ++
        [""] ++
        file_details(files, output_mode) ++
        aggregate_details(codebase)

    Enum.join(lines, "\n")
  end

  defp mermaid_chart(head_grades) do
    names = Enum.map(head_grades, fn g -> ~s("#{g.name}") end) |> Enum.join(", ")
    scores = Enum.map(head_grades, fn g -> to_string(g.score) end) |> Enum.join(", ")

    [
      "```mermaid",
      "%%{init: {'theme': 'neutral'}}%%",
      "xychart-beta",
      "    title \"Code Health After PR\"",
      "    x-axis [#{names}]",
      "    y-axis \"Score\" 0 --> 100",
      "    bar [#{scores}]",
      "```",
      ""
    ]
  end

  defp progress_bars(paired) do
    max_name_len =
      Enum.reduce(paired, 0, fn {_base, head}, acc ->
        max(acc, String.length(head.name))
      end)

    rows =
      Enum.map(paired, fn {base, head} ->
        name = String.pad_trailing(head.name, max_name_len)
        base_bar = build_bar(base.score)
        head_bar = build_bar(head.score)
        emoji = grade_emoji(head.grade)
        delta = head.score - base.score
        delta_str = if delta >= 0, do: "+#{delta}", else: to_string(delta)
        "#{name}  #{base_bar} #{base.score} → #{head_bar} #{head.score}  #{emoji} #{delta_str}"
      end)

    ["```"] ++ rows ++ ["```"]
  end

  defp file_details(files, _output_mode) do
    codebase_summary = CodeQA.Summarizer.summarize_codebase(%{"files" => files, "codebase" => %{}})

    file_summaries =
      Map.new(files, fn {path, data} ->
        {path, CodeQA.Summarizer.summarize_file(path, data)}
      end)

    inner =
      (format_file_table(files, file_summaries) ++ [""])
      |> Enum.join("\n")

    [
      "<details>",
      "<summary><strong>File changes — #{codebase_summary["gist"]}</strong></summary>",
      "",
      inner,
      "</details>",
      ""
    ]
  end

  defp aggregate_details(codebase) do
    inner =
      format_aggregate_table(codebase)
      |> Enum.join("\n")

    if inner == "" do
      []
    else
      [
        "<details>",
        "<summary><strong>Aggregate metrics</strong></summary>",
        "",
        inner,
        "",
        "</details>",
        ""
      ]
    end
  end

  defp build_bar(score) do
    filled = round(score / 100 * @bar_width)
    filled = min(max(filled, 0), @bar_width)
    empty = @bar_width - filled
    String.duplicate(@filled, filled) <> String.duplicate(@empty, empty)
  end

  defp grade_emoji(grade) do
    cond do
      grade in ["A", "A-"] -> "🟢"
      grade in ["B+", "B", "B-"] -> "🟡"
      grade in ["C+", "C", "C-"] -> "🟠"
      true -> "🔴"
    end
  end

  def format_markdown(comparison, output_mode \\ "auto") do
    metadata = comparison["metadata"]
    files = comparison["files"] || %{}
    codebase = comparison["codebase"]

    if metadata["total_files_compared"] == 0 do
      "## Code Quality: PR Comparison\n\nNo file changes detected."
    else
      build_report(metadata, files, codebase, output_mode)
    end
  end

  defp build_report(metadata, files, codebase, output_mode) do
    codebase_summary =
      CodeQA.Summarizer.summarize_codebase(%{"files" => files, "codebase" => codebase})

    lines = [
      "## Code Quality: PR Comparison",
      "",
      "**#{metadata["total_files_compared"]} files compared** (#{metadata["summary"]})",
      ""
    ]

    lines =
      if output_mode in ["auto", "summary"] do
        lines ++ ["> #{codebase_summary["gist"]}", ""]
      else
        lines
      end

    lines =
      if output_mode in ["auto", "changes"] do
        file_summaries =
          Map.new(files, fn {path, data} ->
            {path, CodeQA.Summarizer.summarize_file(path, data)}
          end)

        lines ++ format_file_table(files, file_summaries) ++ [""]
      else
        lines
      end

    lines =
      if output_mode in ["auto", "summary"] do
        lines ++ format_aggregate_table(codebase)
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  defp format_file_table(files, file_summaries) do
    columns = detect_columns(files)

    if columns == [],
      do: ["No metric data available."],
      else: build_file_rows(files, file_summaries, columns)
  end

  defp build_file_rows(files, file_summaries, columns) do
    header =
      "| File | Status | Summary | " <>
        Enum.map_join(columns, " | ", fn {_, _, label} -> label end) <> " |"

    separator =
      "|------|--------|---------|" <> Enum.map_join(columns, "", fn _ -> "--------|" end)

    rows =
      files
      |> Enum.sort_by(fn {path, _} -> path end)
      |> Enum.map(fn {path, data} ->
        gist = get_in(file_summaries, [path, "gist"]) || ""
        cells = format_file_row(data, columns)
        "| `#{path}` | #{data["status"]} | #{gist} | " <> Enum.join(cells, " | ") <> " |"
      end)

    [header, separator | rows]
  end

  defp format_file_row(data, columns) do
    Enum.map(columns, fn {metric_name, key, _label} ->
      case data["status"] do
        "modified" -> format_modified_cell(data, metric_name, key)
        "added" -> format_added_cell(data, metric_name, key)
        "deleted" -> format_deleted_cell(data, metric_name, key)
        _ -> "—"
      end
    end)
  end

  defp format_modified_cell(data, metric_name, key) do
    case get_in(data, ["delta", "metrics", metric_name, key]) do
      nil -> "—"
      val -> format_delta(val)
    end
  end

  defp format_added_cell(data, metric_name, key) do
    case get_in(data, ["head", "metrics", metric_name, key]) do
      nil -> "—"
      val -> "*#{format_value(val)}*"
    end
  end

  defp format_deleted_cell(data, metric_name, key) do
    case get_in(data, ["base", "metrics", metric_name, key]) do
      nil -> "—"
      val -> "~~#{format_value(val)}~~"
    end
  end

  defp format_aggregate_table(codebase) do
    base_agg = get_in(codebase, ["base", "aggregate"]) || %{}
    head_agg = get_in(codebase, ["head", "aggregate"]) || %{}
    delta_agg = get_in(codebase, ["delta", "aggregate"]) || %{}

    if base_agg == %{} and head_agg == %{},
      do: [],
      else: build_aggregate_rows(base_agg, head_agg, delta_agg)
  end

  defp build_aggregate_rows(base_agg, head_agg, delta_agg) do
    header = [
      "### Aggregate Metrics",
      "",
      "| Metric | Base | Head | Delta |",
      "|--------|------|------|-------|"
    ]

    rows =
      MapSet.new(Map.keys(base_agg) ++ Map.keys(head_agg))
      |> Enum.sort()
      |> Enum.flat_map(fn metric_name ->
        base_m = Map.get(base_agg, metric_name, %{})
        head_m = Map.get(head_agg, metric_name, %{})
        delta_m = Map.get(delta_agg, metric_name, %{})

        MapSet.new(Map.keys(base_m) ++ Map.keys(head_m))
        |> Enum.sort()
        |> Enum.map(fn key ->
          "| #{metric_name}.#{key} | #{format_value(base_m[key])} | #{format_value(head_m[key])} | #{format_delta(delta_m[key])} |"
        end)
      end)

    header ++ rows
  end

  defp detect_columns(files) do
    Enum.filter(@summary_metrics, fn {metric_name, key, _label} ->
      Enum.any?(files, fn {_path, data} ->
        source = data["head"] || data["base"]
        source && get_in(source, ["metrics", metric_name, key]) != nil
      end)
    end)
  end

  defp format_delta(nil), do: "—"

  defp format_delta(value) when value > 0,
    do: "+#{:erlang.float_to_binary(value / 1, decimals: 2)}"

  defp format_delta(value) when value < 0, do: :erlang.float_to_binary(value / 1, decimals: 2)
  defp format_delta(_), do: "0.00"

  defp format_value(nil), do: "—"
  defp format_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp format_value(value), do: to_string(value)
end
