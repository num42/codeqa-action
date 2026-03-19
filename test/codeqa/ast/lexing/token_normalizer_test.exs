defmodule CodeQA.AST.TokenNormalizerTest do
  use ExUnit.Case, async: true
  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Lexing.StringToken

  defp kinds(tokens), do: Enum.map(tokens, & &1.kind)

  describe "normalize_structural/1" do
    test "emits <NL> between lines" do
      result = TokenNormalizer.normalize_structural("a\nb")
      assert "<NL>" in kinds(result)
    end

    test "two blank lines produce two or more consecutive <NL> tokens" do
      result = TokenNormalizer.normalize_structural("a\n\nb")

      nl_runs =
        result
        |> Enum.chunk_by(&(&1.kind == "<NL>"))
        |> Enum.filter(fn [h | _] -> h.kind == "<NL>" end)
        |> Enum.map(&length/1)

      assert Enum.any?(nl_runs, &(&1 >= 2))
    end

    test "emits one <WS> token per 2 leading spaces" do
      result = TokenNormalizer.normalize_structural("    foo")
      assert Enum.count(result, &(&1.kind == "<WS>")) == 2
    end

    test "emits one <WS> token per tab" do
      result = TokenNormalizer.normalize_structural("\t\tfoo")
      assert Enum.count(result, &(&1.kind == "<WS>")) == 2
    end

    test "normalizes identifiers to <ID>" do
      result = TokenNormalizer.normalize_structural("foo bar")
      assert kinds(result) == ["<ID>", "<ID>"]
    end

    test "normalizes numbers to <NUM>" do
      result = TokenNormalizer.normalize_structural("x = 42")
      assert "<NUM>" in kinds(result)
    end

    test "empty string returns empty list" do
      assert TokenNormalizer.normalize_structural("") == []
    end

    test "single leading space produces zero <WS> tokens (below threshold)" do
      result = TokenNormalizer.normalize_structural(" foo")
      assert not Enum.any?(result, &(&1.kind == "<WS>"))
    end

    test "punctuation tokens like ( and : survive as individual tokens" do
      result = TokenNormalizer.normalize_structural("foo(x):")
      assert "(" in kinds(result)
      assert ")" in kinds(result)
      assert ":" in kinds(result)
    end

    test "tokens carry line numbers" do
      result = TokenNormalizer.normalize_structural("foo\nbar")
      lines = Enum.map(result, & &1.line)
      assert 1 in lines
      assert 2 in lines
    end

    test "tokens carry col offsets" do
      result = TokenNormalizer.normalize_structural("foo")
      [tok] = result
      assert tok.col == 0
    end

    test "identifier token preserves original content" do
      result = TokenNormalizer.normalize_structural("myVar")
      [tok] = result
      assert tok.kind == "<ID>"
      assert tok.content == "myVar"
    end

    test "keyword content is preserved (not normalized away)" do
      result = TokenNormalizer.normalize_structural("def foo")
      contents = Enum.map(result, & &1.content)
      assert "def" in contents
    end

    test "string token content is the original literal" do
      result = TokenNormalizer.normalize_structural(~s("hello"))
      tok = Enum.find(result, &(&1.kind == "<STR>"))
      assert tok.content == ~s("hello")
    end

    # multi-char operator tests

    test ">= is a single token" do
      result = TokenNormalizer.normalize_structural("x >= y")
      assert ">=" in kinds(result)
      refute ">" in kinds(result)
    end

    test "<= is a single token" do
      result = TokenNormalizer.normalize_structural("x <= y")
      assert "<=" in kinds(result)
      refute "<" in kinds(result)
    end

    test "== is a single token" do
      result = TokenNormalizer.normalize_structural("x == y")
      assert "==" in kinds(result)
    end

    test "!= is a single token" do
      result = TokenNormalizer.normalize_structural("x != y")
      assert "!=" in kinds(result)
      refute "!" in kinds(result)
    end

    test "=== is a single token (not == + =)" do
      result = TokenNormalizer.normalize_structural("x === y")
      assert "===" in kinds(result)
      refute "==" in kinds(result)
    end

    test "!== is a single token" do
      result = TokenNormalizer.normalize_structural("x !== y")
      assert "!==" in kinds(result)
      refute "!=" in kinds(result)
    end

    test "|> is a single token (Elixir pipe)" do
      result = TokenNormalizer.normalize_structural("x |> f")
      assert "|>" in kinds(result)
      refute "|" in kinds(result)
    end

    test "<> is a single token (Elixir concat)" do
      result = TokenNormalizer.normalize_structural(~s("a" <> "b"))
      assert "<>" in kinds(result)
    end

    test "<- is a single token (Elixir/Go arrow)" do
      result = TokenNormalizer.normalize_structural("x <- y")
      assert "<-" in kinds(result)
      refute "<" in kinds(result)
    end

    test "-> is a single token" do
      result = TokenNormalizer.normalize_structural("x -> y")
      assert "->" in kinds(result)
      refute "-" in kinds(result)
    end

    test "=> is a single token (fat arrow)" do
      result = TokenNormalizer.normalize_structural("k => v")
      assert "=>" in kinds(result)
    end

    test "=~ is a single token (regex match)" do
      result = TokenNormalizer.normalize_structural("x =~ y")
      assert "=~" in kinds(result)
    end

    test "&& is a single token" do
      result = TokenNormalizer.normalize_structural("a && b")
      assert "&&" in kinds(result)
      refute "&" in kinds(result)
    end

    test "|| is a single token" do
      result = TokenNormalizer.normalize_structural("a || b")
      assert "||" in kinds(result)
      refute "|" in kinds(result)
    end

    test ":: is a single token" do
      result = TokenNormalizer.normalize_structural("Foo::Bar")
      assert "::" in kinds(result)
      refute ":" in kinds(result)
    end

    test ".. is a single token" do
      result = TokenNormalizer.normalize_structural("1..10")
      assert ".." in kinds(result)
    end

    test "... is a single token (not .. + .)" do
      result = TokenNormalizer.normalize_structural("1...10")
      assert "..." in kinds(result)
      refute ".." in kinds(result)
    end

    test "multi-char operator value equals content (no normalization)" do
      result = TokenNormalizer.normalize_structural("x >= y")
      tok = Enum.find(result, &(&1.kind == ">="))
      assert tok.content == ">="
    end
  end

  describe "interpolated string tokens are normalised to <STR>" do
    test "Elixir/Ruby #{} emits <STR> with interpolations" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello #{name}"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == ["name"]
    end

    test "JS/TS backtick with \${} emits <STR> with interpolations" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`hello ${name}`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == ["name"]
    end

    test "JS/TS backtick static content has interpolation stripped" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`hello ${name} world`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.content == "`hello  world`"
    end

    test "JS/TS backtick two interpolations are both captured" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`${a} and ${b}`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == ["a", "b"]
    end

    test "plain backtick string without interpolation emits <STR> with nil interpolations" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|`hello world`|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == nil
    end

    test "Kotlin/Dart/Scala \${} emits <STR> with interpolations" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello ${name}"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == ["name"]
    end

    test "Kotlin/Dart/Scala static content has interpolation stripped" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello ${name} world"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.content == ~S|"hello  world"|
    end

    test "Kotlin/Dart/Scala two interpolations are both captured" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"${a} and ${b}"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == ["a", "b"]
    end

    test "Swift \\(...) emits <STR> with interpolations" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello \(name)"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == ["name"]
    end

    test "Swift static content has interpolation stripped" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"hello \(name) world"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.content == ~S|"hello  world"|
    end

    test "Swift two interpolations are both captured" do
      [tok] =
        TokenNormalizer.normalize_structural(~S|"\(a) and \(b)"|)
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == ["a", "b"]
    end

    test "plain double-quoted string has nil interpolations" do
      [tok] =
        TokenNormalizer.normalize_structural(~s("hello"))
        |> Enum.filter(&(&1.kind == "<STR>"))

      assert tok.interpolations == nil
    end
  end

  describe "<TRIP_QUOTES> token" do
    test "triple double-quotes emits a StringToken with kind <DOC>" do
      tokens = TokenNormalizer.normalize_structural(~s("""))

      assert [%StringToken{kind: "<DOC>", content: ~s("""), multiline: true, quotes: :double}] =
               tokens
    end

    test "triple single-quotes emits a StringToken with kind <DOC>" do
      tokens = TokenNormalizer.normalize_structural("'''")

      assert [%StringToken{kind: "<DOC>", content: "'''", multiline: true, quotes: :single}] =
               tokens
    end

    test "triple-quote is not consumed as empty string + bare quote" do
      tokens = TokenNormalizer.normalize_structural(~s("""))
      refute Enum.any?(tokens, &(&1.kind == "<STR>"))
    end

    test "content between triple-quotes is tokenized normally" do
      code = ~s("""\nhello world\n""")
      tokens = TokenNormalizer.normalize_structural(code)
      trip_count = Enum.count(tokens, &(&1.kind == "<DOC>"))
      assert trip_count == 2
      assert Enum.any?(tokens, &(&1.kind == "<ID>" and &1.content == "hello"))
    end

    test "regular double-quoted string still works" do
      tokens = TokenNormalizer.normalize_structural(~s("hello"))
      assert [%StringToken{kind: "<STR>"}] = tokens
    end
  end
end
