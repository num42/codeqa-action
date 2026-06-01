defmodule CodeQA.CombinedMetrics.ScorerTest do
  use ExUnit.Case, async: true

  alias CodeQA.CombinedMetrics.Scorer

  describe "referenced_file_metric_names/0" do
    test "returns a MapSet" do
      assert %MapSet{} = Scorer.referenced_file_metric_names()
    end

    test "contains heavy hitters that obviously appear in YAMLs" do
      set = Scorer.referenced_file_metric_names()

      for name <- ~w[halstead ngram entropy branching readability] do
        assert MapSet.member?(set, name),
               "expected #{name} in referenced file metric names"
      end
    end

    test "excludes meta keys (anything starting with _)" do
      set = Scorer.referenced_file_metric_names()

      for name <- set do
        refute String.starts_with?(name, "_"),
               "meta key leaked into referenced metrics: #{inspect(name)}"
      end
    end
  end
end
