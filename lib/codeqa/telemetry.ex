defmodule CodeQA.Telemetry do
  @moduledoc "Simple concurrent telemetry tracker using ETS."

  def setup do
    if :ets.info(:codeqa_telemetry) == :undefined do
      :ets.new(:codeqa_telemetry, [:named_table, :public, :set, write_concurrency: true])
    end
    :ok
  end

  def time(metric_name, fun) do
    if :ets.info(:codeqa_telemetry) != :undefined do
      start_time = System.monotonic_time(:microsecond)
      result = fun.()
      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time
      
      :ets.update_counter(:codeqa_telemetry, metric_name, {2, duration}, {metric_name, 0})
      :ets.update_counter(:codeqa_telemetry, "#{metric_name}_count", {2, 1}, {"#{metric_name}_count", 0})
      
      result
    else
      fun.()
    end
  end

  defp format_metric_line({name, total_time_us}) do
    count = case :ets.lookup(:codeqa_telemetry, "#{name}_count") do
      [{_, c}] -> c
      _ -> 1
    end

    total_ms = Float.round(total_time_us / 1000, 2)
    avg_ms = Float.round(total_ms / count, 2)

    String.pad_trailing(to_string(name), 30) <>
      " | Total: #{String.pad_trailing(to_string(total_ms) <> "ms", 12)}" <>
      " | Count: #{String.pad_trailing(to_string(count), 6)}" <>
      " | Avg: #{avg_ms}ms"
  end

  def print_report do
    if :ets.info(:codeqa_telemetry) != :undefined do
      IO.puts(:stderr, "
--- Telemetry Report (Wall-clock times) ---")
      metrics = :ets.tab2list(:codeqa_telemetry)
      
      # Group totals and counts
      totals = Enum.filter(metrics, fn {k, _} -> not String.ends_with?(to_string(k), "_count") end)
      
      totals
      |> Enum.sort_by(fn {_, time} -> time end, :desc)
      |> Enum.each(&IO.puts(:stderr, format_metric_line(&1)))
      IO.puts(:stderr, "-------------------------------------------
")
    end
  end
end
