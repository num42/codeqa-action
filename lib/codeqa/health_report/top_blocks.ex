defmodule CodeQA.HealthReport.TopBlocks do
  @moduledoc "Assembles the top_blocks report section from analysis node data."

  alias CodeQA.CombinedMetrics.Scorer

  @min_tokens 10
  @severity_critical 0.50
  @severity_high 0.25
  @severity_medium 0.10
  @gap_floor 0.01
  @top_n 10
  @default_min_lines 3
  @default_max_lines 20

  defp build_fix_hint_lookup do
    Scorer.all_yamls()
    |> Enum.flat_map(fn {yaml_path, data} ->
      category = yaml_path |> Path.basename() |> String.trim_trailing(".yml")
      Enum.flat_map(data, &hints_for_behavior(category, &1))
    end)
    |> Map.new()
  end

  defp hints_for_behavior(category, {behavior, behavior_data}) when is_map(behavior_data) do
    case Map.get(behavior_data, "_fix_hint") do
      nil -> []
      hint -> [{{category, behavior}, hint}]
    end
  end

  defp hints_for_behavior(_category, _entry), do: []

  @spec build(map(), [struct()], map(), keyword()) :: [map()]
  def build(analysis_results, changed_files, codebase_cosine_lookup, opts \\ []) do
    base_path = get_in(analysis_results, ["metadata", "path"]) || "."

    analysis_results
    |> collect_enriched_blocks(changed_files, codebase_cosine_lookup, opts)
    # Rank by highest cosine_delta and take top N
    |> Enum.sort_by(&(-max_delta(&1)))
    |> Enum.take(@top_n)
    # Add source code for each block
    |> Enum.map(&add_source_code(&1, base_path))
  end

  @doc """
  Returns a map of category => worst offending block for that category.
  Only includes blocks that overlap with the diff (if diff_line_ranges provided).
  """
  @spec worst_per_category(map(), [struct()], map(), keyword()) :: %{String.t() => map()}
  def worst_per_category(analysis_results, changed_files, codebase_cosine_lookup, opts \\ []) do
    base_path = get_in(analysis_results, ["metadata", "path"]) || "."

    all_blocks =
      collect_enriched_blocks(analysis_results, changed_files, codebase_cosine_lookup, opts)

    # Group blocks by category, finding the worst block per category
    all_blocks
    |> Enum.flat_map(fn block ->
      # Each block may contribute to multiple categories via its potentials
      block.potentials
      |> Enum.map(fn potential ->
        {potential.category, block, potential.cosine_delta}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), fn {_cat, block, delta} -> {block, delta} end)
    |> Enum.map(fn {category, block_deltas} ->
      # Find the block with highest cosine_delta for this category
      {worst_block, _delta} = Enum.max_by(block_deltas, fn {_block, delta} -> delta end)
      {category, add_source_code(worst_block, base_path)}
    end)
    |> Map.new()
  end

  # Shared logic for collecting and enriching blocks
  defp collect_enriched_blocks(analysis_results, changed_files, codebase_cosine_lookup, opts) do
    files = Map.get(analysis_results, "files", %{})
    fix_hints = build_fix_hint_lookup()

    min_lines = Keyword.get(opts, :block_min_lines, @default_min_lines)
    max_lines = Keyword.get(opts, :block_max_lines, @default_max_lines)
    diff_line_ranges = Keyword.get(opts, :diff_line_ranges, %{})

    file_entries =
      if changed_files == [] do
        Enum.map(files, fn {path, data} -> {path, nil, data} end)
      else
        changed_index = Map.new(changed_files, &{&1.path, &1.status})

        files
        |> Enum.filter(fn {path, _} -> Map.has_key?(changed_index, path) end)
        |> Enum.map(fn {path, data} -> {path, Map.get(changed_index, path), data} end)
      end

    # Flatten all blocks across all files, enrich with path
    file_entries
    |> Enum.flat_map(fn {path, status, file_data} ->
      path_diff_ranges = Map.get(diff_line_ranges, path, [])

      file_data
      |> Map.get("nodes", [])
      |> Enum.flat_map(&collect_nodes/1)
      |> Enum.filter(&(&1["token_count"] >= @min_tokens))
      |> Enum.filter(&block_in_line_range?(&1, min_lines, max_lines))
      |> filter_by_diff_overlap(path_diff_ranges, diff_line_ranges)
      |> Enum.map(&enrich_block(&1, codebase_cosine_lookup, fix_hints))
      |> Enum.reject(&(&1.potentials == []))
      |> Enum.map(&Map.merge(&1, %{path: path, status: status}))
    end)
  end

  @spec block_in_line_range?(map(), pos_integer(), pos_integer()) :: boolean()
  defp block_in_line_range?(node, min_lines, max_lines) do
    start_line = node["start_line"] || 1
    end_line = node["end_line"] || start_line
    line_count = end_line - start_line + 1
    line_count >= min_lines and line_count <= max_lines
  end

  # When no diff_line_ranges provided (empty map), show all blocks - no filtering needed
  @spec filter_by_diff_overlap([map()], [{pos_integer(), pos_integer()}], map()) :: [map()]
  defp filter_by_diff_overlap(blocks, _path_ranges, diff_line_ranges)
       when map_size(diff_line_ranges) == 0,
       do: blocks

  # When diff_line_ranges provided, filter blocks by overlap
  defp filter_by_diff_overlap(blocks, path_ranges, _diff_line_ranges) do
    Enum.filter(blocks, &block_overlaps_diff?(&1, path_ranges))
  end

  @spec block_overlaps_diff?(map(), [{pos_integer(), pos_integer()}]) :: boolean()
  defp block_overlaps_diff?(_node, []), do: false

  defp block_overlaps_diff?(node, path_ranges) do
    block_start = node["start_line"] || 1
    block_end = node["end_line"] || block_start

    Enum.any?(path_ranges, fn {diff_start, diff_end} ->
      ranges_overlap?(block_start, block_end, diff_start, diff_end)
    end)
  end

  @spec ranges_overlap?(pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: boolean()
  defp ranges_overlap?(start1, end1, start2, end2) do
    start1 <= end2 and start2 <= end1
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

  defp add_source_code(block, base_path) do
    full_path = Path.join(base_path, block.path)
    start_line = block.start_line
    end_line = block.end_line || start_line

    source =
      case File.read(full_path) do
        {:ok, content} ->
          content
          |> String.split("\n")
          |> Enum.slice((start_line - 1)..(end_line - 1)//1)
          |> Enum.join("\n")

        {:error, _} ->
          nil
      end

    lang = CodeQA.Language.detect(block.path).name()
    Map.merge(block, %{source: source, language: lang})
  end
end
