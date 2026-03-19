defmodule Mix.Tasks.Codeqa.SampleReport do
  use Mix.Task

  @shortdoc "Evaluates combined metric formulas against good/bad sample code"

  @moduledoc """
  Runs combined metric formulas against sample files and prints a separation table.

      mix codeqa.sample_report
      mix codeqa.sample_report --category variable_naming
      mix codeqa.sample_report --verbose
      mix codeqa.sample_report --output results.json
      mix codeqa.sample_report --apply-scalars
      mix codeqa.sample_report --file path/to/file.ex

  A ratio ≥ 2x means the formula meaningfully separates good from bad code.
  A ratio < 1.5x is flagged as weak; < 1.0x is marked ✗ (wrong direction).

  `--apply-scalars` rewrites the YAML config files with suggested scalars derived
  from the sample data. Metrics with ratio in the deadzone (0.995–1.005) are
  excluded. All non-deadzoned metrics are written, including ones not previously
  in the YAML.

  `--file` analyzes a single file or directory and prints all combined metric
  behavior scores, grouped by category, sorted worst-first.
  """

  @switches [
    category: :string,
    verbose: :boolean,
    output: :string,
    report: :string,
    apply_scalars: :boolean,
    file: :string,
    top: :integer
  ]

  def run(args) do
    Mix.Task.run("app.start")
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    results = CodeQA.CombinedMetrics.SampleRunner.run(opts)

    results
    |> Enum.group_by(& &1.category)
    |> Enum.each(&print_category(&1, opts))

    if path = opts[:output] do
      File.write!(path, Jason.encode!(results, pretty: true))
      IO.puts("\nResults written to #{path}")
    end

    if path = opts[:report] do
      report = CodeQA.CombinedMetrics.SampleRunner.build_metric_report(opts)
      File.write!(path, Jason.encode!(report, pretty: true))
      IO.puts("\nMetric report written to #{path}")
    end

    if opts[:apply_scalars] do
      stats = CodeQA.CombinedMetrics.SampleRunner.apply_scalars(opts)
      IO.puts("\nApplied scalars to YAML configs:")
      Enum.each(stats, &print_scalar_stats/1)
    end

    if path = opts[:file] do
      print_file_scores(path, opts)
    end
  end

  defp print_category({category, results}, opts) do
    IO.puts("\n#{category}")
    IO.puts(String.duplicate("-", 75))

    IO.puts(
      "  " <>
        pad("behavior", 35) <>
        pad("bad", 9) <>
        pad("good", 9) <>
        pad("ratio", 13) <>
        "ok?"
    )

    Enum.each(results, &print_row(&1, opts))
  end

  defp print_row(r, opts) do
    ratio_str =
      "#{r.ratio}x" <>
        cond do
          not r.direction_ok -> ""
          r.ratio < 1.5 -> " (weak)"
          true -> ""
        end

    ok = if r.direction_ok, do: "✓", else: "✗"

    IO.puts(
      "  " <>
        pad(r.behavior, 35) <>
        pad(fmt(r.bad_score), 9) <>
        pad(fmt(r.good_score), 9) <>
        pad(ratio_str, 13) <>
        ok
    )

    if opts[:verbose] do
      Enum.each(r.metric_detail, fn m ->
        scalar_str = if m.scalar >= 0, do: "+#{m.scalar}", else: "#{m.scalar}"

        IO.puts(
          "      " <>
            pad("#{m.group}.#{m.key}", 45) <>
            pad(scalar_str, 7) <>
            pad(fmt(m.bad), 8) <>
            pad(fmt(m.good), 8) <>
            "#{m.ratio}x"
        )
      end)
    end
  end

  defp print_file_scores(path, opts) do
    expanded = Path.expand(path)

    files =
      cond do
        File.dir?(expanded) ->
          CodeQA.Engine.Collector.collect_files(expanded)

        File.regular?(expanded) ->
          %{Path.basename(expanded) => File.read!(expanded)}

        true ->
          IO.puts("\nPath not found: #{path}")
          nil
      end

    if files && map_size(files) > 0 do
      IO.puts("\nAnalyzing #{map_size(files)} file(s) at: #{path}")

      aggregate =
        files
        |> CodeQA.Engine.Analyzer.analyze_codebase()
        |> get_in(["codebase", "aggregate"])

      top_n = opts[:top] || 15
      issues = CodeQA.CombinedMetrics.SampleRunner.diagnose_aggregate(aggregate, top: top_n)
      IO.puts("\nTop #{top_n} likely issues (by cosine similarity):")
      IO.puts(String.duplicate("-", 75))
      IO.puts("  " <> pad("behavior", 38) <> pad("cosine", 9) <> "score")
      Enum.each(issues, &print_issue_row/1)

      IO.puts("\nFull breakdown by category:")
      combined = CodeQA.CombinedMetrics.SampleRunner.score_aggregate(aggregate)
      IO.puts("")
      Enum.each(combined, &print_combined_category/1)
    else
      IO.puts("\nNo supported files found at: #{path}")
    end
  end

  defp print_issue_row(%{category: cat, behavior: b, cosine: cos, score: s, top_metrics: metrics}) do
    IO.puts("  " <> pad("#{cat}.#{b}", 38) <> pad(fmt(cos), 9) <> fmt(s))

    Enum.each(metrics, fn %{metric: m, contribution: c} ->
      IO.puts("      " <> pad(m, 44) <> fmt(c))
    end)
  end

  defp print_combined_category(%{name: name, behaviors: behaviors}) do
    IO.puts(name)
    IO.puts(String.duplicate("-", 60))

    IO.puts("  " <> pad("behavior", 40) <> "score")

    behaviors
    |> Enum.sort_by(& &1.score)
    |> Enum.each(fn %{behavior: b, score: s} ->
      flag = if s < 0.0, do: "  ⚠", else: ""
      IO.puts("  " <> pad(b, 40) <> fmt(s) <> flag)
    end)

    IO.puts("")
  end

  defp print_scalar_stats(%{category: cat, updated: u, deadzoned: d, skipped: s}) do
    IO.puts("  #{pad(cat, 30)}  #{u} written  #{d} deadzoned  #{s} skipped (no samples)")
  end

  defp fmt(f), do: :erlang.float_to_binary(f / 1, decimals: 4)
  defp pad(s, n), do: String.pad_trailing(to_string(s), n)
end
