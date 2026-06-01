defmodule CodeQA.AST.StringTokenTest do
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.StringToken
  alias CodeQA.AST.Lexing.TokenNormalizer

  describe "StringToken struct" do
    test "has kind, content, line, col, interpolations, multiline, and quotes fields" do
      tok = %StringToken{
        kind: "<STR>",
        content: ~s("hello"),
        line: 1,
        col: 0,
        interpolations: nil
      }

      assert tok.kind == "<STR>"
      assert tok.content == ~s("hello")
      assert tok.line == 1
      assert tok.col == 0
      assert tok.interpolations == nil
      assert tok.multiline == false
      assert tok.quotes == :double
    end

    test "interpolations defaults to nil" do
      tok = %StringToken{kind: "<STR>", content: ~s("hello")}
      assert tok.interpolations == nil
    end

    test "multiline defaults to false" do
      tok = %StringToken{kind: "<STR>", content: ~s("hello")}
      assert tok.multiline == false
    end

    test "quotes defaults to :double" do
      tok = %StringToken{kind: "<STR>", content: ~s("hello")}
      assert tok.quotes == :double
    end

    test "multiline triple-quote struct" do
      tok = %StringToken{kind: "<DOC>", content: ~s("""), multiline: true, quotes: :double}
      assert tok.multiline == true
      assert tok.quotes == :double
    end
  end

  describe "TokenNormalizer emits StringToken for strings" do
    test "plain string emits a StringToken" do
      [tok] =
        TokenNormalizer.normalize_structural(~s("hello"))
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert %StringToken{} = tok
    end

    test "plain string StringToken has nil interpolations" do
      [tok] =
        TokenNormalizer.normalize_structural(~s("hello"))
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == nil
    end

    test "Elixir/Ruby interpolated string emits a StringToken" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello #{name}"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert %StringToken{} = tok
    end

    test "JS/TS backtick interpolated string emits a StringToken" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`hello ${name}`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert %StringToken{} = tok
    end

    test "Kotlin/Dart/Scala interpolated string emits a StringToken" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello ${name}"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert %StringToken{} = tok
    end

    test "Swift interpolated string emits a StringToken" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello \(name)"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert %StringToken{} = tok
    end

    test "plain backtick string emits a StringToken" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`hello`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert %StringToken{} = tok
    end

    test "non-string tokens are still plain Token structs" do
      tokens = TokenNormalizer.normalize_structural("foo = 42")
      id = Enum.find(tokens, &(&1.kind == "<ID>"))
      refute match?(%StringToken{}, id)
    end
  end

  describe "quotes field" do
    test "double-quoted string has quotes :double" do
      [tok] =
        TokenNormalizer.normalize_structural(~s("hello"))
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.quotes == :double
    end

    test "single-quoted string has quotes :single" do
      [tok] =
        TokenNormalizer.normalize_structural("'hello'")
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.quotes == :single
    end

    test "backtick string has quotes :backtick" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`hello`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.quotes == :backtick
    end

    test "backtick interpolated string has quotes :backtick" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`hello ${name}`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.quotes == :backtick
    end

    test "Elixir interpolated string has quotes :double" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello #{name}"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.quotes == :double
    end
  end

  describe "multiline field" do
    test "regular string has multiline false" do
      [tok] =
        TokenNormalizer.normalize_structural(~s("hello"))
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.multiline == false
    end

    test "double triple-quote token has multiline true" do
      [tok | _] =
        TokenNormalizer.normalize_structural(~s("""\nhello\n"""))
        |> Enum.filter(&(&1.kind == "<DOC>"))

      assert tok.multiline == true
    end

    test "single triple-quote token has multiline true" do
      [tok | _] =
        TokenNormalizer.normalize_structural("'''\nhello\n'''")
        |> Enum.filter(&(&1.kind == "<DOC>"))

      assert tok.multiline == true
    end

    test "triple-quote token quotes :double for \"\"\"" do
      [tok | _] =
        TokenNormalizer.normalize_structural(~s("""\nhello\n"""))
        |> Enum.filter(&(&1.kind == "<DOC>"))

      assert tok.quotes == :double
    end

    test "triple-quote token quotes :single for '''" do
      [tok | _] =
        TokenNormalizer.normalize_structural("'''\nhello\n'''")
        |> Enum.filter(&(&1.kind == "<DOC>"))

      assert tok.quotes == :single
    end
  end
end
