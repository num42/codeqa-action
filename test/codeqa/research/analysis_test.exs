defmodule CodeQA.Research.AnalysisTest do
  use ExUnit.Case, async: true

  alias CodeQA.Research.Analysis

  describe "compare_labels/2" do
    test "agrees when both are :patch" do
      assert %{agreement: true, semver: :patch, commits: :patch} =
               Analysis.compare_labels(:patch, :patch)
    end

    test "maps commit :minor to match semver :minor" do
      assert %{agreement: true} = Analysis.compare_labels(:minor, :minor)
    end

    test "disagrees when labels differ" do
      assert %{agreement: false, semver: :minor, commits: :patch} =
               Analysis.compare_labels(:minor, :patch)
    end

    test "marks :mixed commit label as nil for agreement purposes" do
      result = Analysis.compare_labels(:patch, :mixed)
      assert result.commits_classifiable == false
    end

    test "marks :unclassifiable commit label as nil for agreement purposes" do
      result = Analysis.compare_labels(:patch, :unclassifiable)
      assert result.commits_classifiable == false
    end
  end
end
