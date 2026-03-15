defmodule CodeQA.CombinedMetrics.SampleRunnerTest do
  use ExUnit.Case

  alias CodeQA.CombinedMetrics.SampleRunner

  describe "run/1" do
    test "returns a list of results with required keys" do
      results = SampleRunner.run(category: "variable_naming")
      assert is_list(results)
      assert length(results) > 0
      result = hd(results)
      assert Map.has_key?(result, :bad_score)
      assert Map.has_key?(result, :good_score)
      assert Map.has_key?(result, :ratio)
      assert Map.has_key?(result, :direction_ok)
    end

    test "name_is_generic result has good_score > bad_score" do
      results = SampleRunner.run(category: "variable_naming")
      generic = Enum.find(results, &(&1.behavior == "name_is_generic"))
      assert generic != nil
      assert generic.good_score > generic.bad_score
    end

    test "verbose: true populates metric_detail" do
      [result | _] = SampleRunner.run(category: "variable_naming", verbose: true)
      assert is_list(result.metric_detail)
      # only populated when behavior has scalars configured
    end
  end
end
