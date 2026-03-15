[
  # Dialyzer specializes analyze/2 for the codebase call-site where include_pairs
  # is always true, making the false branch appear unreachable. Both branches are
  # valid and reachable at runtime from the file-level and codebase callers.
  {"lib/codeqa/metrics/near_duplicate_blocks.ex", :pattern_match}
]
