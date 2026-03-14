defmodule CodeQA.CLI do
  @moduledoc false

  @version "0.1.0"

  def main(args) do
    case args do
      ["analyze" | rest] -> handle_analyze(rest)
      ["compare" | rest] -> handle_compare(rest)
      ["history" | rest] -> handle_history(rest)
      ["correlate" | rest] -> handle_correlate(rest)
      ["stopwords" | rest] -> handle_stopwords(rest)
      ["health-report" | rest] -> handle_health_report(rest)
      _ -> print_usage()
    end
  end

  defp handle_analyze(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          output: :string,
          progress: :boolean,
          workers: :integer,
          cache: :boolean,
          cache_dir: :string,
          timeout: :integer,
          show_ncd: :boolean,
          ncd_top: :integer,
          ncd_paths: :string,
          show_files: :boolean,
          show_file_paths: :string,
          combinations: :boolean,
          telemetry: :boolean,
          experimental_stopwords: :boolean,
          stopwords_threshold: :float,
          ignore_paths: :string
        ],
        aliases: [o: :output, w: :workers, t: :timeout]
      )

    if opts[:telemetry], do: CodeQA.Telemetry.setup()

    unless File.dir?(path) do
      IO.puts(:stderr, "Error: '#{path}' is not a directory")
      exit({:shutdown, 1})
    end

    ignore_patterns = parse_ignore_paths(opts[:ignore_paths])
    files = CodeQA.Collector.collect_files(path, ignore_patterns: ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    if opts[:progress] do
      step_prefix = if opts[:show_ncd], do: "1/5 ", else: "1/1 "
      IO.puts(:stderr, "  #{step_prefix}Analyzing #{map_size(files)} files...")
    else
      IO.puts(:stderr, "Analyzing #{map_size(files)} files...")
    end

    analyze_opts = build_analyze_opts(opts)

    start_time = System.monotonic_time(:millisecond)
    results = CodeQA.Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

    total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()

    results = filter_files_for_output(results, opts)

    report =
      %{
        "metadata" => %{
          "path" => Path.expand(path),
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "total_files" => map_size(files),
          "total_bytes" => total_bytes,
          "version" => @version
        }
      }
      |> Map.merge(results)

    json = Jason.encode!(report, pretty: true)

    case opts[:output] do
      nil ->
        IO.puts(json)

      file ->
        File.write!(file, json)
        IO.puts(:stderr, "Report written to #{file}")
    end

    if opts[:telemetry], do: CodeQA.Telemetry.print_report()
  end

  defp handle_compare(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          base_ref: :string,
          head_ref: :string,
          changes_only: :boolean,
          all_files: :boolean,
          format: :string,
          output: :string,
          progress: :boolean,
          workers: :integer,
          cache: :boolean,
          cache_dir: :string,
          timeout: :integer,
          show_ncd: :boolean,
          ncd_top: :integer,
          ncd_paths: :string,
          combinations: :boolean,
          telemetry: :boolean,
          experimental_stopwords: :boolean,
          stopwords_threshold: :float,
          show_files: :boolean,
          show_file_paths: :string,
          ignore_paths: :string,
          watch_files: :string
        ],
        aliases: [w: :workers, t: :timeout]
      )

    if opts[:telemetry], do: CodeQA.Telemetry.setup()

    base_ref = opts[:base_ref] || raise "Missing --base-ref"
    head_ref = opts[:head_ref] || "HEAD"
    changes_only = if opts[:all_files], do: false, else: true
    format = opts[:format] || "json"
    output_mode = opts[:output] || "auto"

    unless File.dir?(path) do
      IO.puts(:stderr, "Error: '#{path}' is not a directory")
      exit({:shutdown, 1})
    end

    ignore_patterns = parse_ignore_paths(opts[:ignore_paths])
    opts = Keyword.put(opts, :ignore_patterns, ignore_patterns)

    {base_result, head_result, changes} =
      run_comparison(path, base_ref, head_ref, changes_only, opts)

    comparison =
      CodeQA.Comparator.compare_results(base_result, head_result, changes)
      |> enrich_comparison_metadata(base_ref, head_ref, changes_only)
      |> filter_files_for_output(opts)

    watch_files = parse_watch_files(opts[:watch_files])
    output_comparison(comparison, format, output_mode, watch_files)

    if opts[:telemetry], do: CodeQA.Telemetry.print_report()
  end

  defp handle_history(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          commits: :integer,
          commit_list: :string,
          output_dir: :string,
          progress: :boolean,
          workers: :integer,
          cache: :boolean,
          cache_dir: :string,
          timeout: :integer,
          show_ncd: :boolean,
          ncd_top: :integer,
          ncd_paths: :string,
          combinations: :boolean,
          show_files: :boolean,
          show_file_paths: :string,
          ignore_paths: :string
        ],
        aliases: [n: :commits, o: :output_dir, w: :workers, t: :timeout]
      )

    output_dir = opts[:output_dir] || raise "Missing --output-dir"

    unless File.dir?(path) do
      IO.puts(:stderr, "Error: '#{path}' is not a directory")
      exit({:shutdown, 1})
    end

    File.mkdir_p!(output_dir)

    commits =
      cond do
        opts[:commit_list] ->
          String.split(opts[:commit_list], ",")

        opts[:commits] ->
          {commits_output, 0} =
            System.cmd("git", ["log", "-n", to_string(opts[:commits]), "--format=%H"], cd: path)

          commits_output |> String.split("\n", trim: true) |> Enum.reverse()

        true ->
          raise "Must provide either --commits N or --commit-list C1,C2"
      end

    IO.puts(:stderr, "Found #{length(commits)} commits to analyze.")

    analyze_opts = build_analyze_opts(opts)
    ignore_patterns = parse_ignore_paths(opts[:ignore_paths])

    commits
    |> Enum.with_index(1)
    |> Enum.each(fn {commit, index} ->
      IO.puts(:stderr, "[#{index}/#{length(commits)}] Analyzing commit #{commit}...")

      start_time_progress = System.monotonic_time(:millisecond)

      current_opts =
        if opts[:progress],
          do: [
            {:on_progress, fn c, t, p, _tt -> progress_callback(c, t, p, start_time_progress) end}
            | analyze_opts
          ],
          else: analyze_opts

      files = CodeQA.Git.collect_files_at_ref(path, commit)
      files = CodeQA.Collector.reject_ignored_map(files, ignore_patterns)

      if map_size(files) == 0 do
        IO.puts(:stderr, "Warning: no source files found at commit #{commit}")
      else
        start_time = System.monotonic_time(:millisecond)
        results = CodeQA.Analyzer.analyze_codebase(files, current_opts)
        end_time = System.monotonic_time(:millisecond)

        IO.puts(:stderr, "  Analysis completed in #{end_time - start_time}ms")

        total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()
        results = filter_files_for_output(results, opts)

        report =
          %{
            "metadata" => %{
              "path" => Path.expand(path),
              "commit" => commit,
              "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
              "total_files" => map_size(files),
              "total_bytes" => total_bytes,
              "version" => @version
            }
          }
          |> Map.merge(results)

        out_file = Path.join(output_dir, "#{commit}.json")
        File.write!(out_file, Jason.encode!(report, pretty: true))
      end
    end)

    IO.puts(:stderr, "Done writing history to #{output_dir}")
  end

  defp handle_correlate(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          top: :integer,
          hide_exact: :boolean,
          all_groups: :boolean,
          min: :float,
          max: :float,
          combined_only: :boolean,
          max_steps: :integer
        ],
        aliases: [t: :top]
      )

    unless File.dir?(path) do
      IO.puts(:stderr, "Error: '#{path}' is not a directory")
      exit({:shutdown, 1})
    end

    files = File.ls!(path) |> Enum.filter(&String.ends_with?(&1, ".json")) |> Enum.sort()

    if length(files) < 2 do
      IO.puts(
        :stderr,
        "Error: Need at least 2 JSON history files in '#{path}' to calculate correlations."
      )

      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Found #{length(files)} history files. Extracting metrics...")

    {series, category_map} = extract_metric_series(path, files)
    active_keys = Map.keys(series) |> Enum.sort()
    num_keys = length(active_keys)

    IO.puts(:stderr, "Calculating correlations between #{num_keys} active metrics...")

    total_start = System.monotonic_time(:millisecond)

    {pairs_stream, total_pairs} = build_correlation_pairs(active_keys, num_keys, opts)

    IO.puts(:stderr, "Calculating correlations for #{total_pairs} pairs...")

    correlations =
      compute_correlations(pairs_stream, total_pairs, total_start, series, category_map, opts)

    total_end = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Telemetry:")
    IO.puts(:stderr, "  Total time: #{total_end - total_start}ms")

    top_n = opts[:top] || 20

    sorted = Enum.sort_by(correlations, &abs(&1["correlation"]), :desc)
    top = Enum.take(sorted, top_n)

    IO.puts(Jason.encode!(top, pretty: true))
  end

  defp extract_metric_series(path, files) do
    t_extract_start = System.monotonic_time(:millisecond)

    extracted =
      Enum.map(files, fn file ->
        data = Path.join(path, file) |> File.read!() |> Jason.decode!()

        data
        |> Map.get("codebase", %{})
        |> Map.get("aggregate", %{})
        |> flatten_aggregate_metrics()
        |> Map.new()
      end)

    t_extract_end = System.monotonic_time(:millisecond)
    IO.puts(:stderr, "  Extraction took #{t_extract_end - t_extract_start}ms")

    t_keys_start = System.monotonic_time(:millisecond)

    keys =
      extracted
      |> Enum.reduce(MapSet.new(), fn m, acc -> MapSet.union(acc, MapSet.new(Map.keys(m))) end)
      |> Enum.to_list()
      |> Enum.sort()

    t_keys_end = System.monotonic_time(:millisecond)
    IO.puts(:stderr, "  Keys resolution took #{t_keys_end - t_keys_start}ms")

    t_series_start = System.monotonic_time(:millisecond)
    # Collect time series for each key, filtering out metrics that are completely constant
    series =
      keys
      |> Enum.map(fn key ->
        values = Enum.map(extracted, &Map.get(&1, key, 0.0))
        min = Enum.min(values)
        max = Enum.max(values)
        {key, values, min != max}
      end)
      |> Enum.filter(fn {_, _, has_variance} -> has_variance end)
      |> Enum.map(fn {key, values, _} -> {key, values} end)
      |> Map.new()

    t_series_end = System.monotonic_time(:millisecond)
    IO.puts(:stderr, "  Series building took #{t_series_end - t_series_start}ms")

    active_keys = Map.keys(series) |> Enum.sort()

    t_cats_start = System.monotonic_time(:millisecond)

    category_map =
      Map.new(active_keys, fn key ->
        cats =
          key
          |> String.split(".")
          |> List.first()
          |> String.split(",")
          |> Enum.flat_map(&String.split(&1, "_"))

        {key, MapSet.new(cats)}
      end)

    t_cats_end = System.monotonic_time(:millisecond)
    IO.puts(:stderr, "  Category precomputation took #{t_cats_end - t_cats_start}ms")

    {series, category_map}
  end

  defp flatten_aggregate_metrics(aggregate) do
    Enum.flat_map(aggregate, fn {category, metrics} ->
      Enum.map(metrics, fn {name, val} -> {"#{category}.#{name}", val} end)
    end)
  end

  defp build_correlation_pairs(active_keys, num_keys, opts) do
    max_steps = opts[:max_steps] || -1

    pairs_to_process =
      if opts[:combined_only] do
        combined_pairs_stream(active_keys)
      else
        all_pairs_stream(active_keys)
      end

    pairs_stream =
      if max_steps > 0, do: Stream.take(pairs_to_process, max_steps), else: pairs_to_process

    # Use exact count if max_steps is set, otherwise approximate based on the cartesian or triangular formula
    total_pairs =
      cond do
        max_steps > 0 ->
          max_steps

        opts[:combined_only] ->
          normal_count = Enum.count(active_keys, &(not String.contains?(&1, ",")))
          combined_count = Enum.count(active_keys, &String.contains?(&1, ","))
          normal_count * combined_count

        true ->
          div(num_keys * (num_keys - 1), 2)
      end

    {pairs_stream, total_pairs}
  end

  defp combined_pairs_stream(active_keys) do
    normal = Enum.reject(active_keys, &String.contains?(&1, ","))
    combined = Enum.filter(active_keys, &String.contains?(&1, ","))

    Stream.flat_map(normal, fn k1 ->
      Stream.map(combined, fn k2 -> {k1, k2} end)
    end)
  end

  defp all_pairs_stream(active_keys) do
    Stream.unfold(active_keys, fn
      [] -> nil
      [_h | t] = list -> {list, t}
    end)
    |> Stream.flat_map(fn
      [k1 | rest] -> Stream.map(rest, fn k2 -> {k1, k2} end)
      [] -> []
    end)
  end

  defp compute_correlations(pairs_stream, total_pairs, total_start, series, category_map, opts) do
    counter = :counters.new(1, [:atomics])

    # We calculate the interval based on 2% jumps, but force it to be at least 1 and max 5000 to prevent console spam
    update_interval = max(1, min(5000, div(total_pairs, 50)))

    pairs_stream
    |> Task.async_stream(
      &correlate_pair(
        &1,
        counter,
        total_pairs,
        update_interval,
        total_start,
        series,
        category_map,
        opts
      ),
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Stream.map(fn {:ok, result} -> result end)
    |> Enum.reject(&is_nil/1)
  end

  defp correlate_pair(
         {k1, k2},
         counter,
         total_pairs,
         update_interval,
         total_start,
         series,
         category_map,
         opts
       ) do
    :counters.add(counter, 1, 1)
    current = :counters.get(counter, 1)
    correlate_progress_callback(current, total_pairs, update_interval, total_start, opts)

    cross_valid =
      opts[:all_groups] ||
        MapSet.disjoint?(Map.fetch!(category_map, k1), Map.fetch!(category_map, k2))

    if cross_valid do
      corr = CodeQA.Math.pearson_correlation_list(Map.fetch!(series, k1), Map.fetch!(series, k2))
      maybe_correlation_result(k1, k2, corr, opts)
    end
  end

  defp maybe_correlation_result(k1, k2, corr, opts) do
    if keep_correlation?(corr, opts) do
      %{"metric1" => k1, "metric2" => k2, "correlation" => corr}
    end
  end

  defp keep_correlation?(corr, opts) do
    valid = corr != 0.0
    valid = if opts[:hide_exact], do: valid and abs(corr) != 1.0, else: valid
    valid = if valid and opts[:min], do: corr >= opts[:min], else: valid
    if valid and opts[:max], do: corr <= opts[:max], else: valid
  end

  defp correlate_progress_callback(current, total_pairs, update_interval, total_start, _opts) do
    if rem(current, update_interval) == 0 or current == total_pairs do
      now = System.monotonic_time(:millisecond)
      elapsed = max(now - total_start, 1)
      avg_time = elapsed / current
      eta_ms = round((total_pairs - current) * avg_time)

      output =
        CodeQA.CLI.UI.progress_bar(current, total_pairs, eta: CodeQA.CLI.UI.format_eta(eta_ms))

      IO.write(:stderr, "\r" <> output)

      if current == total_pairs do
        IO.puts(:stderr, "")
      end
    end
  end

  defp run_comparison(path, base_ref, head_ref, changes_only, opts) do
    ignore_patterns = opts[:ignore_patterns] || []
    changes = CodeQA.Git.changed_files(path, base_ref, head_ref)
    changes = CodeQA.Collector.reject_ignored(changes, ignore_patterns, & &1.path)

    file_paths =
      if changes_only do
        IO.puts(:stderr, "Comparing #{length(changes)} changed files...")
        Enum.map(changes, & &1.path)
      else
        IO.puts(:stderr, "Comparing all source files...")
        nil
      end

    empty = %{"files" => %{}, "codebase" => %{"aggregate" => %{}, "similarity" => %{}}}

    if changes_only and length(changes) == 0 do
      IO.puts(:stderr, "No source files changed — nothing to compare.")
      {empty, empty, []}
    else
      base_files = CodeQA.Git.collect_files_at_ref(path, base_ref, file_paths)
      head_files = CodeQA.Git.collect_files_at_ref(path, head_ref, file_paths)
      base_files = CodeQA.Collector.reject_ignored_map(base_files, ignore_patterns)
      head_files = CodeQA.Collector.reject_ignored_map(head_files, ignore_patterns)

      if map_size(base_files) == 0 and map_size(head_files) == 0 do
        IO.puts(:stderr, "Warning: no source files found at either ref")
        exit({:shutdown, 1})
      end

      print_compare_progress(opts, base_files, head_files)

      analyze_opts = build_analyze_opts(opts)

      base_result =
        if map_size(base_files) > 0,
          do: CodeQA.Analyzer.analyze_codebase(base_files, analyze_opts),
          else: empty

      head_result =
        if map_size(head_files) > 0,
          do: CodeQA.Analyzer.analyze_codebase(head_files, analyze_opts),
          else: empty

      changes = if changes_only, do: changes, else: synthesize_changes(base_files, head_files)

      {base_result, head_result, changes}
    end
  end

  defp print_compare_progress(opts, base_files, head_files) do
    if opts[:progress] do
      step_prefix = if opts[:show_ncd], do: "1/5 ", else: "1/1 "

      IO.puts(
        :stderr,
        "  #{step_prefix}Analyzing base (#{map_size(base_files)} files) and head (#{map_size(head_files)} files)..."
      )
    else
      IO.puts(
        :stderr,
        "Analyzing base (#{map_size(base_files)} files) and head (#{map_size(head_files)} files)..."
      )
    end
  end

  defp enrich_comparison_metadata(comparison, base_ref, head_ref, changes_only) do
    comparison
    |> put_in(["metadata", "base_ref"], base_ref)
    |> put_in(["metadata", "head_ref"], head_ref)
    |> put_in(["metadata", "changes_only"], changes_only)
    |> put_in(["metadata", "version"], @version)
    |> put_in(["metadata", "timestamp"], DateTime.utc_now() |> DateTime.to_iso8601())
  end

  defp output_comparison(comparison, "markdown", output_mode, watch_files) do
    IO.puts(CodeQA.Formatter.format_markdown(comparison, output_mode, watch_files: watch_files))
  end

  defp output_comparison(comparison, "github", output_mode, watch_files) do
    IO.puts(CodeQA.Formatter.format_github(comparison, output_mode, watch_files: watch_files))
  end

  defp output_comparison(comparison, _format, output_mode, _watch_files) do
    codebase_summary = CodeQA.Summarizer.summarize_codebase(comparison)

    file_summaries =
      Map.new(Map.get(comparison, "files", %{}), fn {path, data} ->
        {path, CodeQA.Summarizer.summarize_file(path, data)}
      end)

    IO.puts(
      Jason.encode!(build_json_output(comparison, codebase_summary, file_summaries, output_mode),
        pretty: true
      )
    )
  end

  defp synthesize_changes(base_files, head_files) do
    all_paths = MapSet.union(MapSet.new(Map.keys(base_files)), MapSet.new(Map.keys(head_files)))

    all_paths
    |> Enum.sort()
    |> Enum.map(fn path ->
      status =
        cond do
          Map.has_key?(base_files, path) and Map.has_key?(head_files, path) -> "modified"
          Map.has_key?(head_files, path) -> "added"
          true -> "deleted"
        end

      %CodeQA.Git.ChangedFile{path: path, status: status}
    end)
  end

  defp filter_files_for_output(results, opts) do
    cond do
      opts[:show_files] ->
        results

      opts[:show_file_paths] ->
        target_paths = String.split(opts[:show_file_paths], ",") |> MapSet.new()

        filtered =
          Map.filter(results["files"], fn {path, _} -> MapSet.member?(target_paths, path) end)

        Map.put(results, "files", filtered)

      true ->
        Map.delete(results, "files")
    end
  end

  defp build_json_output(comparison, codebase_summary, file_summaries, output_mode) do
    result = %{"metadata" => comparison["metadata"]}

    result =
      if output_mode in ["auto", "summary"] do
        result
        |> Map.put("summary", codebase_summary)
        |> Map.put("codebase", comparison["codebase"])
      else
        result
      end

    if output_mode in ["auto", "changes"] and Map.has_key?(comparison, "files") do
      files_with_summaries =
        Map.new(comparison["files"], fn {path, data} ->
          {path, Map.put(data, "summary", Map.get(file_summaries, path, %{}))}
        end)

      Map.put(result, "files", files_with_summaries)
    else
      result
    end
  end

  defp progress_callback(completed, total, path, start_time) do
    now = System.monotonic_time(:millisecond)
    elapsed = max(now - start_time, 1)
    avg_time = elapsed / completed
    eta_ms = round((total - completed) * avg_time)

    label = if String.length(path) > 30, do: "..." <> String.slice(path, -27..-1), else: path

    output =
      CodeQA.CLI.UI.progress_bar(completed, total,
        eta: CodeQA.CLI.UI.format_eta(eta_ms),
        label: label
      )

    IO.write(:stderr, "\r" <> output)

    if completed == total do
      IO.puts(:stderr, "")
    end
  end

  defp handle_stopwords(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          workers: :integer,
          stopwords_threshold: :float,
          progress: :boolean,
          ignore_paths: :string
        ],
        aliases: [w: :workers]
      )

    unless File.dir?(path) do
      IO.puts(:stderr, "Error: '#{path}' is not a directory")
      exit({:shutdown, 1})
    end

    ignore_patterns = parse_ignore_paths(opts[:ignore_paths])
    files = CodeQA.Collector.collect_files(path, ignore_patterns: ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Extracting stopwords for #{map_size(files)} files...")
    start_time = System.monotonic_time(:millisecond)

    word_extractor = fn content ->
      Regex.scan(~r/\b[a-zA-Z_]\w*\b/u, content) |> List.flatten()
    end

    opts_word = Keyword.put(opts, :progress_label, "Words")
    word_stopwords = CodeQA.Stopwords.find_stopwords(files, word_extractor, opts_word)

    fp_extractor = fn content ->
      CodeQA.Metrics.TokenNormalizer.normalize(content) |> CodeQA.Metrics.Winnowing.kgrams(5)
    end

    opts_fp = Keyword.put(opts, :progress_label, "Fingerprints")
    fp_stopwords = CodeQA.Stopwords.find_stopwords(files, fp_extractor, opts_fp)

    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "\nAnalysis completed in #{end_time - start_time}ms")
    IO.puts(:stderr, "\n--- Word Stopwords (#{MapSet.size(word_stopwords)}) ---")

    word_stopwords
    |> MapSet.to_list()
    |> Enum.sort()
    |> Enum.chunk_every(10)
    |> Enum.each(fn chunk -> IO.puts(Enum.join(chunk, ", ")) end)

    IO.puts(:stderr, "\n--- Fingerprint Stopwords (#{MapSet.size(fp_stopwords)}) ---")
    IO.puts(:stderr, "Found #{MapSet.size(fp_stopwords)} structural k-gram hashes.")
  end

  defp handle_health_report(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          output: :string,
          config: :string,
          detail: :string,
          top: :integer,
          format: :string,
          progress: :boolean,
          workers: :integer,
          cache: :boolean,
          cache_dir: :string,
          timeout: :integer,
          show_ncd: :boolean,
          ncd_top: :integer,
          ncd_paths: :string,
          combinations: :boolean,
          telemetry: :boolean,
          experimental_stopwords: :boolean,
          stopwords_threshold: :float,
          ignore_paths: :string,
          watch_files: :string
        ],
        aliases: [o: :output, w: :workers, t: :timeout]
      )

    if opts[:telemetry], do: CodeQA.Telemetry.setup()

    unless File.dir?(path) do
      IO.puts(:stderr, "Error: '#{path}' is not a directory")
      exit({:shutdown, 1})
    end

    ignore_patterns = parse_ignore_paths(opts[:ignore_paths])
    files = CodeQA.Collector.collect_files(path, ignore_patterns: ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Analyzing #{map_size(files)} files for health report...")

    analyze_opts = build_analyze_opts(opts)

    start_time = System.monotonic_time(:millisecond)
    results = CodeQA.Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

    # Add metadata to results for the report
    total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()

    results =
      Map.put(results, "metadata", %{
        "path" => Path.expand(path),
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "total_files" => map_size(files),
        "total_bytes" => total_bytes
      })

    detail = parse_detail(opts[:detail])
    format = parse_format(opts[:format])
    top_n = opts[:top] || 5
    watch_files = parse_watch_files(opts[:watch_files])

    report =
      CodeQA.HealthReport.generate(results,
        config: opts[:config],
        detail: detail,
        top: top_n
      )

    markdown = CodeQA.HealthReport.to_markdown(report, detail, format, watch_files: watch_files)

    case opts[:output] do
      nil ->
        IO.puts(markdown)

      file ->
        File.write!(file, markdown)
        IO.puts(:stderr, "Health report written to #{file}")
    end

    if opts[:telemetry], do: CodeQA.Telemetry.print_report()
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

  defp build_analyze_opts(opts) do
    start_time_progress = System.monotonic_time(:millisecond)

    passthrough_keys = [
      :workers,
      :show_ncd,
      :ncd_top,
      :combinations,
      :telemetry,
      :experimental_stopwords,
      :stopwords_threshold
    ]

    base =
      [{:timeout, opts[:timeout] || 5000}]
      |> maybe_add(
        opts[:progress],
        {:on_progress, fn c, t, p, _tt -> progress_callback(c, t, p, start_time_progress) end}
      )
      |> maybe_add(opts[:cache], {:cache_dir, opts[:cache_dir] || ".codeqa_cache"})
      |> maybe_add(
        opts[:ncd_paths],
        {:ncd_paths, opts[:ncd_paths] && String.split(opts[:ncd_paths], ",")}
      )

    Enum.reduce(passthrough_keys, base, fn key, acc ->
      if opts[key], do: [{key, opts[key]} | acc], else: acc
    end)
  end

  defp maybe_add(opts, val, item) do
    if val, do: [item | opts], else: opts
  end

  defp parse_ignore_paths(nil), do: []

  defp parse_ignore_paths(paths_string) do
    paths_string
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp parse_watch_files(nil), do: MapSet.new()

  defp parse_watch_files(paths_string) do
    paths_string
    |> String.split([",", "\n"], trim: true)
    |> Enum.map(&String.trim/1)
    |> MapSet.new()
  end

  defp print_usage do
    IO.puts("""
    Usage: codeqa <command> [options]

    Commands:
      analyze <path>    Analyze a codebase for statistical code quality metrics
      compare <path>    Compare code quality metrics between two git refs
      history <path>    Analyze the history of a codebase across multiple commits
      correlate <dir>   Find metric correlations in a directory of history JSONs
      stopwords <path>  Print codebase-specific stopwords based on frequency
      health-report <path>  Generate a graded health report for a codebase
    Options for analyze:
      -o, --output FILE     Output file path (default: stdout)
      --progress            Show per-file progress on stderr
      -w, --workers N       Number of parallel workers
      --cache               Enable caching file metrics
      --cache-dir DIR       Directory to store cache (default: .codeqa_cache)
      -t, --timeout MS      Timeout for similarity analysis (default: 5000)
      --show-ncd            Compute and show NCD similarity metric
      --ncd-top N           Number of top similar files to show per file
      --ncd-paths PATHS     Comma-separated list of paths to compute NCD for
      --show-files          Include individual file metrics in the output
      --show-file-paths P   Comma-separated list of paths to include in the output
      --ignore-paths PATHS  Comma-separated list of path patterns to ignore (supports wildcards, e.g. "test/*,docs/*")

    Options for compare:
      --base-ref REF        Base git ref to compare from (required)
      --head-ref REF        Head git ref to compare to (default: HEAD)
      --changes-only        Only analyze changed files (default)
      --all-files           Analyze all source files
      --format FORMAT       Output format: json or markdown
      --output MODE         Output mode: auto, summary, or changes
      --progress            Show per-file progress
      -w, --workers N       Number of parallel workers
      --cache               Enable caching file metrics
      --cache-dir DIR       Directory to store cache (default: .codeqa_cache)
      -t, --timeout MS      Timeout for similarity analysis (default: 5000)
      --show-ncd            Compute and show NCD similarity metric
      --ncd-top N           Number of top similar files to show per file
      --ncd-paths PATHS     Comma-separated list of paths to compute NCD for
      --show-files          Include individual file metrics in the output
      --show-file-paths P   Comma-separated list of paths to include in the output
      --ignore-paths PATHS  Comma-separated list of path patterns to ignore (supports wildcards, e.g. "test/*,docs/*")

    Options for history:
      -n, --commits N       Number of recent commits to analyze
      --commit-list L       Comma-separated list of commit hashes to analyze
      -o, --output-dir DIR  Directory to save JSON results for each commit (required)
      --progress            Show per-file progress
      -w, --workers N       Number of parallel workers
      --cache               Enable caching file metrics
      --cache-dir DIR       Directory to store cache (default: .codeqa_cache)
      -t, --timeout MS      Timeout for similarity analysis (default: 5000)
      --show-ncd            Compute and show NCD similarity metric
      --ncd-top N           Number of top similar files to show per file
      --ncd-paths PATHS     Comma-separated list of paths to compute NCD for
      --show-files          Include individual file metrics in the output
      --show-file-paths P   Comma-separated list of paths to include in the output
      --ignore-paths PATHS  Comma-separated list of path patterns to ignore (supports wildcards, e.g. "test/*,docs/*")

    Options for correlate:
      -t, --top N           Number of top correlations to show (default: 20)
      --hide-exact          Hide correlations that are exactly 1.0 or -1.0
      --all-groups          Include correlations between metrics in the same group
      --combined-only       Only show correlations where exactly one metric is a combined metric (e.g. a/b)
      --min FLOAT           Only show correlations greater than or equal to this value
      --max FLOAT           Only show correlations less than or equal to this value
      --max-steps N         Maximum number of correlation pairs to evaluate (for debugging)

    Options for health-report:
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

    """)
  end
end
