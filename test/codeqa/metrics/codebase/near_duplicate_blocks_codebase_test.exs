defmodule CodeQA.Metrics.Codebase.NearDuplicateBlocksCodebaseTest do
  use ExUnit.Case, async: true
  alias CodeQA.Analysis.FileContextServer
  alias CodeQA.Metrics.Codebase.NearDuplicateBlocksCodebase

  defp files(pairs), do: Map.new(pairs)

  defp with_pid(fun) do
    {:ok, pid} = FileContextServer.start_link()
    fun.(pid)
  end

  describe "name/0" do
    test "returns near_duplicate_blocks_codebase" do
      assert NearDuplicateBlocksCodebase.name() == "near_duplicate_blocks_codebase"
    end
  end

  describe "analyze/2" do
    test "returns all count keys d0..d8" do
      with_pid(fn pid ->
        result =
          NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1\n"}]), file_context_pid: pid)

        for d <- 0..8, do: assert(Map.has_key?(result, "near_dup_block_d#{d}"))
      end)
    end

    test "returns all pairs keys d0..d8" do
      with_pid(fn pid ->
        result =
          NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1\n"}]), file_context_pid: pid)

        for d <- 0..8, do: assert(Map.has_key?(result, "near_dup_block_d#{d}_pairs"))
      end)
    end

    test "zero counts for a single trivial file" do
      with_pid(fn pid ->
        result =
          NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1\n"}]), file_context_pid: pid)

        assert result["near_dup_block_d0"] == 0
      end)
    end

    test "detects exact duplicate block across two files" do
      block = "def foo\n  x = 1\nend\n"

      with_pid(fn pid ->
        result =
          NearDuplicateBlocksCodebase.analyze(
            files([{"a.ex", block}, {"b.ex", block}]),
            file_context_pid: pid
          )

        assert result["near_dup_block_d0"] >= 1
      end)
    end

    test "pair sources include file paths" do
      block = "def foo\n  x = 1\nend\n"

      with_pid(fn pid ->
        result =
          NearDuplicateBlocksCodebase.analyze(
            files([{"a.ex", block}, {"b.ex", block}]),
            file_context_pid: pid
          )

        all_pairs = result |> Map.values() |> Enum.filter(&is_list/1) |> List.flatten()

        if all_pairs != [] do
          pair = hd(all_pairs)
          assert Map.has_key?(pair, "source_a")
          assert Map.has_key?(pair, "source_b")
        end
      end)
    end

    test "pairs list is capped at max_pairs_per_bucket" do
      block = "def foo\n  x = 1\nend\n"
      many_files = for i <- 1..5, do: {"file#{i}.ex", block}

      with_pid(fn pid ->
        result =
          NearDuplicateBlocksCodebase.analyze(
            files(many_files),
            file_context_pid: pid,
            near_duplicate_blocks: [max_pairs_per_bucket: 2]
          )

        pairs_lists = result |> Map.values() |> Enum.filter(&is_list/1)
        assert Enum.all?(pairs_lists, &(length(&1) <= 2))
      end)
    end
  end
end
