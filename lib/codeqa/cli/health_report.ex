defmodule CodeQA.CLI.HealthReport do
  @moduledoc false

  @behaviour CodeQA.CLI.Command

  alias CodeQA.CLI.Options
  alias CodeQA.Config
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Engine.Collector
  alias CodeQA.Git
  alias CodeQA.HealthReport

  @impl CodeQA.CLI.Command
  def usage do
    """
    Usage: codeqa health-report <path> [options]

      Generate a graded health report for a codebase.

    Options:
      -o, --output FILE     Output file path (default: stdout)
      --config FILE         YAML config file for category/threshold overrides
      --detail MODE         Detail level: summary, default, or full (default: default)
      --format FORMAT       Output format: plain or github (default: plain)
      --top N               Number of worst offenders per category (default: 5)
      --progress            Show per-file progress on stderr
      -w, --workers N       Number of parallel workers
      --cache               Enable caching file metrics
      --cache-dir DIR       Directory to store cache (default: .codeqa_cache)
      -t, --timeout MS      Timeout for similarity analysis (default: 5000)
      --ignore-paths PATHS  Comma-separated list of path patterns to ignore (supports wildcards, e.g. "test/*,docs/*")
      --base-ref REF        Base git ref for PR comparison (enables delta and block scoping)
      --head-ref REF        Head git ref (default: HEAD)
      --comment             Multi-part mode: writes numbered part files to TMPDIR for PR comments
    """
  end

  @impl CodeQA.CLI.Command
  def run(args) when args in [["--help"], ["-h"]] do
    usage()
  end

  @command_options [
    output: :string,
    config: :string,
    detail: :string,
    top: :integer,
    format: :string,
    ignore_paths: :string,
    base_ref: :string,
    head_ref: :string,
    telemetry: :boolean,
    comment: :boolean
  ]

  def run(args) do
    {opts, [path], _} = Options.parse(args, @command_options, o: :output)
    Options.validate_dir!(path)
    extra_ignore_patterns = Options.parse_ignore_paths(opts[:ignore_paths])

    base_ref = opts[:base_ref]
    head_ref = opts[:head_ref] || "HEAD"

    files =
      Collector.collect_files(path, extra_ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Analyzing #{map_size(files)} files for health report...")

    telemetry_pid = if opts[:telemetry], do: attach_block_impact_telemetry()

    analyze_opts =
      Options.build_analyze_opts(opts) ++
        Config.near_duplicate_blocks_opts() ++ [compute_nodes: true]

    start_time = System.monotonic_time(:millisecond)
    results = Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

    if telemetry_pid, do: print_block_impact_telemetry(telemetry_pid)

    total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()

    results =
      Map.put(results, "metadata", %{
        "path" => Path.expand(path),
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "total_files" => map_size(files),
        "total_bytes" => total_bytes
      })

    {base_results, changed_files, diff_line_ranges} =
      if base_ref do
        IO.puts(:stderr, "Collecting base snapshot at #{base_ref}...")
        base_files = Git.collect_files_at_ref(path, base_ref)
        changed = Git.changed_files(path, base_ref, head_ref)

        diff_ranges =
          case Git.diff_line_ranges(path, base_ref, head_ref) do
            {:ok, ranges} ->
              ranges

            {:error, reason} ->
              IO.puts(:stderr, "Warning: failed to parse diff line ranges: #{inspect(reason)}")
              IO.puts(:stderr, "Block scoping disabled - showing all blocks in changed files")
              %{}
          end

        IO.puts(:stderr, "Analyzing base snapshot (#{map_size(base_files)} files)...")
        base_res = Analyzer.analyze_codebase(base_files, analyze_opts)

        {base_res, changed, diff_ranges}
      else
        {nil, [], %{}}
      end

    detail = parse_detail(opts[:detail])
    format = parse_format(opts[:format])
    top_n = opts[:top] || 5

    report =
      HealthReport.generate(results,
        config: opts[:config],
        detail: detail,
        top: top_n,
        base_results: base_results,
        changed_files: changed_files,
        diff_line_ranges: diff_line_ranges
      )

    if opts[:comment] do
      write_comment_parts(report, detail)
    else
      markdown = HealthReport.to_markdown(report, detail, format)

      case opts[:output] do
        nil ->
          markdown

        file ->
          File.write!(file, markdown)
          IO.puts(:stderr, "Health report written to #{file}")
          ""
      end
    end
  end

  defp write_comment_parts(report, detail) do
    tmpdir = System.get_env("TMPDIR", "/tmp")
    parts = HealthReport.Formatter.render_parts(report, detail: detail)

    # Write each part to a numbered file
    Enum.with_index(parts, 1)
    |> Enum.each(fn {content, n} ->
      path = Path.join(tmpdir, "codeqa-part-#{n}.md")
      File.write!(path, content)
      IO.puts(:stderr, "Part #{n} written to #{path} (#{byte_size(content)} bytes)")
    end)

    # Ensure at least 3 parts exist for stale cleanup
    actual_count = length(parts)
    padded_count = max(actual_count, 3)

    for n <- (actual_count + 1)..padded_count//1 do
      path = Path.join(tmpdir, "codeqa-part-#{n}.md")
      placeholder = "> _No content for this section._\n\n<!-- codeqa-health-report-#{n} -->"
      File.write!(path, placeholder)
      IO.puts(:stderr, "Part #{n} (placeholder) written to #{path}")
    end

    # Write part count for run.sh to read
    count_path = Path.join(tmpdir, "codeqa-part-count.txt")
    File.write!(count_path, to_string(padded_count))
    IO.puts(:stderr, "Part count (#{padded_count}) written to #{count_path}")

    ""
  end

  defp parse_detail(nil), do: :default
  defp parse_detail("summary"), do: :summary
  defp parse_detail("default"), do: :default
  defp parse_detail("full"), do: :full

  defp parse_detail(other) do
    IO.puts(:stderr, "Warning: unknown detail level '#{other}', using 'default'")
    :default
  end

  defp parse_format(nil), do: :plain
  defp parse_format("plain"), do: :plain
  defp parse_format("github"), do: :github

  defp parse_format(other) do
    IO.puts(:stderr, "Warning: unknown format '#{other}', using 'plain'")
    :plain
  end

  # ---------------------------------------------------------------------------
  # Block impact telemetry
  # ---------------------------------------------------------------------------

  defp attach_block_impact_telemetry do
    {:ok, pid} = Agent.start_link(fn -> %{nodes: [], files: [], codebase_cosines_us: 0} end)

    :telemetry.attach_many(
      "block-impact-reporter",
      [
        [:codeqa, :block_impact, :codebase_cosines],
        [:codeqa, :block_impact, :file],
        [:codeqa, :block_impact, :node]
      ],
      &handle_block_impact_event(&1, &2, &3, &4),
      pid
    )

    pid
  end

  defp handle_block_impact_event(
         [:codeqa, :block_impact, :codebase_cosines],
         measurements,
         _metadata,
         pid
       ) do
    Agent.update(pid, &Map.put(&1, :codebase_cosines_us, measurements.duration))
  end

  defp handle_block_impact_event([:codeqa, :block_impact, :file], measurements, metadata, pid) do
    Agent.update(pid, fn state ->
      Map.update!(state, :files, &[{metadata.path, measurements} | &1])
    end)
  end

  defp handle_block_impact_event([:codeqa, :block_impact, :node], measurements, metadata, pid) do
    Agent.update(pid, fn state ->
      Map.update!(state, :nodes, &[{metadata.path, measurements} | &1])
    end)
  end

  defp print_block_impact_telemetry(pid) do
    state = Agent.get(pid, & &1)
    Agent.stop(pid)
    :telemetry.detach("block-impact-reporter")

    nodes = state.nodes
    files = state.files

    total_nodes = length(nodes)
    total_files = length(files)

    node_totals = Enum.map(nodes, fn {_, m} -> m end)
    file_totals = Enum.map(files, fn {_, m} -> m end)

    IO.puts(:stderr, """

    ── Block Impact Telemetry ──────────────────────────────
    Codebase cosines:     #{us(state.codebase_cosines_us)}
    Files processed:      #{total_files}
    Nodes processed:      #{total_nodes}

    Per-file breakdown (avg across #{total_files} files):
      tokenize:           #{avg_us(file_totals, :tokenize_us)}
      parse blocks:       #{avg_us(file_totals, :parse_us)}
      file cosines:       #{avg_us(file_totals, :file_cosines_us)}
      total/file:         #{avg_us(file_totals, :duration)}

    Per-node breakdown (avg across #{total_nodes} nodes):
      reconstruct:        #{avg_us(node_totals, :reconstruct_us)}
      analyze_file:       #{avg_us(node_totals, :analyze_file_us)}
      aggregate:          #{avg_us(node_totals, :aggregate_us)}
      refactoring cosine: #{avg_us(node_totals, :refactoring_us)}
      total/node:         #{avg_us(node_totals, :duration)}

    Top 5 slowest files (total node time):
    #{top_slow_files(files, nodes)}
    ────────────────────────────────────────────────────────
    """)
  end

  defp top_slow_files(files, nodes) do
    node_time_by_file =
      nodes
      |> Enum.group_by(fn {path, _} -> path end, fn {_, m} -> m.duration end)
      |> Map.new(fn {path, durations} -> {path, Enum.sum(durations)} end)

    files
    |> Enum.map(fn {path, fm} ->
      node_time = Map.get(node_time_by_file, path, 0)
      {path, fm.node_count, node_time}
    end)
    |> Enum.sort_by(fn {_, _, t} -> -t end)
    |> Enum.take(5)
    |> Enum.map_join("\n", fn {path, node_count, node_time} ->
      "  #{path}  (#{node_count} nodes, #{us(node_time)} node time)"
    end)
  end

  defp avg_us([], _key), do: "n/a"

  defp avg_us(measurements, key) do
    total = Enum.sum(Enum.map(measurements, &Map.get(&1, key, 0)))
    us(div(total, length(measurements)))
  end

  defp us(microseconds) when microseconds >= 1_000_000,
    do: "#{Float.round(microseconds / 1_000_000, 2)}s"

  defp us(microseconds) when microseconds >= 1_000,
    do: "#{Float.round(microseconds / 1_000, 1)}ms"

  defp us(microseconds), do: "#{microseconds}µs"
end
