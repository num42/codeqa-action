defmodule CodeQA.Metrics.File.ConditionalEntropyTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.ConditionalEntropy

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: ConditionalEntropy.analyze(ctx(code))

  describe "analyze/1 - edge cases" do
    test "returns zeros for empty content" do
      assert result("") == %{
               "conditional_entropy" => 0.0,
               "perplexity" => 1.0,
               "normalized_conditional_entropy" => 0.0
             }
    end

    test "returns zeros for fewer than 2 tokens" do
      r = result("x")
      assert r["conditional_entropy"] == 0.0
      assert r["perplexity"] == 1.0
    end
  end

  describe "analyze/1 - conditional entropy" do
    test "fully predictable sequence has near-zero entropy" do
      # a a a a → every prev 'a' is always followed by 'a' → H = 0
      r = result("a a a a a a")
      assert_in_delta r["conditional_entropy"], 0.0, 0.0001
    end

    test "perplexity is 2^H, so ~1 for a predictable sequence" do
      r = result("a a a a a a")
      assert_in_delta r["perplexity"], 1.0, 0.01
    end

    test "unpredictable transitions yield higher entropy than predictable ones" do
      predictable = result("a b a b a b a b")["conditional_entropy"]
      # each prev token leads to two equally likely successors → H = 1 bit
      unpredictable = result("a b a c a d a e b a c a d a e a")["conditional_entropy"]
      assert unpredictable > predictable
    end

    test "deterministic alternation has zero conditional entropy" do
      # a→b always, b→a always → fully determined transitions → H = 0
      r = result("a b a b a b a b a b")
      assert_in_delta r["conditional_entropy"], 0.0, 0.0001
    end

    test "branching successor distribution raises entropy toward 1 bit" do
      # prev 'a' followed by b or c with equal probability → H(next|a) = 1 bit
      r = result("a b a c a b a c")
      assert r["conditional_entropy"] > 0.4
    end

    test "perplexity equals two to the power of conditional entropy" do
      r = result("a b a c a b a c a d")
      assert_in_delta r["perplexity"], :math.pow(2, r["conditional_entropy"]), 0.001
    end

    test "normalized entropy stays within 0..1" do
      r = result("foo bar baz qux foo bar baz qux quux corge")
      assert r["normalized_conditional_entropy"] >= 0.0
      assert r["normalized_conditional_entropy"] <= 1.0
    end
  end
end
