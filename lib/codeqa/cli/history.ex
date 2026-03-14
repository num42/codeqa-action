defmodule CodeQA.CLI.History do
  @moduledoc false

  alias CodeQA.CLI.Options

  @version "0.1.0"

  @spec run(list(String.t())) :: :ok
  def run(args) do
    {opts, [path], _} =
      Options.parse(args,
        [
          commits: :integer,
          commit_list: :string,
          output_dir: :string
        ],
        [n: :commits, o: :output_dir]
      )

    output_dir = opts[:output_dir] || raise "Missing --output-dir"

    Options.validate_dir!(path)
    File.mkdir_p!(output_dir)

    commits = resolve_commits(opts, path)
    IO.puts(:stderr, "Found #{length(commits)} commits to analyze.")

    analyze_opts = Options.build_analyze_opts(opts)
    ignore_patterns = Options.parse_ignore_paths(opts[:ignore_paths])

    commits
    |> Enum.with_index(1)
    |> Enum.each(&analyze_commit(&1, path, output_dir, analyze_opts, ignore_patterns, opts))

    IO.puts(:stderr, "Done writing history to #{output_dir}")
  end

  defp resolve_commits(opts, path) do
    cond do
      opts[:commit_list] ->
        String.split(opts[:commit_list], ",")

      opts[:commits] ->
        {output, 0} =
          System.cmd("git", ["log", "-n", to_string(opts[:commits]), "--format=%H"], cd: path)

        output |> String.split("\n", trim: true) |> Enum.reverse()

      true ->
        raise "Must provide either --commits N or --commit-list C1,C2"
    end
  end

  defp analyze_commit({commit, index}, path, output_dir, analyze_opts, ignore_patterns, opts) do
    IO.puts(:stderr, "[#{index}] Analyzing commit #{commit}...")

    start_time_progress = System.monotonic_time(:millisecond)

    current_opts =
      if opts[:progress],
        do: [
          {:on_progress,
           fn c, t, p, _tt -> CodeQA.CLI.Progress.callback(c, t, p, start_time_progress) end}
          | analyze_opts
        ],
        else: analyze_opts

    files = CodeQA.Git.collect_files_at_ref(path, commit)
    files = CodeQA.Collector.reject_ignored_map(files, ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found at commit #{commit}")
    else
      write_commit_result(commit, path, output_dir, files, current_opts)
    end
  end

  defp write_commit_result(commit, path, output_dir, files, analyze_opts) do
    start_time = System.monotonic_time(:millisecond)
    results = CodeQA.Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "  Analysis completed in #{end_time - start_time}ms")

    total_bytes = results["files"] |> Map.values() |> Enum.map(& &1["bytes"]) |> Enum.sum()

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
      |> Map.merge(Map.delete(results, "files"))

    out_file = Path.join(output_dir, "#{commit}.json")
    File.write!(out_file, Jason.encode!(report, pretty: true))
  end
end
