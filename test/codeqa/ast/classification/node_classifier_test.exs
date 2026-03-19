defmodule CodeQA.AST.NodeClassifierTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Classification.NodeClassifier
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.AST.Enrichment.Node

  alias CodeQA.AST.Nodes.{
    CodeNode,
    DocNode,
    FunctionNode,
    ModuleNode,
    ImportNode,
    AttributeNode,
    TestNode
  }

  alias CodeQA.Languages.Code.Vm.Elixir, as: ElixirLang
  alias CodeQA.Languages.Code.Scripting.Python
  alias CodeQA.Languages.Code.Web.JavaScript
  alias CodeQA.Languages.Code.Native.Go
  alias CodeQA.Languages.Code.Native.Rust
  alias CodeQA.Languages.Code.Scripting.Ruby
  alias CodeQA.Languages.Code.Web.TypeScript
  alias CodeQA.Languages.Code.Vm.Java
  alias CodeQA.Languages.Code.Vm.CSharp

  defp classify_first(code, opts \\ []) do
    lang_mod = opts[:language_module] || CodeQA.Languages.Unknown

    [block | _] =
      code
      |> TokenNormalizer.normalize_structural()
      |> Parser.detect_blocks(lang_mod)

    NodeClassifier.classify(block, lang_mod)
  end

  defp node_with_tokens(tokens) do
    %Node{
      tokens: tokens,
      line_count: 1,
      children: []
    }
  end

  describe "classify/1 — function detection" do
    test "def → FunctionNode" do
      assert %FunctionNode{} =
               classify_first("def foo(x), do: x + 1", language_module: ElixirLang)
    end

    test "defp → FunctionNode" do
      assert %FunctionNode{} = classify_first("defp bar(x), do: x", language_module: ElixirLang)
    end

    test "defmacro → FunctionNode" do
      assert %FunctionNode{} =
               classify_first("defmacro my_macro(x), do: x", language_module: ElixirLang)
    end

    test "function keyword → FunctionNode" do
      assert %FunctionNode{} =
               classify_first("function foo(x) {\n  return x\n}", language_module: JavaScript)
    end

    test "func keyword → FunctionNode" do
      assert %FunctionNode{} =
               classify_first("func Foo(x int) int {\n  return x\n}", language_module: Go)
    end

    test "fn keyword → FunctionNode" do
      assert %FunctionNode{} =
               classify_first("fn main() {\n  println!(\"hello\")\n}", language_module: Rust)
    end
  end

  describe "classify/1 — module detection" do
    test "defmodule → ModuleNode" do
      assert %ModuleNode{} =
               classify_first("defmodule Foo do\n  :ok\nend", language_module: ElixirLang)
    end

    test "class → ModuleNode" do
      assert %ModuleNode{} = classify_first("class Foo:\n  pass", language_module: Python)
    end

    test "module → ModuleNode" do
      assert %ModuleNode{} =
               classify_first("module Foo\n  def bar; end\nend", language_module: Ruby)
    end

    test "interface → ModuleNode" do
      assert %ModuleNode{} =
               classify_first("interface Foo {\n  bar(): void\n}", language_module: TypeScript)
    end

    test "struct → ModuleNode" do
      assert %ModuleNode{} =
               classify_first("struct Point {\n  x: f64,\n  y: f64,\n}", language_module: Rust)
    end
  end

  describe "classify/1 — import detection" do
    test "import → ImportNode" do
      assert %ImportNode{} = classify_first("import Foo", language_module: ElixirLang)
    end

    test "alias → ImportNode" do
      assert %ImportNode{} = classify_first("alias Foo.Bar", language_module: ElixirLang)
    end

    test "use → ImportNode" do
      assert %ImportNode{} =
               classify_first("use ExUnit.Case, async: true", language_module: ElixirLang)
    end

    test "require → ImportNode" do
      assert %ImportNode{} = classify_first("require Logger", language_module: ElixirLang)
    end

    test "from keyword → ImportNode" do
      assert %ImportNode{} = classify_first("from os import path", language_module: Python)
    end
  end

  describe "classify/1 — test detection" do
    test "test macro → TestNode" do
      assert %TestNode{} =
               classify_first(~s(test "something" do\n  :ok\nend), language_module: ElixirLang)
    end

    test "describe → TestNode" do
      assert %TestNode{} =
               classify_first(~s(describe "some context" do\n  :ok\nend),
                 language_module: ElixirLang
               )
    end

    test "it → TestNode" do
      code = "it \"behaves correctly\" do\n  :ok\nend"
      assert %TestNode{} = classify_first(code, language_module: JavaScript)
    end
  end

  describe "classify/1 — doc detection" do
    test "<DOC> token → DocNode" do
      # A standalone triple-quoted string starts directly with the <DOC> token
      assert %DocNode{} = classify_first(~s("""\nSome doc.\n"""))
    end

    test "direct <DOC> token in node → DocNode" do
      doc_token = %Token{kind: "<DOC>", content: ~s("""), line: 1, col: 0}
      nl = %Token{kind: "<NL>", content: "\n", line: 2, col: 0}
      node = node_with_tokens([doc_token, nl])
      assert %DocNode{} = NodeClassifier.classify(node, CodeQA.Languages.Unknown)
    end
  end

  describe "classify/1 — attribute detection" do
    test "@spec → AttributeNode with kind: :typespec" do
      result = classify_first("@spec foo(integer()) :: :ok", language_module: ElixirLang)
      assert %AttributeNode{kind: :typespec} = result
    end

    test "@type → AttributeNode with kind: :typespec" do
      result = classify_first("@type user_id :: integer()", language_module: ElixirLang)
      assert %AttributeNode{kind: :typespec} = result
    end

    test "@typep → AttributeNode with kind: :typespec" do
      result = classify_first("@typep internal :: atom()", language_module: ElixirLang)
      assert %AttributeNode{kind: :typespec} = result
    end

    test "@callback → AttributeNode with kind: :typespec" do
      result =
        classify_first("@callback fetch(term()) :: {:ok, term()}", language_module: ElixirLang)

      assert %AttributeNode{kind: :typespec} = result
    end

    test "@enforce_keys → AttributeNode with kind: nil" do
      result = classify_first("@enforce_keys [:name, :age]", language_module: ElixirLang)
      assert %AttributeNode{kind: nil} = result
    end

    test "all Elixir typespec attributes are recognized" do
      for attr <- ~w[spec type typep opaque callback macrocallback] do
        result = classify_first("@#{attr} foo :: bar", language_module: ElixirLang)

        assert %AttributeNode{kind: :typespec} = result,
               "expected AttributeNode(kind: :typespec) for @#{attr}"
      end
    end
  end

  describe "classify/1 — code fallback" do
    test "unrecognized token → CodeNode" do
      assert %CodeNode{} = classify_first("x = 1 + 2")
    end

    test "empty-like node with only whitespace tokens → CodeNode" do
      nl = %Token{kind: "<NL>", content: "\n", line: 1, col: 0}
      node = node_with_tokens([nl])

      assert %CodeNode{} =
               NodeClassifier.classify(node, CodeQA.Languages.Unknown)
    end
  end

  describe "classify/1 — ambiguity resolution" do
    test "test beats function (test is not defp-style)" do
      # 'test' is in TestSignal; FunctionSignal does not include 'test'
      result = classify_first(~s(test "foo" do\n  :ok\nend), language_module: ElixirLang)
      assert %TestNode{} = result
    end

    test "@inside code body at indent > 0 does not make block :attribute" do
      code = "def foo do\n  @cache true\n  :ok\nend"
      # FunctionSignal sees 'def' at indent 0 → :function wins
      # AttributeSignal sees '@cache' but at indent 2, not 0 → no vote
      result = classify_first(code, language_module: ElixirLang)
      assert %FunctionNode{} = result
    end
  end

  describe "classify/1 — field preservation" do
    test "preserves tokens, line_count, children, start/end_line" do
      tokens =
        "def foo, do: :ok"
        |> TokenNormalizer.normalize_structural()

      [node] = Parser.detect_blocks(tokens, ElixirLang)
      result = NodeClassifier.classify(node, ElixirLang)

      assert result.tokens == node.tokens
      assert result.line_count == node.line_count
      assert result.children == node.children
      assert result.start_line == node.start_line
      assert result.end_line == node.end_line
    end
  end
end
