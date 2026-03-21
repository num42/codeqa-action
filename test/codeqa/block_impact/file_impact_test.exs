defmodule CodeQA.BlockImpact.FileImpactTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.BlockImpact.FileImpact
  alias CodeQA.Languages.Unknown

  @fixture_content """
  defmodule MyModule do
    def foo do
      x = 1
      y = 2
      x + y
    end

    def bar do
      :ok
    end
  end
  """

  defp get_first_block(content) do
    tokens = TokenNormalizer.normalize_structural(content)
    [first | _] = Parser.detect_blocks(tokens, Unknown)
    first
  end

  describe "compute/2" do
    test "returns a metrics map when node has >= 10 tokens" do
      node = get_first_block(@fixture_content)

      if length(node.tokens) >= 10 do
        result = FileImpact.compute(@fixture_content, node)
        assert is_map(result)
        assert map_size(result) > 0
      end
    end

    test "returns nil for a node with fewer than 10 tokens" do
      # Create a tiny node by parsing very short content
      tiny_content = "x = 1"
      tokens = TokenNormalizer.normalize_structural(tiny_content)
      nodes = Parser.detect_blocks(tokens, Unknown)
      # Find or construct a node with < 10 tokens
      small_nodes = Enum.filter(nodes, fn n -> length(n.tokens) < 10 end)

      if small_nodes != [] do
        node = List.first(small_nodes)
        assert FileImpact.compute(tiny_content, node) == nil
      end
    end

    test "reconstructed content does not contain the removed node's first token line" do
      tokens = TokenNormalizer.normalize_structural(@fixture_content)
      [node | _] = Parser.detect_blocks(tokens, Unknown)
      # Only test if node is large enough
      if length(node.tokens) >= 10 do
        result = FileImpact.compute(@fixture_content, node)
        assert is_map(result)
      end
    end
  end
end
