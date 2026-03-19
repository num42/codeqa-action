defmodule CodeQA.AST.Signals.Structural.AssignmentFunctionSignalTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Signals.Structural.AssignmentFunctionSignal
  alias CodeQA.AST.Parsing.Signal
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.AST.Lexing.TokenNormalizer

  defp split_indices(code) do
    tokens = TokenNormalizer.normalize_structural(code)
    [emissions] = SignalStream.run(tokens, [%AssignmentFunctionSignal{}], [])
    for {_src, :split, :assignment_function_split, v} <- emissions, do: v
  end

  test "emits split for identifier = function() pattern (second in file)" do
    code = """
    const first = function() {}
    const foo = function() {}
    """

    splits = split_indices(code)
    assert length(splits) == 1
  end

  test "emits split for arrow function pattern: bar = () => {}" do
    code = """
    const first = function() {}
    const bar = () => {}
    """

    splits = split_indices(code)
    assert length(splits) == 1
  end

  test "emits split for async function pattern: baz = async function() {}" do
    code = """
    const first = function() {}
    const baz = async function() {}
    """

    splits = split_indices(code)
    assert length(splits) == 1
  end

  test "does NOT emit for the first assignment in file (seen_content == false)" do
    code = "const foo = function() {}\n"
    splits = split_indices(code)
    assert splits == []
  end

  test "does NOT emit for plain assignment: x = 1" do
    code = """
    const first = function() {}
    x = 1
    """

    splits = split_indices(code)
    assert splits == []
  end

  test "does NOT emit when identifier is indented (indent > 0)" do
    code = """
    const first = function() {}
      foo = function() {}
    """

    splits = split_indices(code)
    assert splits == []
  end

  test "emits split for module.exports = function() pattern" do
    code = """
    const first = function() {}
    module.exports = function() {}
    """

    splits = split_indices(code)
    assert length(splits) == 1
  end

  test "group/1 returns :split" do
    assert Signal.group(%AssignmentFunctionSignal{}) == :split
  end
end
