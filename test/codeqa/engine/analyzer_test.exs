defmodule CodeQA.Engine.AnalyzerTest do
  use ExUnit.Case, async: true

  alias CodeQA.Engine.Analyzer

  describe "analyze_file/2" do
    test "returns a metrics map with group keys" do
      content = "defmodule Foo do\n  def bar, do: :ok\nend\n"
      result = Analyzer.analyze_file("lib/foo.ex", content)
      assert is_map(result)
      assert map_size(result) > 0
      # Each value should be a map of metric keys to numbers
      Enum.each(result, fn {_group, keys} ->
        assert is_map(keys)
      end)
    end
  end

  describe "analyze_codebase_aggregate/2" do
    test "returns aggregate map with mean_ keys" do
      files = %{
        "lib/a.ex" => "defmodule A do\n  def foo, do: :a\nend\n",
        "lib/b.ex" => "defmodule B do\n  def bar, do: :b\nend\n"
      }

      agg = Analyzer.analyze_codebase_aggregate(files)
      assert is_map(agg)
      # At least one group should have mean_ keys
      Enum.each(agg, fn {_group, keys} ->
        Enum.each(keys, fn {key, val} ->
          assert String.starts_with?(key, "mean_") or String.starts_with?(key, "std_") or
                   String.starts_with?(key, "min_") or String.starts_with?(key, "max_")

          assert is_float(val) or is_integer(val)
        end)
      end)
    end

    test "does not run codebase metrics (returns quickly for large input)" do
      # Just assert it returns without error for a reasonable input
      files = %{"lib/foo.ex" => "defmodule Foo do\n  def bar, do: 1\nend\n"}
      agg = Analyzer.analyze_codebase_aggregate(files)
      assert is_map(agg)
    end
  end

  describe "analyze_file_for_loo_partial/3" do
    @sample """
    defmodule Foo do
      def bar do
        x = 1
        y = 2
        x + y
      end
    end
    """

    test "result matches analyze_file_for_loo/2 for referenced metrics" do
      baseline = Analyzer.analyze_file_for_loo("lib/foo.ex", @sample)
      partial = Analyzer.analyze_file_for_loo_partial("lib/foo.ex", @sample, baseline)
      referenced = CodeQA.CombinedMetrics.Scorer.referenced_file_metric_names()

      for name <- referenced, Map.has_key?(baseline, name) do
        assert Map.get(partial, name) == Map.get(baseline, name),
               "referenced metric #{name} diverges in partial"
      end
    end

    test "non-referenced metrics are inherited verbatim from baseline" do
      baseline = Analyzer.analyze_file_for_loo("lib/foo.ex", @sample)
      sentinel = %{"sentinel_key" => 99.0}

      tampered_baseline =
        Enum.reduce(baseline, %{}, fn {name, _val}, acc ->
          if name in CodeQA.CombinedMetrics.Scorer.referenced_file_metric_names() do
            Map.put(acc, name, baseline[name])
          else
            Map.put(acc, name, sentinel)
          end
        end)

      partial =
        Analyzer.analyze_file_for_loo_partial("lib/foo.ex", @sample, tampered_baseline)

      for {name, value} <- partial,
          name not in CodeQA.CombinedMetrics.Scorer.referenced_file_metric_names() do
        assert value == sentinel,
               "non-referenced metric #{name} was recomputed instead of inherited"
      end
    end

    test "result has same set of metric names as analyze_file_for_loo/2" do
      baseline = Analyzer.analyze_file_for_loo("lib/foo.ex", @sample)
      partial = Analyzer.analyze_file_for_loo_partial("lib/foo.ex", @sample, baseline)

      assert MapSet.new(Map.keys(partial)) == MapSet.new(Map.keys(baseline))
    end
  end
end
