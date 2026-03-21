defmodule Mix.Tasks.Research.Report do
  @shortdoc "Print semver vs commit analysis comparison report from results.json"
  @moduledoc """
  Reads priv/research/results.json and prints a comparison report
  showing semver coverage, conventional commit coverage, and agreement rates.

  Usage:
      mix research.report
      mix research.report --output report.md
  """

  use Mix.Task

  alias CodeQA.Research.Report

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [output: :string])

    results_path = "priv/research/results.json"

    unless File.exists?(results_path) do
      Mix.raise("#{results_path} not found — run `mix research.analyze` first")
    end

    results = results_path |> File.read!() |> Jason.decode!(keys: :atoms)
    report = Report.generate(results)

    case opts[:output] do
      nil ->
        IO.puts(report)

      path ->
        File.write!(path, report)
        Mix.shell().info("Report saved to #{path}")
    end
  end
end
