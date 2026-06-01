defmodule CodeQA.AST.Lexing.TokenProtocolTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.StringToken
  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Lexing.TokenProtocol

  describe "Token implementation" do
    setup do
      {:ok, token: %Token{col: 7, content: "foo", kind: "<ID>", line: 3}}
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
      t = %Token{col: nil, content: "\n", kind: "<NL>", line: nil}
      assert TokenProtocol.line(t) == nil
      assert TokenProtocol.col(t) == nil
    end
  end

  describe "StringToken implementation" do
    setup do
      {:ok,
       token: %StringToken{
         col: 2,
         content: "\"hello\"",
         interpolations: nil,
         kind: "<STR>",
         line: 10
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
        col: 0,
        content: "\"\#{x}\"",
        interpolations: ["x"],
        kind: "<STR>",
        line: 5
      }

      assert TokenProtocol.kind(t) == "<STR>"
      assert TokenProtocol.content(t) == "\"\#{x}\""
    end
  end

  describe "StringToken <DOC> (multiline) via protocol" do
    setup do
      {:ok,
       token: %StringToken{
         col: 0,
         content: ~s("""),
         kind: "<DOC>",
         line: 2,
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
        col: 0,
        content: "'''",
        kind: "<DOC>",
        line: 5,
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
        %Token{col: 0, content: "x", kind: "<ID>", line: 1},
        %StringToken{col: 4, content: "\"hi\"", kind: "<STR>", line: 1},
        %StringToken{
          col: 0,
          content: ~s("""),
          kind: "<DOC>",
          line: 2,
          multiline: true,
          quotes: :double
        },
        %Token{col: 3, content: "\n", kind: "<NL>", line: 2}
      ]

      kinds = tokens |> Enum.map(&TokenProtocol.kind/1)
      assert kinds == ["<ID>", "<STR>", "<DOC>", "<NL>"]
    end
  end
end
