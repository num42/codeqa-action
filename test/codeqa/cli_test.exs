defmodule CodeQA.CLITest do
  use ExUnit.Case, async: false

  setup do
    CodeQA.Config.reset()
    tmp_dir = Path.join(System.tmp_dir!(), "codeqa_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp_dir, "lib"))
    File.write!(Path.join(tmp_dir, "lib/app.ex"), "defmodule App do\nend\n")

    on_exit(fn ->
      CodeQA.Config.reset()
      File.rm_rf!(tmp_dir)
    end)

    %{dir: tmp_dir}
  end

  describe "config file ignore paths" do
    test "patterns from .codeqa.yml are applied automatically", %{dir: dir} do
      File.mkdir_p!(Path.join(dir, "ignored"))
      File.write!(Path.join(dir, "ignored/secret.ex"), "defmodule Secret do\nend\n")

      File.write!(Path.join(dir, ".codeqa.yml"), """
      ignore_paths:
        - ignored/**
      """)

      json = CodeQA.CLI.main(["analyze", dir, "--show-files"])
      report = Jason.decode!(json)

      # total_files == 1 proves the ignored file was excluded (setup has exactly 2 files)
      assert report["metadata"]["total_files"] == 1
      # file paths confirm secret.ex is absent
      refute Map.has_key?(report["files"], Path.join(dir, "ignored/secret.ex"))
    end

    test "works normally when .codeqa.yml is absent", %{dir: dir} do
      json = CodeQA.CLI.main(["analyze", dir])
      report = Jason.decode!(json)

      assert report["metadata"]["total_files"] == 1
    end

    test "config file and --ignore-paths are merged additively", %{dir: dir} do
      File.mkdir_p!(Path.join(dir, "ignored_by_config"))
      File.mkdir_p!(Path.join(dir, "ignored_by_flag"))
      File.write!(Path.join(dir, "ignored_by_config/a.ex"), "defmodule A do\nend\n")
      File.write!(Path.join(dir, "ignored_by_flag/b.ex"), "defmodule B do\nend\n")

      File.write!(Path.join(dir, ".codeqa.yml"), """
      ignore_paths:
        - ignored_by_config/**
      """)

      json = CodeQA.CLI.main(["analyze", dir, "--ignore-paths", "ignored_by_flag/**"])
      report = Jason.decode!(json)

      # Only lib/app.ex should be analyzed — both ignore sources must apply
      assert report["metadata"]["total_files"] == 1
    end
  end
end
