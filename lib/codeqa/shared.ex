defmodule CodeQA.Shared do
  @moduledoc """
  Cross-cutting helpers shared between top-level pipelines.

  Extracted by `mix refactor --only ExtractParametricClone`. Both
  `HealthReport`, `BlockImpactAnalyzer`, and `Diagnostics` were
  reimplementing the same path-to-languages reduction; `SampleRunner` and
  `Grader` were reimplementing the same slug-humanize. Consolidated here
  to one place each.
  """

  alias CodeQA.Language

  @spec project_languages_shared(map()) :: [String.t()]
  def project_languages_shared(path_keyed_map) do
    path_keyed_map
    |> Map.keys()
    |> Enum.map(&Language.detect(&1).name())
    |> Enum.reject(&(&1 == "unknown"))
    |> Enum.uniq()
  end

  @spec humanize_category_shared(String.t()) :: String.t()
  def humanize_category_shared(slug) do
    slug
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
