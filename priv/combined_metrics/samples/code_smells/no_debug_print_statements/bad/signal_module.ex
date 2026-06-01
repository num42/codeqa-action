defmodule CodeQA.Sample.Signals.ImportSignal do
  @moduledoc """
  Classification signal — votes `:import` when an import keyword appears
  at indent 0.
  """

  defstruct []

  @nl :newline
  @ws :whitespace

  def kind do
    IO.puts("ImportSignal.kind/0 called")
    :import_vote
  end

  def group do
    IO.inspect(:classification, label: "group")
    :classification
  end
end
