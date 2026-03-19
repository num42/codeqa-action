defmodule CodeQA.HealthReport.GraderTest do
  use ExUnit.Case, async: true

  alias CodeQA.HealthReport.Grader

  @default_scale CodeQA.HealthReport.Categories.default_grade_scale()

  # -----------------------------------------------------------------------
  # score_cosine/1
  # -----------------------------------------------------------------------

  describe "score_cosine/1" do
    test "cosine 1.0 maps to 100" do
      assert Grader.score_cosine(1.0) == 100
    end

    test "cosine -1.0 maps to 0" do
      assert Grader.score_cosine(-1.0) == 0
    end

    test "cosine 0.5 (lower bound of top band) maps to 90" do
      assert Grader.score_cosine(0.5) == 90
    end

    test "cosine 0.2 (lower bound of second band) maps to 70" do
      assert Grader.score_cosine(0.2) == 70
    end

    test "cosine 0.0 (lower bound of third band) maps to 50" do
      assert Grader.score_cosine(0.0) == 50
    end

    test "cosine -0.3 (lower bound of fourth band) maps to 30" do
      assert Grader.score_cosine(-0.3) == 30
    end

    test "interpolation in [0.0, 0.2) band: cosine 0.12 → 62" do
      # ratio = 0.12 / 0.2 = 0.6, score = 50 + 0.6 * 20 = 62
      assert Grader.score_cosine(0.12) == 62
    end

    test "interpolation in [0.2, 0.5) band: cosine 0.35 → 80" do
      # ratio = (0.35 - 0.2) / (0.5 - 0.2) = 0.15/0.3 = 0.5, score = 70 + 0.5 * 20 = 80
      assert Grader.score_cosine(0.35) == 80
    end

    test "interpolation in [0.5, 1.0] band: cosine 0.75 → 95" do
      # ratio = (0.75 - 0.5) / (1.0 - 0.5) = 0.25/0.5 = 0.5, score = 90 + 0.5 * 10 = 95
      assert Grader.score_cosine(0.75) == 95
    end

    test "interpolation in [-0.3, 0.0) band: cosine -0.15 → 40" do
      # ratio = (-0.15 - (-0.3)) / (0.0 - (-0.3)) = 0.15/0.3 = 0.5, score = 30 + 0.5 * 20 = 40
      assert Grader.score_cosine(-0.15) == 40
    end

    test "interpolation in [-1.0, -0.3) band: cosine -0.65 → 15" do
      # ratio = (-0.65 - (-1.0)) / (-0.3 - (-1.0)) = 0.35/0.7 = 0.5, score = 0 + 0.5 * 30 = 15
      assert Grader.score_cosine(-0.65) == 15
    end

    test "result is always an integer" do
      for cosine <- [-1.0, -0.5, 0.0, 0.1, 0.3, 0.6, 1.0] do
        assert is_integer(Grader.score_cosine(cosine)),
               "expected integer for cosine #{cosine}"
      end
    end

    test "result is always in [0, 100]" do
      for cosine <- [-1.0, -0.9, -0.3, 0.0, 0.2, 0.5, 1.0] do
        score = Grader.score_cosine(cosine)

        assert score >= 0 and score <= 100,
               "score #{score} out of range for cosine #{cosine}"
      end
    end
  end

  # -----------------------------------------------------------------------
  # overall_score/3 (including backward compat as /2)
  # -----------------------------------------------------------------------

  describe "overall_score/3" do
    test "empty list returns {0, 'F'}" do
      assert Grader.overall_score([], @default_scale) == {0, "F"}
    end

    test "equal weights produces arithmetic mean (backward compat /2)" do
      categories = [
        %{key: :readability, score: 80},
        %{key: :complexity, score: 60}
      ]

      {score, _grade} = Grader.overall_score(categories, @default_scale)
      assert score == 70
    end

    test "weighted average applies impact_map correctly" do
      categories = [
        %{key: :readability, score: 80},
        %{key: :complexity, score: 60}
      ]

      # readability has weight 3, complexity has weight 1
      # weighted = (80*3 + 60*1) / 4 = 300/4 = 75
      impact_map = %{"readability" => 3, "complexity" => 1}
      {score, _grade} = Grader.overall_score(categories, @default_scale, impact_map)
      assert score == 75
    end

    test "missing keys in impact_map default to 1" do
      categories = [
        %{key: :readability, score: 80},
        %{key: :complexity, score: 60}
      ]

      # Only readability in map with weight 2; complexity defaults to 1
      # weighted = (80*2 + 60*1) / 3 = 220/3 ≈ 73
      impact_map = %{"readability" => 2}
      {score, _grade} = Grader.overall_score(categories, @default_scale, impact_map)
      assert score == round((80 * 2 + 60 * 1) / 3)
    end

    test "backward compat: /2 call with empty impact_map equals arithmetic mean" do
      categories = [
        %{key: :readability, score: 90},
        %{key: :complexity, score: 70},
        %{key: :naming, score: 50}
      ]

      {score_two, grade_two} = Grader.overall_score(categories, @default_scale)
      {score_three, grade_three} = Grader.overall_score(categories, @default_scale, %{})

      assert score_two == score_three
      assert grade_two == grade_three
    end

    test "returns grade string along with integer score" do
      categories = [%{key: :readability, score: 100}]
      {score, grade} = Grader.overall_score(categories, @default_scale)
      assert is_integer(score)
      assert is_binary(grade)
    end

    test "atom keys are converted to strings for impact_map lookup" do
      categories = [
        %{key: :function_design, score: 60},
        %{key: :variable_naming, score: 40}
      ]

      impact_map = %{"function_design" => 2, "variable_naming" => 1}
      {score, _} = Grader.overall_score(categories, @default_scale, impact_map)
      # (60*2 + 40*1) / 3 = 160/3 ≈ 53
      assert score == round((60 * 2 + 40 * 1) / 3)
    end
  end

  # Shared aggregate for grade_cosine_categories/3 tests — computed once for the module.
  setup_all do
    files = CodeQA.Engine.Collector.collect_files("lib", [])
    result = CodeQA.Engine.Analyzer.analyze_codebase(files)
    aggregate = get_in(result, ["codebase", "aggregate"])
    {:ok, aggregate: aggregate}
  end

  # -----------------------------------------------------------------------
  # grade_cosine_categories/3
  # -----------------------------------------------------------------------

  describe "grade_cosine_categories/3" do
    test "returns a list", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)
      assert is_list(result)
    end

    test "each entry has required top-level keys", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)

      for cat <- result do
        assert Map.has_key?(cat, :type), "missing :type in #{inspect(cat)}"
        assert Map.has_key?(cat, :key), "missing :key"
        assert Map.has_key?(cat, :name), "missing :name"
        assert Map.has_key?(cat, :score), "missing :score"
        assert Map.has_key?(cat, :grade), "missing :grade"
        assert Map.has_key?(cat, :behaviors), "missing :behaviors"
      end
    end

    test "type is :cosine for every entry", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)
      for cat <- result, do: assert(cat.type == :cosine)
    end

    test "scores are integers in [0, 100]", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)

      for cat <- result do
        assert is_integer(cat.score), "score not integer in #{cat.key}"
        assert cat.score >= 0 and cat.score <= 100
      end
    end

    test "grade is a string", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)
      for cat <- result, do: assert(is_binary(cat.grade))
    end

    test "impact key is absent (HealthReport.generate/2 is responsible for embedding impact)", %{
      aggregate: aggregate
    } do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)
      for cat <- result, do: refute(Map.has_key?(cat, :impact))
    end

    test "name is humanized from key", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)

      for cat <- result do
        # name must be a non-empty string, words capitalized
        assert is_binary(cat.name)
        assert String.length(cat.name) > 0
        # key should be a string (category slug)
        assert is_binary(cat.key)
      end
    end

    test "each behavior entry has required keys", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)

      for cat <- result, b <- cat.behaviors do
        assert Map.has_key?(b, :behavior)
        assert Map.has_key?(b, :cosine)
        assert Map.has_key?(b, :score)
        assert Map.has_key?(b, :grade)
        assert Map.has_key?(b, :worst_offenders)
      end
    end

    test "behavior scores are integers in [0, 100]", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)

      for cat <- result, b <- cat.behaviors do
        assert is_integer(b.score)
        assert b.score >= 0 and b.score <= 100
      end
    end

    test "worst_offenders uses worst_files lookup", %{aggregate: aggregate} do
      sentinel = [%{file: "lib/sentinel.ex", cosine: -0.99}]
      # Get one real behavior key to inject into worst_files
      [first_cat | _] = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)
      first_behavior = hd(first_cat.behaviors)
      lookup_key = "#{first_cat.key}.#{first_behavior.behavior}"

      worst_files = %{lookup_key => sentinel}
      result = Grader.grade_cosine_categories(aggregate, worst_files, @default_scale)

      found_cat = Enum.find(result, &(&1.key == first_cat.key))
      found_behavior = Enum.find(found_cat.behaviors, &(&1.behavior == first_behavior.behavior))
      assert found_behavior.worst_offenders == sentinel
    end

    test "top_metrics and top_nodes pass through unmodified", %{aggregate: aggregate} do
      sentinel = [
        %{
          file: "lib/sentinel.ex",
          cosine: -0.99,
          top_metrics: [%{metric: "foo.bar", contribution: -1.5}],
          top_nodes: [%{"start_line" => 42, "type" => "block"}]
        }
      ]

      [first_cat | _] = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)
      first_behavior = hd(first_cat.behaviors)
      lookup_key = "#{first_cat.key}.#{first_behavior.behavior}"

      worst_files = %{lookup_key => sentinel}
      result = Grader.grade_cosine_categories(aggregate, worst_files, @default_scale)

      found_cat = Enum.find(result, &(&1.key == first_cat.key))
      found_behavior = Enum.find(found_cat.behaviors, &(&1.behavior == first_behavior.behavior))
      assert found_behavior.worst_offenders == sentinel
    end

    test "worst_offenders defaults to [] when key absent", %{aggregate: aggregate} do
      result = Grader.grade_cosine_categories(aggregate, %{}, @default_scale)
      for cat <- result, b <- cat.behaviors, do: assert(b.worst_offenders == [])
    end
  end

  # -----------------------------------------------------------------------
  # worst_offenders/4 — top_nodes
  # -----------------------------------------------------------------------

  describe "worst_offenders/4 top_nodes" do
    @category %{
      key: :function_design,
      name: "Function Design",
      metrics: [
        %{
          source: "halstead",
          name: "tokens",
          weight: 1.0,
          good: :low,
          thresholds: %{a: 10, b: 20, c: 30, d: 40}
        }
      ]
    }

    test "returns top_nodes: [] when file_data has no nodes key" do
      files = %{
        "lib/foo.ex" => %{
          "metrics" => %{"halstead" => %{"tokens" => 50.0}},
          "lines" => 10,
          "bytes" => 100
        }
      }

      result = Grader.worst_offenders(@category, files, 5)
      [entry | _] = result
      assert entry.top_nodes == []
    end

    test "returns top_nodes: [] when file_data nodes is nil" do
      files = %{
        "lib/foo.ex" => %{
          "metrics" => %{"halstead" => %{"tokens" => 50.0}},
          "nodes" => nil,
          "lines" => 10,
          "bytes" => 100
        }
      }

      result = Grader.worst_offenders(@category, files, 5)
      [entry | _] = result
      assert entry.top_nodes == []
    end

    test "returns top_nodes: [] when file_data nodes is []" do
      files = %{
        "lib/foo.ex" => %{
          "metrics" => %{"halstead" => %{"tokens" => 50.0}},
          "nodes" => [],
          "lines" => 10,
          "bytes" => 100
        }
      }

      result = Grader.worst_offenders(@category, files, 5)
      [entry | _] = result
      assert entry.top_nodes == []
    end

    test "returns top 3 nodes ranked by refactoring_potentials descending" do
      nodes = [
        %{
          "start_line" => 1,
          "column_start" => 0,
          "char_length" => 50,
          "type" => "function",
          "token_count" => 20,
          "refactoring_potentials" => [
            %{"category" => "function_design", "behavior" => "x", "cosine_delta" => 0.5}
          ],
          "children" => []
        },
        %{
          "start_line" => 10,
          "column_start" => 0,
          "char_length" => 100,
          "type" => "function",
          "token_count" => 40,
          "refactoring_potentials" => [
            %{"category" => "function_design", "behavior" => "x", "cosine_delta" => 0.9},
            %{"category" => "naming", "behavior" => "y", "cosine_delta" => 0.4}
          ],
          "children" => []
        },
        %{
          "start_line" => 20,
          "column_start" => 0,
          "char_length" => 30,
          "type" => "function",
          "token_count" => 10,
          "refactoring_potentials" => [
            %{"category" => "function_design", "behavior" => "z", "cosine_delta" => 0.2}
          ],
          "children" => []
        },
        %{
          "start_line" => 30,
          "column_start" => 0,
          "char_length" => 10,
          "type" => "function",
          "token_count" => 5,
          "refactoring_potentials" => [],
          "children" => []
        }
      ]

      files = %{
        "lib/foo.ex" => %{
          "metrics" => %{"halstead" => %{"tokens" => 50.0}},
          "nodes" => nodes,
          "lines" => 40,
          "bytes" => 400
        }
      }

      result = Grader.worst_offenders(@category, files, 5)
      [entry | _] = result

      assert length(entry.top_nodes) == 3
      # The node with highest sum of cosine_delta comes first (0.9+0.4=1.3)
      [first | _] = entry.top_nodes
      assert first["start_line"] == 10
    end

    test "parent+child overlap: only parent is included when both rank top 3" do
      child_node = %{
        "start_line" => 11,
        "column_start" => 2,
        "char_length" => 30,
        "type" => "function",
        "token_count" => 10,
        "refactoring_potentials" => [
          %{"category" => "function_design", "behavior" => "x", "cosine_delta" => 0.8}
        ],
        "children" => []
      }

      nodes = [
        %{
          "start_line" => 10,
          "column_start" => 0,
          "char_length" => 100,
          "type" => "function",
          "token_count" => 40,
          "refactoring_potentials" => [
            %{"category" => "function_design", "behavior" => "x", "cosine_delta" => 0.9}
          ],
          "children" => [child_node]
        },
        %{
          "start_line" => 20,
          "column_start" => 0,
          "char_length" => 50,
          "type" => "function",
          "token_count" => 20,
          "refactoring_potentials" => [
            %{"category" => "naming", "behavior" => "y", "cosine_delta" => 0.5}
          ],
          "children" => []
        },
        %{
          "start_line" => 30,
          "column_start" => 0,
          "char_length" => 30,
          "type" => "function",
          "token_count" => 10,
          "refactoring_potentials" => [
            %{"category" => "naming", "behavior" => "z", "cosine_delta" => 0.3}
          ],
          "children" => []
        }
      ]

      files = %{
        "lib/foo.ex" => %{
          "metrics" => %{"halstead" => %{"tokens" => 50.0}},
          "nodes" => nodes,
          "lines" => 40,
          "bytes" => 400
        }
      }

      result = Grader.worst_offenders(@category, files, 5)
      [entry | _] = result

      # child_node is not top-level, so only top-level nodes are considered
      assert length(entry.top_nodes) == 3
      start_lines = Enum.map(entry.top_nodes, & &1["start_line"])
      refute 11 in start_lines
    end
  end
end
