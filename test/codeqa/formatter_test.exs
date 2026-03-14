defmodule CodeQA.FormatterTest do
  use ExUnit.Case, async: true

  alias CodeQA.Formatter

  @sample_comparison %{
    "metadata" => %{
      "total_files_compared" => 1,
      "summary" => "1 modified",
      "base_ref" => "abc123",
      "head_ref" => "HEAD"
    },
    "files" => %{
      "lib/foo.ex" => %{
        "status" => "modified",
        "base" => %{
          "metrics" => %{"halstead" => %{"volume" => 1000.0}},
          "lines" => 100,
          "bytes" => 3000
        },
        "head" => %{
          "metrics" => %{"halstead" => %{"volume" => 800.0}},
          "lines" => 95,
          "bytes" => 2800
        },
        "delta" => %{
          "metrics" => %{"halstead" => %{"volume" => -200.0}},
          "lines" => -5,
          "bytes" => -200
        }
      }
    },
    "codebase" => %{
      "base" => %{
        "aggregate" => %{
          "readability" => %{
            "mean_flesch_adapted" => 65.0,
            "mean_fog_adapted" => 8.0,
            "mean_avg_tokens_per_line" => 7.0,
            "mean_avg_line_length" => 45.0
          },
          "halstead" => %{
            "mean_difficulty" => 15.0,
            "mean_effort" => 8000.0,
            "mean_volume" => 500.0,
            "mean_estimated_bugs" => 0.2
          }
        }
      },
      "head" => %{
        "aggregate" => %{
          "readability" => %{
            "mean_flesch_adapted" => 75.0,
            "mean_fog_adapted" => 7.0,
            "mean_avg_tokens_per_line" => 6.0,
            "mean_avg_line_length" => 42.0
          },
          "halstead" => %{
            "mean_difficulty" => 12.0,
            "mean_effort" => 6000.0,
            "mean_volume" => 400.0,
            "mean_estimated_bugs" => 0.15
          }
        }
      },
      "delta" => %{"aggregate" => %{}}
    }
  }

  describe "format_github/1" do
    test "includes mermaid chart of head scores" do
      result = Formatter.format_github(@sample_comparison)
      assert result =~ "```mermaid"
      assert result =~ "xychart-beta"
      assert result =~ "bar ["
    end

    test "includes progress bars with base → head" do
      result = Formatter.format_github(@sample_comparison)
      assert result =~ "→"
    end

    test "includes grade emoji" do
      result = Formatter.format_github(@sample_comparison)
      assert result =~ "🟢" or result =~ "🟡" or result =~ "🟠" or result =~ "🔴"
    end

    test "wraps file details in collapsible section" do
      result = Formatter.format_github(@sample_comparison)
      assert result =~ "<details>"
      assert result =~ "</details>"
    end

    test "shows no changes message when zero files compared" do
      comparison = put_in(@sample_comparison, ["metadata", "total_files_compared"], 0)
      result = Formatter.format_github(comparison)
      assert result =~ "No file changes detected"
    end
  end
end
