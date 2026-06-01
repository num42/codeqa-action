defmodule CodeQA.Metrics.PostProcessing.Menzerath do
  @moduledoc """
  Measures structural hierarchy conformance using Menzerath's law.

  ## Block-level score

  For each parsed block in a file, computes:

      ratio = block.line_count / parent.line_count

  Root blocks use the file's line count as parent. Ratio close to 1.0 means the block
  dominates its parent (poor decomposition). Low ratio means the block is small relative
  to its parent (good decomposition).

  For internal nodes that have children, also computes `avg_child_ratio` — the mean ratio
  of direct children. High `avg_child_ratio` means this node failed to decompose its
  children into small enough pieces.

  ## Codebase-level score

  Collects `{function_count, avg_function_lines}` pairs from all files and computes:
  - Pearson correlation (negative = law holds across the codebase)
  - Power-law exponent `b` from `y = a · x^b` fit on log-log scale
  - R² of the fit
  """

  @behaviour CodeQA.Metrics.PostProcessing.PostProcessingMetric

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Languages.Unknown

  @violation_threshold 0.6

  @impl true
  def name, do: "menzerath"

  @impl true
  def analyze(pipeline_result, files_map, _opts) do
    file_scores =
      Map.new(files_map, fn {path, content} ->
        {path, %{"menzerath" => score_file(content)}}
      end)

    codebase_score = compute_codebase_score(pipeline_result)

    %{
      "files" => file_scores,
      "codebase" => %{"menzerath" => codebase_score}
    }
  end

  # --- file-level scoring ---

  defp score_file("") do
    %{
      "blocks" => [],
      "mean_ratio" => 0.0,
      "max_ratio" => 0.0,
      "violation_count" => 0,
      "insight" => "Empty file."
    }
  end

  defp score_file(content) do
    file_lines = content |> String.split("\n") |> length()
    root_tokens = TokenNormalizer.normalize_structural(content)
    top_nodes = Parser.detect_blocks(root_tokens, Unknown)

    blocks = Enum.map(top_nodes, &score_node(&1, file_lines))
    all_ratios = collect_ratios(blocks)
    n = length(all_ratios)

    mean_ratio = if(n == 0, do: 0.0, else: round4(Enum.sum(all_ratios) / n))
    max_ratio = if(n == 0, do: 0.0, else: round4(Enum.max(all_ratios)))
    violation_count = Enum.count(all_ratios, &(&1 >= @violation_threshold))

    %{
      "blocks" => blocks,
      "mean_ratio" => mean_ratio,
      "max_ratio" => max_ratio,
      "violation_count" => violation_count,
      "insight" => file_insight(mean_ratio, max_ratio, violation_count, length(top_nodes))
    }
  end

  defp file_insight(_mean, _max, _violations, 0),
    do: "No blocks detected."

  defp file_insight(_mean, _max, 0, _block_count),
    do: "Well decomposed — all blocks are small relative to their parents."

  defp file_insight(_mean, max_ratio, violations, _block_count) when max_ratio >= 0.9,
    do:
      "#{violations} block(s) nearly span the entire file — the file is not decomposed into meaningful pieces."

  defp file_insight(mean_ratio, _max, violations, _block_count) when mean_ratio >= 0.5,
    do:
      "#{violations} violation(s); blocks are large on average (mean ratio #{mean_ratio}) — the file likely needs to be split or its blocks extracted."

  defp file_insight(_mean, _max, violations, _block_count),
    do:
      "#{violations} block(s) dominate their parent context — consider extracting those into separate functions or modules."

  defp score_node(node, parent_lines) do
    ratio = if parent_lines > 0, do: round4(node.line_count / parent_lines), else: 0.0

    children = Enum.map(node.children, &score_node(&1, node.line_count))

    base = %{
      "start_line" => node.start_line,
      "end_line" => node.end_line,
      "line_count" => node.line_count,
      "parent_lines" => parent_lines,
      "ratio" => ratio,
      "insight" => block_insight(ratio, []),
      "children" => children
    }

    case children do
      [] ->
        base

      kids ->
        child_ratios = Enum.map(kids, & &1["ratio"])
        avg = round4(Enum.sum(child_ratios) / length(child_ratios))

        base
        |> Map.put("avg_child_ratio", avg)
        |> Map.put("insight", block_insight(ratio, avg_child_ratio: avg))
    end
  end

  defp block_insight(ratio, opts) do
    avg_child_ratio = Keyword.get(opts, :avg_child_ratio)

    cond do
      ratio >= 0.9 ->
        "Block spans nearly the entire parent — no meaningful decomposition at this level."

      (ratio >= @violation_threshold and avg_child_ratio) &&
          avg_child_ratio >= @violation_threshold ->
        "Block is large relative to its parent and its own children are also large — nested decomposition failure."

      ratio >= @violation_threshold ->
        "Block is large relative to its parent — consider splitting or extracting."

      avg_child_ratio && avg_child_ratio >= @violation_threshold ->
        "Block is reasonably sized but its children are too large — this block should be broken down further."

      true ->
        nil
    end
  end

  defp collect_ratios(blocks) do
    Enum.flat_map(blocks, fn block ->
      [block["ratio"] | collect_ratios(block["children"])]
    end)
  end

  # --- codebase-level scoring ---

  defp compute_codebase_score(pipeline_result) do
    pairs =
      pipeline_result
      |> Map.get("files", %{})
      |> Enum.flat_map(fn {_path, file_data} ->
        fm = get_in(file_data, ["metrics", "function_metrics"]) || %{}
        count = fm["function_count"]
        avg = fm["avg_function_lines"]

        if is_number(count) and is_number(avg) and count > 0 do
          [{count * 1.0, avg * 1.0}]
        else
          []
        end
      end)

    n = length(pairs)

    if n < 3 do
      %{
        "correlation" => nil,
        "exponent" => nil,
        "r_squared" => nil,
        "sample_size" => n,
        "insight" =>
          "Not enough files with function data to compute Menzerath conformance (need ≥ 3, got #{n})."
      }
    else
      xs = Enum.map(pairs, &elem(&1, 0))
      ys = Enum.map(pairs, &elem(&1, 1))
      correlation = round4(pearson(xs, ys))
      {exponent, r_squared} = fit_power_law(xs, ys)

      %{
        "correlation" => correlation,
        "exponent" => if(exponent, do: round4(exponent), else: nil),
        "r_squared" => if(r_squared, do: round4(r_squared), else: nil),
        "sample_size" => n,
        "insight" => codebase_insight(correlation, r_squared)
      }
    end
  end

  defp codebase_insight(correlation, r_squared) do
    fit_quality = if r_squared && r_squared >= 0.5, do: " (strong fit, R²=#{r_squared})", else: ""

    cond do
      correlation <= -0.3 ->
        "Menzerath's law holds#{fit_quality} — larger files tend to have shorter functions, indicating healthy decomposition."

      correlation >= 0.3 ->
        "Menzerath's law violated#{fit_quality} — larger files have longer functions. Files are growing without being decomposed; consider splitting large files or extracting functions."

      true ->
        "Weak Menzerath signal (correlation #{correlation}) — no clear relationship between file size and function length. Decomposition patterns are inconsistent across the codebase."
    end
  end

  defp pearson(xs, ys) do
    n = length(xs)
    sum_x = Enum.sum(xs)
    sum_y = Enum.sum(ys)
    sum_xy = Enum.zip(xs, ys) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    sum_x2 = Enum.reduce(xs, 0.0, fn x, acc -> acc + x * x end)
    sum_y2 = Enum.reduce(ys, 0.0, fn y, acc -> acc + y * y end)

    num = n * sum_xy - sum_x * sum_y
    den = :math.sqrt((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y))

    if den == 0.0, do: 0.0, else: num / den
  end

  defp fit_power_law(xs, ys) do
    # Linearize: log(y) = log(a) + b * log(x), fit via OLS on log-log scale
    pairs =
      Enum.zip(xs, ys)
      |> Enum.filter(fn {x, y} -> x > 0 and y > 0 end)

    if length(pairs) < 2 do
      {nil, nil}
    else
      log_xs = Enum.map(pairs, fn {x, _} -> :math.log(x) end)
      log_ys = Enum.map(pairs, fn {_, y} -> :math.log(y) end)

      n = length(pairs)
      sum_lx = Enum.sum(log_xs)
      sum_ly = Enum.sum(log_ys)
      sum_lx2 = Enum.reduce(log_xs, 0.0, fn x, acc -> acc + x * x end)
      sum_lxly = Enum.zip(log_xs, log_ys) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)

      denom = n * sum_lx2 - sum_lx * sum_lx

      if denom == 0.0 do
        {nil, nil}
      else
        fit_power_law_coefficients(log_xs, log_ys, sum_lx, sum_ly, sum_lxly, n, denom)
      end
    end
  end

  defp fit_power_law_coefficients(log_xs, log_ys, sum_lx, sum_ly, sum_lxly, n, denom) do
    b = (n * sum_lxly - sum_lx * sum_ly) / denom
    log_a = (sum_ly - b * sum_lx) / n
    mean_ly = sum_ly / n

    ss_tot = Enum.reduce(log_ys, 0.0, fn ly, acc -> acc + (ly - mean_ly) ** 2 end)

    ss_res =
      Enum.zip(log_xs, log_ys)
      |> Enum.reduce(0.0, fn {lx, ly}, acc ->
        acc + (ly - (log_a + b * lx)) ** 2
      end)

    r_squared = if ss_tot == 0.0, do: 0.0, else: 1.0 - ss_res / ss_tot
    {b, r_squared}
  end

  defp round4(v), do: Float.round(v * 1.0, 4)
end
