defmodule CodeQA.CLITest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "lib"))
    File.write!(Path.join(tmp_dir, "lib/app.ex"), "defmodule App do\nend\n")
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

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          CodeQA.CLI.main(["analyze", dir])
        end)

      # The ignored file should not be counted
      refute output =~ "secret.ex"
      assert output =~ "Analyzing 1 files"
    end

    test "works normally when .codeqa.yml is absent", %{dir: dir} do
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          CodeQA.CLI.main(["analyze", dir])
        end)

      assert output =~ "Analyzing 1 files"
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

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          CodeQA.CLI.main(["analyze", dir, "--ignore-paths", "ignored_by_flag/**"])
        end)

      # Only lib/app.ex should be analyzed
      assert output =~ "Analyzing 1 files"
    end
  end
end
