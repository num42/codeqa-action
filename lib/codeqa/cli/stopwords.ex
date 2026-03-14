defmodule CodeQA.CLI.Stopwords do
  @moduledoc false

  alias CodeQA.CLI.Options

  @spec run(list(String.t())) :: :ok
  def run(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          workers: :integer,
          stopwords_threshold: :float,
          progress: :boolean,
          ignore_paths: :string
        ],
        aliases: [w: :workers]
      )

    Options.validate_dir!(path)

    ignore_patterns = Options.parse_ignore_paths(opts[:ignore_paths])
    files = CodeQA.Collector.collect_files(path, ignore_patterns: ignore_patterns)

    if map_size(files) == 0 do
      IO.puts(:stderr, "Warning: no source files found in '#{path}'")
      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Extracting stopwords for #{map_size(files)} files...")
    start_time = System.monotonic_time(:millisecond)

    word_stopwords = find_word_stopwords(files, opts)
    fp_stopwords = find_fingerprint_stopwords(files, opts)

    end_time = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "\nAnalysis completed in #{end_time - start_time}ms")
    print_word_stopwords(word_stopwords)
    IO.puts(:stderr, "\n--- Fingerprint Stopwords (#{MapSet.size(fp_stopwords)}) ---")
    IO.puts(:stderr, "Found #{MapSet.size(fp_stopwords)} structural k-gram hashes.")
  end

  defp find_word_stopwords(files, opts) do
    word_extractor = fn content ->
      Regex.scan(~r/\b[a-zA-Z_]\w*\b/u, content) |> List.flatten()
    end

    CodeQA.Stopwords.find_stopwords(
      files,
      word_extractor,
      Keyword.put(opts, :progress_label, "Words")
    )
  end

  defp find_fingerprint_stopwords(files, opts) do
    fp_extractor = fn content ->
      CodeQA.Metrics.TokenNormalizer.normalize(content) |> CodeQA.Metrics.Winnowing.kgrams(5)
    end

    CodeQA.Stopwords.find_stopwords(
      files,
      fp_extractor,
      Keyword.put(opts, :progress_label, "Fingerprints")
    )
  end

  defp print_word_stopwords(word_stopwords) do
    IO.puts(:stderr, "\n--- Word Stopwords (#{MapSet.size(word_stopwords)}) ---")

    word_stopwords
    |> MapSet.to_list()
    |> Enum.sort()
    |> Enum.chunk_every(10)
    |> Enum.each(fn chunk -> IO.puts(Enum.join(chunk, ", ")) end)
  end
end
