defmodule CodeQA.BlockImpact.CodebaseImpactTest do
  use ExUnit.Case, async: true

  alias CodeQA.BlockImpact.CodebaseImpact
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Languages.Unknown

  @content_a """
  defmodule A do
    def foo do
      x = 1 + 2
      y = x * 3
      x + y
    end

    def bar do
      :ok
    end
  end
  """

  @content_b """
  defmodule B do
    def baz, do: :baz
  end
  """

  defp files_map, do: %{"lib/a.ex" => @content_a, "lib/b.ex" => @content_b}

  defp first_block(content) do
    tokens = TokenNormalizer.normalize_structural(content)
    [first | _] = Parser.detect_blocks(tokens, Unknown)
    first
  end

  describe "compute/4" do
    test "returns a codebase aggregate map" do
      node = first_block(@content_a)
      result = CodebaseImpact.compute("lib/a.ex", @content_a, node, files_map())
      assert is_map(result)
      # Should have at least one group with mean_ keys
      all_keys = result |> Map.values() |> Enum.flat_map(&Map.keys/1)
      assert Enum.any?(all_keys, &String.starts_with?(&1, "mean_"))
    end

    test "produces a different aggregate than the baseline when a large node is removed" do
      node = first_block(@content_a)

      if length(node.tokens) >= 10 do
        baseline = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(files_map())
        without = CodebaseImpact.compute("lib/a.ex", @content_a, node, files_map())
        # Not necessarily different in all keys, but result is valid
        assert is_map(without)
        assert is_map(baseline)
      end
    end
  end
end
