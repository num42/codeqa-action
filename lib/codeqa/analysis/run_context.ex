defmodule CodeQA.Analysis.RunContext do
  @moduledoc """
  Holds PIDs for the per-run GenServers started under `RunSupervisor`.

  Passed through the analysis call chain so all callers can access
  cached state without named process registration.
  """

  defstruct [:behavior_config_pid, :file_context_pid, :file_metrics_pid]

  @type t :: %__MODULE__{
          behavior_config_pid: pid(),
          file_context_pid: pid(),
          file_metrics_pid: pid()
        }
end
