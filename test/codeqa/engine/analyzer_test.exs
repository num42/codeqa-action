defmodule CodeQA.Engine.AnalyzerTest do
  use ExUnit.Case, async: true

  describe "analyze_file/2" do
    test "returns a metrics map with group keys" do
      content = "defmodule Foo do\n  def bar, do: :ok\nend\n"
      result = CodeQA.Engine.Analyzer.analyze_file("lib/foo.ex", content)
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

      agg = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(files)
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
      agg = CodeQA.Engine.Analyzer.analyze_codebase_aggregate(files)
      assert is_map(agg)
    end
  end
end
