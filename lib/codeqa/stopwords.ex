defmodule CodeQA.Stopwords do
  @moduledoc "Finds highly frequent items across a codebase to act as stopwords."

  @doc """
  Finds items that appear in more than the specified threshold of files.
  `extractor` is a function that takes a file's content and returns an Enumerable of items.
  """
  def find_stopwords(files, extractor, opts \\ []) do
    threshold_ratio = Keyword.get(opts, :stopwords_threshold, 0.15)
    total_docs = map_size(files)
    min_docs = max(1, round(total_docs * threshold_ratio))
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    has_progress = Keyword.get(opts, :progress, false)
    label = Keyword.get(opts, :progress_label, "")

    counter = :counters.new(1, [:atomics])
    start_time = System.monotonic_time(:millisecond)

    files
    |> Task.async_stream(fn {_path, content} ->
      res = content
      |> extractor.()
      |> MapSet.new()

      if has_progress do
        :counters.add(counter, 1, 1)
        completed = :counters.get(counter, 1)
        print_progress(completed, total_docs, start_time, label)
      end

      res
    end, max_concurrency: workers, timeout: :infinity)
    |> Enum.reduce(%{}, fn {:ok, unique_items_in_file}, doc_freqs ->
      Enum.reduce(unique_items_in_file, doc_freqs, fn item, acc ->
        Map.update(acc, item, 1, &(&1 + 1))
      end)
    end)
    |> Enum.filter(fn {_item, count} -> count >= min_docs end)
    |> Enum.map(fn {item, _count} -> item end)
    |> MapSet.new()
  end

  defp print_progress(completed, total, start_time, label) do
    now = System.monotonic_time(:millisecond)
    elapsed = max(now - start_time, 1)
    avg_time = elapsed / completed
    eta_ms = round((total - completed) * avg_time)

    output = CodeQA.CLI.UI.progress_bar(completed, total,
      eta: CodeQA.CLI.UI.format_eta(eta_ms),
      label: label
    )

    IO.write(:stderr, "\r" <> output)

    if completed == total do
      IO.puts(:stderr, "")
    end
  end
end
