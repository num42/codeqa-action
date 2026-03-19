defmodule CodeQA.Analysis.BehaviorConfigServer do
  @moduledoc """
  Per-run GenServer that loads all YAML behavior configs once and serves them
  from an anonymous ETS table.

  Eliminates repeated disk reads in `SampleRunner.diagnose_aggregate/2` by
  loading `priv/combined_metrics/*.yml` on startup and keeping data in memory
  for the duration of the analysis run.

  ETS layout: `{category, behavior} => behavior_data`
  where `behavior_data` is the raw YAML map for that behavior.
  """

  use GenServer

  @yaml_dir "priv/combined_metrics"

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Returns the ETS table id. Callers may read directly from it."
  @spec get_tid(pid()) :: :ets.tid()
  def get_tid(pid), do: GenServer.call(pid, :get_tid)

  @doc """
  Returns all behaviors grouped by category.

      %{"function_design" => [{"no_boolean_parameter", behavior_data}, ...], ...}
  """
  @spec get_all_behaviors(pid()) :: %{String.t() => [{String.t(), map()}]}
  def get_all_behaviors(pid) do
    tid = get_tid(pid)

    tid
    |> :ets.tab2list()
    |> Enum.reduce(%{}, fn {{cat, beh}, data}, acc ->
      Map.update(acc, cat, [{beh, data}], &[{beh, data} | &1])
    end)
  end

  @doc "Returns the scalar weight map for a given category + behavior."
  @spec get_scalars(pid(), String.t(), String.t()) :: %{{String.t(), String.t()} => float()}
  def get_scalars(pid, category, behavior) do
    tid = get_tid(pid)

    case :ets.lookup(tid, {category, behavior}) do
      [{_, data}] -> scalars_from_behavior_data(data)
      [] -> %{}
    end
  end

  @doc "Returns the `_log_baseline` value for a given category + behavior."
  @spec get_log_baseline(pid(), String.t(), String.t()) :: float()
  def get_log_baseline(pid, category, behavior) do
    tid = get_tid(pid)

    case :ets.lookup(tid, {category, behavior}) do
      [{_, data}] -> Map.get(data, "_log_baseline", 0.0) / 1.0
      [] -> 0.0
    end
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    tid = :ets.new(:behavior_config, [:set, :public, read_concurrency: true])
    load_configs(tid)
    {:ok, %{tid: tid}}
  end

  @impl true
  def handle_call(:get_tid, _from, state) do
    {:reply, state.tid, state}
  end

  # --- Private helpers ---

  defp load_configs(tid) do
    case File.ls(@yaml_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".yml"))
        |> Enum.each(fn yml_file ->
          category = String.trim_trailing(yml_file, ".yml")
          yaml_path = Path.join(@yaml_dir, yml_file)
          {:ok, data} = YamlElixir.read_from_file(yaml_path)

          data
          |> Enum.filter(fn {_k, v} -> is_map(v) end)
          |> Enum.each(fn {behavior, behavior_data} ->
            :ets.insert(tid, {{category, behavior}, behavior_data})
          end)
        end)

      {:error, _} ->
        :ok
    end
  end

  @doc false
  def scalars_from_behavior_data(behavior_data) do
    behavior_data
    |> Enum.flat_map(fn
      {group, keys} when is_map(keys) ->
        Enum.map(keys, fn {key, scalar} -> {{group, key}, scalar / 1.0} end)

      _ ->
        []
    end)
    |> Map.new()
  end
end
