defmodule CodeQA.HealthReport.TopBlocksTest do
  use ExUnit.Case, async: true

  alias CodeQA.Git.ChangedFile
  alias CodeQA.HealthReport.TopBlocks

  # A node with cosine_delta 0.60 — will be :critical when codebase_cosine = 0.0 (gap=1.0, ratio=0.60)
  defp make_node(cosine_delta, token_count \\ 20) do
    %{
      "start_line" => 1,
      "end_line" => 10,
      "type" => "code",
      "token_count" => token_count,
      "refactoring_potentials" => [
        %{
          "category" => "function_design",
          "behavior" => "cyclomatic_complexity_under_10",
          "cosine_delta" => cosine_delta
        }
      ],
      "children" => []
    }
  end

  defp make_results(nodes) do
    %{"files" => %{"lib/foo.ex" => %{"nodes" => nodes}}}
  end

  defp lookup(cosine \\ 0.0) do
    %{{"function_design", "cyclomatic_complexity_under_10"} => cosine}
  end

  describe "severity classification" do
    test ":critical when severity_ratio > 0.50" do
      # gap = max(0.01, 1.0 - 0.0) = 1.0, ratio = 0.60 / 1.0 = 0.60 > 0.50
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup())
      assert hd(hd(group.blocks).potentials).severity == :critical
    end

    test ":high when severity_ratio > 0.25 and <= 0.50" do
      # ratio = 0.30 / 1.0 = 0.30
      [group] = TopBlocks.build(make_results([make_node(0.30)]), [], lookup())
      assert hd(hd(group.blocks).potentials).severity == :high
    end

    test ":medium when severity_ratio > 0.10 and <= 0.25" do
      # ratio = 0.15 / 1.0 = 0.15
      [group] = TopBlocks.build(make_results([make_node(0.15)]), [], lookup())
      assert hd(hd(group.blocks).potentials).severity == :medium
    end

    test "filtered when severity_ratio <= 0.10" do
      # ratio = 0.05 / 1.0 = 0.05 — block should not appear
      assert TopBlocks.build(make_results([make_node(0.05)]), [], lookup()) == []
    end

    test "gap floor prevents division by zero when codebase_cosine = 1.0" do
      # gap = max(0.01, 1.0 - 1.0) = 0.01, ratio = 0.02 / 0.01 = 2.0 → :critical
      [group] = TopBlocks.build(make_results([make_node(0.02)]), [], lookup(1.0))
      assert hd(hd(group.blocks).potentials).severity == :critical
    end

    test "gap handles negative codebase_cosine" do
      # codebase_cosine = -0.5, gap = max(0.01, 1.0 - (-0.5)) = 1.5
      # ratio = 0.60 / 1.5 = 0.40 → :high
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup(-0.5))
      assert hd(hd(group.blocks).potentials).severity == :high
    end

    test "unknown behavior defaults codebase_cosine to 0.0" do
      lookup_empty = %{}
      # gap = 1.0, ratio = 0.60 → :critical
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup_empty)
      assert hd(hd(group.blocks).potentials).severity == :critical
    end
  end

  describe "changed_files filtering" do
    test "when changed_files is empty, shows all files" do
      [group] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup())
      assert group.path == "lib/foo.ex"
      assert group.status == nil
    end

    test "when changed_files given, only shows matching files" do
      changed = [%ChangedFile{path: "lib/other.ex", status: "added"}]
      assert TopBlocks.build(make_results([make_node(0.60)]), changed, lookup()) == []
    end

    test "status comes from ChangedFile struct" do
      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]
      [group] = TopBlocks.build(make_results([make_node(0.60)]), changed, lookup())
      assert group.status == "modified"
    end
  end

  describe "block filtering" do
    test "blocks with token_count < 10 are excluded" do
      assert TopBlocks.build(make_results([make_node(0.60, 9)]), [], lookup()) == []
    end

    test "blocks are ordered by highest cosine_delta descending" do
      node_low = make_node(0.20)
      node_high = put_in(make_node(0.60), ["start_line"], 20)
      results = %{"files" => %{"lib/foo.ex" => %{"nodes" => [node_low, node_high]}}}

      [group] = TopBlocks.build(results, [], lookup())
      deltas = Enum.map(group.blocks, fn b -> hd(b.potentials).cosine_delta end)
      assert deltas == Enum.sort(deltas, :desc)
    end

    test "children nodes are included" do
      parent = %{
        "start_line" => 1,
        "end_line" => 20,
        "type" => "code",
        "token_count" => 5,
        "refactoring_potentials" => [],
        "children" => [make_node(0.60)]
      }

      [group] = TopBlocks.build(make_results([parent]), [], lookup())
      assert length(group.blocks) == 1
    end
  end

  describe "fix hints" do
    test "includes fix_hint string for known behavior" do
      # naming_conventions/file_name_matches_primary_export has _fix_hint in YAML
      node = %{
        "start_line" => 1,
        "end_line" => 10,
        "type" => "code",
        "token_count" => 20,
        "refactoring_potentials" => [
          %{
            "category" => "naming_conventions",
            "behavior" => "file_name_matches_primary_export",
            "cosine_delta" => 0.60
          }
        ],
        "children" => []
      }

      hint_lookup = %{{"naming_conventions", "file_name_matches_primary_export"} => 0.0}
      [group] = TopBlocks.build(make_results([node]), [], hint_lookup)
      potential = hd(hd(group.blocks).potentials)
      assert is_binary(potential.fix_hint)
    end

    test "fix_hint is nil for unknown behavior" do
      node = %{
        "start_line" => 1,
        "end_line" => 10,
        "type" => "code",
        "token_count" => 20,
        "refactoring_potentials" => [
          %{"category" => "unknown_cat", "behavior" => "unknown_beh", "cosine_delta" => 0.60}
        ],
        "children" => []
      }

      [group] = TopBlocks.build(make_results([node]), [], %{})
      assert hd(hd(group.blocks).potentials).fix_hint == nil
    end
  end
end
