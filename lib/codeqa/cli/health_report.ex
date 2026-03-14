defmodule CodeQA.CLI.HealthReport do
  @moduledoc false

  alias CodeQA.CLI.Options

  @spec run(list(String.t())) :: :ok
  def run(args) do
    {opts, [path], _} =
      Options.parse(args,
        [
          output: :string,
          config: :string,
          detail: :string,
          top: :integer,
          format: :string
        ],
        [o: :output]
      )

    if opts[:telemetry], do: CodeQA.Telemetry.setup()

    Options.validate_dir!(path)

    ignore_patterns = Options.parse_ignore_paths(opts[:ignore_paths])
    files = CodeQA.Collector.collect_files(path, ignore_patterns: ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Analyzing #{map_size(files)} files for health report...")

    analyze_opts = Options.build_analyze_opts(opts)

    start_time = System.monotonic_time(:millisecond)
    results = CodeQA.Analyzer.analyze_codebase(files, analyze_opts)
    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Analysis completed in #{end_time - start_time}ms")

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

    report =
      CodeQA.HealthReport.generate(results,
        config: opts[:config],
        detail: detail,
        top: top_n
      )

    markdown = CodeQA.HealthReport.to_markdown(report, detail, format)

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
end
