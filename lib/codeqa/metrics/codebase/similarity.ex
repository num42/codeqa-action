defmodule CodeQA.Metrics.Codebase.Similarity do
  @moduledoc """
  Detects cross-file code duplication at the codebase level.

  Uses winnowing fingerprints and locality-sensitive hashing (LSH) to identify
  candidate pairs, then scores them with normalized compression distance (NCD).
  Reports per-pair similarity scores and an overall cross-file density metric.

  See [winnowing](https://theory.stanford.edu/~aiken/publications/papers/sigmod03.pdf),
  [locality-sensitive hashing](https://en.wikipedia.org/wiki/Locality-sensitive_hashing),
  and [normalized compression distance](https://en.wikipedia.org/wiki/Normalized_compression_distance).
  """

  @behaviour CodeQA.Metrics.Codebase.CodebaseMetric

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.CLI.UI
  alias CodeQA.Metrics.File.Winnowing

  @impl true
  def name, do: "similarity"

  def keys, do: ["ncd_pairs", "cross_file_density"]

  @spec analyze(map(), keyword()) :: map()
  @impl true
  def analyze(files, opts \\ [])

  def analyze(files, _opts) when map_size(files) < 2 do
    %{"ncd_pairs" => %{}, "cross_file_density" => 0.0}
  end

  def analyze(files, opts) do
    names = Map.keys(files)
    contents = Map.values(files)
    has_progress = Keyword.has_key?(opts, :on_progress)

    if has_progress, do: IO.puts(:stderr, "  Computing cross-file density...")

    result = %{
      "cross_file_density" => cross_file_density(contents)
    }

    if Keyword.get(opts, :show_ncd, false) do
      Map.put(result, "ncd_pairs", compute_ncd(names, contents, opts))
    else
      result
    end
  end

  defp compute_ncd(names, contents, opts) do
    target_paths = Keyword.get(opts, :ncd_paths)
    target_paths = if target_paths in [nil, []], do: names, else: target_paths
    target_set = MapSet.new(target_paths)
    top_n = Keyword.get(opts, :ncd_top)
    threshold = Keyword.get(opts, :ncd_threshold, 0.20)
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    has_progress = Keyword.has_key?(opts, :on_progress)

    fingerprints_by_id = generate_fingerprints(contents, opts, workers, has_progress)
    inverted_index = build_inverted_index(fingerprints_by_id, has_progress)

    filtered_pairs =
      find_candidate_pairs(
        fingerprints_by_id,
        inverted_index,
        names,
        target_set,
        threshold,
        workers,
        has_progress
      )

    computed_ncd = compute_exact_ncd(filtered_pairs, contents, workers, has_progress)
    build_results_map(computed_ncd, target_paths, target_set, top_n)
  end

  defp generate_fingerprints(contents, opts, workers, has_progress) do
    if has_progress, do: IO.puts(:stderr, "  2/5 Computing Winnowing fingerprints...")

    result =
      contents
      |> Enum.with_index()
      |> Task.async_stream(
        fn {content, i} ->
          fp = compute_fingerprints(content, opts)
          {i, fp}
        end,
        max_concurrency: workers,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, {i, fp}} ->
        maybe_print_fingerprint_progress(has_progress, i, length(contents))
        {i, fp}
      end)
      |> Map.new()

    if has_progress, do: IO.puts(:stderr, "")
    result
  end

  defp maybe_print_fingerprint_progress(false, _i, _total), do: :ok

  defp maybe_print_fingerprint_progress(true, i, total) do
    if rem(i + 1, max(1, div(total, 20))) == 0 do
      IO.write(:stderr, "\r" <> UI.progress_bar(i + 1, total, label: "Fingerprinting"))
    end
  end

  defp build_inverted_index(fingerprints_by_id, has_progress) do
    if has_progress, do: IO.puts(:stderr, "  3/5 Building inverted index...")

    total = map_size(fingerprints_by_id)

    result =
      fingerprints_by_id
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {{i, set}, idx}, acc ->
        maybe_print_index_progress(has_progress, idx, total)
        index_fingerprint_set(set, i, acc)
      end)

    if has_progress, do: IO.puts(:stderr, "")
    result
  end

  defp index_fingerprint_set(set, doc_id, acc) do
    Enum.reduce(set, acc, fn fp, idx_acc ->
      Map.update(idx_acc, fp, [doc_id], &[doc_id | &1])
    end)
  end

  defp maybe_print_index_progress(false, _idx, _total), do: :ok

  defp maybe_print_index_progress(true, idx, total) do
    if rem(idx + 1, max(1, div(total, 20))) == 0 do
      IO.write(:stderr, "\r" <> UI.progress_bar(idx + 1, total, label: "Indexing"))
    end
  end

  defp find_candidate_pairs(
         fingerprints_by_id,
         inverted_index,
         names,
         target_set,
         threshold,
         workers,
         has_progress
       ) do
    if has_progress, do: IO.puts(:stderr, "  4/5 Identifying candidate pairs...")

    total = map_size(fingerprints_by_id)

    candidates =
      fingerprints_by_id
      |> Enum.with_index()
      |> Task.async_stream(
        fn {{i, set}, idx} ->
          valid_pairs =
            collect_valid_pairs(
              i,
              set,
              inverted_index,
              fingerprints_by_id,
              names,
              target_set,
              threshold
            )

          {idx, valid_pairs}
        end,
        max_concurrency: workers,
        timeout: :infinity
      )
      |> Enum.reduce(%{}, fn {:ok, {idx, valid_pairs}}, acc ->
        maybe_print_lsh_progress(has_progress, idx, total)
        merge_valid_pairs(valid_pairs, acc)
      end)

    if has_progress, do: IO.puts(:stderr, "")

    Enum.map(candidates, fn {{i, j}, jaccard} ->
      {Enum.at(names, i), i, Enum.at(names, j), j, jaccard}
    end)
  end

  defp collect_valid_pairs(
         i,
         set,
         inverted_index,
         fingerprints_by_id,
         names,
         target_set,
         threshold
       ) do
    collisions = count_collisions(set, inverted_index, i)

    size_a = MapSet.size(set)
    name_a = Enum.at(names, i)

    is_target_a = MapSet.member?(target_set, name_a)

    collisions
    |> Enum.filter(fn {j, _} -> is_target_a or MapSet.member?(target_set, Enum.at(names, j)) end)
    |> Enum.reduce([], fn {j, intersection}, acc_pairs ->
      jaccard = compute_jaccard(size_a, MapSet.size(Map.get(fingerprints_by_id, j)), intersection)
      if jaccard >= threshold, do: [{{i, j}, jaccard} | acc_pairs], else: acc_pairs
    end)
  end

  defp compute_jaccard(size_a, size_b, intersection) do
    union = size_a + size_b - intersection
    if union == 0, do: 0.0, else: intersection / union
  end

  defp count_collisions(set, inverted_index, i) do
    Enum.reduce(set, %{}, fn fp, coll_acc ->
      inverted_index |> Map.get(fp, []) |> count_forward_docs(i, coll_acc)
    end)
  end

  defp count_forward_docs(docs, i, acc) do
    Enum.reduce(docs, acc, fn doc_id, c_acc ->
      if doc_id > i, do: Map.update(c_acc, doc_id, 1, &(&1 + 1)), else: c_acc
    end)
  end

  defp merge_valid_pairs(valid_pairs, acc) do
    Enum.reduce(valid_pairs, acc, fn {pair, jaccard}, inner_acc ->
      Map.put(inner_acc, pair, jaccard)
    end)
  end

  defp maybe_print_lsh_progress(false, _idx, _total), do: :ok

  defp maybe_print_lsh_progress(true, idx, total) do
    if rem(idx + 1, max(1, div(total, 20))) == 0 do
      IO.write(:stderr, "\r" <> UI.progress_bar(idx + 1, total, label: "LSH Filter"))
    end
  end

  defp compute_exact_ncd(filtered_pairs, contents, workers, has_progress) do
    total_pairs = length(filtered_pairs)

    if has_progress and total_pairs > 0 do
      IO.puts(:stderr, "  5/5 Computing exact NCD for #{total_pairs} candidate pairs...")
    end

    precomputed =
      contents
      |> Enum.map(fn c -> {c, byte_size(:zlib.compress(c))} end)
      |> List.to_tuple()

    counter = :counters.new(1, [:atomics])
    start_time_ncd = System.monotonic_time(:millisecond)

    filtered_pairs
    |> Task.async_stream(
      fn {name_a, i, name_b, j, _jaccard} ->
        ncd = compute_single_ncd(precomputed, i, j)
        maybe_print_ncd_progress(has_progress, counter, total_pairs, start_time_ncd)
        {name_a, name_b, ncd}
      end,
      max_concurrency: workers,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  defp compute_single_ncd(precomputed, i, j) do
    {a, ca} = elem(precomputed, i)
    {b, cb} = elem(precomputed, j)
    cab = byte_size(:zlib.compress([a, b]))
    ncd = if max(ca, cb) > 0, do: (cab - min(ca, cb)) / max(ca, cb), else: 0.0
    Float.round(ncd, 4)
  end

  defp maybe_print_ncd_progress(false, _counter, _total_pairs, _start_time), do: :ok

  defp maybe_print_ncd_progress(true, counter, total_pairs, start_time_ncd) do
    :counters.add(counter, 1, 1)
    c = :counters.get(counter, 1)

    if rem(c, max(1, div(total_pairs, 100))) == 0 or c == total_pairs do
      now = System.monotonic_time(:millisecond)
      elapsed = max(now - start_time_ncd, 1)
      avg_time = elapsed / c
      eta_ms = round((total_pairs - c) * avg_time)

      output =
        UI.progress_bar(c, total_pairs,
          eta: UI.format_eta(eta_ms),
          label: "NCD Compression"
        )

      IO.write(:stderr, "\r" <> output)

      if c == total_pairs, do: IO.puts(:stderr, "")
    end
  end

  defp build_results_map(computed_ncd, target_paths, target_set, top_n) do
    results =
      Enum.reduce(computed_ncd, %{}, fn {name_a, name_b, ncd}, acc ->
        acc = maybe_add_similarity(acc, name_a, name_b, ncd, target_set)
        maybe_add_similarity(acc, name_b, name_a, ncd, target_set)
      end)

    target_paths
    |> Enum.map(fn path ->
      similarities = Map.get(results, path, [])
      sorted = Enum.sort_by(similarities, & &1["score"])
      sorted = if top_n, do: Enum.take(sorted, top_n), else: sorted
      {path, sorted}
    end)
    |> Enum.into(%{})
  end

  defp maybe_add_similarity(acc, path, other_path, ncd, target_set) do
    if MapSet.member?(target_set, path) do
      Map.update(
        acc,
        path,
        [%{"path" => other_path, "score" => ncd}],
        &[%{"path" => other_path, "score" => ncd} | &1]
      )
    else
      acc
    end
  end

  defp compute_fingerprints(content, _opts) do
    content
    |> TokenNormalizer.normalize_structural()
    |> Enum.map(& &1.kind)
    |> Winnowing.kgrams(5)
    |> MapSet.new()
  end

  defp cross_file_density(contents) do
    individual_sum =
      contents
      |> Enum.map(fn c -> byte_size(:zlib.compress(c)) end)
      |> Enum.sum()

    joined = Enum.intersperse(contents, "\n")
    combined = byte_size(:zlib.compress(joined))

    Float.round(individual_sum / max(1, combined), 4)
  end
end
