%{
  inputs: ["lib/**/*.ex", "test/**/*.exs"],
  configured_modules: [],
  skipped_modules: [
    # Re-renames identifiers without scope-awareness: collapses two distinct
    # variables in the same scope (e.g. base_val + head_val) into a single
    # shadowed name, silently breaking semantics. Also fights manual rename
    # decisions on each rerun (avg_us → microseconds → microseconds collision).
    # Track upstream issue before re-enabling.
    Number42.Refactors.Ex.ExpandShortFormBindings
  ]
}
