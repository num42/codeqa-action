defmodule CodeQA.Metrics.File.BrevityTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.Brevity

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: Brevity.analyze(ctx(code))

  describe "analyze/1 - edge cases" do
    test "returns zeros for empty content" do
      assert result("") == %{"correlation" => 0.0, "slope" => 0.0, "sample_size" => 0}
    end

    test "returns zeros for fewer than 3 unique tokens" do
      assert result("a a b b")["correlation"] == 0.0
      assert result("a a b b")["slope"] == 0.0
    end
  end

  describe "analyze/1 - brevity law" do
    test "negative correlation when shorter tokens are more frequent" do
      # x(len=1): 10×, to(len=2): 3×, longname(len=8): 1×
      code = String.duplicate("x ", 10) <> String.duplicate("to ", 3) <> "longname"
      assert result(code)["correlation"] < 0.0
    end

    test "positive correlation when longer tokens are more frequent" do
      # longword(len=8): 4×, a(len=1): 1×, b(len=1): 1×
      code = String.duplicate("longword ", 4) <> "a b"
      assert result(code)["correlation"] > 0.0
    end

    test "sample_size reflects unique token count" do
      code = "alpha beta gamma alpha beta"
      assert result(code)["sample_size"] == 3
    end

    test "slope is negative when brevity law holds" do
      code = String.duplicate("x ", 10) <> String.duplicate("to ", 3) <> "longname"
      assert result(code)["slope"] < 0.0
    end
  end
end
