%{
  inputs: ["lib/**/*.ex", "test/**/*.exs"],
  configured_modules: [],
  skipped_modules: [
    # Re-renames identifiers without scope-awareness: collapses two distinct
    # variables in the same scope (e.g. base_val + head_val) into a single
    # shadowed name, silently breaking semantics. Also fights manual rename
    # decisions on each rerun (avg_us → microseconds → microseconds collision).
    # Track upstream issue before re-enabling.
    Number42.Refactors.Ex.ExpandShortFormBindings,

    # Loses guard conditions in transit. Example: rewrites
    #   if next == nil do
    #     if total > 0 and ratio > 0.6, do: vote, else: nothing
    #   else
    #     nothing
    #   end
    # to a cond block whose first arm is `compute_total.() -> vote`
    # (i.e. just "any positive total casts a vote") — the original
    # guard `ratio > 0.6` and the outer `next == nil` precondition
    # are simply dropped. Produced 2 test failures in
    # data_signal_test.exs on first try.
    Number42.Refactors.Ex.IfElseToCond
  ]
}
