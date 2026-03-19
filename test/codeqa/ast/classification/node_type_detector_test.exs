defmodule CodeQA.AST.Classification.NodeTypeDetectorTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.AST.Classification.NodeTypeDetector
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Nodes.{CodeNode, DocNode, AttributeNode, FunctionNode}

  defp detect_types(code, lang_mod \\ CodeQA.Languages.Code.Vm.Elixir) do
    code
    |> TokenNormalizer.normalize_structural()
    |> Parser.detect_blocks(lang_mod)
    |> NodeTypeDetector.detect_types(lang_mod)
  end

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
        Enum.find(blocks, fn b ->
          Enum.any?(b.tokens, &(&1.kind == "<ID>" and &1.content == "def"))
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
      assert [] == NodeTypeDetector.detect_types([], CodeQA.Languages.Unknown)
    end
  end

  describe "detect_types/1 — typed struct output" do
    test "returns DocNode for doc blocks" do
      doc_token = %CodeQA.AST.Lexing.Token{kind: "<DOC>", content: ~s("""), line: 1, col: 0}
      nl = %CodeQA.AST.Lexing.Token{kind: "<NL>", content: "\n", line: 2, col: 0}

      node = %CodeQA.AST.Enrichment.Node{
        tokens: [doc_token, nl],
        line_count: 2,
        children: [],
        start_line: 1,
        end_line: 2
      }

      [result] =
        CodeQA.AST.Classification.NodeTypeDetector.detect_types(
          [node],
          CodeQA.Languages.Code.Vm.Elixir
        )

      assert is_struct(result, DocNode)
    end

    test "returns AttributeNode for typespec blocks" do
      at = %CodeQA.AST.Lexing.Token{kind: "@", content: "@", line: 1, col: 0}
      spec = %CodeQA.AST.Lexing.Token{kind: "<ID>", content: "spec", line: 1, col: 1}
      nl = %CodeQA.AST.Lexing.Token{kind: "<NL>", content: "\n", line: 1, col: 5}

      node = %CodeQA.AST.Enrichment.Node{
        tokens: [at, spec, nl],
        line_count: 1,
        children: [],
        start_line: 1,
        end_line: 1
      }

      [result] =
        CodeQA.AST.Classification.NodeTypeDetector.detect_types(
          [node],
          CodeQA.Languages.Code.Vm.Elixir
        )

      assert is_struct(result, AttributeNode)
      assert result.kind == :typespec
    end

    test "returns CodeNode for unclassified blocks" do
      id = %CodeQA.AST.Lexing.Token{kind: "<ID>", content: "foo", line: 1, col: 0}
      nl = %CodeQA.AST.Lexing.Token{kind: "<NL>", content: "\n", line: 1, col: 3}

      node = %CodeQA.AST.Enrichment.Node{
        tokens: [id, nl],
        line_count: 1,
        children: [],
        start_line: 1,
        end_line: 1
      }

      [result] =
        CodeQA.AST.Classification.NodeTypeDetector.detect_types(
          [node],
          CodeQA.Languages.Code.Vm.Elixir
        )

      assert is_struct(result, CodeNode)
    end
  end
end
