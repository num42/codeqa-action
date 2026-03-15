defmodule CodeQA.Metrics.Vocabulary do
  @moduledoc """
  Analyzes vocabulary diversity using type-token ratio (TTR) and MATTR.

  TTR measures the ratio of unique identifiers to total identifiers. MATTR
  (moving-average TTR) smooths this over a sliding window to reduce sensitivity
  to file length. Also reports the sorted vocabulary list.

  `ctx.identifiers` contains raw identifier strings (e.g. `fooBar`); `ctx.words`
  contains the extracted sub-word tokens (e.g. `foo`, `bar`) used for vocabulary
  building.

  See [type-token ratio](https://en.wikipedia.org/wiki/Lexical_density)
  and [MATTR](https://doi.org/10.3758/BRM.42.2.381).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "vocabulary"

  @impl true
  def keys, do: ["raw_ttr", "mattr", "unique_identifiers", "total_identifiers", "vocabulary"]


  @window_size 100

  @spec analyze(map()) :: map()
  @impl true
  def analyze(ctx) do
    identifiers = Tuple.to_list(ctx.identifiers)
    total = length(identifiers)
    vocabulary = ctx.words |> Tuple.to_list() |> Enum.uniq() |> Enum.sort()

    if total == 0 do
      %{
        "raw_ttr" => 0.0,
        "mattr" => 0.0,
        "unique_identifiers" => 0,
        "total_identifiers" => 0,
        "vocabulary" => vocabulary
      }
    else
      unique = identifiers |> MapSet.new() |> MapSet.size()
      raw_ttr = unique / total
      mattr = compute_mattr(identifiers, total)

      %{
        "raw_ttr" => raw_ttr,
        "mattr" => mattr,
        "unique_identifiers" => unique,
        "total_identifiers" => total,
        "vocabulary" => vocabulary
      }
    end
  end

  defp compute_mattr(identifiers, total) when total < @window_size do
    length(Enum.uniq(identifiers)) / max(total, 1)
  end

  defp compute_mattr(identifiers, _total) do
    # Rolling frequency map optimization: O(N) instead of O(N*K)
    # Start with the first window
    {first_window, rest} = Enum.split(identifiers, @window_size)
    initial_freqs = Enum.frequencies(first_window)
    initial_count = map_size(initial_freqs)

    # Use a recursive reducer to slide the window
    # identifiers: the list we slide over
    # trailing: the list of items to remove as we slide
    # current_freqs: current counts of words in window
    # current_unique: current number of unique keys (Map.size)
    # sum: total sum of unique counts for averaging

    {sum, count} = slide_window(rest, identifiers, initial_freqs, initial_count, initial_count, 1)

    sum / count / @window_size
  end

  defp slide_window([], _outgoing_list, _freqs, _unique, sum, count), do: {sum, count}

  defp slide_window(
         [incoming | rest_incoming],
         [outgoing | rest_outgoing],
         freqs,
         unique,
         sum,
         count
       ) do
    # 1. Add incoming word
    new_freqs = Map.update(freqs, incoming, 1, &(&1 + 1))
    new_unique = if Map.get(freqs, incoming) == nil, do: unique + 1, else: unique

    # 2. Remove outgoing word
    final_unique = if Map.get(new_freqs, outgoing) == 1, do: new_unique - 1, else: new_unique

    final_freqs =
      case Map.get(new_freqs, outgoing) do
        1 -> Map.delete(new_freqs, outgoing)
        val -> Map.put(new_freqs, outgoing, val - 1)
      end

    slide_window(
      rest_incoming,
      rest_outgoing,
      final_freqs,
      final_unique,
      sum + final_unique,
      count + 1
    )
  end
end
