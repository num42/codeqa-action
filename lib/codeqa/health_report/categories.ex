defmodule CodeQA.HealthReport.Categories do
  @moduledoc "Default health report category definitions."

  @doc "Returns the default grade scale as `[{min_score, letter}, ...]` sorted descending."
  @spec default_grade_scale() :: [{number(), String.t()}]
  def default_grade_scale do
    [
      {93, "A"},
      {85, "A-"},
      {78, "B+"},
      {72, "B"},
      {67, "B-"},
      {63, "C+"},
      {55, "C"},
      {48, "C-"},
      {42, "D+"},
      {35, "D"},
      {25, "D-"},
      {18, "E+"},
      {12, "E"},
      {6, "E-"},
      {0, "F"}
    ]
  end

  @doc "Returns the built-in category definitions."
  @spec defaults() :: [map()]
  def defaults do
    [
      %{
        key: :readability,
        name: "Readability",
        metrics: [
          %{
            name: "flesch_adapted",
            source: "readability",
            weight: 0.4,
            good: :high,
            thresholds: %{a: 70, b: 50, c: 35, d: 20}
          },
          %{
            name: "fog_adapted",
            source: "readability",
            weight: 0.3,
            good: :low,
            thresholds: %{a: 6, b: 10, c: 15, d: 22}
          },
          %{
            name: "avg_tokens_per_line",
            source: "readability",
            weight: 0.2,
            good: :low,
            thresholds: %{a: 6, b: 10, c: 14, d: 20}
          },
          %{
            name: "avg_line_length",
            source: "readability",
            weight: 0.1,
            good: :low,
            thresholds: %{a: 40, b: 60, c: 80, d: 100}
          }
        ]
      },
      %{
        key: :complexity,
        name: "Complexity",
        metrics: [
          %{
            name: "difficulty",
            source: "halstead",
            weight: 0.35,
            good: :low,
            thresholds: %{a: 10, b: 20, c: 35, d: 50}
          },
          %{
            name: "effort",
            source: "halstead",
            weight: 0.30,
            good: :low,
            thresholds: %{a: 5000, b: 20000, c: 50000, d: 100_000}
          },
          %{
            name: "volume",
            source: "halstead",
            weight: 0.20,
            good: :low,
            thresholds: %{a: 300, b: 1000, c: 3000, d: 8000}
          },
          %{
            name: "estimated_bugs",
            source: "halstead",
            weight: 0.15,
            good: :low,
            thresholds: %{a: 0.1, b: 0.5, c: 1.0, d: 3.0}
          }
        ]
      },
      %{
        key: :structure,
        name: "Structure",
        metrics: [
          %{
            name: "branching_density",
            source: "branching",
            weight: 0.25,
            good: :low,
            thresholds: %{a: 0.08, b: 0.17, c: 0.30, d: 0.45}
          },
          %{
            name: "mean_depth",
            source: "indentation",
            weight: 0.2,
            good: :low,
            thresholds: %{a: 3.5, b: 7, c: 10, d: 15}
          },
          %{
            name: "avg_function_lines",
            source: "function_metrics",
            weight: 0.2,
            good: :low,
            thresholds: %{a: 8, b: 15, c: 30, d: 65}
          },
          %{
            name: "max_depth",
            source: "indentation",
            weight: 0.1,
            good: :low,
            thresholds: %{a: 8, b: 16, c: 25, d: 35}
          },
          %{
            name: "max_function_lines",
            source: "function_metrics",
            weight: 0.1,
            good: :low,
            thresholds: %{a: 20, b: 50, c: 100, d: 200}
          },
          %{
            name: "variance",
            source: "indentation",
            weight: 0.1,
            good: :low,
            thresholds: %{a: 7, b: 20, c: 40, d: 65}
          },
          %{
            name: "avg_param_count",
            source: "function_metrics",
            weight: 0.03,
            good: :low,
            thresholds: %{a: 2, b: 3, c: 5, d: 7}
          },
          %{
            name: "max_param_count",
            source: "function_metrics",
            weight: 0.02,
            good: :low,
            thresholds: %{a: 3, b: 5, c: 7, d: 10}
          }
        ]
      },
      %{
        key: :duplication,
        name: "Duplication",
        metrics: [
          %{
            name: "redundancy",
            source: "compression",
            weight: 0.5,
            good: :low,
            thresholds: %{a: 0.3, b: 0.5, c: 0.65, d: 0.8}
          },
          %{
            name: "bigram_repetition_rate",
            source: "ngram",
            weight: 0.3,
            good: :low,
            thresholds: %{a: 0.15, b: 0.30, c: 0.45, d: 0.60}
          },
          %{
            name: "trigram_repetition_rate",
            source: "ngram",
            weight: 0.2,
            good: :low,
            thresholds: %{a: 0.05, b: 0.15, c: 0.30, d: 0.45}
          }
        ]
      },
      %{
        key: :naming,
        name: "Naming",
        metrics: [
          %{
            name: "entropy",
            source: "casing_entropy",
            weight: 0.3,
            good: :low,
            thresholds: %{a: 1.0, b: 1.5, c: 2.0, d: 2.3}
          },
          %{
            name: "mean",
            source: "identifier_length_variance",
            weight: 0.25,
            good: :low,
            thresholds: %{a: 12, b: 18, c: 25, d: 35}
          },
          %{
            name: "variance",
            source: "identifier_length_variance",
            weight: 0.25,
            good: :low,
            thresholds: %{a: 15, b: 30, c: 50, d: 80}
          },
          %{
            name: "avg_sub_words_per_id",
            source: "readability",
            weight: 0.2,
            good: :low,
            thresholds: %{a: 3, b: 4, c: 5, d: 7}
          }
        ]
      },
      %{
        key: :magic_numbers,
        name: "Magic Numbers",
        metrics: [
          %{
            name: "density",
            source: "magic_number_density",
            weight: 1.0,
            good: :low,
            thresholds: %{a: 0.02, b: 0.05, c: 0.10, d: 0.20}
          }
        ]
      }
    ]
  end
end
