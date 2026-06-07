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
      --view VIEW           metrics (scales only), actions (agent prompt), or both (default: both)
                            --view actions without --base-ref scans the whole codebase (slow)
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
    view: :string,
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
    view = parse_view(opts[:view])
    warn_actions_full_scan(view, base_ref)

    collect_t0 = System.monotonic_time(:microsecond)

    files =
      Collector.collect_files(path, extra_ignore_patterns)

    collect_us = System.monotonic_time(:microsecond) - collect_t0

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Analyzing #{map_size(files)} files for health report...")

    telemetry_pid = if opts[:telemetry], do: attach_telemetry()

    # In a PR context the report only shows blocks from changed files, so per-node
    # leave-one-out is computed only for those. The codebase aggregate and
    # baseline cosines are still built from every file. `nil` (no base ref) means
    # all files get nodes, preserving standalone-run behavior.
    {changed_files, diff_line_ranges} = collect_diff(path, base_ref, head_ref)

    analyze_opts =
      Options.build_analyze_opts(opts) ++
        Config.near_duplicate_blocks_opts() ++ node_opts(view, changed_files)

    start_time = System.monotonic_time(:millisecond)
    results = Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

    if telemetry_pid,
      do: record_phase(telemetry_pid, :analyze, (end_time - start_time) * 1_000)

    total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()

    results =
      results
      |> Map.put("metadata", %{
        "path" => Path.expand(path),
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "total_files" => map_size(files),
        "total_bytes" => total_bytes
      })

    base_results = base_snapshot_for_view(view, path, base_ref, analyze_opts)

    detail = parse_detail(opts[:detail])
    format = parse_format(opts[:format])
    top_n = opts[:top] || 5

    report_gen_t0 = System.monotonic_time(:microsecond)

    report =
      HealthReport.generate(results,
        config: opts[:config],
        detail: detail,
        top: top_n,
        view: view,
        base_results: base_results,
        changed_files: changed_files,
        diff_line_ranges: diff_line_ranges
      )

    report_gen_us = System.monotonic_time(:microsecond) - report_gen_t0

    if telemetry_pid do
      record_phase(telemetry_pid, :collect, collect_us)
      record_phase(telemetry_pid, :report_gen, report_gen_us)
    end

    output = build_output(report, opts, detail, format, view, telemetry_pid)

    if telemetry_pid, do: print_telemetry(telemetry_pid)

    output
  end

  # Block-impact LOO is the heaviest phase, so it runs only for views that
  # render blocks. In a PR context per-node work is scoped to the changed files.
  defp node_opts(:metrics, _changed_files), do: [compute_nodes: false]

  defp node_opts(_view, changed_files) do
    node_paths = if changed_files == [], do: nil, else: Enum.map(changed_files, & &1.path)
    [compute_nodes: true, node_paths: node_paths]
  end

  # The base snapshot is a full second analysis run; it only feeds the metric
  # changes delta, so skip it for the actions-only view.
  defp base_snapshot_for_view(:actions, _path, _base_ref, _analyze_opts), do: nil

  # The delta only reads codebase aggregates (Delta.compute), never per-node
  # block impact nor codebase metrics (near-duplicate blocks, similarity) — so
  # the snapshot skips both. On large repos the base tree is the whole codebase;
  # leave-one-out and the O(files^2) near-duplicate pass were the two dominant
  # costs, and both produced data the delta throws away.
  defp base_snapshot_for_view(_view, path, base_ref, analyze_opts) do
    base_opts =
      analyze_opts
      |> Keyword.put(:compute_nodes, false)
      |> Keyword.put(:skip_codebase_metrics, true)
      |> Keyword.delete(:node_paths)

    collect_base_snapshot(path, base_ref, base_opts)
  end

  defp warn_actions_full_scan(:actions, nil),
    do:
      IO.puts(
        :stderr,
        "Warning: --view actions without --base-ref scans the whole codebase (slow). Pass --base-ref to scope blocks to changed files."
      )

  defp warn_actions_full_scan(_view, _base_ref), do: :ok

  # Resolves the changed files and per-file diff line ranges once, up front, so
  # the head analysis can scope its per-node work to the changed files. Returns
  # `{[], %{}}` outside a PR context (no base ref) — meaning "no scoping".
  defp collect_diff(_path, nil, _head_ref), do: {[], %{}}

  defp collect_diff(path, base_ref, head_ref) do
    changed = Git.changed_files(path, base_ref, head_ref)
    diff_ranges = collect_diff_ranges(path, base_ref, head_ref)
    {changed, diff_ranges}
  end

  defp collect_base_snapshot(_path, nil, _analyze_opts), do: nil

  defp collect_base_snapshot(path, base_ref, analyze_opts) do
    IO.puts(:stderr, "Collecting base snapshot at #{base_ref}...")
    base_files = Git.collect_files_at_ref(path, base_ref)

    IO.puts(:stderr, "Analyzing base snapshot (#{map_size(base_files)} files)...")
    Analyzer.analyze_codebase(base_files, analyze_opts)
  end

  defp collect_diff_ranges(path, base_ref, head_ref) do
    case Git.diff_line_ranges(path, base_ref, head_ref) do
      {:ok, ranges} ->
        ranges

      {:error, reason} ->
        IO.puts(:stderr, "Warning: failed to parse diff line ranges: #{inspect(reason)}")
        IO.puts(:stderr, "Block scoping disabled - showing all blocks in changed files")
        %{}
    end
  end

  defp build_output(report, opts, detail, format, view, telemetry_pid) do
    if opts[:comment] do
      write_comment_parts(report, detail, view)
    else
      render_markdown(report, opts, detail, format, view, telemetry_pid)
    end
  end

  defp render_markdown(report, opts, detail, format, view, telemetry_pid) do
    render_t0 = System.monotonic_time(:microsecond)
    markdown = HealthReport.to_markdown(report, detail, format, view)
    render_us = System.monotonic_time(:microsecond) - render_t0
    if telemetry_pid, do: record_phase(telemetry_pid, :render, render_us)

    write_markdown(markdown, opts[:output])
  end

  defp write_markdown(markdown, nil), do: markdown

  defp write_markdown(markdown, file) do
    File.write!(file, markdown)
    IO.puts(:stderr, "Health report written to #{file}")
    ""
  end

  defp write_comment_parts(report, detail, view) do
    tmpdir = System.get_env("TMPDIR", "/tmp")
    parts = HealthReport.Formatter.render_parts(report, detail: detail, view: view)

    # Write each part to a numbered file
    parts
    |> Enum.with_index(1)
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

  defp parse_view(nil), do: :both
  defp parse_view("metrics"), do: :metrics
  defp parse_view("actions"), do: :actions
  defp parse_view("both"), do: :both

  defp parse_view(other) do
    IO.puts(:stderr, "Warning: unknown view '#{other}', using 'both'")
    :both
  end

  # ---------------------------------------------------------------------------
  # Pipeline telemetry (block-impact + stage + per-metric + CLI phases)
  # ---------------------------------------------------------------------------

  @telemetry_handler "codeqa-telemetry-reporter"

  defp attach_telemetry do
    {:ok, pid} =
      Agent.start_link(fn ->
        %{
          codebase_cosines_us: 0,
          codebase_metrics: %{},
          cosine_breakdown: %{},
          cosine_breakdown_calls: 0,
          file_metrics: %{},
          files: [],
          loo_breakdown: %{},
          loo_breakdown_calls: 0,
          nodes: [],
          phases: %{},
          stages: %{}
        }
      end)

    :telemetry.attach_many(
      @telemetry_handler,
      [
        [:codeqa, :block_impact, :codebase_cosines],
        [:codeqa, :block_impact, :file],
        [:codeqa, :block_impact, :node],
        [:codeqa, :stage],
        [:codeqa, :file_metric],
        [:codeqa, :codebase_metric],
        [:codeqa, :loo_breakdown],
        [:codeqa, :cosine_breakdown]
      ],
      &handle_event(&1, &2, &3, &4),
      pid
    )

    pid
  end

  defp record_phase(pid, name, duration_us) do
    Agent.update(pid, fn state ->
      Map.update!(state, :phases, &Map.put(&1, name, duration_us))
    end)
  end

  defp handle_event(
         [:codeqa, :block_impact, :codebase_cosines],
         measurements,
         _metadata,
         pid
       ),
       do: pid |> Agent.update(&Map.put(&1, :codebase_cosines_us, measurements.duration))

  defp handle_event([:codeqa, :block_impact, :file], measurements, metadata, pid) do
    Agent.update(pid, fn state ->
      Map.update!(state, :files, &[{metadata.path, measurements} | &1])
    end)
  end

  defp handle_event([:codeqa, :block_impact, :node], measurements, metadata, pid) do
    Agent.update(pid, fn state ->
      Map.update!(state, :nodes, &[{metadata.path, measurements} | &1])
    end)
  end

  defp handle_event([:codeqa, :stage], measurements, metadata, pid) do
    Agent.update(pid, &put_in(&1, [:stages, metadata.stage], measurements.duration))
  end

  defp handle_event([:codeqa, :file_metric], measurements, metadata, pid) do
    Agent.update(pid, &accumulate_file_metric(&1, metadata.metric, measurements.duration))
  end

  defp handle_event([:codeqa, :codebase_metric], measurements, metadata, pid) do
    Agent.update(pid, fn state ->
      Map.update!(state, :codebase_metrics, &Map.put(&1, metadata.metric, measurements.duration))
    end)
  end

  defp handle_event([:codeqa, :loo_breakdown], measurements, _metadata, pid) do
    Agent.update(pid, fn state ->
      merged =
        measurements
        |> Enum.reduce(state.loo_breakdown, fn {k, v}, acc ->
          Map.update(acc, k, v, &(&1 + v))
        end)

      state
      |> Map.put(:loo_breakdown, merged)
      |> Map.update!(:loo_breakdown_calls, &(&1 + 1))
    end)
  end

  defp handle_event([:codeqa, :cosine_breakdown], measurements, _metadata, pid) do
    Agent.update(pid, fn state ->
      merged =
        measurements
        |> Enum.reduce(state.cosine_breakdown, fn {k, v}, acc ->
          Map.update(acc, k, v, &(&1 + v))
        end)

      state
      |> Map.put(:cosine_breakdown, merged)
      |> Map.update!(:cosine_breakdown_calls, &(&1 + 1))
    end)
  end

  defp accumulate_file_metric(state, metric, duration) do
    update_in(state, [:file_metrics, Access.key(metric, {0, 0})], fn {n, sum} ->
      {n + 1, sum + duration}
    end)
  end

  defp print_telemetry(pid) do
    state = Agent.get(pid, & &1)
    Agent.stop(pid)
    :telemetry.detach(@telemetry_handler)

    nodes = state.nodes
    files = state.files

    total_nodes = length(nodes)
    total_files = length(files)

    node_totals = nodes |> Enum.map(fn {_, m} -> m end)
    file_totals = files |> Enum.map(fn {_, m} -> m end)

    IO.puts(:stderr, """

    ── CLI Phases ──────────────────────────────────────────
    #{format_phases(state.phases)}

    ── Top-Level Stages (inside Analyzer.analyze_codebase) ─
    #{format_stages(state.stages)}

    ── Codebase Metrics (run once over all files) ──────────
    #{format_codebase_metrics(state.codebase_metrics)}

    ── File Metrics (summed over all files; #{total_files} files) ──
    #{format_file_metrics(state.file_metrics, total_files)}

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

    ── LOO breakdown (per analyze_file_for_loo_partial call) ─
    Calls: #{state.loo_breakdown_calls}
    #{format_breakdown_avg(state.loo_breakdown, state.loo_breakdown_calls)}

    ── Cosine breakdown (per diagnose_aggregate call) ──────
    Calls: #{state.cosine_breakdown_calls}
    #{format_breakdown_avg(state.cosine_breakdown, state.cosine_breakdown_calls)}

    ── File-size scaling (block_impact: total node time) ──
    #{format_scaling(files, nodes)}
    ────────────────────────────────────────────────────────
    """)
  end

  defp format_breakdown_avg(breakdown, calls) when map_size(breakdown) == 0 or calls == 0,
    do: "  (no data)"

  defp format_breakdown_avg(breakdown, calls) do
    breakdown
    |> Enum.sort_by(fn {_, v} -> -v end)
    |> Enum.take(25)
    |> Enum.map_join("\n", fn {key, total_us} ->
      avg_us = div(total_us, calls)
      pct = total_us * 100 / Enum.sum(Map.values(breakdown))

      "  #{String.pad_trailing(to_string(key), 32)} total #{us(total_us)}  avg/call #{us(avg_us)}  (#{Float.round(pct, 1)}%)"
    end)
  end

  defp format_scaling(files, nodes) do
    nodes_by_path = nodes |> Enum.group_by(fn {p, _} -> p end, fn {_, m} -> m end)

    rows =
      files
      |> Enum.map(fn {path, fm} ->
        node_durations = nodes_by_path |> Map.get(path, []) |> Enum.map(& &1.duration)
        total_node_us = node_durations |> Enum.sum()

        %{
          bytes: Map.get(fm, :bytes, 0),
          file_us: fm.duration,
          nodes: Map.get(fm, :node_count, 0),
          path: path,
          tokens: Map.get(fm, :token_count, 0),
          total_node_us: total_node_us
        }
      end)

    bins = [
      {"<2KB ", fn r -> r.bytes < 2_000 end},
      {"2-8KB", fn r -> r.bytes >= 2_000 and r.bytes < 8_000 end},
      {"8-32KB", fn r -> r.bytes >= 8_000 and r.bytes < 32_000 end},
      {">32KB", fn r -> r.bytes >= 32_000 end}
    ]

    bins
    |> Enum.map_join("\n", fn {label, pred} -> format_bin(label, Enum.filter(rows, pred)) end)
  end

  defp format_bin(label, []), do: "  #{label}  (none)"

  defp format_bin(label, bucket) do
    n = length(bucket)
    avg_bytes = div(bucket |> Enum.map(& &1.bytes) |> Enum.sum(), n)
    avg_tokens = div(bucket |> Enum.map(& &1.tokens) |> Enum.sum(), n)
    avg_nodes = div(bucket |> Enum.map(& &1.nodes) |> Enum.sum(), n)
    avg_node_us = div(bucket |> Enum.map(& &1.total_node_us) |> Enum.sum(), n)
    per_node_us = if avg_nodes > 0, do: div(avg_node_us, avg_nodes), else: 0

    "  #{label}  files=#{n}  avg bytes=#{avg_bytes} tokens=#{avg_tokens} nodes=#{avg_nodes}  total_node=#{us(avg_node_us)}  per_node=#{us(per_node_us)}"
  end

  defp format_phases(phases) when map_size(phases) == 0, do: "  (no phases recorded)"

  defp format_phases(phases) do
    [:collect, :analyze, :report_gen, :render]
    |> Enum.filter(&Map.has_key?(phases, &1))
    |> Enum.map_join("\n", fn name ->
      "  #{String.pad_trailing(Atom.to_string(name), 12)} #{us(phases[name])}"
    end)
  end

  defp format_stages(stages) when map_size(stages) == 0, do: "  (no stages recorded)"

  defp format_stages(stages) do
    stages
    |> Enum.sort_by(fn {_, dur} -> -dur end)
    |> Enum.map_join("\n", fn {name, dur} ->
      "  #{String.pad_trailing(Atom.to_string(name), 20)} #{us(dur)}"
    end)
  end

  defp format_codebase_metrics(m) when map_size(m) == 0, do: "  (none recorded)"

  defp format_codebase_metrics(m) do
    m
    |> Enum.sort_by(fn {_, dur} -> -dur end)
    |> Enum.map_join("\n", fn {name, dur} ->
      "  #{String.pad_trailing(to_string(name), 32)} #{us(dur)}"
    end)
  end

  defp format_file_metrics(m, _file_count) when map_size(m) == 0, do: "  (none recorded)"

  defp format_file_metrics(m, file_count) do
    fc = max(file_count, 1)

    m
    |> Enum.map(fn {name, {n, sum}} ->
      avg_us = if n > 0, do: div(sum, n), else: 0
      {name, sum, avg_us, n}
    end)
    |> Enum.sort_by(fn {_, sum, _, _} -> -sum end)
    |> Enum.map_join("\n", fn {name, sum, avg_us, n} ->
      "  #{String.pad_trailing(to_string(name), 32)} total #{us(sum)}  avg/file #{us(div(sum, fc))}  (#{n} calls, avg/call #{us(avg_us)})"
    end)
  end

  defp top_slow_files(files, nodes) do
    node_time_by_file =
      nodes
      |> Enum.group_by(fn {path, _} -> path end, fn {_, m} -> m.duration end)
      |> Map.new(fn {path, durations} -> {path, durations |> Enum.sum()} end)

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
    total = measurements |> Enum.map(&Map.get(&1, key, 0)) |> Enum.sum()
    us(div(total, length(measurements)))
  end

  defp us(microseconds) when microseconds >= 1_000_000,
    do: "#{Float.round(microseconds / 1_000_000, 2)}s"

  defp us(microseconds) when microseconds >= 1_000,
    do: "#{Float.round(microseconds / 1_000, 1)}ms"

  defp us(microseconds), do: "#{microseconds}µs"
end
