defmodule CodeQA.AST.Parsing.ParserTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Languages.Code.Scripting.Python
  alias CodeQA.Languages.Code.Vm.Elixir, as: ElixirLang
  alias CodeQA.Languages.Unknown

  defp tokenize(code), do: TokenNormalizer.normalize_structural(code)

  describe "detect_blocks/2" do
    test "single block for file with no blank lines" do
      tokens = tokenize("def foo\n  x = 1\nend\n")
      blocks = Parser.detect_blocks(tokens, ElixirLang)
      assert length(blocks) == 1
    end

    test "splits into two blocks at blank line" do
      tokens = tokenize("def foo\n  x\nend\n\n\ndef bar\n  y\nend\n")
      blocks = Parser.detect_blocks(tokens, ElixirLang)
      assert length(blocks) == 2
    end

    test "each block has correct line_count" do
      tokens = tokenize("def foo\n  x\nend\n\n\ndef bar\n  y\nend\n")
      [b1, b2] = Parser.detect_blocks(tokens, ElixirLang)
      assert b1.line_count >= 3
      assert b2.line_count >= 3
    end

    test "empty input returns empty list" do
      assert Parser.detect_blocks([], Unknown) == []
    end

    test "detects bracket sub-blocks" do
      tokens = tokenize("foo(a, b)\nbar(c)\n")
      [block] = Parser.detect_blocks(tokens, Unknown)
      assert block.children != []
    end

    test "detects colon-indent sub-blocks for python language hint" do
      tokens = tokenize("def foo:\n    return 1\n")
      [block] = Parser.detect_blocks(tokens, Python)
      assert block.children != []
    end

    test "fewer sub-blocks without python hint than with it (colon rule not applied)" do
      tokens = tokenize("def foo:\n    return 1\n")
      without_hint = Parser.detect_blocks(tokens, Unknown)
      with_hint = Parser.detect_blocks(tokens, Python)
      count_without = without_hint |> Enum.map(&length(&1.children)) |> Enum.sum()
      count_with = with_hint |> Enum.map(&length(&1.children)) |> Enum.sum()
      assert count_with >= count_without
    end

    test "block has children_count accessible via Node.children_count/1" do
      tokens = tokenize("foo(a)\nbar(b)\n")
      [block] = Parser.detect_blocks(tokens, Unknown)
      assert Node.children_count(block) == length(block.children)
    end
  end

  describe "recursive sub-block nesting" do
    test "nested bracket calls produce a multi-level sub-block tree" do
      # def foo(bar(x, y), baz) — the arg list contains another call with its own args
      tokens = tokenize("def foo(bar(x, y), baz)\n  result\nend\n")
      [block] = Parser.detect_blocks(tokens, Unknown)

      # depth 1 — the outer argument list
      args =
        Enum.find(block.children, fn b ->
          Enum.any?(b.tokens, &(&1.content == "bar"))
        end)

      assert args != nil, "expected an arg-list sub-block containing 'bar'"

      # depth 2 — the inner call (x, y) inside bar(...)
      inner =
        Enum.find(args.children, fn b ->
          Enum.any?(b.tokens, &(&1.content == "x"))
        end)

      assert inner != nil, "expected a sub-block for the inner call (x, y)"

      # depth 3 — (x, y) is a leaf: no further bracket structure inside
      assert inner.children == []
    end

    test "triply nested brackets produce three levels of sub-blocks" do
      tokens = tokenize("def outer(inner(deep(value)))\n  :ok\nend\n")
      [block] = Parser.detect_blocks(tokens, Unknown)

      # depth 1: (inner(deep(value)))
      d1 =
        Enum.find(block.children, fn b ->
          Enum.any?(b.tokens, &(&1.content == "inner"))
        end)

      assert d1 != nil

      # depth 2: (deep(value))
      d2 =
        Enum.find(d1.children, fn b ->
          Enum.any?(b.tokens, &(&1.content == "deep"))
        end)

      assert d2 != nil

      # depth 3: (value) — leaf
      d3 =
        Enum.find(d2.children, fn b ->
          Enum.any?(b.tokens, &(&1.content == "value"))
        end)

      assert d3 != nil
      assert d3.children == []
    end
  end

  describe "triple-quote protection" do
    test "blank lines inside a heredoc do not create a new block" do
      code = """
      before


      \"""
      Some doc.

      More doc.
      \"""

      after
      """

      tokens = TokenNormalizer.normalize_structural(code)
      blocks = Parser.detect_blocks(tokens, Unknown)
      # The heredoc (including its blank line) should be ONE block, not split
      heredoc_block =
        Enum.find(blocks, fn b ->
          Enum.any?(b.tokens, &(&1.kind == "<DOC>"))
        end)

      assert heredoc_block != nil
      # Ensure no split happened inside — the heredoc block contains both "Some" and "More"
      contents = Enum.filter(heredoc_block.tokens, &(&1.kind == "<ID>"))
      names = Enum.map(contents, & &1.content)
      assert "Some" in names
      assert "More" in names
    end

    test "content before and after a heredoc becomes separate blocks" do
      code = """
      def foo do
        :ok
      end


      \"""
      doc here
      \"""


      def bar do
        :ok
      end
      """

      tokens = TokenNormalizer.normalize_structural(code)
      blocks = Parser.detect_blocks(tokens, Unknown)
      # Expect exactly 3 blocks: code-before, heredoc, code-after
      assert length(blocks) == 3
      assert Enum.any?(Enum.at(blocks, 0).tokens, &(&1.content == "foo"))
      assert Enum.any?(Enum.at(blocks, 1).tokens, &(&1.kind == "<DOC>"))
      assert Enum.any?(Enum.at(blocks, 2).tokens, &(&1.content == "bar"))
    end
  end

  describe "language_from_path/1" do
    test "returns :python for .py files" do
      assert Parser.language_from_path("lib/foo.py") == :python
    end

    test "returns :unknown for unknown extensions" do
      assert Parser.language_from_path("lib/foo.xyz") == :unknown
    end
  end
end
