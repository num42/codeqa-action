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
    %{"files" => %{"lib/foo.ex" => %{"nodes" => nodes}}, "metadata" => %{"path" => "/tmp"}}
  end

  defp lookup(cosine \\ 0.0) do
    %{{"function_design", "cyclomatic_complexity_under_10"} => cosine}
  end

  describe "severity classification" do
    test ":critical when severity_ratio > 0.50" do
      # gap = max(0.01, 1.0 - 0.0) = 1.0, ratio = 0.60 / 1.0 = 0.60 > 0.50
      [block] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup())
      assert hd(block.potentials).severity == :critical
    end

    test ":high when severity_ratio > 0.25 and <= 0.50" do
      # ratio = 0.30 / 1.0 = 0.30
      [block] = TopBlocks.build(make_results([make_node(0.30)]), [], lookup())
      assert hd(block.potentials).severity == :high
    end

    test ":medium when severity_ratio > 0.10 and <= 0.25" do
      # ratio = 0.15 / 1.0 = 0.15
      [block] = TopBlocks.build(make_results([make_node(0.15)]), [], lookup())
      assert hd(block.potentials).severity == :medium
    end

    test "filtered when severity_ratio <= 0.10" do
      # ratio = 0.05 / 1.0 = 0.05 — block should not appear
      assert TopBlocks.build(make_results([make_node(0.05)]), [], lookup()) == []
    end

    test "gap floor prevents division by zero when codebase_cosine = 1.0" do
      # gap = max(0.01, 1.0 - 1.0) = 0.01, ratio = 0.02 / 0.01 = 2.0 → :critical
      [block] = TopBlocks.build(make_results([make_node(0.02)]), [], lookup(1.0))
      assert hd(block.potentials).severity == :critical
    end

    test "gap handles negative codebase_cosine" do
      # codebase_cosine = -0.5, gap = max(0.01, 1.0 - (-0.5)) = 1.5
      # ratio = 0.60 / 1.5 = 0.40 → :high
      [block] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup(-0.5))
      assert hd(block.potentials).severity == :high
    end

    test "unknown behavior defaults codebase_cosine to 0.0" do
      lookup_empty = %{}
      # gap = 1.0, ratio = 0.60 → :critical
      [block] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup_empty)
      assert hd(block.potentials).severity == :critical
    end
  end

  describe "changed_files filtering" do
    test "when changed_files is empty, shows all files" do
      [block] = TopBlocks.build(make_results([make_node(0.60)]), [], lookup())
      assert block.path == "lib/foo.ex"
      assert block.status == nil
    end

    test "when changed_files given, only shows matching files" do
      changed = [%ChangedFile{path: "lib/other.ex", status: "added"}]
      assert TopBlocks.build(make_results([make_node(0.60)]), changed, lookup()) == []
    end

    test "status comes from ChangedFile struct" do
      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]
      [block] = TopBlocks.build(make_results([make_node(0.60)]), changed, lookup())
      assert block.status == "modified"
    end
  end

  describe "block filtering" do
    test "blocks with token_count < 10 are excluded" do
      assert TopBlocks.build(make_results([make_node(0.60, 9)]), [], lookup()) == []
    end

    test "blocks are ordered by highest cosine_delta descending" do
      node_low = make_node(0.20)
      node_high = put_in(make_node(0.60), ["start_line"], 20)

      results = %{
        "files" => %{"lib/foo.ex" => %{"nodes" => [node_low, node_high]}},
        "metadata" => %{"path" => "/tmp"}
      }

      blocks = TopBlocks.build(results, [], lookup())
      deltas = Enum.map(blocks, fn b -> hd(b.potentials).cosine_delta end)
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

      blocks = TopBlocks.build(make_results([parent]), [], lookup())
      assert length(blocks) == 1
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
      [block] = TopBlocks.build(make_results([node]), [], hint_lookup)
      potential = hd(block.potentials)
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

      [block] = TopBlocks.build(make_results([node]), [], %{})
      assert hd(block.potentials).fix_hint == nil
    end
  end

  describe "source code extraction" do
    test "includes source code when file exists" do
      # Create a temp file
      tmp_dir = System.tmp_dir!()
      test_dir = Path.join(tmp_dir, "top_blocks_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(test_dir)
      file_path = Path.join(test_dir, "test.ex")
      File.write!(file_path, "line 1\nline 2\nline 3\nline 4\nline 5")

      results = %{
        "files" => %{"test.ex" => %{"nodes" => [make_node(0.60) |> Map.put("end_line", 3)]}},
        "metadata" => %{"path" => test_dir}
      }

      [block] = TopBlocks.build(results, [], lookup())
      assert block.source == "line 1\nline 2\nline 3"
      assert block.language == "elixir"

      File.rm_rf!(test_dir)
    end

    test "source is nil when file does not exist" do
      results = %{
        "files" => %{"nonexistent.ex" => %{"nodes" => [make_node(0.60)]}},
        "metadata" => %{"path" => "/nonexistent/path"}
      }

      [block] = TopBlocks.build(results, [], lookup())
      assert block.source == nil
    end
  end

  describe "top N limiting" do
    test "returns at most 10 blocks" do
      # Create 15 nodes, each 10 lines (within default 3-20 range)
      nodes =
        for i <- 1..15 do
          make_node(0.60 + i * 0.01)
          |> put_in(["start_line"], i * 20)
          |> put_in(["end_line"], i * 20 + 9)
        end

      results = %{
        "files" => %{"lib/foo.ex" => %{"nodes" => nodes}},
        "metadata" => %{"path" => "/tmp"}
      }

      blocks = TopBlocks.build(results, [], lookup())
      assert length(blocks) == 10
    end
  end

  describe "line range filtering" do
    test "blocks outside line range are excluded" do
      # 2-line block (below min of 3)
      small_node =
        make_node(0.60)
        |> put_in(["start_line"], 1)
        |> put_in(["end_line"], 2)

      # 25-line block (above max of 20)
      large_node =
        make_node(0.60)
        |> put_in(["start_line"], 10)
        |> put_in(["end_line"], 34)

      results = %{
        "files" => %{"lib/foo.ex" => %{"nodes" => [small_node, large_node]}},
        "metadata" => %{"path" => "/tmp"}
      }

      blocks = TopBlocks.build(results, [], lookup())
      assert blocks == []
    end

    test "blocks within line range are included" do
      # 10-line block (within 3-20 range)
      node =
        make_node(0.60)
        |> put_in(["start_line"], 1)
        |> put_in(["end_line"], 10)

      results = %{
        "files" => %{"lib/foo.ex" => %{"nodes" => [node]}},
        "metadata" => %{"path" => "/tmp"}
      }

      blocks = TopBlocks.build(results, [], lookup())
      assert length(blocks) == 1
    end

    test "line range is configurable" do
      # 2-line block
      small_node =
        make_node(0.60)
        |> put_in(["start_line"], 1)
        |> put_in(["end_line"], 2)

      results = %{
        "files" => %{"lib/foo.ex" => %{"nodes" => [small_node]}},
        "metadata" => %{"path" => "/tmp"}
      }

      # Default range (3-20) excludes it
      assert TopBlocks.build(results, [], lookup()) == []

      # Custom range (1-5) includes it
      blocks = TopBlocks.build(results, [], lookup(), block_min_lines: 1, block_max_lines: 5)
      assert length(blocks) == 1
    end
  end

  describe "diff_line_ranges filtering" do
    test "when diff_line_ranges is empty map, shows all blocks" do
      node = make_node(0.60)
      [block] = TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: %{})
      assert block.path == "lib/foo.ex"
    end

    test "when diff_line_ranges provided, only shows blocks overlapping diff" do
      # Block at lines 1-10
      node = make_node(0.60)

      # Diff changes lines 5-7 (overlaps with block)
      diff_ranges = %{"lib/foo.ex" => [{5, 7}]}

      [block] =
        TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)

      assert block.path == "lib/foo.ex"
    end

    test "excludes blocks that don't overlap with diff" do
      # Block at lines 1-10
      node = make_node(0.60)

      # Diff changes lines 50-55 (no overlap)
      diff_ranges = %{"lib/foo.ex" => [{50, 55}]}

      blocks = TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)
      assert blocks == []
    end

    test "excludes blocks when file has no diff ranges" do
      node = make_node(0.60)

      # Diff only has ranges for different file
      diff_ranges = %{"lib/other.ex" => [{1, 10}]}

      blocks = TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)
      assert blocks == []
    end

    test "includes block with exact overlap" do
      # Block at lines 5-15
      node =
        make_node(0.60)
        |> put_in(["start_line"], 5)
        |> put_in(["end_line"], 15)

      # Diff changes exactly lines 5-15
      diff_ranges = %{"lib/foo.ex" => [{5, 15}]}

      [block] =
        TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)

      assert block.start_line == 5
      assert block.end_line == 15
    end

    test "includes block with partial overlap at start" do
      # Block at lines 10-20
      node =
        make_node(0.60)
        |> put_in(["start_line"], 10)
        |> put_in(["end_line"], 20)

      # Diff changes lines 5-12 (overlaps start of block)
      diff_ranges = %{"lib/foo.ex" => [{5, 12}]}

      [block] =
        TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)

      assert block.start_line == 10
    end

    test "includes block with partial overlap at end" do
      # Block at lines 10-20
      node =
        make_node(0.60)
        |> put_in(["start_line"], 10)
        |> put_in(["end_line"], 20)

      # Diff changes lines 18-25 (overlaps end of block)
      diff_ranges = %{"lib/foo.ex" => [{18, 25}]}

      [block] =
        TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)

      assert block.end_line == 20
    end

    test "includes block when diff is entirely inside block" do
      # Block at lines 1-10
      node = make_node(0.60)

      # Diff changes lines 3-5 (inside block)
      diff_ranges = %{"lib/foo.ex" => [{3, 5}]}

      [block] =
        TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)

      assert block.path == "lib/foo.ex"
      assert block.start_line == 1
      assert block.end_line == 10
    end

    test "works with multiple diff ranges for same file" do
      # Block at lines 1-10
      node = make_node(0.60)

      # Diff changes lines 50-55 and 5-7 (second range overlaps)
      diff_ranges = %{"lib/foo.ex" => [{50, 55}, {5, 7}]}

      [block] =
        TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)

      assert block.path == "lib/foo.ex"
      assert block.start_line == 1
      assert block.end_line == 10
    end

    test "excludes adjacent but non-overlapping ranges" do
      # Block at lines 1-10
      node = make_node(0.60)

      # Diff changes line 11 (adjacent but not overlapping)
      diff_ranges = %{"lib/foo.ex" => [{11, 11}]}

      blocks = TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)
      assert blocks == []
    end

    test "excludes blocks when file has empty diff ranges list" do
      node = make_node(0.60)

      # File is present but with empty ranges (e.g., only deletions)
      diff_ranges = %{"lib/foo.ex" => []}

      blocks = TopBlocks.build(make_results([node]), [], lookup(), diff_line_ranges: diff_ranges)
      assert blocks == []
    end

    test "single-line block overlapping single-line diff" do
      # Single-line block at line 5
      node =
        make_node(0.60)
        |> put_in(["start_line"], 5)
        |> put_in(["end_line"], 5)

      diff_ranges = %{"lib/foo.ex" => [{5, 5}]}

      # Need to adjust min_lines for this test since block is only 1 line
      [block] =
        TopBlocks.build(make_results([node]), [], lookup(),
          diff_line_ranges: diff_ranges,
          block_min_lines: 1
        )

      assert block.start_line == 5
      assert block.end_line == 5
    end

    test "when both changed_files and diff_line_ranges provided, both filters apply" do
      node = make_node(0.60)
      changed = [%ChangedFile{path: "lib/foo.ex", status: "modified"}]
      diff_ranges = %{"lib/foo.ex" => [{5, 7}]}

      [block] =
        TopBlocks.build(make_results([node]), changed, lookup(), diff_line_ranges: diff_ranges)

      assert block.path == "lib/foo.ex"
      assert block.status == "modified"
      assert block.start_line == 1
      assert block.end_line == 10
    end

    test "changed_files filter applies before diff_line_ranges filter" do
      node = make_node(0.60)
      # File is in diff_ranges but not in changed_files
      changed = [%ChangedFile{path: "lib/other.ex", status: "modified"}]
      diff_ranges = %{"lib/foo.ex" => [{5, 7}]}

      blocks =
        TopBlocks.build(make_results([node]), changed, lookup(), diff_line_ranges: diff_ranges)

      assert blocks == []
    end
  end
end
