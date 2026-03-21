defmodule CodeQA.Research.Analysis do
  @moduledoc """
  Orchestrates the semver vs. commit message comparison for a single repo.

  For each repo:
  1. Fetch all semver tags
  2. Extract valid transitions (filtering by semver rules)
  3. Sample up to 5 transitions per jump type to limit API calls
  4. For each transition, fetch commit messages from GitHub
  5. Classify commits and compare against semver label
  6. Return structured result map
  """

  alias CodeQA.Research.{Github, Semver, Commits}

  @max_per_jump_type 5

  @doc """
  Analyse a single repo. Returns a result map or {:error, reason}.
  """
  @spec analyse_repo(owner :: String.t(), repo :: String.t(), language :: String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def analyse_repo(owner, repo, language) do
    with {:ok, tags} <- Github.fetch_tags(owner, repo),
         transitions = Semver.extract_transitions(tags),
         {:ok, sampled} <- {:ok, sample_transitions(transitions)},
         {:ok, compared} <- compare_all(owner, repo, sampled) do
      {:ok,
       %{
         repo: "#{owner}/#{repo}",
         language: language,
         total_tags: length(tags),
         total_transitions: length(transitions),
         sampled_transitions: length(sampled),
         comparisons: compared,
         semver_classifiable: length(transitions) > 0,
         conventional_commit_ratio: aggregate_cc_ratio(compared)
       }}
    end
  end

  @doc "Compare two labels, returning a comparison result map."
  @spec compare_labels(semver_label :: atom(), commit_label :: atom()) :: map()
  def compare_labels(semver_label, commit_label) do
    classifiable = commit_label not in [:mixed, :unclassifiable]

    %{
      semver: semver_label,
      commits: commit_label,
      commits_classifiable: classifiable,
      agreement: classifiable and semver_label == commit_label
    }
  end

  # --- Private ---

  defp sample_transitions(transitions) do
    [:major, :minor, :patch, :hotfix]
    |> Enum.flat_map(fn jump ->
      transitions
      |> Enum.filter(&(&1.jump == jump))
      |> Enum.take(-@max_per_jump_type)
    end)
  end

  defp compare_all(owner, repo, transitions) do
    results =
      Enum.flat_map(transitions, fn t ->
        case Github.fetch_commits_between(owner, repo, t.from_sha, t.to_sha) do
          {:ok, messages} ->
            commit_label = Commits.classify_messages(messages)
            cc_ratio = Commits.conventional_commit_ratio(messages)
            comparison = compare_labels(t.jump, commit_label)

            [
              Map.merge(comparison, %{
                from_tag: t.from_tag,
                to_tag: t.to_tag,
                jump: t.jump,
                multi_skip: t.multi_skip,
                commit_count: length(messages),
                cc_ratio: cc_ratio
              })
            ]

          {:error, reason} ->
            IO.warn(
              "Failed to fetch commits for #{owner}/#{repo} #{t.from_tag}..#{t.to_tag}: #{reason}"
            )

            []
        end
      end)

    {:ok, results}
  end

  defp aggregate_cc_ratio([]), do: 0.0

  defp aggregate_cc_ratio(comparisons) do
    total = Enum.reduce(comparisons, 0.0, &(&1.cc_ratio + &2))
    total / length(comparisons)
  end
end
