defmodule Mix.Tasks.Research.Analyze do
  @shortdoc "Analyze repos from repos.json: compare semver vs commit labels. Output: results.json"
  @moduledoc """
  Reads priv/research/repos.json and for each repo:
  1. Fetches all semver tags
  2. Extracts valid semver transitions (up to 5 per jump type)
  3. Fetches commits between each transition pair
  4. Classifies commits using conventional commit prefixes
  5. Compares semver label vs commit label

  Output: priv/research/results.json

  Usage:
      mix research.analyze
      mix research.analyze --language rust    # single language only
  """

  use Mix.Task

  alias CodeQA.Research.Analysis

  @rate_limit_ms 1_000

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [language: :string])
    language_filter = opts[:language]

    repos_path = "priv/research/repos.json"

    unless File.exists?(repos_path) do
      Mix.raise("#{repos_path} not found — run `mix research.fetch` first")
    end

    repos =
      repos_path
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> then(fn all ->
        if language_filter do
          Enum.filter(all, &(&1.language == language_filter))
        else
          all
        end
      end)

    Mix.shell().info("Analyzing #{length(repos)} repos...")

    results =
      repos
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {repo, idx} ->
        Mix.shell().info("[#{idx}/#{length(repos)}] #{repo.full_name}...")

        result =
          case Analysis.analyse_repo(repo.owner, repo.name, repo.language) do
            {:ok, data} ->
              transitions = length(data.comparisons)

              Mix.shell().info(
                "  -> #{data.total_tags} tags, #{transitions} transitions compared"
              )

              [data]

            {:error, reason} ->
              Mix.shell().error("  -> ERROR: #{reason}")
              []
          end

        # Rate limit to avoid GitHub API throttling
        if idx < length(repos), do: Process.sleep(@rate_limit_ms)

        result
      end)

    output_path = "priv/research/results.json"
    File.write!(output_path, Jason.encode!(results, pretty: true))
    Mix.shell().info("\nSaved #{length(results)} results to #{output_path}")
  end
end
