defmodule CodeQA.AST.SignalTest do
  use ExUnit.Case, async: true

  defmodule TestSignal do
    defstruct []

    defimpl CodeQA.AST.Parsing.Signal do
      def source(_), do: TestSignal
      def group(_), do: :split
      def init(_, _opts), do: %{count: 0}

      def emit(_, _token, state) do
        new_state = %{state | count: state.count + 1}
        {MapSet.new([{:tick, state.count}]), new_state}
      end
    end
  end

  defmodule SilentSignal do
    defstruct []

    defimpl CodeQA.AST.Parsing.Signal do
      def source(_), do: SilentSignal
      def group(_), do: :split
      def init(_, _), do: %{}
      def emit(_, _token, state), do: {MapSet.new(), state}
    end
  end

  alias CodeQA.AST.Parsing.Signal

  test "source returns the implementing module" do
    assert Signal.source(%TestSignal{}) == TestSignal
  end

  test "group returns the signal's group atom" do
    assert Signal.group(%TestSignal{}) == :split
  end

  test "init returns initial state" do
    assert Signal.init(%TestSignal{}, []) == %{count: 0}
  end

  test "emit returns {MapSet of {name, value} pairs, new_state}" do
    token = %CodeQA.AST.Lexing.Token{kind: "<ID>", content: "foo", line: 1, col: 0}
    {emissions, new_state} = Signal.emit(%TestSignal{}, token, %{count: 0})
    assert MapSet.member?(emissions, {:tick, 0})
    assert new_state == %{count: 1}
  end

  test "emit may return empty MapSet for no emission" do
    token = %CodeQA.AST.Lexing.Token{kind: "<NL>", content: "\n", line: 1, col: 0}
    {emissions, _state} = Signal.emit(%SilentSignal{}, token, %{})
    assert MapSet.size(emissions) == 0
  end
end
