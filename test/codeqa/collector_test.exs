defmodule CodeQA.CollectorTest do
  use ExUnit.Case, async: true

  alias CodeQA.Collector

  describe "ignored?/2" do
    test "matches simple wildcard pattern" do
      assert Collector.ignored?("test/foo.ex", ["test/*"])
    end

    test "does not match files outside pattern" do
      refute Collector.ignored?("lib/foo.ex", ["test/*"])
    end

    test "wildcard does not cross directory boundaries" do
      refute Collector.ignored?("test/nested/foo.ex", ["test/*"])
    end

    test "globstar matches nested paths" do
      assert Collector.ignored?("test/nested/deep/foo.ex", ["test/**"])
    end

    test "globstar with file extension" do
      assert Collector.ignored?("src/components/Button.generated.ts", ["**/*.generated.ts"])
    end

    test "exact path match" do
      assert Collector.ignored?("docs/README.md", ["docs/README.md"])
    end

    test "question mark matches single character" do
      assert Collector.ignored?("test/a.ex", ["test/?.ex"])
      refute Collector.ignored?("test/ab.ex", ["test/?.ex"])
    end

    test "dots in pattern are literal" do
      assert Collector.ignored?("foo.ex", ["foo.ex"])
      refute Collector.ignored?("fooXex", ["foo.ex"])
    end

    test "matches against any pattern in the list" do
      patterns = ["test/*", "docs/*"]
      assert Collector.ignored?("test/foo.ex", patterns)
      assert Collector.ignored?("docs/guide.md", patterns)
      refute Collector.ignored?("lib/app.ex", patterns)
    end

    test "empty patterns never match" do
      refute Collector.ignored?("anything.ex", [])
    end
  end

  describe "reject_ignored_map/2" do
    test "removes matching paths from file map" do
      files = %{
        "lib/app.ex" => "code",
        "test/app_test.exs" => "test code",
        "test/support/helper.ex" => "helper"
      }

      result = Collector.reject_ignored_map(files, ["test/*"])

      assert Map.has_key?(result, "lib/app.ex")
      refute Map.has_key?(result, "test/app_test.exs")
      # test/* does not match nested paths
      assert Map.has_key?(result, "test/support/helper.ex")
    end

    test "with globstar removes nested matches" do
      files = %{
        "lib/app.ex" => "code",
        "test/app_test.exs" => "test",
        "test/support/helper.ex" => "helper"
      }

      result = Collector.reject_ignored_map(files, ["test/**"])

      assert Map.has_key?(result, "lib/app.ex")
      refute Map.has_key?(result, "test/app_test.exs")
      refute Map.has_key?(result, "test/support/helper.ex")
    end

    test "empty patterns returns map unchanged" do
      files = %{"a.ex" => "a", "b.ex" => "b"}
      assert Collector.reject_ignored_map(files, []) == files
    end
  end

  describe "reject_ignored/3" do
    test "filters list items by key function" do
      items = [
        %{path: "test/foo.ex", status: "added"},
        %{path: "lib/bar.ex", status: "modified"}
      ]

      result = Collector.reject_ignored(items, ["test/*"], & &1.path)

      assert length(result) == 1
      assert hd(result).path == "lib/bar.ex"
    end

    test "empty patterns returns list unchanged" do
      items = [%{path: "test/foo.ex"}]
      assert Collector.reject_ignored(items, [], & &1.path) == items
    end
  end

  describe "collect_files/2 with ignore_patterns" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "codeqa_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(Path.join(tmp_dir, "lib"))
      File.mkdir_p!(Path.join(tmp_dir, "test"))
      File.write!(Path.join(tmp_dir, "lib/app.ex"), "defmodule App do\nend")
      File.write!(Path.join(tmp_dir, "test/app_test.exs"), "defmodule AppTest do\nend")

      on_exit(fn -> File.rm_rf!(tmp_dir) end)

      %{tmp_dir: tmp_dir}
    end

    test "without ignore patterns collects all files", %{tmp_dir: tmp_dir} do
      files = Collector.collect_files(tmp_dir)
      assert Map.has_key?(files, "lib/app.ex")
      assert Map.has_key?(files, "test/app_test.exs")
    end

    test "with ignore patterns excludes matching files", %{tmp_dir: tmp_dir} do
      files = Collector.collect_files(tmp_dir, ignore_patterns: ["test/*"])
      assert Map.has_key?(files, "lib/app.ex")
      refute Map.has_key?(files, "test/app_test.exs")
    end
  end
end
