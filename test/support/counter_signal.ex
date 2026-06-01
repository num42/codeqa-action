defmodule CodeQA.Support.CounterSignal do
  @moduledoc false
  defstruct []
end

defimpl CodeQA.AST.Parsing.Signal, for: CodeQA.Support.CounterSignal do
  def source(_), do: CodeQA.Support.CounterSignal
  def group(_), do: :test
  def init(_, _), do: %{idx: 0}

  def emit(_, {_prev, token, _next}, %{idx: i} = state) do
    emissions =
      if token.kind == "<ID>",
        do: MapSet.new([{:id_seen, i}]),
        else: MapSet.new()

    {emissions, %{state | idx: i + 1}}
  end
end
