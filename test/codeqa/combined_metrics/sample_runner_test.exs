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
