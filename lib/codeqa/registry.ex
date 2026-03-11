defmodule CodeQA.Registry do
  @moduledoc "Metric registration and execution."

  defstruct file_metrics: [], codebase_metrics: []

  def new, do: %__MODULE__{}

  def register_file_metric(%__MODULE__{} = reg, metric_module) do
    %{reg | file_metrics: reg.file_metrics ++ [metric_module]}
  end

  def register_codebase_metric(%__MODULE__{} = reg, metric_module) do
    %{reg | codebase_metrics: reg.codebase_metrics ++ [metric_module]}
  end

  def run_file_metrics(%__MODULE__{} = reg, ctx, opts \\ []) do
    base_metrics = Map.new(reg.file_metrics, fn mod -> 
      {mod.name(), CodeQA.Telemetry.time(String.to_atom("metric_" <> mod.name()), fn -> mod.analyze(ctx) end)} 
    end)

    if Keyword.get(opts, :combinations, false) do
      CodeQA.Telemetry.time(:registry_combinations, fn ->
        combinations = generate_combinations(flat_numeric_metrics(base_metrics), [])
        Map.merge(base_metrics, Map.new(combinations))
      end)
    else
      base_metrics
    end
  end

  defp flat_numeric_metrics(base_metrics) do
    for {name, data} <- base_metrics,
        {k, v} <- data,
        is_number(v),
        do: {"#{name}_#{k}", v / 1.0}
  end

  defp generate_combinations([], acc), do: acc
  defp generate_combinations([{k1, v1} | rest], acc) do
    # Generate all pairs for the head with the rest of the list
    new_acc =
      Enum.reduce(rest, acc, fn {k2, v2}, current_acc ->
        combined = %{
          "keys" => [k1, k2],
          "add" => v1 + v2,
          "sub_a_b" => v1 - v2,
          "sub_b_a" => v2 - v1,
          "mul" => v1 * v2,
          "div_a_b" => if(v2 == 0.0, do: 0.0, else: v1 / v2),
          "div_b_a" => if(v1 == 0.0, do: 0.0, else: v2 / v1)
        }
        [{"#{k1},#{k2}", combined} | current_acc]
      end)
      
    generate_combinations(rest, new_acc)
  end

  def run_codebase_metrics(%__MODULE__{} = reg, files, opts \\ []) do
    Map.new(reg.codebase_metrics, fn mod -> {mod.name(), mod.analyze(files, opts)} end)
  end
end
