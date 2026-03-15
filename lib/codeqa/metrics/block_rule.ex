defmodule CodeQA.Metrics.BlockRule do
  @moduledoc """
  Behaviour for pluggable block and sub-block detection rules.

  A rule scans a token list and returns boundary signals:
  - `{:split, idx}` — token at `idx` starts a new top-level block
  - `{:enclosure, start_idx, end_idx}` — tokens `start_idx..end_idx` form a sub-block
  """

  @type boundary ::
    {:split, non_neg_integer()}
    | {:enclosure, non_neg_integer(), non_neg_integer()}

  @callback detect([String.t()], keyword()) :: [boundary()]
end
