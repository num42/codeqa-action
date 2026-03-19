defmodule CodeQA.Analysis.RunSupervisor do
  @moduledoc """
  One-shot supervisor for the per-analysis-run GenServers.

  Started at the top of `BlockImpactAnalyzer.analyze/3` and stopped (via
  `Supervisor.stop/1`) in an `after` block when the run completes.

  Servers are not registered by name, preventing collisions when multiple
  analysis runs share the same BEAM node (e.g. parallel tests).
  """

  use Supervisor

  alias CodeQA.Analysis.{BehaviorConfigServer, FileContextServer, FileMetricsServer, RunContext}

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @doc """
  Queries child PIDs from `sup` and returns a `RunContext` struct.

  Call once after `start_link/1` succeeds, before beginning analysis.
  """
  @spec run_context(pid()) :: RunContext.t()
  def run_context(sup) do
    children = Supervisor.which_children(sup)

    %RunContext{
      behavior_config_pid: find_pid(children, BehaviorConfigServer),
      file_context_pid: find_pid(children, FileContextServer),
      file_metrics_pid: find_pid(children, FileMetricsServer)
    }
  end

  @impl true
  def init(_opts) do
    children = [
      {BehaviorConfigServer, []},
      {FileContextServer, []},
      {FileMetricsServer, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp find_pid(children, module) do
    {_id, pid, _type, _modules} =
      Enum.find(children, fn {id, _pid, _type, _modules} -> id == module end)

    pid
  end
end
