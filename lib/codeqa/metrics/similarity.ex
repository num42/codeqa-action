defmodule CodeQA.Metrics.Similarity do
  @moduledoc """
  Detects cross-file code duplication at the codebase level.

  Uses winnowing fingerprints and locality-sensitive hashing (LSH) to identify
  candidate pairs, then scores them with normalized compression distance (NCD).
  Reports per-pair similarity scores and an overall cross-file density metric.

  See [winnowing](https://theory.stanford.edu/~aiken/publications/papers/sigmod03.pdf),
  [locality-sensitive hashing](https://en.wikipedia.org/wiki/Locality-sensitive_hashing),
  and [normalized compression distance](https://en.wikipedia.org/wiki/Normalized_compression_distance).
  """

  @behaviour CodeQA.Metrics.CodebaseMetric

  # Number of tokens per k-gram window used in Winnowing fingerprinting.
  @kgram_size 5

  # Jaccard similarity threshold below which a candidate pair is discarded before NCD.
  @default_ncd_threshold 0.20

  # Decimal places for NCD scores.
  @ncd_precision 4

  # Progress is printed every 1/@progress_steps of total work (5% increments).
  @progress_steps 20

  # NCD progress is printed every 1/100 of pairs (1% increments).
  @ncd_progress_steps 100

  @impl true
  def name, do: "similarity"

  @impl true
  def analyze(files, opts \\ [])

  def analyze(files, _opts) when map_size(files) < 2 do
    %{"ncd_pairs" => %{}, "cross_file_density" => 0.0}
  end

  def analyze(files, opts) do
    names = Map.keys(files)
    contents = Map.values(files)

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
    threshold = Keyword.get(opts, :ncd_threshold, @default_ncd_threshold)
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

    total = length(contents)

    result =
      CodeQA.Telemetry.time(:ncd_fingerprinting, fn ->
        contents
        |> Enum.with_index()
        |> Task.async_stream(&fingerprint_indexed_content(&1, opts), max_concurrency: workers, timeout: :infinity)
        |> Enum.map(fn {:ok, {i, fp}} ->
          maybe_print_fingerprint_progress(has_progress, i, total)
          {i, fp}
        end)
        |> Map.new()
      end)

    if has_progress, do: IO.puts(:stderr, "")
    result
  end

  defp fingerprint_indexed_content({content, i}, opts), do: {i, compute_fingerprints(content, opts)}

  defp maybe_print_fingerprint_progress(has_progress, i, total),
    do: maybe_print_step_progress(has_progress, i + 1, total, "Fingerprinting")

  defp build_inverted_index(fingerprints_by_id, has_progress) do
    if has_progress, do: IO.puts(:stderr, "  3/5 Building inverted index...")

    total = map_size(fingerprints_by_id)

    result =
      CodeQA.Telemetry.time(:ncd_build_index, fn ->
        fingerprints_by_id
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {{i, set}, index}, acc ->
          maybe_print_index_progress(has_progress, index, total)
          index_fingerprint_set(set, i, acc)
        end)
      end)

    if has_progress, do: IO.puts(:stderr, "")
    result
  end

  # Maps each fingerprint hash → list of doc_ids that contain it, for fast collision lookup.
  defp index_fingerprint_set(set, doc_id, acc) do
    Enum.reduce(set, acc, fn fp, idx_acc ->
      Map.update(idx_acc, fp, [doc_id], &[doc_id | &1])
    end)
  end

  defp maybe_print_index_progress(has_progress, index, total),
    do: maybe_print_step_progress(has_progress, index + 1, total, "Indexing")

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
      CodeQA.Telemetry.time(:ncd_lsh_filter, fn ->
        fingerprints_by_id
        |> Enum.with_index()
        |> Task.async_stream(
          &pairs_for_indexed_doc(&1, inverted_index, fingerprints_by_id, names, target_set, threshold),
          max_concurrency: workers, timeout: :infinity)
        |> Enum.reduce(%{}, fn {:ok, {index, valid_pairs}}, acc ->
          maybe_print_lsh_progress(has_progress, index, total)
          merge_valid_pairs(valid_pairs, acc)
        end)
      end)

    if has_progress, do: IO.puts(:stderr, "")

    Enum.map(candidates, fn {{i, j}, jaccard} ->
      {Enum.at(names, i), i, Enum.at(names, j), j, jaccard}
    end)
  end

  defp pairs_for_indexed_doc({{i, set}, index}, inverted_index, fingerprints_by_id, names, target_set, threshold) do
    {index, collect_valid_pairs(i, set, inverted_index, fingerprints_by_id, names, target_set, threshold)}
  end

  # For document i, finds all documents j > i that share fingerprints and meet the Jaccard threshold.
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
    |> Enum.reduce([], &add_pair_if_above_threshold(&1, &2, i, size_a, fingerprints_by_id, threshold))
  end

  defp add_pair_if_above_threshold({j, intersection}, acc_pairs, i, size_a, fingerprints_by_id, threshold) do
    jaccard = compute_jaccard(size_a, MapSet.size(Map.get(fingerprints_by_id, j)), intersection)
    if jaccard >= threshold, do: [{{i, j}, jaccard} | acc_pairs], else: acc_pairs
  end

  defp compute_jaccard(size_a, size_b, intersection) when size_a + size_b - intersection == 0,
    do: 0.0

  defp compute_jaccard(size_a, size_b, intersection) do
    intersection / (size_a + size_b - intersection)
  end

  # Returns a map of doc_id → shared fingerprint count for all docs that share at least one fingerprint with doc i.
  defp count_collisions(set, inverted_index, i) do
    Enum.reduce(set, %{}, fn fp, coll_acc ->
      inverted_index |> Map.get(fp, []) |> count_forward_docs(i, coll_acc)
    end)
  end

  # Only counts doc_ids greater than i to avoid double-counting pairs (i, j) and (j, i).
  defp count_forward_docs(docs, i, acc) do
    Enum.reduce(docs, acc, fn
      doc_id, c_acc when doc_id > i -> Map.update(c_acc, doc_id, 1, &(&1 + 1))
      _doc_id, c_acc -> c_acc
    end)
  end

  defp merge_valid_pairs(valid_pairs, acc) do
    Enum.reduce(valid_pairs, acc, fn {pair, jaccard}, inner_acc ->
      Map.put(inner_acc, pair, jaccard)
    end)
  end

  defp maybe_print_lsh_progress(has_progress, index, total),
    do: maybe_print_step_progress(has_progress, index + 1, total, "LSH Filter")

  # Prints a single-line progress bar at every @progress_steps interval.
  defp maybe_print_step_progress(false, _current, _total, _label), do: :ok

  defp maybe_print_step_progress(true, current, total, label) do
    if rem(current, max(1, div(total, @progress_steps))) == 0 do
      IO.write(:stderr, "\r" <> CodeQA.CLI.UI.progress_bar(current, total, label: label))
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

    CodeQA.Telemetry.time(:ncd_exact_compression_phase, fn ->
      filtered_pairs
      |> Task.async_stream(
        &compute_ncd_pair(&1, precomputed, has_progress, counter, total_pairs, start_time_ncd),
        max_concurrency: workers, timeout: :infinity)
      |> Enum.map(fn {:ok, res} -> res end)
    end)
  end

  defp compute_ncd_pair({name_a, i, name_b, j, _jaccard}, precomputed, has_progress, counter, total_pairs, start_time) do
    ncd = compute_single_ncd(precomputed, i, j)
    maybe_print_ncd_progress(has_progress, counter, total_pairs, start_time)
    {name_a, name_b, ncd}
  end

  defp compute_single_ncd(precomputed, i, j) do
    CodeQA.Telemetry.time(:ncd_single_compression, fn ->
      {a, ca} = elem(precomputed, i)
      {b, cb} = elem(precomputed, j)
      cab = byte_size(:zlib.compress([a, b]))
      ncd = if max(ca, cb) > 0, do: (cab - min(ca, cb)) / max(ca, cb), else: 0.0
      Float.round(ncd, @ncd_precision)
    end)
  end

  defp maybe_print_ncd_progress(false, _counter, _total_pairs, _start_time), do: :ok

  defp maybe_print_ncd_progress(true, counter, total_pairs, start_time_ncd) do
    :counters.add(counter, 1, 1)
    c = :counters.get(counter, 1)

    if rem(c, max(1, div(total_pairs, @ncd_progress_steps))) == 0 or c == total_pairs do
      IO.write(:stderr, "\r" <> render_ncd_bar(c, total_pairs, start_time_ncd))
      if c == total_pairs, do: IO.puts(:stderr, "")
    end
  end

  defp render_ncd_bar(c, total_pairs, start_time) do
    elapsed = max(System.monotonic_time(:millisecond) - start_time, 1)
    eta_ms = round((total_pairs - c) * (elapsed / c))
    CodeQA.CLI.UI.progress_bar(c, total_pairs, eta: CodeQA.CLI.UI.format_eta(eta_ms), label: "NCD Compression")
  end

  defp build_results_map(computed_ncd, target_paths, target_set, top_n) do
    results =
      Enum.reduce(computed_ncd, %{}, fn {name_a, name_b, ncd}, acc ->
        acc = maybe_add_similarity(acc, name_a, name_b, ncd, target_set)
        maybe_add_similarity(acc, name_b, name_a, ncd, target_set)
      end)

    target_paths
    |> Enum.map(fn path ->
      sorted =
        results
        |> Map.get(path, [])
        |> Enum.sort_by(& &1["score"])
        |> then(&if top_n, do: Enum.take(&1, top_n), else: &1)

      {path, sorted}
    end)
    |> Map.new()
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

  defp compute_fingerprints(content, opts) do
    fp_stopwords = Keyword.get(opts, :fp_stopwords, MapSet.new())

    content
    |> CodeQA.Metrics.TokenNormalizer.normalize()
    |> CodeQA.Metrics.Winnowing.kgrams(@kgram_size)
    |> Enum.reject(&MapSet.member?(fp_stopwords, &1))
    |> MapSet.new()
  end

  # Compresses all files individually and combined; ratio > 1 means shared content across files.
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
