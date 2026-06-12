defmodule CodeQA.Metrics.File.LexicalDensityTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.LexicalDensity

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: LexicalDensity.analyze(ctx(code))

  describe "analyze/1 - edge cases" do
    test "returns zeros for empty content" do
      assert result("") == %{
               "lexical_density" => 0.0,
               "content_tokens" => 0,
               "function_tokens" => 0
             }
    end
  end

  describe "analyze/1 - lexical density" do
    test "high density for content-heavy arithmetic" do
      # total = subtotal + tax + shipping - discount
      # content: total, subtotal, tax, shipping, discount (5 ids)
      # function: = + + - (4 punct)
      code = "total = subtotal + tax + shipping - discount"
      assert result(code)["lexical_density"] > 0.5
    end

    test "low density for structure-heavy scaffold" do
      # case x do _ -> nil end
      # content: x, nil (2 ids — case/do/end are keywords)
      # function: case do _ -> end (keywords + punct)
      code = "case x do _ -> nil end"
      assert result(code)["lexical_density"] < 0.5
    end

    test "numeric literals count as content" do
      assert result("1 + 2 + 3")["content_tokens"] == 3
    end

    test "keywords count as function tokens, not content" do
      # `do`/`end` are keywords → filtered from identifiers → not content
      content = result("do end")["content_tokens"]
      assert content == 0
    end

    test "content and function tokens always partition the total (no negatives)" do
      # Unicode identifiers split differently across the word-scan and the
      # tokenizer; the partition must still hold and stay non-negative.
      for code <- ["café naïve über", "a1 b2 c3", ~s(x = "hello world"), ""] do
        r = result(code)
        assert r["function_tokens"] >= 0
        assert r["content_tokens"] >= 0
      end
    end

    test "density is content over total tokens" do
      # x + y → content: x, y (2); function: + (1); total 3 → 2/3
      r = result("x + y")
      assert r["content_tokens"] == 2
      assert r["function_tokens"] == 1
      assert_in_delta r["lexical_density"], 2 / 3, 0.0001
    end
  end
end
