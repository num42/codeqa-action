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
