defmodule CodeQA.AST.Classification.NodeTypeDetectorTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Classification.NodeTypeDetector
  alias CodeQA.AST.Enrichment.Node
  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Nodes.AttributeNode
  alias CodeQA.AST.Nodes.CodeNode
  alias CodeQA.AST.Nodes.DocNode
  alias CodeQA.AST.Nodes.FunctionNode
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Languages.Code.Vm.Elixir, as: ElixirLang
  alias CodeQA.Languages.Unknown

  defp detect_types(code, lang_mod \\ ElixirLang),
    do:
      code
      |> TokenNormalizer.normalize_structural()
      |> Parser.detect_blocks(lang_mod)
      |> NodeTypeDetector.detect_types(lang_mod)

  describe "detect_types/1" do
    test "block with <TRIP_QUOTES> gets type :doc" do
      code = ~s(@moduledoc """\nSome doc.\n""")
      [block] = detect_types(code)
      assert is_struct(block, DocNode)
    end

    test "block with @spec gets type :typespec" do
      code = "@spec fetch_user(integer()) :: {:ok, term()}"
      [block] = detect_types(code)
      assert is_struct(block, AttributeNode)
      assert block.kind == :typespec
    end

    test "block with @type gets type :typespec" do
      code = "@type user_id :: integer()"
      [block] = detect_types(code)
      assert is_struct(block, AttributeNode)
      assert block.kind == :typespec
    end

    test "block starting with def gets type :function" do
      code = "def foo(x), do: x + 1"
      [block] = detect_types(code)
      assert is_struct(block, FunctionNode)
    end

    test "@ attribute inside function body does not make block :attribute" do
      # FunctionSignal sees 'def' first → :function wins
      # AttributeSignal sees '@cache' but at indent > 0 → no vote
      code = "def foo do\n  @cache true\n  :ok\nend"
      blocks = detect_types(code)

      code_block =
        blocks
        |> Enum.find(fn b ->
          b.tokens |> Enum.any?(&(&1.kind == "<ID>" and &1.content == "def"))
        end)

      assert is_struct(code_block, FunctionNode)
    end

    test "returns same number of blocks as input" do
      code = "@spec foo() :: :ok\n\n\ndef foo, do: :ok"
      blocks = detect_types(code)
      assert length(blocks) == 2
    end

    test "all @typespec_attributes are recognized" do
      for attr <- ~w[spec type typep opaque callback macrocallback] do
        code = "@#{attr} foo :: bar"
        [block] = detect_types(code)

        assert is_struct(block, AttributeNode) and block.kind == :typespec,
               "expected AttributeNode with kind: :typespec for @#{attr}"
      end
    end

    test "empty list returns empty list" do
      assert [] == NodeTypeDetector.detect_types([], Unknown)
    end
  end

  describe "detect_types/1 — typed struct output" do
    test "returns DocNode for doc blocks" do
      doc_token = %Token{col: 0, content: ~s("""), kind: "<DOC>", line: 1}
      nl = %Token{col: 0, content: "\n", kind: "<NL>", line: 2}

      node = %Node{
        children: [],
        end_line: 2,
        line_count: 2,
        start_line: 1,
        tokens: [doc_token, nl]
      }

      [result] =
        NodeTypeDetector.detect_types(
          [node],
          ElixirLang
        )

      assert is_struct(result, DocNode)
    end

    test "returns AttributeNode for typespec blocks" do
      at = %Token{col: 0, content: "@", kind: "@", line: 1}
      spec = %Token{col: 1, content: "spec", kind: "<ID>", line: 1}
      nl = %Token{col: 5, content: "\n", kind: "<NL>", line: 1}

      node = %Node{
        children: [],
        end_line: 1,
        line_count: 1,
        start_line: 1,
        tokens: [at, spec, nl]
      }

      [result] =
        NodeTypeDetector.detect_types(
          [node],
          ElixirLang
        )

      assert is_struct(result, AttributeNode)
      assert result.kind == :typespec
    end

    test "returns CodeNode for unclassified blocks" do
      id = %Token{col: 0, content: "foo", kind: "<ID>", line: 1}
      nl = %Token{col: 3, content: "\n", kind: "<NL>", line: 1}

      node = %Node{
        children: [],
        end_line: 1,
        line_count: 1,
        start_line: 1,
        tokens: [id, nl]
      }

      [result] =
        NodeTypeDetector.detect_types(
          [node],
          ElixirLang
        )

      assert is_struct(result, CodeNode)
    end
  end
end
