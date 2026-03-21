defmodule CodeQA.Research.Report do
  @moduledoc "Formats analysis results as text report."

  @doc """
  Generate a report string from results list (output of mix research.analyze).
  `results` is a list of per-repo result maps.
  """
  @spec generate(list(map())) :: String.t()
  def generate([]) do
    """
    # Semver vs Commit Message Analysis Report

    No data available. Run `mix research.analyze` first.
    """
  end

  def generate(results) do
    by_language =
      results
      |> Enum.filter(& &1[:comparisons])
      |> Enum.group_by(& &1.language)
      |> Enum.sort_by(fn {lang, _} -> lang end)

    header = """
    # Semver vs Commit Message Analysis Report

    How well does semver jump type (PATCH/MINOR/MAJOR) agree with
    conventional commit message majority vote for the same transitions?

    Coverage  = % of analyzed repos where the method assigns a label
    Agreement = % of transitions where both methods agree (excl. :mixed/:unclassifiable)
    CC Ratio  = average ratio of commits using conventional commit format

    """

    table_header =
      "| Language         | Repos | Semver Coverage | CC Coverage | Agreement Rate | Avg CC Ratio |\n"

    table_sep =
      "|------------------|-------|----------------|-------------|----------------|--------------|\n"

    rows =
      Enum.map(by_language, fn {lang, repos} ->
        total = length(repos)
        semver_cov = Enum.count(repos, & &1.semver_classifiable)
        cc_cov = Enum.count(repos, fn r -> (r[:conventional_commit_ratio] || 0.0) > 0.3 end)

        all_comps = Enum.flat_map(repos, &(&1[:comparisons] || []))
        both_classifiable = Enum.filter(all_comps, & &1.commits_classifiable)
        agreements = Enum.count(both_classifiable, & &1.agreement)

        agreement_str =
          if length(both_classifiable) > 0,
            do:
              "#{round(agreements / length(both_classifiable) * 100)}% (#{agreements}/#{length(both_classifiable)})",
            else: "N/A"

        avg_cc =
          if total > 0 do
            total_ratio =
              Enum.reduce(repos, 0.0, &((&1[:conventional_commit_ratio] || 0.0) + &2))

            Float.round(total_ratio / total, 2)
          else
            0.0
          end

        "| #{String.pad_trailing(lang, 16)} | #{String.pad_leading("#{total}", 5)} | " <>
          "#{String.pad_leading("#{semver_cov}/#{total}", 14)} | " <>
          "#{String.pad_leading("#{cc_cov}/#{total}", 11)} | " <>
          "#{String.pad_trailing(agreement_str, 14)} | #{avg_cc} |\n"
      end)

    details =
      Enum.map_join(by_language, "\n", fn {lang, repos} ->
        language_detail(lang, repos)
      end)

    header <> table_header <> table_sep <> Enum.join(rows) <> "\n---\n\n" <> details
  end

  defp language_detail(lang, repos) do
    all_comps = Enum.flat_map(repos, &(&1[:comparisons] || []))
    both_classifiable = Enum.filter(all_comps, & &1.commits_classifiable)

    confusion =
      both_classifiable
      |> Enum.reject(& &1.agreement)
      |> Enum.group_by(fn c -> {c.jump, c.commits} end)
      |> Enum.map(fn {{semver, commits}, items} ->
        "  semver=#{semver} vs commits=#{commits}: #{length(items)} cases"
      end)
      |> Enum.join("\n")

    """
    ## #{String.upcase(lang)}

    Repos analyzed: #{length(repos)}
    Disagreement breakdown (where both methods produce a label):
    #{if confusion == "", do: "  (no disagreements, or insufficient data)", else: confusion}
    """
  end
end
