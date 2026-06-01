defmodule CodeQA.Metrics.File.NearDuplicateBlocksTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.File.NearDuplicateBlocks, as: NDB

  describe "token_edit_distance/2" do
    test "identical sequences have distance 0" do
      assert NDB.token_edit_distance(~w[a b c], ~w[a b c]) == 0
    end

    test "empty vs non-empty equals length of other" do
      assert NDB.token_edit_distance([], ~w[a b c]) == 3
      assert NDB.token_edit_distance(~w[a b c], []) == 3
    end

    test "single substitution" do
      assert NDB.token_edit_distance(~w[a b c], ~w[a x c]) == 1
    end
  end

  describe "find_pairs/2 idf_max_freq option" do
    defp make_block(tokens, label) do
      %CodeQA.AST.Enrichment.Node{
        label: label,
        tokens: Enum.map(tokens, &%{kind: &1}),
        line_count: length(tokens),
        children: []
      }
    end

    test "exact duplicates are still detected when all bigrams are high-frequency" do
      # 30 blocks all sharing bigram [end, nil] → pruned by IDF
      # Two additional identical blocks → should still match via exact hash index (d0)
      common = Enum.map(1..30, fn i -> make_block(~w[end nil common_#{i}], "file:#{i}") end)
      dup = make_block(~w[end nil special unique_token], "dup:1")
      dup2 = make_block(~w[end nil special unique_token], "dup:2")

      result = NDB.find_pairs(common ++ [dup, dup2], idf_max_freq: 0.05)

      assert result[0].count >= 1
    end

    test "near-duplicates are detected via non-pruned unique bigrams" do
      # 50 blocks all sharing [end, nil] → pruned
      # Two near-duplicates sharing unique bigrams [nil, special], [special, alpha] → not pruned
      common = Enum.map(1..50, fn i -> make_block(~w[end nil common_#{i}], "common:#{i}") end)
      near_a = make_block(~w[end nil special alpha beta gamma], "near:1")
      near_b = make_block(~w[end nil special alpha beta delta], "near:2")

      result = NDB.find_pairs(common ++ [near_a, near_b], idf_max_freq: 0.05)

      total = Map.values(result) |> Enum.map(& &1.count) |> Enum.sum()
      assert total >= 1
    end
  end

  describe "analyze_from_blocks/2 sub_block_count" do
    test "sub_block_count equals sum of children counts across all blocks" do
      child = make_block(["x"], "child:1")

      parent = %CodeQA.AST.Enrichment.Node{
        label: "a:1",
        tokens: Enum.map(["def", "<ID>", "end"], &%{kind: &1}),
        line_count: 3,
        children: [child, child]
      }

      solo = make_block(["y", "z", "w", "v", "u"], "b:1")
      result = NDB.analyze_from_blocks([parent, solo], [])
      assert result["sub_block_count"] == 2
    end

    test "sub_block_count is zero when no block has children" do
      a = make_block(["x", "y", "z", "w", "v"], "a:1")
      b = make_block(["x", "y", "z", "w", "Q"], "b:1")
      result = NDB.analyze_from_blocks([a, b], [])
      assert result["sub_block_count"] == 0
    end
  end

  describe "canonical_values (via find_pairs)" do
    test "blocks identical except for leading/trailing newline tokens are detected as d0 exact duplicates" do
      core = ["def", "<ID>", "end"]
      trimmed = make_block(core, "a:1")
      with_nl = make_block(["<NL>"] ++ core ++ ["<NL>"], "b:1")
      result = NDB.find_pairs([trimmed, with_nl], [])
      assert Map.get(result, 0, %{count: 0}).count >= 1
    end

    test "blocks identical except for leading/trailing whitespace tokens are detected as d0 exact duplicates" do
      core = ["def", "<ID>", "end"]
      trimmed = make_block(core, "a:1")
      with_ws = make_block(["<WS>"] ++ core ++ ["<WS>"], "b:1")
      result = NDB.find_pairs([trimmed, with_ws], [])
      assert Map.get(result, 0, %{count: 0}).count >= 1
    end
  end

  describe "find_pairs/2 near-boundary behavior" do
    test "pair at exactly d8 boundary (50% edit distance) is detected" do
      # 10 tokens each, 5 substitutions = exactly 50% edit distance → d8
      # First 5 tokens identical → 4 shared bigrams, passes shingle filter
      a = ~w[a b c d e f g h i j]
      b = ~w[a b c d e X Y Z W V]
      result = NDB.find_pairs([make_block(a, "x:1"), make_block(b, "x:2")], [])
      total = Map.values(result) |> Enum.map(& &1.count) |> Enum.sum()
      assert total >= 1
    end

    test "pair just over d8 boundary (>50% edit distance) is not reported" do
      # a: 10 tokens, b: 11 tokens — first 5 identical (4 shared bigrams, passes shingle),
      # abs(10-11)=1 passes token-length guard, but edit distance = 6 (60%) → nil
      a = ~w[a b c d e f g h i j]
      b = ~w[a b c d e X Y Z W V U]
      result = NDB.find_pairs([make_block(a, "x:1"), make_block(b, "x:2")], [])
      total = Map.values(result) |> Enum.map(& &1.count) |> Enum.sum()
      assert total == 0
    end
  end

  describe "percent_bucket/2" do
    test "returns 0 for edit distance 0" do
      assert NDB.percent_bucket(0, 100) == 0
    end

    test "returns 1 for 1% difference (within 0–5%)" do
      assert NDB.percent_bucket(1, 100) == 1
    end

    test "returns 1 for 5% difference (boundary)" do
      assert NDB.percent_bucket(5, 100) == 1
    end

    test "returns 2 for 6% difference" do
      assert NDB.percent_bucket(6, 100) == 2
    end

    test "returns 8 for 50% difference" do
      assert NDB.percent_bucket(50, 100) == 8
    end

    test "returns nil for >50% difference" do
      assert NDB.percent_bucket(51, 100) == nil
    end

    test "returns nil when min_token_count is 0" do
      assert NDB.percent_bucket(0, 0) == nil
    end

    test "returns 7 for exactly 40% (d7 upper boundary)" do
      assert NDB.percent_bucket(40, 100) == 7
    end

    test "returns 8 for 41% (just above d7 boundary, in d8)" do
      assert NDB.percent_bucket(41, 100) == 8
    end

    test "returns 7 for mid-range d7 (35%)" do
      assert NDB.percent_bucket(35, 100) == 7
    end
  end

  describe "analyze/2" do
    test "returns all expected count keys" do
      result = NDB.analyze([{"a.ex", "x = 1\n"}], [])

      for d <- 0..8 do
        assert Map.has_key?(result, "near_dup_block_d#{d}")
      end
    end

    test "returns block_count and sub_block_count" do
      result = NDB.analyze([{"a.ex", "def foo\n  x\nend\n"}], [])
      assert Map.has_key?(result, "block_count")
      assert Map.has_key?(result, "sub_block_count")
    end

    test "block_count reflects detected blocks" do
      code = "def foo\n  x\nend\n\n\ndef bar\n  y\nend\n"
      result = NDB.analyze([{"a.ex", code}], [])
      assert result["block_count"] >= 2
    end

    test "detects exact duplicate blocks at d0" do
      # Two identical function-like blocks separated by blank lines
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block <> "\n\n" <> block}], [])
      assert result["near_dup_block_d0"] >= 1
    end

    test "detects near-duplicate blocks (single token difference)" do
      block_a = "def foo\n  x = 1\nend\n"
      # one identifier differs
      block_b = "def bar\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block_a <> "\n\n" <> block_b}], [])
      near_dup_total = Enum.sum(for d <- 0..8, do: result["near_dup_block_d#{d}"])
      assert near_dup_total >= 1
    end

    test "cross-file detection: same block in two files" do
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block}, {"b.ex", block}], [])
      assert result["near_dup_block_d0"] >= 1
    end

    test "returns only count keys (no pairs keys)" do
      result = NDB.analyze([{"a.ex", "x = 1\n"}], [])
      refute Enum.any?(Map.keys(result), &String.ends_with?(&1, "_pairs"))
    end

    test "find_pairs/2 with include_pairs option returns pair data" do
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block <> "\n\n" <> block}], include_pairs: true)
      pairs_keys = Map.keys(result) |> Enum.filter(&String.ends_with?(&1, "_pairs"))
      assert pairs_keys != []
    end

    test "pair sources include file:line format" do
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block <> "\n\n" <> block}], include_pairs: true)
      pairs = result["near_dup_block_d0_pairs"]
      assert pairs != []
      [first | _] = pairs
      assert first["source_a"] =~ ~r/a\.ex:\d+/
      assert first["source_b"] =~ ~r/a\.ex:\d+/
    end
  end
end
