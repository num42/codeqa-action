defmodule CodeQA.Research.ReportTest do
  use ExUnit.Case, async: true

  alias CodeQA.Research.Report

  test "generate/1 with empty list returns a header with no data rows" do
    output = Report.generate([])
    assert String.contains?(output, "Semver vs Commit Message Analysis Report")
    assert String.contains?(output, "No data available")
    refute String.contains?(output, "##")
  end

  test "generate/1 with valid results includes language row" do
    results = [
      %{
        language: "rust",
        repo: "tokio-rs/tokio",
        semver_classifiable: true,
        conventional_commit_ratio: 0.85,
        comparisons: [
          %{
            jump: :patch,
            commits: :patch,
            commits_classifiable: true,
            agreement: true,
            from_tag: "v1.0.0",
            to_tag: "v1.0.1",
            multi_skip: false,
            commit_count: 5,
            cc_ratio: 0.8
          }
        ]
      }
    ]

    output = Report.generate(results)
    assert String.contains?(output, "rust")
    assert String.contains?(output, "RUST")
  end
end
