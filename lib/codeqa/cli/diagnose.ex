defmodule CodeQA.CLI.Diagnose do
  @moduledoc false

  @behaviour CodeQA.CLI.Command

  @impl CodeQA.CLI.Command
  def usage do
    """
    Usage: codeqa diagnose [options]

      Diagnose likely code quality issues using cosine similarity against behavior profiles.

    Options:
      --path PATH           File or directory path to analyze (required)
      --mode MODE           Output mode: aggregate (default) or per-file
      --top N               Number of top issues to display (default: 15)
      --format FORMAT       Output format: plain (default) or json
      --combined-top N      Number of worst offender files per behavior (default: 2)
    """
  end

  @impl CodeQA.CLI.Command
  def run(args) when args in [["--help"], ["-h"]] do
    usage()
  end

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          path: :string,
          mode: :string,
          top: :integer,
          format: :string,
          combined_top: :integer
        ]
      )

    path = opts[:path]

    unless path do
      IO.puts(:stderr, "Error: --path required")
      exit({:shutdown, 1})
    end

    unless File.exists?(path) do
      IO.puts(:stderr, "Error: '#{path}' does not exist")
      exit({:shutdown, 1})
    end

    mode =
      case opts[:mode] do
        "per-file" -> :per_file
        _ -> :aggregate
      end

    format =
      case opts[:format] do
        "json" -> :json
        _ -> :plain
      end

    CodeQA.Diagnostics.run(
      path: path,
      mode: mode,
      top: opts[:top] || 15,
      format: format,
      combined_top: opts[:combined_top] || 2
    )
  end
end
