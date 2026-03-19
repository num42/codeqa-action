defmodule CodeQA.CombinedMetrics.FileScorerTest do
  use ExUnit.Case, async: true

  alias CodeQA.CombinedMetrics.FileScorer

  describe "file_to_aggregate/1" do
    test "prefixes each key with mean_" do
      input = %{"halstead" => %{"tokens" => 42.0, "effort" => 100.5}}

      assert FileScorer.file_to_aggregate(input) == %{
               "halstead" => %{"mean_tokens" => 42.0, "mean_effort" => 100.5}
             }
    end

    test "handles multiple groups" do
      input = %{
        "halstead" => %{"tokens" => 10.0},
        "branching" => %{"branching_density" => 0.5}
      }

      result = FileScorer.file_to_aggregate(input)

      assert result == %{
               "halstead" => %{"mean_tokens" => 10.0},
               "branching" => %{"mean_branching_density" => 0.5}
             }
    end

    test "returns empty map for empty input" do
      assert FileScorer.file_to_aggregate(%{}) == %{}
    end

    test "preserves values unchanged" do
      input = %{"entropy" => %{"normalized_entropy" => 0.87}}
      result = FileScorer.file_to_aggregate(input)
      assert get_in(result, ["entropy", "mean_normalized_entropy"]) == 0.87
    end
  end

  describe "worst_files_per_behavior/2" do
    test "returns a map with string keys in category.behavior format" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map, combined_top: 2)

      assert is_map(result)

      for {key, entries} <- result do
        assert is_binary(key)
        assert String.contains?(key, ".")
        assert is_list(entries)
      end
    end

    test "each entry has file and cosine keys" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map, combined_top: 2)

      for {_key, entries} <- result do
        for entry <- entries do
          assert Map.has_key?(entry, :file)
          assert Map.has_key?(entry, :cosine)
          assert is_binary(entry.file)
          assert is_float(entry.cosine)
        end
      end
    end

    test "respects combined_top limit" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map, combined_top: 1)

      for {_key, entries} <- result do
        assert length(entries) <= 1
      end
    end

    test "entries are sorted ascending by cosine (most negative first)" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map, combined_top: 99)

      for {_key, entries} <- result do
        cosines = Enum.map(entries, & &1.cosine)
        assert cosines == Enum.sort(cosines)
      end
    end

    test "skips files with empty metrics" do
      files_map = %{
        "lib/empty.ex" => %{"metrics" => %{}, "lines" => 10},
        "lib/nokey.ex" => %{"lines" => 5}
      }

      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result do
        file_paths = Enum.map(entries, & &1.file)
        refute "lib/empty.ex" in file_paths
        refute "lib/nokey.ex" in file_paths
      end
    end

    test "uses default combined_top of 2" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result do
        assert length(entries) <= 2
      end
    end

    test "each entry has top_metrics key" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result, entry <- entries do
        assert Map.has_key?(entry, :top_metrics), "missing :top_metrics in #{inspect(entry)}"
      end
    end

    test "top_metrics is a list" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result, entry <- entries do
        assert is_list(entry.top_metrics)
      end
    end

    test "top_metrics is [] (not nil) when all contributions are zero" do
      # Single file with no variation — cosines will be near 0
      files_map = %{
        "lib/zero.ex" => %{
          "metrics" => %{
            "halstead" => %{"tokens" => 0.0}
          },
          "lines" => 1,
          "bytes" => 5
        }
      }

      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result, entry <- entries do
        assert entry.top_metrics == []
      end
    end

    test "each entry has top_nodes key" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result, entry <- entries do
        assert Map.has_key?(entry, :top_nodes), "missing :top_nodes in #{inspect(entry)}"
      end
    end

    test "top_nodes is [] when file_data has no nodes key" do
      files_map = build_files_map()
      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result, entry <- entries do
        assert entry.top_nodes == []
      end
    end

    test "top_nodes is [] when file_data nodes is nil" do
      files_map =
        build_files_map()
        |> Map.new(fn {path, data} -> {path, Map.put(data, "nodes", nil)} end)

      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result, entry <- entries do
        assert entry.top_nodes == []
      end
    end

    test "top_nodes is [] when file_data nodes is []" do
      files_map =
        build_files_map()
        |> Map.new(fn {path, data} -> {path, Map.put(data, "nodes", [])} end)

      result = FileScorer.worst_files_per_behavior(files_map)

      for {_key, entries} <- result, entry <- entries do
        assert entry.top_nodes == []
      end
    end
  end

  # Build a realistic files_map using a real project file so diagnose_aggregate
  # has real metric values to work with. We use a small fixed map rather than
  # running the full analyzer to keep tests fast.
  defp build_files_map do
    %{
      "lib/example_a.ex" => %{
        "metrics" => %{
          "halstead" => %{
            "tokens" => 80.0,
            "vocabulary" => 30.0,
            "volume" => 400.0,
            "difficulty" => 12.0,
            "effort" => 4800.0,
            "bugs" => 0.1
          },
          "branching" => %{
            "branching_density" => 0.3
          },
          "entropy" => %{
            "normalized_entropy" => 0.75
          },
          "function_metrics" => %{
            "avg_function_length" => 20.0,
            "max_function_length" => 40.0,
            "function_count" => 5.0,
            "avg_params" => 2.0,
            "max_params" => 4.0
          },
          "readability" => %{
            "readability_score" => 0.6
          },
          "indentation" => %{
            "avg_indent_level" => 2.0,
            "max_indent_level" => 4.0,
            "indent_variance" => 0.5
          }
        },
        "lines" => 100,
        "bytes" => 2048
      },
      "lib/example_b.ex" => %{
        "metrics" => %{
          "halstead" => %{
            "tokens" => 200.0,
            "vocabulary" => 60.0,
            "volume" => 1200.0,
            "difficulty" => 30.0,
            "effort" => 36000.0,
            "bugs" => 0.4
          },
          "branching" => %{
            "branching_density" => 0.7
          },
          "entropy" => %{
            "normalized_entropy" => 0.9
          },
          "function_metrics" => %{
            "avg_function_length" => 50.0,
            "max_function_length" => 120.0,
            "function_count" => 15.0,
            "avg_params" => 4.0,
            "max_params" => 8.0
          },
          "readability" => %{
            "readability_score" => 0.3
          },
          "indentation" => %{
            "avg_indent_level" => 4.0,
            "max_indent_level" => 8.0,
            "indent_variance" => 2.0
          }
        },
        "lines" => 300,
        "bytes" => 8192
      }
    }
  end
end
