[
  # Dialyzer specializes analyze/2 for the codebase call-site where include_pairs
  # is always true, making the false branch appear unreachable. Both branches are
  # valid and reachable at runtime from the file-level and codebase callers.
  {"lib/codeqa/metrics/file/near_duplicate_blocks.ex", :pattern_match},
  # Mix module type information is not available in the PLT; these are valid
  # Mix.Task callbacks and standard Mix module calls.
  {"lib/mix/tasks/codeqa/sample_report.ex", :callback_info_missing},
  {"lib/mix/tasks/codeqa/signal_debug.ex", :callback_info_missing},
  {"lib/mix/tasks/codeqa/sample_report.ex", :unknown_function},
  {"lib/mix/tasks/codeqa/signal_debug.ex", :unknown_function},
  # CodeQA.Engine.Registry.t/0 is defined via a macro; type is available at runtime.
  {"lib/codeqa/analysis/file_metrics_server.ex", :unknown_type}
]
