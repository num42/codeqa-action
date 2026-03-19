defmodule CodeQA.CLI.CompareTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    # Initialize a git repo with one source file and one non-source file
    System.cmd("git", ["init"], cd: tmp_dir)
    System.cmd("git", ["config", "user.email", "test@test.com"], cd: tmp_dir)
    System.cmd("git", ["config", "user.name", "Test"], cd: tmp_dir)

    File.mkdir_p!(Path.join(tmp_dir, "lib"))
    File.write!(Path.join(tmp_dir, "lib/app.ex"), "defmodule App do\nend")
    System.cmd("git", ["add", "."], cd: tmp_dir)
    System.cmd("git", ["commit", "-m", "initial"], cd: tmp_dir)

    %{repo: tmp_dir}
  end

  describe "compare with github format" do
    test "file changes section shows actual file count when source files changed", %{repo: repo} do
      File.write!(Path.join(repo, "lib/app.ex"), """
      defmodule App do
        def hello, do: :world
        def goodbye, do: :world
      end
      """)

      System.cmd("git", ["add", "."], cd: repo)
      System.cmd("git", ["commit", "-m", "update app"], cd: repo)

      stdout = CodeQA.CLI.main(["compare", repo, "--base-ref", "HEAD~1", "--format", "github"])

      assert stdout =~ "File changes — 1 modified"
      refute stdout =~ "File changes — no changes"
    end
  end

  describe "compare with no source file changes" do
    test "exits 0 when only non-source files changed", %{repo: repo} do
      # Create a branch, change only a .md file (not a source file)
      File.write!(Path.join(repo, "README.txt"), "hello")
      System.cmd("git", ["add", "."], cd: repo)
      System.cmd("git", ["commit", "-m", "add readme"], cd: repo)

      # compare should succeed (not crash) when no source files changed
      {base_ref, head_ref} = {"HEAD~1", "HEAD"}

      changes = CodeQA.Git.changed_files(repo, base_ref, head_ref)
      assert changes == [], "expected no source file changes, got: #{inspect(changes)}"

      # Verify the CLI handles this gracefully by calling main
      stdout =
        CodeQA.CLI.main([
          "compare",
          repo,
          "--base-ref",
          base_ref,
          "--changes-only",
          "--format",
          "json"
        ])

      result = Jason.decode!(stdout)

      assert result["metadata"]["total_files_compared"] == 0
    end

    test "outputs valid JSON with empty comparison", %{repo: repo} do
      # Change only a non-source file
      File.write!(Path.join(repo, "README.txt"), "hello")
      System.cmd("git", ["add", "."], cd: repo)
      System.cmd("git", ["commit", "-m", "add readme"], cd: repo)

      # Assert on JSON return value directly
      stdout =
        CodeQA.CLI.main([
          "compare",
          repo,
          "--base-ref",
          "HEAD~1",
          "--changes-only",
          "--format",
          "json"
        ])

      assert {:ok, result} = Jason.decode(stdout)
      assert result["metadata"]["total_files_compared"] == 0
    end
  end
end
