defmodule CodeQA.Metrics.File.MTLDTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Pipeline
  alias CodeQA.Metrics.File.MTLD

  defp ctx(code), do: Pipeline.build_file_context(code)
  defp result(code), do: MTLD.analyze(ctx(code))

  describe "analyze/1 - edge cases" do
    test "returns zeros for empty content" do
      assert result("") == %{"mtld" => 0.0, "mtld_forward" => 0.0, "mtld_backward" => 0.0}
    end

    test "returns zeros when content has no identifiers" do
      assert result("1 + 2") == %{"mtld" => 0.0, "mtld_forward" => 0.0, "mtld_backward" => 0.0}
    end

    test "sequence never dropping below threshold yields sequence length" do
      # all unique: TTR stays 1.0, no factor completes, partial factor is 0
      code = Enum.map_join(1..20, " ", &"id#{&1}")
      assert result(code) == %{"mtld" => 20.0, "mtld_forward" => 20.0, "mtld_backward" => 20.0}
    end
  end

  describe "analyze/1 - diversity" do
    test "immediate repetition yields low MTLD" do
      # identifiers: x x x x x x x x x x — factor completes every 2 tokens
      code = String.duplicate("x = x + 1\n", 5)
      assert result(code) == %{"mtld" => 2.0, "mtld_forward" => 2.0, "mtld_backward" => 2.0}
    end

    test "diverse sequence scores higher than repetitive one" do
      diverse = Enum.map_join(1..60, " ", &"token#{&1}")
      repetitive = String.duplicate("x y x y ", 15)
      assert result(diverse)["mtld"] > result(repetitive)["mtld"]
    end

    test "mtld is the mean of forward and backward passes" do
      # forward: one factor closes late; backward: repetition up front closes factors early
      code = "q b c d e f g h q q q q"
      r = result(code)
      assert r["mtld_forward"] == 12.0
      assert r["mtld_backward"] == 6.0
      assert r["mtld"] == 9.0
    end
  end
end
