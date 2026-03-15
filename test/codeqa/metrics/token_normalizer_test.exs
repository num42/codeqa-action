defmodule CodeQA.Metrics.TokenNormalizerTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.TokenNormalizer

  describe "normalize_structural/1" do
    test "emits <NL> between lines" do
      result = TokenNormalizer.normalize_structural("a\nb")
      assert "<NL>" in result
    end

    test "two blank lines produce two or more consecutive <NL> tokens" do
      result = TokenNormalizer.normalize_structural("a\n\nb")
      nl_runs =
        result
        |> Enum.chunk_by(&(&1 == "<NL>"))
        |> Enum.filter(fn [h | _] -> h == "<NL>" end)
        |> Enum.map(&length/1)
      assert Enum.any?(nl_runs, &(&1 >= 2))
    end

    test "emits one <WS> token per 2 leading spaces" do
      result = TokenNormalizer.normalize_structural("    foo")
      assert Enum.count(result, &(&1 == "<WS>")) == 2
    end

    test "emits one <WS> token per tab" do
      result = TokenNormalizer.normalize_structural("\t\tfoo")
      assert Enum.count(result, &(&1 == "<WS>")) == 2
    end

    test "normalizes identifiers to <ID>" do
      result = TokenNormalizer.normalize_structural("foo bar")
      assert result == ["<ID>", "<ID>"]
    end

    test "normalizes numbers to <NUM>" do
      result = TokenNormalizer.normalize_structural("x = 42")
      assert "<NUM>" in result
    end

    test "empty string returns empty list" do
      assert TokenNormalizer.normalize_structural("") == []
    end

    test "single leading space produces zero <WS> tokens (below threshold)" do
      result = TokenNormalizer.normalize_structural(" foo")
      assert Enum.count(result, &(&1 == "<WS>")) == 0
    end

    test "punctuation tokens like ( and : survive as individual tokens" do
      result = TokenNormalizer.normalize_structural("foo(x):")
      assert "(" in result
      assert ")" in result
      assert ":" in result
    end

    test "existing normalize/1 still works unchanged" do
      # normalize/1 must not emit <NL> — other metrics depend on it
      result = TokenNormalizer.normalize("foo\nbar")
      refute "<NL>" in result
    end
  end
end
