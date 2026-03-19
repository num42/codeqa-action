defmodule Test.NodeMatcher do
  @moduledoc """
  Helpers for asserting on tokens within `CompoundNode` structures.

  Returns tagged tuples that can be matched against token fields:

  - `exact(:content, "add")` — token whose `content` equals `"add"` exactly
  - `partial(:content, "@doc")` — token whose `content` contains `"@doc"` as a substring
  - `:value` targets the normalized token value instead of raw source content
  """

  @spec exact(:content | :value, String.t()) :: {:exact, :content | :value, String.t()}
  def exact(field, value) when field in [:content, :value], do: {:exact, field, value}

  @spec partial(:content | :value, String.t()) :: {:partial, :content | :value, String.t()}
  def partial(field, value) when field in [:content, :value], do: {:partial, field, value}
end
