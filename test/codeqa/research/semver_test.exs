defmodule CodeQA.Research.SemverTest do
  use ExUnit.Case, async: true

  alias CodeQA.Research.Semver

  describe "parse/1" do
    test "parses standard semver" do
      assert {:ok, {1, 2, 3, nil, nil}} = Semver.parse("v1.2.3")
      assert {:ok, {0, 9, 0, nil, nil}} = Semver.parse("0.9.0")
    end

    test "parses semver with pre-release" do
      assert {:ok, {1, 0, 0, "rc.1", nil}} = Semver.parse("v1.0.0-rc.1")
      assert {:ok, {1, 0, 0, "alpha", nil}} = Semver.parse("1.0.0-alpha")
    end

    test "parses 4-position semver (truncates)" do
      assert {:ok, {1, 2, 3, nil, 4}} = Semver.parse("1.2.3.4")
    end

    test "rejects non-semver" do
      assert :error = Semver.parse("release-2024-q1")
      assert :error = Semver.parse("latest")
    end

    test "detects CalVer" do
      assert {:ok, {2024, 1, 15, nil, nil}} = Semver.parse("2024.1.15")
    end
  end

  describe "classify_jump/2" do
    test "classifies MAJOR jump" do
      assert :major = Semver.classify_jump({1, 0, 0, nil, nil}, {2, 0, 0, nil, nil})
    end

    test "classifies MINOR jump" do
      assert :minor = Semver.classify_jump({1, 0, 0, nil, nil}, {1, 1, 0, nil, nil})
    end

    test "classifies PATCH jump" do
      assert :patch = Semver.classify_jump({1, 0, 3, nil, nil}, {1, 0, 4, nil, nil})
    end

    test "classifies 4th-position-only jump as hotfix" do
      assert :hotfix = Semver.classify_jump({1, 2, 3, nil, 0}, {1, 2, 3, nil, 4})
    end

    test "returns :exclude for pre-release involved" do
      assert :exclude = Semver.classify_jump({1, 0, 0, "rc.1", nil}, {1, 0, 0, nil, nil})
    end

    test "returns :exclude for CalVer" do
      assert :exclude = Semver.classify_jump({2024, 1, 0, nil, nil}, {2024, 2, 0, nil, nil})
    end
  end

  describe "extract_transitions/1" do
    test "extracts consecutive transitions from tag list" do
      tags = [
        %{name: "v1.0.2", sha: "c"},
        %{name: "v1.0.1", sha: "b"},
        %{name: "v1.0.0", sha: "a"}
      ]

      result = Semver.extract_transitions(tags)

      assert [
               %{from_tag: "v1.0.0", to_tag: "v1.0.1", jump: :patch, multi_skip: false},
               %{from_tag: "v1.0.1", to_tag: "v1.0.2", jump: :patch, multi_skip: false}
             ] = result
    end

    test "excludes all 0.x.x transitions (minor)" do
      tags = [
        %{name: "v0.2.0", sha: "b"},
        %{name: "v0.1.0", sha: "a"}
      ]

      assert [] = Semver.extract_transitions(tags)
    end

    test "excludes all 0.x.x transitions (patch)" do
      tags = [
        %{name: "v0.1.1", sha: "b"},
        %{name: "v0.1.0", sha: "a"}
      ]

      assert [] = Semver.extract_transitions(tags)
    end

    test "flags multi-skip transitions" do
      tags = [
        %{name: "v1.3.0", sha: "c"},
        %{name: "v1.1.0", sha: "a"}
      ]

      result = Semver.extract_transitions(tags)
      assert [%{multi_skip: true}] = result
    end
  end
end
