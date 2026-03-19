defmodule CodeQA.Metrics.Codebase.SimilarityTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.Codebase.Similarity

  describe "name/0" do
    test "returns similarity" do
      assert Similarity.name() == "similarity"
    end
  end

  describe "analyze/2 with fewer than 2 files" do
    test "empty codebase returns zero density" do
      result = Similarity.analyze(%{})
      assert result["cross_file_density"] == 0.0
    end

    test "single file returns zero density" do
      result = Similarity.analyze(%{"a.ex" => "x = 1"})
      assert result["cross_file_density"] == 0.0
    end

    test "fewer than 2 files returns empty ncd_pairs" do
      result = Similarity.analyze(%{"a.ex" => "x = 1"})
      assert result["ncd_pairs"] == %{}
    end
  end

  describe "analyze/2 cross_file_density" do
    test "returns a float between 0 and 2" do
      files = %{"a.ex" => "def foo, do: 1", "b.ex" => "def bar, do: 2"}
      result = Similarity.analyze(files)
      assert is_float(result["cross_file_density"])
      assert result["cross_file_density"] >= 0.0
    end

    test "identical files produce higher density than dissimilar files" do
      content = String.duplicate("def foo do\n  x = 1\nend\n", 20)
      identical = %{"a.ex" => content, "b.ex" => content}
      dissimilar = %{"a.ex" => content, "b.ex" => String.duplicate("zzz qqq rrr\n", 20)}

      assert Similarity.analyze(identical)["cross_file_density"] >
               Similarity.analyze(dissimilar)["cross_file_density"]
    end

    test "does not return ncd_pairs key by default" do
      files = %{"a.ex" => "x = 1", "b.ex" => "y = 2"}
      result = Similarity.analyze(files)
      refute Map.has_key?(result, "ncd_pairs")
    end
  end

  describe "analyze/2 with show_ncd: true" do
    test "returns ncd_pairs key" do
      files = %{"a.ex" => "x = 1", "b.ex" => "y = 2"}
      result = Similarity.analyze(files, show_ncd: true)
      assert Map.has_key?(result, "ncd_pairs")
    end

    test "identical files have ncd near 0" do
      content = String.duplicate("def foo do\n  x = 1\nend\n", 10)
      files = %{"a.ex" => content, "b.ex" => content}

      result = Similarity.analyze(files, show_ncd: true, ncd_paths: ["a.ex"])
      pairs = result["ncd_pairs"]

      scores = pairs |> Map.values() |> List.flatten() |> Enum.map(& &1["score"])
      assert Enum.all?(scores, &(&1 < 0.2))
    end

    test "ncd_paths restricts which files are compared" do
      files = %{"a.ex" => "x = 1", "b.ex" => "y = 2", "c.ex" => "z = 3"}
      result = Similarity.analyze(files, show_ncd: true, ncd_paths: ["a.ex"])
      pairs = result["ncd_pairs"]
      assert Map.has_key?(pairs, "a.ex")
      refute Map.has_key?(pairs, "b.ex")
      refute Map.has_key?(pairs, "c.ex")
    end
  end
end
