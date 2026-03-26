defmodule CodeQA.AST.Enrichment.CompoundNodeBuilderTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.NodeTypeDetector
  alias CodeQA.AST.Enrichment.CompoundNode
  alias CodeQA.AST.Enrichment.CompoundNodeBuilder
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Nodes.{AttributeNode, CodeNode, DocNode}
  alias CodeQA.AST.Parsing.Parser

  defp build(code) do
    lang_mod = CodeQA.Languages.Code.Vm.Elixir
    opts = [language_module: lang_mod]

    code
    |> TokenNormalizer.normalize_structural()
    |> Parser.detect_blocks(lang_mod)
    |> NodeTypeDetector.detect_types(lang_mod)
    |> CompoundNodeBuilder.build()
  end

  describe "build/1" do
    test "returns CompoundNode structs" do
      [compound | _] = build("def foo, do: :ok")
      assert %CompoundNode{} = compound
    end

    test "bare code block wraps in compound with empty docs and typespecs" do
      [compound] = build("def foo, do: :ok")
      assert compound.docs == []
      assert compound.typespecs == []
      assert length(compound.code) == 1
    end

    test "@doc block attaches to following code block" do
      code = ~s(@doc """\nSome doc.\n"""\ndef foo, do: :ok)
      [compound] = build(code)
      assert length(compound.docs) == 1
      assert length(compound.code) == 1
    end

    test "@spec block attaches to following code block" do
      code = "@spec foo() :: :ok\ndef foo, do: :ok"
      [compound] = build(code)
      assert length(compound.typespecs) == 1
      assert length(compound.code) == 1
    end

    test "consecutive code clauses accumulate in same compound" do
      code = "def foo(:a), do: 1\ndef foo(:b), do: 2\ndef foo(_), do: 3"
      [compound] = build(code)
      assert length(compound.code) == 3
    end

    test "doc after code starts a new compound" do
      code = ~s(def foo do\n  :ok\nend\n\n\n@doc """\nSome doc.\n"""\ndef bar, do: :ok)
      compounds = build(code)
      assert length(compounds) == 2
      [first, second] = compounds
      assert first.docs == []
      assert length(second.docs) == 1
    end

    test "two blank lines between code blocks starts a new compound" do
      code = "def foo, do: :ok\n\n\ndef bar, do: :ok"
      compounds = build(code)
      assert length(compounds) == 2
    end

    test "single blank line between code blocks does NOT start a new compound" do
      code = "def foo(:a), do: 1\n\ndef foo(:b), do: 2"
      [compound] = build(code)
      assert length(compound.code) == 2
    end

    test "start_line is set from first non-whitespace token" do
      [compound] = build("def foo, do: :ok")
      assert is_integer(compound.start_line)
      assert compound.start_line >= 1
    end

    test "start_col is set from first non-whitespace token" do
      [compound] = build("def foo, do: :ok")
      assert is_integer(compound.start_col)
    end

    test "typespec block before any code attaches to compound (no flush)" do
      code = "@spec foo() :: :ok\ndef foo, do: :ok"
      [compound] = build(code)
      assert length(compound.typespecs) == 1
      assert length(compound.code) == 1
    end

    test "end_line is set from last non-whitespace token" do
      [compound] = build("def foo, do: :ok")
      assert is_integer(compound.end_line)
    end

    test "end_col is set from last non-whitespace token" do
      [compound] = build("def foo, do: :ok")
      assert is_integer(compound.end_col)
    end

    test "empty list returns empty list" do
      assert [] == CompoundNodeBuilder.build([])
    end
  end

  describe "build/1 with typed node structs" do
    test "routes DocNode to docs bucket" do
      doc = %DocNode{tokens: [:d], line_count: 1, children: [], start_line: 1, end_line: 1}
      code = %CodeNode{tokens: [:c], line_count: 2, children: [], start_line: 2, end_line: 3}

      [compound] = CompoundNodeBuilder.build([doc, code])
      assert length(compound.docs) == 1
      assert is_struct(hd(compound.docs), DocNode)
    end

    test "routes AttributeNode to typespecs bucket" do
      attr = %AttributeNode{
        tokens: [:a],
        line_count: 1,
        children: [],
        start_line: 1,
        end_line: 1,
        kind: :typespec
      }

      code = %CodeNode{tokens: [:c], line_count: 2, children: [], start_line: 2, end_line: 3}

      [compound] = CompoundNodeBuilder.build([attr, code])
      assert length(compound.typespecs) == 1
      assert is_struct(hd(compound.typespecs), AttributeNode)
    end
  end
end
