defmodule Mix.Tasks.Research.Fetch do
  @shortdoc "Fetch top 20 starred repos per language from GitHub. Output: priv/research/repos.json"
  @moduledoc """
  Fetches the top 20 most-starred GitHub repos for each supported code language.

  Usage:
      mix research.fetch
      mix research.fetch --languages rust,go,python   # comma-separated subset

  Output: priv/research/repos.json
  """

  use Mix.Task

  alias CodeQA.Research.Github

  @code_languages ~w(
    cpp go haskell ocaml rust swift zig
    julia lua perl php python r ruby shell
    clojure csharp dart elixir erlang fsharp java kotlin scala
    javascript typescript
  )

  # Minimum semver tag count to be included in analysis.
  # Repos with fewer tags don't have enough transitions for meaningful comparison.
  @min_semver_tags 10

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    languages = parse_languages(args)

    Mix.shell().info("Fetching top 20 repos for #{length(languages)} languages...")
    Mix.shell().info("Filtering to repos with ≥#{@min_semver_tags} valid semver tags...\n")

    results =
      languages
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {lang, idx} ->
        Mix.shell().info("[#{idx}/#{length(languages)}] #{lang}...")

        case Github.fetch_top_repos(lang, 20) do
          {:ok, repos} ->
            qualified = Enum.filter(repos, &qualifies?/1)

            Mix.shell().info(
              "  -> #{length(qualified)}/#{length(repos)} repos have ≥#{@min_semver_tags} semver tags"
            )

            qualified

          {:error, reason} ->
            Mix.shell().error("  -> ERROR: #{reason}")
            []
        end
      end)

    output_path = "priv/research/repos.json"
    File.write!(output_path, Jason.encode!(results, pretty: true))
    Mix.shell().info("\nSaved #{length(results)} qualifying repos to #{output_path}")
  end

  # Check if a repo has enough valid semver tags to be worth analyzing.
  # Fetches tags and counts ones that match the semver pattern.
  defp qualifies?(%{owner: owner, name: name}) do
    case Github.fetch_tags(owner, name) do
      {:ok, tags} ->
        semver_count =
          Enum.count(tags, fn %{name: tag_name} ->
            Regex.match?(~r/^v?\d+\.\d+\.\d+/, tag_name)
          end)

        semver_count >= @min_semver_tags

      {:error, _} ->
        false
    end
  end

  defp parse_languages(args) do
    case OptionParser.parse(args, strict: [languages: :string]) do
      {[languages: langs_str], _, _} -> String.split(langs_str, ",")
      _ -> @code_languages
    end
  end
end
