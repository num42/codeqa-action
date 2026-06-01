defmodule CodeQA.Sample.Signals.ImportSignal do
  @moduledoc """
  Classification signal — votes `:import` when an import keyword appears
  at indent 0.

  Weights:
  - 3 when first content token of the block
  - 1 when found later
  """

  defstruct []

  @nl :newline
  @ws :whitespace

  def kind, do: :import_vote
  def group, do: :classification
end
