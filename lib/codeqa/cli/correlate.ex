defmodule CodeQA.CLI.Correlate do
  @moduledoc false

  @behaviour CodeQA.CLI.Command

  alias CodeQA.CLI.Options
  alias CodeQA.CLI.UI

  @impl CodeQA.CLI.Command
  def usage do
    """
    Usage: codeqa correlate <dir> [options]

      Find metric correlations in a directory of history JSON files.

    Options:
      -t, --top N           Number of top correlations to show (default: 20)
      --hide-exact          Hide correlations that are exactly 1.0 or -1.0
      --all-groups          Include correlations between metrics in the same group
      --combined-only       Only show correlations where exactly one metric is a combined metric (e.g. a/b)
      --min FLOAT           Only show correlations greater than or equal to this value
      --max FLOAT           Only show correlations less than or equal to this value
      --max-steps N         Maximum number of correlation pairs to evaluate (for debugging)
    """
  end

  @impl CodeQA.CLI.Command
  def run(args) when args in [["--help"], ["-h"]] do
    usage()
  end

  def run(args) do
    {opts, [path], _} =
      OptionParser.parse(args,
        strict: [
          top: :integer,
          hide_exact: :boolean,
          all_groups: :boolean,
          min: :float,
          max: :float,
          combined_only: :boolean,
          max_steps: :integer
        ],
        aliases: [t: :top]
      )

    Options.validate_dir!(path)

    files = File.ls!(path) |> Enum.filter(&String.ends_with?(&1, ".json")) |> Enum.sort()

    if length(files) < 2 do
      IO.puts(
        :stderr,
        "Error: Need at least 2 JSON history files in '#{path}' to calculate correlations."
      )

      exit({:shutdown, 1})
    end

    IO.puts(:stderr, "Found #{length(files)} history files. Extracting metrics...")

    {series, category_map} = extract_metric_series(path, files)
    active_keys = Map.keys(series) |> Enum.sort()
    num_keys = length(active_keys)

    IO.puts(:stderr, "Calculating correlations between #{num_keys} active metrics...")

    total_start = System.monotonic_time(:millisecond)

    {pairs_stream, total_pairs} = build_correlation_pairs(active_keys, num_keys, opts)

    IO.puts(:stderr, "Calculating correlations for #{total_pairs} pairs...")

    correlations =
      compute_correlations(pairs_stream, total_pairs, total_start, series, category_map, opts)

    total_end = System.monotonic_time(:millisecond)

    IO.puts(:stderr, "Telemetry:")
    IO.puts(:stderr, "  Total time: #{total_end - total_start}ms")

    top_n = opts[:top] || 20
    sorted = Enum.sort_by(correlations, &abs(&1["correlation"]), :desc)
    top = Enum.take(sorted, top_n)

    Jason.encode!(top, pretty: true)
  end

  defp extract_metric_series(path, files) do
    t0 = System.monotonic_time(:millisecond)

    extracted =
      Enum.map(files, fn file ->
        Path.join(path, file)
        |> File.read!()
        |> Jason.decode!()
        |> Map.get("codebase", %{})
        |> Map.get("aggregate", %{})
        |> flatten_aggregate_metrics()
        |> Map.new()
      end)

    IO.puts(:stderr, "  Extraction took #{elapsed_ms(t0)}ms")

    t1 = System.monotonic_time(:millisecond)

    keys =
      extracted
      |> Enum.reduce(MapSet.new(), fn m, acc -> MapSet.union(acc, MapSet.new(Map.keys(m))) end)
      |> Enum.to_list()
      |> Enum.sort()

    IO.puts(:stderr, "  Keys resolution took #{elapsed_ms(t1)}ms")

    t2 = System.monotonic_time(:millisecond)

    series =
      keys
      |> Enum.map(fn key ->
        values = Enum.map(extracted, &Map.get(&1, key, 0.0))
        {key, values, Enum.min(values) != Enum.max(values)}
      end)
      |> Enum.filter(fn {_, _, has_variance} -> has_variance end)
      |> Map.new(fn {key, values, _} -> {key, values} end)

    IO.puts(:stderr, "  Series building took #{elapsed_ms(t2)}ms")

    t3 = System.monotonic_time(:millisecond)
    active_keys = Map.keys(series) |> Enum.sort()

    category_map =
      Map.new(active_keys, fn key ->
        cats =
          key
          |> String.split(".")
          |> List.first()
          |> String.split(",")
          |> Enum.flat_map(&String.split(&1, "_"))

        {key, MapSet.new(cats)}
      end)

    IO.puts(:stderr, "  Category precomputation took #{elapsed_ms(t3)}ms")

    {series, category_map}
  end

  defp flatten_aggregate_metrics(aggregate) do
    Enum.flat_map(aggregate, fn {category, metrics} ->
      Enum.map(metrics, fn {name, val} -> {"#{category}.#{name}", val} end)
    end)
  end

  defp build_correlation_pairs(active_keys, num_keys, opts) do
    max_steps = opts[:max_steps] || -1

    pairs_to_process =
      if opts[:combined_only],
        do: combined_pairs_stream(active_keys),
        else: all_pairs_stream(active_keys)

    pairs_stream =
      if max_steps > 0, do: Stream.take(pairs_to_process, max_steps), else: pairs_to_process

    total_pairs =
      cond do
        max_steps > 0 ->
          max_steps

        opts[:combined_only] ->
          normal_count = Enum.count(active_keys, &(not String.contains?(&1, ",")))
          combined_count = Enum.count(active_keys, &String.contains?(&1, ","))
          normal_count * combined_count

        true ->
          div(num_keys * (num_keys - 1), 2)
      end

    {pairs_stream, total_pairs}
  end

  defp combined_pairs_stream(active_keys) do
    normal = Enum.reject(active_keys, &String.contains?(&1, ","))
    combined = Enum.filter(active_keys, &String.contains?(&1, ","))

    Stream.flat_map(normal, fn k1 ->
      Stream.map(combined, fn k2 -> {k1, k2} end)
    end)
  end

  defp all_pairs_stream(active_keys) do
    Stream.unfold(active_keys, fn
      [] -> nil
      [_h | t] = list -> {list, t}
    end)
    |> Stream.flat_map(fn
      [k1 | rest] -> Stream.map(rest, fn k2 -> {k1, k2} end)
      [] -> []
    end)
  end

  defp compute_correlations(pairs_stream, total_pairs, total_start, series, category_map, opts) do
    counter = :counters.new(1, [:atomics])
    update_interval = max(1, min(5000, div(total_pairs, 50)))

    pairs_stream
    |> Task.async_stream(
      &correlate_pair(
        &1,
        counter,
        total_pairs,
        update_interval,
        total_start,
        series,
        category_map,
        opts
      ),
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Stream.map(fn {:ok, result} -> result end)
    |> Enum.reject(&is_nil/1)
  end

  defp correlate_pair(
         {k1, k2},
         counter,
         total_pairs,
         update_interval,
         total_start,
         series,
         category_map,
         opts
       ) do
    :counters.add(counter, 1, 1)
    current = :counters.get(counter, 1)
    progress_callback(current, total_pairs, update_interval, total_start)

    cross_valid =
      opts[:all_groups] ||
        MapSet.disjoint?(Map.fetch!(category_map, k1), Map.fetch!(category_map, k2))

    if cross_valid do
      corr = CodeQA.Math.pearson_correlation_list(Map.fetch!(series, k1), Map.fetch!(series, k2))
      maybe_correlation_result(k1, k2, corr, opts)
    end
  end

  defp maybe_correlation_result(k1, k2, corr, opts) do
    if keep_correlation?(corr, opts) do
      %{"metric1" => k1, "metric2" => k2, "correlation" => corr}
    end
  end

  defp keep_correlation?(corr, opts) do
    valid = corr != 0.0
    valid = if opts[:hide_exact], do: valid and abs(corr) != 1.0, else: valid
    valid = if valid and opts[:min], do: corr >= opts[:min], else: valid
    if valid and opts[:max], do: corr <= opts[:max], else: valid
  end

  defp progress_callback(current, total_pairs, update_interval, total_start) do
    if rem(current, update_interval) == 0 or current == total_pairs do
      now = System.monotonic_time(:millisecond)
      elapsed = max(now - total_start, 1)
      avg_time = elapsed / current
      eta_ms = round((total_pairs - current) * avg_time)

      output =
        UI.progress_bar(current, total_pairs, eta: UI.format_eta(eta_ms))

      IO.write(:stderr, "\r" <> output)
      if current == total_pairs, do: IO.puts(:stderr, "")
    end
  end

  defp elapsed_ms(t0), do: System.monotonic_time(:millisecond) - t0
end
