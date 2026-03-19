defmodule CodeQA.ConfigTest do
  use ExUnit.Case, async: false

  alias CodeQA.Config

  setup do
    Config.reset()
    on_exit(&Config.reset/0)
  end

  describe "load/1 and accessors" do
    test "returns defaults when no .codeqa.yml exists" do
      dir = System.tmp_dir!()
      Config.load(dir)

      assert Config.ignore_paths() == []
      assert Config.combined_top() == 2
      assert Config.cosine_significance_threshold() == 0.15
      assert Config.near_duplicate_blocks_opts() == []
      assert is_map(Config.impact_map())
      assert Map.get(Config.impact_map(), "complexity") == 5
    end

    test "loads ignore_paths from .codeqa.yml" do
      dir =
        tmp_dir_with_config("""
        ignore_paths:
          - priv/**
          - docs/**
        """)

      Config.load(dir)

      assert Config.ignore_paths() == ["priv/**", "docs/**"]
    end

    test "loads impact overrides" do
      dir =
        tmp_dir_with_config("""
        impact:
          complexity: 10
          documentation: 3
        """)

      Config.load(dir)

      assert Config.impact_map()["complexity"] == 10
      assert Config.impact_map()["documentation"] == 3
      assert Config.impact_map()["function_design"] == 4
    end

    test "loads combined_top" do
      dir = tmp_dir_with_config("combined_top: 5\n")
      Config.load(dir)
      assert Config.combined_top() == 5
    end

    test "loads cosine_significance_threshold" do
      dir = tmp_dir_with_config("cosine_significance_threshold: 0.25\n")
      Config.load(dir)
      assert Config.cosine_significance_threshold() == 0.25
    end

    test "loads near_duplicate_blocks opts" do
      dir =
        tmp_dir_with_config("""
        near_duplicate_blocks:
          max_pairs_per_bucket: 25
        """)

      Config.load(dir)

      assert Config.near_duplicate_blocks_opts() == [max_pairs_per_bucket: 25]
    end

    test "caches: second load/1 call is a no-op" do
      dir1 = tmp_dir_with_config("combined_top: 7\n")
      dir2 = tmp_dir_with_config("combined_top: 3\n")

      Config.load(dir1)
      Config.load(dir2)

      assert Config.combined_top() == 7
    end

    test "reset/0 clears cache so load/1 works again" do
      dir1 = tmp_dir_with_config("combined_top: 7\n")
      dir2 = tmp_dir_with_config("combined_top: 3\n")

      Config.load(dir1)
      Config.reset()
      Config.load(dir2)

      assert Config.combined_top() == 3
    end
  end

  defp tmp_dir_with_config(yaml) do
    dir = Path.join(System.tmp_dir!(), "codeqa_config_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, ".codeqa.yml"), yaml)
    dir
  end
end
