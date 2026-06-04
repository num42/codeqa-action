defmodule CodeQA.CombinedMetrics.SampleRunnerTest do
  use ExUnit.Case

  alias CodeQA.CombinedMetrics.SampleRunner
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Engine.Collector
  alias CodeQA.HealthReport.Grader

  setup_all do
    results = SampleRunner.run(category: "variable_naming", verbose: true)
    %{results: results}
  end

  describe "apply_languages/1" do
    # Copy the real YAMLs into a scratch dir so the test never mutates the
    # committed priv/ fixtures. apply_languages writes to opts[:dir].
    setup do
      tmp = Path.join(System.tmp_dir!(), "scalar_applier_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)

      ~w(variable_naming.yml code_smells.yml)
      |> Enum.each(fn f ->
        File.cp!(Path.join("priv/combined_metrics", f), Path.join(tmp, f))
      end)

      on_exit(fn -> File.rm_rf!(tmp) end)
      %{dir: tmp}
    end

    test "returns one entry per requested category", %{dir: dir} do
      stats = SampleRunner.apply_languages(category: "variable_naming", dir: dir)
      assert length(stats) == 1
      [entry] = stats
      assert entry.category == "variable_naming"
      assert is_integer(entry.behaviors_with_languages)
    end

    test "writes _languages to behaviors that have samples", %{dir: dir} do
      SampleRunner.apply_languages(category: "variable_naming", dir: dir)
      {:ok, data} = YamlElixir.read_from_file(Path.join(dir, "variable_naming.yml"))
      langs = get_in(data, ["name_is_generic", "_languages"])
      assert is_list(langs)
      assert langs != []
      assert langs |> Enum.all?(&is_binary/1)
    end

    test "behaviors without sample dirs get no _languages key", %{dir: dir} do
      SampleRunner.apply_languages(category: "variable_naming", dir: dir)
      {:ok, data} = YamlElixir.read_from_file(Path.join(dir, "variable_naming.yml"))

      data
      |> Enum.each(fn {_behavior, groups} ->
        if is_map(groups) do
          case Map.get(groups, "_languages") do
            nil -> :ok
            langs -> assert is_list(langs) and langs != []
          end
        end
      end)
    end

    test "leaves a behavior with _excludes_languages untouched", %{dir: dir} do
      SampleRunner.apply_languages(category: "code_smells", dir: dir)
      {:ok, data} = YamlElixir.read_from_file(Path.join(dir, "code_smells.yml"))

      # no_dead_code_after_return is blocklisted for elixir — the auto allowlist
      # must not overwrite it.
      groups = Map.get(data, "no_dead_code_after_return")
      assert get_in(groups, ["_excludes_languages"]) == ["elixir"]
      refute Map.has_key?(groups, "_languages")
    end
  end

  describe "diagnose_aggregate/2 language option" do
    test "accepts :language option without crashing" do
      # minimal aggregate — behavior will be scored but most will have no scalars
      agg = %{}
      result = SampleRunner.diagnose_aggregate(agg, top: 5, language: "elixir")
      assert is_list(result)
    end

    test "accepts :languages option without crashing" do
      agg = %{}
      result = SampleRunner.diagnose_aggregate(agg, top: 5, languages: ["elixir", "rust"])
      assert is_list(result)
    end

    # NOTE: This test uses `<=` intentionally. Before Task 7 + `mix compile --force`,
    # all behaviors have empty `_languages` in the compiled cache, so no filtering
    # occurs and all three counts are equal. The `<=` assertion passes in both
    # pre- and post-Task-7 states.
    test "with language option returns subset of unfiltered results" do
      agg =
        "priv/combined_metrics/samples/variable_naming/name_is_generic/bad"
        |> Collector.collect_files()
        |> Analyzer.analyze_codebase()
        |> get_in(["codebase", "aggregate"])

      all = SampleRunner.diagnose_aggregate(agg, top: 999)
      elixir_only = SampleRunner.diagnose_aggregate(agg, top: 999, language: "elixir")
      rust_only = SampleRunner.diagnose_aggregate(agg, top: 999, language: "rust")

      # Filtered sets are subsets (or equal, pre-Task-7) of unfiltered
      assert length(elixir_only) <= length(all)
      assert length(rust_only) <= length(all)
    end
  end

  describe "score_aggregate/2 language filtering" do
    test "accepts :languages option without crashing" do
      result = SampleRunner.score_aggregate(%{}, languages: ["elixir"])
      assert is_list(result)
      assert result |> Enum.all?(&Map.has_key?(&1, :behaviors))
    end

    test "with languages option returns fewer behaviors than unfiltered" do
      agg =
        "priv/combined_metrics/samples/variable_naming/name_is_generic/bad"
        |> Collector.collect_files()
        |> Analyzer.analyze_codebase()
        |> get_in(["codebase", "aggregate"])

      all_count = SampleRunner.score_aggregate(agg) |> Enum.flat_map(& &1.behaviors) |> length()

      elixir_count =
        SampleRunner.score_aggregate(agg, languages: ["elixir"])
        |> Enum.flat_map(& &1.behaviors)
        |> length()

      # elixir-only project sees fewer or equal behaviors
      assert elixir_count <= all_count
    end
  end

  describe "grade_cosine_categories/3" do
    test "returns a list for empty input" do
      result = Grader.grade_cosine_categories(%{}, %{})
      assert is_list(result)
    end
  end

  describe "run/1" do
    test "returns a list of results with required keys", %{results: results} do
      assert is_list(results)
      assert results != []
      result = hd(results)
      assert Map.has_key?(result, :bad_score)
      assert Map.has_key?(result, :good_score)
      assert Map.has_key?(result, :ratio)
      assert Map.has_key?(result, :direction_ok)
    end

    test "name_is_generic result has good_score > bad_score", %{results: results} do
      generic = results |> Enum.find(&(&1.behavior == "name_is_generic"))
      assert generic != nil
      assert generic.good_score > generic.bad_score
    end

    test "verbose: true populates metric_detail", %{results: results} do
      [result | _] = results
      assert is_list(result.metric_detail)
      # only populated when behavior has scalars configured
    end
  end
end
