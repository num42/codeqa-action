defmodule CodeQA.Analyzer do
  @moduledoc "Orchestrates metric computation across files."

  alias CodeQA.Registry
  alias CodeQA.Metrics

  def build_registry do
    Registry.new()
    |> Registry.register_file_metric(Metrics.Entropy)
    |> Registry.register_file_metric(Metrics.Compression)
    |> Registry.register_file_metric(Metrics.Zipf)
    |> Registry.register_file_metric(Metrics.Heaps)
    |> Registry.register_file_metric(Metrics.Vocabulary)
    |> Registry.register_file_metric(Metrics.Ngram)
    |> Registry.register_file_metric(Metrics.Halstead)
    |> Registry.register_file_metric(Metrics.Readability)
    |> Registry.register_file_metric(Metrics.CasingEntropy)
    |> Registry.register_file_metric(Metrics.IdentifierLengthVariance)
    |> Registry.register_file_metric(Metrics.Indentation)
    |> Registry.register_file_metric(Metrics.MagicNumberDensity)
    |> Registry.register_file_metric(Metrics.SymbolDensity)
    |> Registry.register_file_metric(Metrics.VowelDensity)
    |> Registry.register_codebase_metric(Metrics.Similarity)
  end

  def analyze_codebase(files, opts \\ []) do
    registry = build_registry()

    opts =
      if Keyword.get(opts, :experimental_stopwords, false) do
        has_progress = Keyword.get(opts, :on_progress)

        if has_progress, do: IO.puts(:stderr, "  Analyzing Stopwords (Tokens and Fingerprints)...")

        word_extractor = fn content -> Regex.scan(~r/\b[a-zA-Z_]\w*\b/u, content) |> List.flatten() end
        word_stopwords = CodeQA.Telemetry.time(:stopwords_words, fn -> CodeQA.Stopwords.find_stopwords(files, word_extractor, opts) end)
        
        fp_extractor = fn content -> CodeQA.Metrics.TokenNormalizer.normalize(content) |> CodeQA.Metrics.Winnowing.kgrams(5) end
        fp_stopwords = CodeQA.Telemetry.time(:stopwords_fingerprints, fn -> CodeQA.Stopwords.find_stopwords(files, fp_extractor, opts) end)

        if has_progress do
          IO.puts(:stderr, "  Found #{MapSet.size(word_stopwords)} common word stopwords and #{MapSet.size(fp_stopwords)} common fingerprint stopwords.")
        end

        opts
        |> Keyword.put(:word_stopwords, word_stopwords)
        |> Keyword.put(:fp_stopwords, fp_stopwords)
      else
        opts
      end

    file_results = CodeQA.Parallel.analyze_files(files, opts)
    codebase_metrics = Registry.run_codebase_metrics(registry, files, opts)
    aggregate = aggregate_file_metrics(file_results)

    %{
      "files" => file_results,
      "codebase" => %{
        "aggregate" => aggregate,
        "similarity" => Map.get(codebase_metrics, "similarity", %{})
      }
    }
  end

  defp metric_data_to_triples({metric_name, metric_data}) do
    metric_data
    |> Enum.filter(fn {_k, v} -> is_number(v) end)
    |> Enum.map(fn {key, value} -> {metric_name, key, value / 1} end)
  end

  defp aggregate_file_metrics(file_results) do
    file_results
    |> Map.values()
    |> Enum.flat_map(fn file_data ->
      file_data
      |> Map.get("metrics", %{})
      |> Enum.flat_map(&metric_data_to_triples/1)
    end)
    |> Enum.group_by(fn {metric, key, _val} -> {metric, key} end, fn {_, _, val} -> val end)
    |> Enum.reduce(%{}, fn {{metric, key}, values}, acc ->
      stats = compute_stats(values)
      metric_agg = Map.get(acc, metric, %{})
      updated = Map.merge(metric_agg, %{
        "mean_#{key}" => stats.mean,
        "std_#{key}" => stats.std,
        "min_#{key}" => stats.min,
        "max_#{key}" => stats.max
      })
      Map.put(acc, metric, updated)
    end)
  end

  defp compute_stats([]), do: %{mean: 0.0, std: 0.0, min: 0.0, max: 0.0}

  defp compute_stats(values) do
    n = length(values)
    mean = Enum.sum(values) / n
    sum_squares = Enum.reduce(values, 0.0, fn v, acc -> acc + (v - mean) ** 2 end)
    variance = sum_squares / n
    std = :math.sqrt(variance)

    %{
      mean: Float.round(mean * 1.0, 4),
      std: Float.round(std * 1.0, 4),
      min: Float.round(Enum.min(values) * 1.0, 4),
      max: Float.round(Enum.max(values) * 1.0, 4)
    }
  end
end
