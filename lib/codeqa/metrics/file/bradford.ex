defmodule CodeQA.Metrics.File.Bradford do
  @moduledoc """
  Applies Bradford's concentration law to token density across lines.

  Lines are ranked by token count (densest first), then grouped into three
  zones of equal total tokens. The ratio between zone sizes gives Bradford's
  k values: how many more lines each successive zone needs to match the
  token yield of the previous one.

      k ≈ 1    uniform density — tokens spread evenly across lines
      k = 3–5  Bradford-like — a small dense core, long sparse tail
      k >> 5   extreme concentration — a few lines carry almost all tokens

  k1 = zone2_lines / zone1_lines  (core → middle transition)
  k2 = zone3_lines / zone2_lines  (middle → tail transition)
  k_ratio = k2 / k1               (> 1 means tail is more stretched than core)

  In a perfect Bradford distribution k1 ≈ k2. In practice k2 > k1 is common
  (moderate core, very stretched tail); k1 > k2 suggests extreme concentration
  that levels off quickly.

  See [Bradford's law](https://en.wikipedia.org/wiki/Bradford%27s_law).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "bradford"

  @impl true
  def keys, do: ["k1", "k2", "k_ratio"]

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{tokens: []}) do
    %{"k1" => 0.0, "k2" => 0.0, "k_ratio" => 0.0}
  end

  def analyze(%{tokens: tokens}) do
    # Count tokens per line using the .line field, then rank densest-first —
    # this is Bradford's "sort sources by yield" step.
    counts =
      tokens
      |> Enum.group_by(& &1.line)
      |> Enum.map(fn {_line, toks} -> length(toks) end)
      |> Enum.sort(:desc)

    total = Enum.sum(counts)

    # Need at least 3 lines and 3 tokens to form meaningful zones.
    if total < 3 or length(counts) < 3 do
      %{"k1" => 0.0, "k2" => 0.0, "k_ratio" => 0.0}
    else
      # Each zone should contain one third of all tokens.
      # We find zone boundaries by walking the ranked list until each third is filled.
      third = total / 3

      # n1: lines in zone 1 (the dense core — fewest lines, highest token density)
      # n2: lines in zone 2 (middle tier)
      # n3: all remaining lines (the sparse tail)
      {n1, rest} = count_until(counts, third)
      {n2, _} = count_until(rest, third)
      n3 = length(counts) - n1 - n2

      # k1 > 1 always: the middle zone always needs more lines than the core.
      # Higher k1 = more extreme concentration in the core (fewer lines do more work).
      k1 = if n1 > 0, do: Float.round(n2 / n1, 4), else: 0.0

      # k2 > 1 always: the tail always needs more lines than the middle.
      # Higher k2 = longer sparse tail relative to the middle zone.
      k2 = if n2 > 0, do: Float.round(n3 / n2, 4), else: 0.0

      # k_ratio = k2 / k1
      # > 1: the tail is more stretched than the core is concentrated (common — many trivial lines)
      # < 1: the core is more extreme than the tail is sparse (god-function pattern)
      # ≈ 1: a clean Bradford distribution where each zone multiplies evenly
      k_ratio = if k1 > 0, do: Float.round(k2 / k1, 4), else: 0.0

      %{"k1" => k1, "k2" => k2, "k_ratio" => k_ratio}
    end
  end

  # Walks the density-ranked list, consuming lines until the accumulated token
  # count reaches the zone target. Returns {lines_consumed, remaining_list}.
  # The remaining list is passed directly to the next zone's count_until call,
  # so zones are computed in a single linear pass over the sorted counts.
  defp count_until(counts, target), do: do_count(counts, target, 0, 0)

  defp do_count([], _target, n, _acc), do: {n, []}

  defp do_count([h | rest], target, n, acc) do
    new_acc = acc + h
    # Once we've accumulated enough tokens to fill the zone, stop and return
    # the remainder so the next zone can continue from where we left off.
    if new_acc >= target,
      do: {n + 1, rest},
      else: do_count(rest, target, n + 1, new_acc)
  end
end
