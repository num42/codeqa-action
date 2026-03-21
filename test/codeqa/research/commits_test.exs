defmodule CodeQA.Research.CommitsTest do
  use ExUnit.Case, async: true

  alias CodeQA.Research.Commits

  describe "classify_messages/1" do
    test "classifies as :major when BREAKING CHANGE present" do
      messages = ["feat!: drop support for v1 API", "fix: minor typo"]
      assert :major = Commits.classify_messages(messages)
    end

    test "classifies as :major when feat! prefix used" do
      assert :major = Commits.classify_messages(["feat!: rewrite auth"])
    end

    test "classifies as :minor when majority are feat:" do
      messages = ["feat: add dark mode", "feat: add export button", "fix: typo"]
      assert :minor = Commits.classify_messages(messages)
    end

    test "classifies as :patch when majority are fix:" do
      messages = [
        "fix: null pointer in payment",
        "fix: off-by-one in date calc",
        "docs: update readme"
      ]

      assert :patch = Commits.classify_messages(messages)
    end

    test "returns :mixed when no clear majority" do
      messages = ["feat: add feature", "fix: fix bug"]
      assert :mixed = Commits.classify_messages(messages)
    end

    test "returns :unclassifiable when no conventional commits" do
      messages = ["Update things", "More stuff", "typo fix"]
      assert :unclassifiable = Commits.classify_messages(messages)
    end

    test "ignores chore/docs/test/ci for majority calculation" do
      messages = [
        "fix: actual bugfix",
        "chore: bump deps",
        "docs: update readme",
        "test: add missing test",
        "ci: update workflow"
      ]

      # Only 1 fix: — should still classify as :patch (only meaningful commit)
      assert :patch = Commits.classify_messages(messages)
    end
  end

  describe "conventional_commit_ratio/1" do
    test "returns 1.0 for all conventional commits" do
      messages = ["feat: a", "fix: b", "chore: c"]
      assert 1.0 = Commits.conventional_commit_ratio(messages)
    end

    test "returns 0.0 for no conventional commits" do
      messages = ["update stuff", "more changes"]
      assert 0.0 = Commits.conventional_commit_ratio(messages)
    end

    test "returns partial ratio for mixed" do
      messages = ["feat: a", "random commit message"]
      assert 0.5 = Commits.conventional_commit_ratio(messages)
    end

    test "returns 0.0 for empty list" do
      assert 0.0 = Commits.conventional_commit_ratio([])
    end
  end
end
