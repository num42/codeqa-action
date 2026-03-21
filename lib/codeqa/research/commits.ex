defmodule CodeQA.Research.Commits do
  @moduledoc """
  Classifies a list of commit messages using conventional commit prefixes.

  Classification labels:
  - :major  — BREAKING CHANGE: or feat!: present
  - :minor  — majority of meaningful commits use feat:/feature:
  - :patch  — majority of meaningful commits use fix:/bugfix:
  - :mixed  — split between feat: and fix: with no clear majority
  - :unclassifiable — no conventional commit prefixes found

  "Meaningful commits" excludes: chore:, docs:, test:, ci:, style:, build:
  """

  @breaking_patterns [~r/^BREAKING CHANGE:/i, ~r/^feat!:/i, ~r/^[a-z]+\(.*\)!:/i]
  @feature_pattern ~r/^(feat|feature)(\([^)]+\))?:/i
  @fix_pattern ~r/^(fix|bugfix|hotfix)(\([^)]+\))?:/i
  @noise_pattern ~r/^(chore|docs?|test|ci|style|build|refactor)(\([^)]+\))?:/i
  @any_conventional ~r/^[a-z]+(\([^)]+\))?!?:/

  @doc """
  Classify a list of commit messages into :major | :minor | :patch | :mixed | :unclassifiable.
  """
  @spec classify_messages(list(String.t())) :: :major | :minor | :patch | :mixed | :unclassifiable
  def classify_messages([]), do: :unclassifiable

  def classify_messages(messages) do
    # Breaking change overrides everything
    if Enum.any?(messages, &breaking?/1) do
      :major
    else
      meaningful = Enum.reject(messages, &noise?/1)

      feat_count = Enum.count(meaningful, &feature?/1)
      fix_count = Enum.count(meaningful, &fix?/1)
      total = feat_count + fix_count

      cond do
        total == 0 ->
          :unclassifiable

        feat_count > fix_count and feat_count / total > 0.5 ->
          :minor

        fix_count > feat_count and fix_count / total > 0.5 ->
          :patch

        true ->
          :mixed
      end
    end
  end

  @doc """
  Ratio of messages that use any conventional commit prefix.
  Returns float 0.0–1.0.
  """
  @spec conventional_commit_ratio(list(String.t())) :: float()
  def conventional_commit_ratio([]), do: 0.0

  def conventional_commit_ratio(messages) do
    conventional_count = Enum.count(messages, &Regex.match?(@any_conventional, &1))
    conventional_count / length(messages)
  end

  # --- Private ---

  defp breaking?(msg), do: Enum.any?(@breaking_patterns, &Regex.match?(&1, msg))
  defp feature?(msg), do: Regex.match?(@feature_pattern, msg)
  defp fix?(msg), do: Regex.match?(@fix_pattern, msg)
  defp noise?(msg), do: Regex.match?(@noise_pattern, msg)
end
