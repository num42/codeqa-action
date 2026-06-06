defmodule CodeQA.HealthReport.TopBlocks do
  alias CodeQA.Language
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
      data |> Enum.flat_map(&hints_for_behavior(category, &1))
    end)
    |> Map.new()
  end

  defp hints_for_behavior(category, {behavior, behavior_data}) when is_map(behavior_data) do
    Map.get(behavior_data, "_fix_hint") |> wrap_fix_hint(behavior, category)
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
      {worst_block, _delta} = block_deltas |> Enum.max_by(fn {_block, delta} -> delta end)
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
        files |> Enum.map(fn {path, data} -> {path, nil, data} end)
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

      file_blocks =
        file_data
        |> Map.get("nodes", [])
        |> Enum.flat_map(&collect_nodes/1)
        |> dedupe_overlapping()
        |> Enum.filter(
          &(&1["token_count"] >= @min_tokens and block_in_line_range?(&1, min_lines, max_lines))
        )

      # A behavior's cosine_delta is largely file-level: removing one small block
      # barely moves a large file's metric vector, so nearly every block inherits
      # the same per-behavior delta. Subtract that file baseline (the minimum block
      # delta per behavior — the unavoidable file-level floor) so only blocks that
      # genuinely stand out survive. Computed over ALL file blocks, before any diff
      # scoping, so the floor reflects the whole file rather than just the changed
      # region.
      baselines = file_delta_baselines(file_blocks)

      file_blocks
      |> filter_by_diff_overlap(path_diff_ranges, diff_line_ranges)
      |> Enum.map(&enrich_block(&1, codebase_cosine_lookup, fix_hints, baselines))
      |> Enum.reject(&(&1.potentials == []))
      |> Enum.map(&Map.merge(&1, %{path: path, status: status}))
    end)
  end

  # Collapses blocks that cover the exact same line range (the analyzer can emit
  # two overlapping nodes for one span, e.g. a call and its argument list). Keeps
  # the first seen per range. Genuine parent/child nesting is preserved — only
  # identical {start, end} pairs are deduplicated.
  defp dedupe_overlapping(nodes) do
    nodes
    |> Enum.uniq_by(fn n -> {n["start_line"], n["end_line"]} end)
  end

  # Per-behavior file-level floor: the minimum block delta across the file.
  # Only computed when there are enough blocks to distinguish a floor from a
  # genuine signal.
  #
  # A single block carries NO block-specific signal: its delta is purely the
  # file-level cosine (leave-one-out on the only block ≈ removing the whole
  # file's contribution), so it is the worst phantom source. We treat its own
  # delta as the floor → relative delta 0 → filtered.
  defp file_delta_baselines(nodes) do
    nodes
    |> Enum.flat_map(fn n ->
      n
      |> Map.get("refactoring_potentials", [])
      |> Enum.map(&{&1["behavior"], &1["cosine_delta"]})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {behavior, deltas} -> {behavior, floor_for(deltas)} end)
  end

  # n == 1: no comparison possible → floor is the value itself (suppressed).
  # n >= 2: the file-level floor is the minimum block delta.
  defp floor_for([only]), do: only
  defp floor_for(deltas), do: Enum.min(deltas)

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
  defp filter_by_diff_overlap(blocks, path_ranges, _diff_line_ranges),
    do: blocks |> Enum.filter(&block_overlaps_diff?(&1, path_ranges))

  @spec block_overlaps_diff?(map(), [{pos_integer(), pos_integer()}]) :: boolean()
  defp block_overlaps_diff?(_node, []), do: false

  defp block_overlaps_diff?(node, path_ranges) do
    block_start = node["start_line"] || 1
    block_end = node["end_line"] || block_start

    path_ranges
    |> Enum.any?(fn {diff_start, diff_end} ->
      ranges_overlap?(block_start, block_end, diff_start, diff_end)
    end)
  end

  @spec ranges_overlap?(pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: boolean()
  defp ranges_overlap?(start1, end1, start2, end2), do: start1 <= end2 and start2 <= end1

  defp collect_nodes(node) do
    children = node |> Map.get("children", []) |> Enum.flat_map(&collect_nodes/1)
    [node | children]
  end

  defp enrich_block(node, cosine_lookup, fix_hints, baselines) do
    block_vars = block_template_vars(node)

    potentials =
      node
      |> Map.get("refactoring_potentials", [])
      |> Enum.map(&enrich_potential(&1, cosine_lookup, fix_hints, baselines, block_vars))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.cosine_delta, :desc)

    %{
      end_line: node["end_line"],
      potentials: potentials,
      start_line: node["start_line"],
      token_count: node["token_count"],
      type: node["type"]
    }
  end

  defp block_template_vars(node) do
    start_line = node["start_line"] || 1
    end_line = node["end_line"] || start_line

    %{
      "line_count" => end_line - start_line + 1,
      "start_line" => start_line,
      "end_line" => end_line,
      "token_count" => node["token_count"] || 0,
      "char_length" => node["char_length"] || 0,
      "type" => node["type"] || "block"
    }
  end

  defp enrich_potential(p, cosine_lookup, fix_hints, baselines, block_vars) do
    category = p["category"]
    behavior = p["behavior"]
    # Block-relative delta: how far this block stands above the file baseline for
    # this behavior. A block at the file baseline contributes nothing distinctive.
    baseline = Map.get(baselines, behavior, 0.0)
    cosine_delta = max(p["cosine_delta"] - baseline, 0.0)

    codebase_cosine = Map.get(cosine_lookup, {category, behavior}, 0.0)
    gap = max(@gap_floor, 1.0 - codebase_cosine)
    severity = classify(cosine_delta / gap)

    if severity == :filtered do
      nil
    else
      vars = Map.put(block_vars, "severity", severity)
      hint = fix_hints |> Map.get({category, behavior}) |> render_template(vars)

      %{
        behavior: behavior,
        category: category,
        cosine_delta: cosine_delta,
        fix_hint: hint,
        severity: severity
      }
    end
  end

  # Substitutes {{var}} placeholders with block context. Unknown placeholders are
  # left untouched so a typo stays visible rather than silently vanishing.
  defp render_template(nil, _vars), do: nil

  defp render_template(hint, vars) do
    Regex.replace(~r/\{\{(\w+)\}\}/, hint, fn whole, key ->
      case Map.fetch(vars, key) do
        {:ok, value} -> to_string(value)
        :error -> whole
      end
    end)
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

    lang = Language.detect(block.path).name()
    Map.merge(block, %{language: lang, source: source})
  end

  defp wrap_fix_hint(nil, _behavior, _category), do: []

  defp wrap_fix_hint(hint, behavior, category), do: [{{category, behavior}, hint}]
end
