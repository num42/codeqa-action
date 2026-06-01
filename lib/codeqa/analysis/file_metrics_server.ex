defmodule CodeQA.Analysis.FileMetricsServer do
  @moduledoc """
  Per-run GenServer that caches `Registry.run_file_metrics/2` results.

  Pre-populated from `pipeline_result` before block analysis starts so baseline
  metrics are served directly from ETS without recomputation.

  ETS layout:
  - `{:path, path}` => metrics map   (baseline for existing files)
  - `{:hash, md5_binary}` => metrics map  (computed on demand for reconstructed content)
  """

  use GenServer

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Engine.Registry

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Returns the ETS table id. Callers may read directly from it."
  @spec get_tid(pid()) :: :ets.tid()
  def get_tid(pid), do: GenServer.call(pid, :get_tid)

  @doc """
  Bulk-inserts all baseline metrics from `pipeline_result` and cross-indexes by
  content hash for each path present in `files_map`.

  Call once after starting the supervisor, before beginning block analysis.
  """
  @spec populate(pid(), map(), map()) :: :ok
  def populate(pid, pipeline_result, files_map) do
    tid = get_tid(pid)
    files_data = Map.get(pipeline_result, "files", %{})

    Enum.each(files_data, fn {path, file_data} ->
      metrics = Map.get(file_data, "metrics", %{})
      :ets.insert(tid, {{:path, path}, metrics})
    end)

    Enum.each(files_map, fn {path, content} ->
      hash = md5(content)

      case :ets.lookup(tid, {:path, path}) do
        [{_, metrics}] -> :ets.insert(tid, {{:hash, hash}, metrics})
        [] -> :ok
      end
    end)

    :ok
  end

  @doc "Returns pre-populated baseline metrics for `path`, or `nil` if not found."
  @spec get_by_path(pid(), String.t()) :: map() | nil
  def get_by_path(pid, path) do
    tid = get_tid(pid)

    case :ets.lookup(tid, {:path, path}) do
      [{_, metrics}] -> metrics
      [] -> nil
    end
  end

  @doc """
  Returns metrics for `content`, using the hash cache.

  On a cache miss, builds the file context and runs metrics in the calling
  process, then inserts the result into ETS for future lookups.
  """
  @spec get_for_content(pid(), Registry.t(), String.t(), keyword()) :: map()
  def get_for_content(pid, registry, content, opts \\ []) do
    tid = get_tid(pid)
    hash = md5(content)

    case :ets.lookup(tid, {:hash, hash}) do
      [{_, metrics}] ->
        metrics

      [] ->
        ctx = Pipeline.build_file_context(content, opts)
        metrics = Registry.run_file_metrics(registry, ctx)
        :ets.insert(tid, {{:hash, hash}, metrics})
        metrics
    end
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    tid = :ets.new(:file_metrics, [:set, :public, read_concurrency: true])
    {:ok, %{tid: tid}}
  end

  @impl true
  def handle_call(:get_tid, _from, state) do
    {:reply, state.tid, state}
  end

  # --- Private helpers ---

  defp md5(content), do: :crypto.hash(:md5, content)
end
