defmodule CodeQA.GitTest do
  use ExUnit.Case, async: true

  alias CodeQA.Git

  describe "gitignored_files/2" do
    test "returns files that are gitignored" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, ".gitignore"), "*.secret\n")
        File.write!(Path.join(repo, "config.secret"), "password=123")
        File.write!(Path.join(repo, "app.ex"), "defmodule App do end")

        ignored = Git.gitignored_files(repo, ["config.secret", "app.ex"])

        assert ignored == MapSet.new(["config.secret"])
      end)
    end

    test "returns empty set when no files are gitignored" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, ".gitignore"), "*.secret\n")
        File.write!(Path.join(repo, "app.ex"), "defmodule App do end")

        ignored = Git.gitignored_files(repo, ["app.ex"])

        assert ignored == MapSet.new()
      end)
    end

    test "handles empty file list" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, ".gitignore"), "*.secret\n")

        ignored = Git.gitignored_files(repo, [])

        assert ignored == MapSet.new()
      end)
    end

    test "respects nested .gitignore files" do
      in_tmp_git_repo(fn repo ->
        File.mkdir_p!(Path.join(repo, "subdir"))
        File.write!(Path.join(repo, "subdir/.gitignore"), "local.ex\n")
        File.write!(Path.join(repo, "subdir/local.ex"), "# local")
        File.write!(Path.join(repo, "subdir/other.ex"), "# other")

        ignored = Git.gitignored_files(repo, ["subdir/local.ex", "subdir/other.ex"])

        assert ignored == MapSet.new(["subdir/local.ex"])
      end)
    end

    test "handles more than 1000 paths without ARG_MAX issues" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, ".gitignore"), "ignored.ex\n")

        paths = Enum.map(1..1200, fn i -> "file_#{i}.ex" end) ++ ["ignored.ex"]

        ignored = Git.gitignored_files(repo, paths)

        assert ignored == MapSet.new(["ignored.ex"])
      end)
    end

    test "filters files inside a gitignored directory" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, ".gitignore"), "/docs/\n")

        ignored =
          Git.gitignored_files(repo, [
            "docs/readme.md",
            "docs/guide/intro.md",
            "lib/app.ex"
          ])

        assert ignored == MapSet.new(["docs/readme.md", "docs/guide/intro.md"])
      end)
    end

    test "filters gitignored-pattern files even when already tracked by git" do
      in_tmp_git_repo(fn repo ->
        File.mkdir_p!(Path.join(repo, "docs"))
        File.mkdir_p!(Path.join(repo, "lib"))
        File.write!(Path.join(repo, "docs/readme.md"), "# Docs")
        File.write!(Path.join(repo, "lib/app.ex"), "defmodule App do end")

        System.cmd("git", ["add", "."], cd: repo)
        System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        File.write!(Path.join(repo, ".gitignore"), "/docs/\n")

        ignored = Git.gitignored_files(repo, ["docs/readme.md", "lib/app.ex"])

        assert ignored == MapSet.new(["docs/readme.md"])
      end)
    end
  end

  describe "diff_line_ranges/3" do
    test "parses single-line hunks" do
      in_tmp_git_repo(fn repo ->
        # Create initial commit
        File.write!(Path.join(repo, "foo.ex"), "line1\nline2\nline3\n")
        System.cmd("git", ["add", "."], cd: repo)
        System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        # Modify a single line
        File.write!(Path.join(repo, "foo.ex"), "line1\nmodified\nline3\n")
        System.cmd("git", ["add", "."], cd: repo)
        System.cmd("git", ["commit", "-m", "change"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        assert Map.has_key?(ranges, "foo.ex")
        assert {2, 2} in ranges["foo.ex"]
      end)
    end

    test "parses multi-line hunks" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, "foo.ex"), "a\nb\nc\nd\ne\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        # Replace lines 2-4
        File.write!(Path.join(repo, "foo.ex"), "a\nX\nY\nZ\ne\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "change"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        assert Map.has_key?(ranges, "foo.ex")
        assert {2, 4} in ranges["foo.ex"]
      end)
    end

    test "handles multiple hunks in same file" do
      in_tmp_git_repo(fn repo ->
        lines = Enum.map_join(1..20, "\n", &"line#{&1}")
        File.write!(Path.join(repo, "foo.ex"), lines <> "\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        # Change line 2 and line 15
        new_lines =
          1..20
          |> Enum.map(fn
            2 -> "changed2"
            15 -> "changed15"
            n -> "line#{n}"
          end)
          |> Enum.join("\n")

        File.write!(Path.join(repo, "foo.ex"), new_lines <> "\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "change"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        assert Map.has_key?(ranges, "foo.ex")
        assert length(ranges["foo.ex"]) == 2
        assert {2, 2} in ranges["foo.ex"]
        assert {15, 15} in ranges["foo.ex"]
      end)
    end

    test "handles multiple files" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, "a.ex"), "a1\na2\n")
        File.write!(Path.join(repo, "b.ex"), "b1\nb2\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        File.write!(Path.join(repo, "a.ex"), "a1\nchanged\n")
        File.write!(Path.join(repo, "b.ex"), "b1\nchanged\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "change"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        assert {2, 2} in ranges["a.ex"]
        assert {2, 2} in ranges["b.ex"]
      end)
    end

    test "handles added lines (insertion)" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, "foo.ex"), "a\nb\n")
        System.cmd("git", ["add", "."], cd: repo)
        System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        # Insert new line between a and b
        File.write!(Path.join(repo, "foo.ex"), "a\nnew\nb\n")
        System.cmd("git", ["add", "."], cd: repo)
        System.cmd("git", ["commit", "-m", "insert"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        assert Map.has_key?(ranges, "foo.ex")
        # Line 2 is the new line
        assert {2, 2} in ranges["foo.ex"]
      end)
    end

    test "handles deleted lines (no new lines)" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, "foo.ex"), "a\nb\nc\n")
        System.cmd("git", ["add", "."], cd: repo)
        System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        # Delete line b
        File.write!(Path.join(repo, "foo.ex"), "a\nc\n")
        System.cmd("git", ["add", "."], cd: repo)
        System.cmd("git", ["commit", "-m", "delete"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        # File should either not be in ranges or have empty list (deletion only)
        ranges_for_file = Map.get(ranges, "foo.ex", [])
        # No new lines were added, so no ranges pointing to new content
        assert ranges_for_file == [] or not Map.has_key?(ranges, "foo.ex")
      end)
    end

    test "returns empty map when no diff" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, "foo.ex"), "content\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD", "HEAD")

        assert ranges == %{}
      end)
    end

    test "handles new file (no base version)" do
      in_tmp_git_repo(fn repo ->
        File.write!(Path.join(repo, "existing.ex"), "existing\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        File.write!(Path.join(repo, "new.ex"), "line1\nline2\nline3\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "add new file"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        assert Map.has_key?(ranges, "new.ex")
        assert {1, 3} in ranges["new.ex"]
      end)
    end

    test "returns ranges in ascending order" do
      in_tmp_git_repo(fn repo ->
        lines = Enum.map_join(1..20, "\n", &"line#{&1}")
        File.write!(Path.join(repo, "foo.ex"), lines <> "\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "initial"], cd: repo)

        # Change lines 2, 10, and 18
        new_lines =
          1..20
          |> Enum.map(fn
            2 -> "changed2"
            10 -> "changed10"
            18 -> "changed18"
            n -> "line#{n}"
          end)
          |> Enum.join("\n")

        File.write!(Path.join(repo, "foo.ex"), new_lines <> "\n")
        {_, 0} = System.cmd("git", ["add", "."], cd: repo)
        {_, 0} = System.cmd("git", ["commit", "-m", "change"], cd: repo)

        {:ok, ranges} = Git.diff_line_ranges(repo, "HEAD~1", "HEAD")

        # Ranges should be in ascending order by start line
        assert ranges["foo.ex"] == [{2, 2}, {10, 10}, {18, 18}]
      end)
    end
  end

  defp in_tmp_git_repo(fun) do
    tmp = Path.join(System.tmp_dir!(), "codeqa_git_test_#{:rand.uniform(999_999)}")
    File.mkdir_p!(tmp)
    System.cmd("git", ["init"], cd: tmp)
    System.cmd("git", ["config", "user.email", "test@test.com"], cd: tmp)
    System.cmd("git", ["config", "user.name", "Test"], cd: tmp)

    try do
      fun.(tmp)
    after
      File.rm_rf!(tmp)
    end
  end
end
