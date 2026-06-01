defmodule CodeQA.Metrics.File.SeparatorCountsTest do
  use ExUnit.Case, async: true

  alias CodeQA.Metrics.File.SeparatorCounts

  describe "name/0" do
    test "returns separator_counts" do
      assert SeparatorCounts.name() == "separator_counts"
    end
  end

  describe "keys/0" do
    test "returns four count keys" do
      assert SeparatorCounts.keys() == [
               "underscore_count",
               "hyphen_count",
               "slash_count",
               "dot_count"
             ]
    end
  end

  describe "analyze/1" do
    test "counts separators in source code" do
      content = "def my_func(a_b) do\n  File.read(\"path/to/file.txt\")\nend"

      result = SeparatorCounts.analyze(%{content: content})

      assert result["underscore_count"] == 2
      assert result["slash_count"] == 2
      assert result["dot_count"] == 2
      assert result["hyphen_count"] == 0
    end

    test "counts hyphens" do
      content = "some-component {\n  background-color: red;\n}"

      result = SeparatorCounts.analyze(%{content: content})

      assert result["hyphen_count"] == 2
    end

    test "returns zeros for empty content" do
      result = SeparatorCounts.analyze(%{content: ""})

      assert result == %{
               "underscore_count" => 0,
               "hyphen_count" => 0,
               "slash_count" => 0,
               "dot_count" => 0
             }
    end
  end
end
