defmodule CodeQA.HealthReport.TopBlocks do
  @moduledoc "Assembles the top_blocks report section from analysis node data."

  alias CodeQA.CombinedMetrics.Scorer

  @min_tokens 10
  @severity_critical 0.50
  @severity_high 0.25
  @severity_medium 0.10
  @gap_floor 0.01

  @spec build(map(), [struct()], map()) :: [map()]
  def build(analysis_results, changed_files, codebase_cosine_lookup) do
    files = Map.get(analysis_results, "files", %{})
    fix_hints = build_fix_hint_lookup()

    file_entries =
      if changed_files == [] do
        Enum.map(files, fn {path, data} -> {path, nil, data} end)
      else
        changed_index = Map.new(changed_files, &{&1.path, &1.status})

        files
        |> Enum.filter(fn {path, _} -> Map.has_key?(changed_index, path) end)
        |> Enum.map(fn {path, data} -> {path, Map.get(changed_index, path), data} end)
      end

    file_entries
    |> Enum.map(fn {path, status, file_data} ->
      blocks =
        file_data
        |> Map.get("nodes", [])
        |> Enum.flat_map(&collect_nodes/1)
        |> Enum.filter(&(&1["token_count"] >= @min_tokens))
        |> Enum.map(&enrich_block(&1, codebase_cosine_lookup, fix_hints))
        |> Enum.reject(&(&1.potentials == []))
        |> Enum.sort_by(&(-max_delta(&1)))

      %{path: path, status: status, blocks: blocks}
    end)
    |> Enum.reject(&(&1.blocks == []))
    |> Enum.sort_by(& &1.path)
  end

  defp collect_nodes(node) do
    children = node |> Map.get("children", []) |> Enum.flat_map(&collect_nodes/1)
    [node | children]
  end

  defp enrich_block(node, cosine_lookup, fix_hints) do
    potentials =
      node
      |> Map.get("refactoring_potentials", [])
      |> Enum.map(&enrich_potential(&1, cosine_lookup, fix_hints))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.cosine_delta, :desc)

    %{
      start_line: node["start_line"],
      end_line: node["end_line"],
      type: node["type"],
      token_count: node["token_count"],
      potentials: potentials
    }
  end

  defp enrich_potential(p, cosine_lookup, fix_hints) do
    category = p["category"]
    behavior = p["behavior"]
    cosine_delta = p["cosine_delta"]

    codebase_cosine = Map.get(cosine_lookup, {category, behavior}, 0.0)
    gap = max(@gap_floor, 1.0 - codebase_cosine)
    severity = classify(cosine_delta / gap)

    if severity == :filtered do
      nil
    else
      %{
        category: category,
        behavior: behavior,
        cosine_delta: cosine_delta,
        severity: severity,
        fix_hint: Map.get(fix_hints, {category, behavior})
      }
    end
  end

  defp classify(ratio) when ratio > @severity_critical, do: :critical
  defp classify(ratio) when ratio > @severity_high, do: :high
  defp classify(ratio) when ratio > @severity_medium, do: :medium
  defp classify(_ratio), do: :filtered

  defp max_delta(%{potentials: []}), do: 0.0

  defp max_delta(%{potentials: potentials}),
    do: Enum.max_by(potentials, & &1.cosine_delta).cosine_delta

  defp build_fix_hint_lookup do
    Scorer.all_yamls()
    |> Enum.flat_map(fn {yaml_path, data} ->
      category = yaml_path |> Path.basename() |> String.trim_trailing(".yml")

      Enum.flat_map(data, fn {behavior, behavior_data} ->
        case get_in(behavior_data, ["_fix_hint"]) do
          nil -> []
          hint -> [{{category, behavior}, hint}]
        end
      end)
    end)
    |> Map.new()
  end
end
