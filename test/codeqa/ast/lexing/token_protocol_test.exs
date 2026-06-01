defmodule CodeQA.AST.Lexing.TokenProtocolTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.StringToken
  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Lexing.TokenProtocol

  describe "Token implementation" do
    setup do
      {:ok, token: %Token{kind: "<ID>", content: "foo", line: 3, col: 7}}
    end

    test "kind/1", %{token: t} do
      assert TokenProtocol.kind(t) == "<ID>"
    end

    test "content/1", %{token: t} do
      assert TokenProtocol.content(t) == "foo"
    end

    test "line/1", %{token: t} do
      assert TokenProtocol.line(t) == 3
    end

    test "col/1", %{token: t} do
      assert TokenProtocol.col(t) == 7
    end

    test "nil location fields are preserved" do
      t = %Token{kind: "<NL>", content: "\n", line: nil, col: nil}
      assert TokenProtocol.line(t) == nil
      assert TokenProtocol.col(t) == nil
    end
  end

  describe "StringToken implementation" do
    setup do
      {:ok,
       token: %StringToken{
         kind: "<STR>",
         content: "\"hello\"",
         line: 10,
         col: 2,
         interpolations: nil
       }}
    end

    test "kind/1", %{token: t} do
      assert TokenProtocol.kind(t) == "<STR>"
    end

    test "content/1", %{token: t} do
      assert TokenProtocol.content(t) == "\"hello\""
    end

    test "line/1", %{token: t} do
      assert TokenProtocol.line(t) == 10
    end

    test "col/1", %{token: t} do
      assert TokenProtocol.col(t) == 2
    end

    test "works with interpolated string token" do
      t = %StringToken{
        kind: "<STR>",
        content: "\"\#{x}\"",
        line: 5,
        col: 0,
        interpolations: ["x"]
      }

      assert TokenProtocol.kind(t) == "<STR>"
      assert TokenProtocol.content(t) == "\"\#{x}\""
    end
  end

  describe "StringToken <DOC> (multiline) via protocol" do
    setup do
      {:ok,
       token: %StringToken{
         kind: "<DOC>",
         content: ~s("""),
         line: 2,
         col: 0,
         multiline: true,
         quotes: :double
       }}
    end

    test "kind/1", %{token: t} do
      assert TokenProtocol.kind(t) == "<DOC>"
    end

    test "content/1", %{token: t} do
      assert TokenProtocol.content(t) == ~s(""")
    end

    test "line/1", %{token: t} do
      assert TokenProtocol.line(t) == 2
    end

    test "col/1", %{token: t} do
      assert TokenProtocol.col(t) == 0
    end

    test "single-quote variant" do
      t = %StringToken{
        kind: "<DOC>",
        content: "'''",
        line: 5,
        col: 0,
        multiline: true,
        quotes: :single
      }

      assert TokenProtocol.kind(t) == "<DOC>"
      assert t.quotes == :single
    end
  end

  describe "polymorphic use" do
    test "mixed token list can be processed uniformly" do
      tokens = [
        %Token{kind: "<ID>", content: "x", line: 1, col: 0},
        %StringToken{kind: "<STR>", content: "\"hi\"", line: 1, col: 4},
        %StringToken{
          kind: "<DOC>",
          content: ~s("""),
          line: 2,
          col: 0,
          multiline: true,
          quotes: :double
        },
        %Token{kind: "<NL>", content: "\n", line: 2, col: 3}
      ]

      kinds = Enum.map(tokens, &TokenProtocol.kind/1)
      assert kinds == ["<ID>", "<STR>", "<DOC>", "<NL>"]
    end
  end
end
