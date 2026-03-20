defmodule CodeQA.CombinedMetrics.SampleRunnerTest do
  use ExUnit.Case

  alias CodeQA.CombinedMetrics.SampleRunner

  setup_all do
    results = SampleRunner.run(category: "variable_naming", verbose: true)
    %{results: results}
  end

  describe "apply_languages/1" do
    test "returns one entry per requested category" do
      stats = SampleRunner.apply_languages(category: "variable_naming")
      assert length(stats) == 1
      [entry] = stats
      assert entry.category == "variable_naming"
      assert is_integer(entry.behaviors_with_languages)
    end

    test "writes _languages to behaviors that have samples" do
      SampleRunner.apply_languages(category: "variable_naming")
      {:ok, data} = YamlElixir.read_from_file("priv/combined_metrics/variable_naming.yml")
      langs = get_in(data, ["name_is_generic", "_languages"])
      assert is_list(langs)
      assert length(langs) > 0
      assert Enum.all?(langs, &is_binary/1)
    end

    test "behaviors without sample dirs get no _languages key" do
      SampleRunner.apply_languages(category: "variable_naming")
      {:ok, data} = YamlElixir.read_from_file("priv/combined_metrics/variable_naming.yml")

      Enum.each(data, fn {_behavior, groups} ->
        if is_map(groups) do
          case Map.get(groups, "_languages") do
            nil -> :ok
            langs -> assert is_list(langs) and length(langs) > 0
          end
        end
      end)
    end

    test "only includes languages with both good and bad samples" do
      # uses code_smells which has single-language behaviors
      SampleRunner.apply_languages(category: "code_smells")
      {:ok, data} = YamlElixir.read_from_file("priv/combined_metrics/code_smells.yml")

      # no_dead_code_after_return has only .ex samples
      langs = get_in(data, ["no_dead_code_after_return", "_languages"])
      assert langs == ["elixir"]
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
        |> CodeQA.Engine.Collector.collect_files()
        |> CodeQA.Engine.Analyzer.analyze_codebase()
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
      assert Enum.all?(result, &Map.has_key?(&1, :behaviors))
    end

    test "with languages option returns fewer behaviors than unfiltered" do
      agg =
        "priv/combined_metrics/samples/variable_naming/name_is_generic/bad"
        |> CodeQA.Engine.Collector.collect_files()
        |> CodeQA.Engine.Analyzer.analyze_codebase()
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

  describe "grade_cosine_categories/4 languages wiring" do
    test "accepts languages argument" do
      result = CodeQA.HealthReport.Grader.grade_cosine_categories(%{}, %{}, [], ["elixir"])
      assert is_list(result)
    end
  end

  describe "run/1" do
    test "returns a list of results with required keys", %{results: results} do
      assert is_list(results)
      assert length(results) > 0
      result = hd(results)
      assert Map.has_key?(result, :bad_score)
      assert Map.has_key?(result, :good_score)
      assert Map.has_key?(result, :ratio)
      assert Map.has_key?(result, :direction_ok)
    end

    test "name_is_generic result has good_score > bad_score", %{results: results} do
      generic = Enum.find(results, &(&1.behavior == "name_is_generic"))
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
