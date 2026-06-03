defmodule CodeQA.HealthReport.Categories do
  @moduledoc "Default health report category definitions."

  @doc "Returns the default grade scale as `[{min_score, letter}, ...]` sorted descending."
  @spec default_grade_scale() :: [{number(), String.t()}]
  def default_grade_scale,
    do: [
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

  @doc "Returns the built-in category definitions."
  @spec defaults() :: [map()]
  def defaults,
    do: [
      %{
        key: :readability,
        metrics: [
          %{
            fix_hint:
              "Low readability score — simplify sentences, prefer short identifiers, avoid deeply nested expressions",
            good: :high,
            name: "flesch_adapted",
            source: "readability",
            thresholds: %{a: 70, b: 50, c: 35, d: 20},
            weight: 0.4
          },
          %{
            fix_hint:
              "High fog index — reduce complex multi-word identifiers and long compound expressions",
            good: :low,
            name: "fog_adapted",
            source: "readability",
            thresholds: %{a: 6, b: 10, c: 15, d: 22},
            weight: 0.3
          },
          %{
            fix_hint:
              "Too many tokens per line — break long lines into multiple shorter statements",
            good: :low,
            name: "avg_tokens_per_line",
            source: "readability",
            thresholds: %{a: 6, b: 10, c: 14, d: 20},
            weight: 0.2
          },
          %{
            fix_hint:
              "Lines too long — wrap at 80–120 characters and extract intermediate variables",
            good: :low,
            name: "avg_line_length",
            source: "readability",
            thresholds: %{a: 40, b: 60, c: 80, d: 100},
            weight: 0.1
          }
        ],
        name: "Readability"
      },
      %{
        key: :complexity,
        metrics: [
          %{
            fix_hint:
              "High operator/operand ratio — extract repeated sub-expressions into named variables",
            good: :low,
            name: "difficulty",
            source: "halstead",
            thresholds: %{a: 10, b: 20, c: 35, d: 50},
            weight: 0.35
          },
          %{
            fix_hint:
              "High implementation effort — simplify logic by extracting helpers and reducing branching",
            good: :low,
            name: "effort",
            source: "halstead",
            thresholds: %{a: 5000, b: 20_000, c: 50_000, d: 100_000},
            weight: 0.3
          },
          %{
            fix_hint:
              "High token volume — extract helper functions to reduce the total operation count",
            good: :low,
            name: "volume",
            source: "halstead",
            thresholds: %{a: 300, b: 1000, c: 3000, d: 8000},
            weight: 0.2
          },
          %{
            fix_hint: "High defect estimate — reduce complexity; simpler code has fewer bugs",
            good: :low,
            name: "estimated_bugs",
            source: "halstead",
            thresholds: %{a: 0.1, b: 0.5, c: 1.0, d: 3.0},
            weight: 0.15
          }
        ],
        name: "Complexity"
      },
      %{
        key: :structure,
        metrics: [
          %{
            fix_hint:
              "Too many branches per line — flatten conditionals using guard clauses or early returns",
            good: :low,
            name: "branching_density",
            source: "branching",
            thresholds: %{a: 0.08, b: 0.17, c: 0.30, d: 0.45},
            weight: 0.25
          },
          %{
            fix_hint: "High average nesting — extract inner blocks into helper functions",
            good: :low,
            name: "mean_depth",
            source: "indentation",
            thresholds: %{a: 3.5, b: 7, c: 10, d: 15},
            weight: 0.2
          },
          %{
            fix_hint:
              "Functions too long on average — split into smaller single-purpose functions",
            good: :low,
            name: "avg_function_lines",
            source: "function_metrics",
            thresholds: %{a: 8, b: 15, c: 30, d: 65},
            weight: 0.2
          },
          %{
            fix_hint: "Deep nesting — restructure using early returns or extract nested logic",
            good: :low,
            name: "max_depth",
            source: "indentation",
            thresholds: %{a: 8, b: 16, c: 25, d: 35},
            weight: 0.1
          },
          %{
            fix_hint:
              "Largest function too long — decompose the longest function into focused helpers",
            good: :low,
            name: "max_function_lines",
            source: "function_metrics",
            thresholds: %{a: 20, b: 50, c: 100, d: 200},
            weight: 0.1
          },
          %{
            fix_hint:
              "Inconsistent indentation depth — standardize nesting by flattening or restructuring",
            good: :low,
            name: "variance",
            source: "indentation",
            thresholds: %{a: 7, b: 20, c: 40, d: 65},
            weight: 0.1
          },
          %{
            fix_hint:
              "Too many parameters on average — group related params into a struct or map",
            good: :low,
            name: "avg_param_count",
            source: "function_metrics",
            thresholds: %{a: 2, b: 3, c: 5, d: 7},
            weight: 0.03
          },
          %{
            fix_hint:
              "Function has too many parameters — introduce a parameter object or options map",
            good: :low,
            name: "max_param_count",
            source: "function_metrics",
            thresholds: %{a: 3, b: 5, c: 7, d: 10},
            weight: 0.02
          }
        ],
        name: "Structure"
      },
      %{
        key: :duplication,
        metrics: [
          %{
            fix_hint:
              "High redundancy — extract repeated patterns into shared helpers or abstractions",
            good: :low,
            name: "redundancy",
            source: "compression",
            thresholds: %{a: 0.3, b: 0.5, c: 0.65, d: 0.8},
            weight: 0.5
          },
          %{
            fix_hint:
              "Repeated two-token sequences — consolidate duplicated patterns into named functions",
            good: :low,
            name: "bigram_repetition_rate",
            source: "ngram",
            thresholds: %{a: 0.15, b: 0.30, c: 0.45, d: 0.60},
            weight: 0.3
          },
          %{
            fix_hint:
              "Repeated three-token sequences — extract duplicated logic into reusable abstractions",
            good: :low,
            name: "trigram_repetition_rate",
            source: "ngram",
            thresholds: %{a: 0.05, b: 0.15, c: 0.30, d: 0.45},
            weight: 0.2
          }
        ],
        name: "Duplication"
      },
      %{
        key: :naming,
        metrics: [
          %{
            fix_hint:
              "Mixed casing styles — use a single consistent casing convention throughout the file",
            good: :low,
            name: "entropy",
            source: "casing_entropy",
            thresholds: %{a: 1.0, b: 1.5, c: 2.0, d: 2.3},
            weight: 0.3
          },
          %{
            fix_hint: "Identifiers too long on average — prefer concise, intent-revealing names",
            good: :low,
            name: "mean",
            source: "identifier_length_variance",
            thresholds: %{a: 12, b: 18, c: 25, d: 35},
            weight: 0.25
          },
          %{
            fix_hint: "High identifier length variance — standardize name length conventions",
            good: :low,
            name: "variance",
            source: "identifier_length_variance",
            thresholds: %{a: 15, b: 30, c: 50, d: 80},
            weight: 0.25
          },
          %{
            fix_hint:
              "Identifiers have too many sub-words — simplify to 2–3 word names where possible",
            good: :low,
            name: "avg_sub_words_per_id",
            source: "readability",
            thresholds: %{a: 3, b: 4, c: 5, d: 7},
            weight: 0.2
          }
        ],
        name: "Naming"
      },
      %{
        key: :magic_numbers,
        metrics: [
          %{
            fix_hint: "Too many magic numbers — replace literal values with named constants",
            good: :low,
            name: "density",
            source: "magic_number_density",
            thresholds: %{a: 0.02, b: 0.05, c: 0.10, d: 0.20},
            weight: 1.0
          }
        ],
        name: "Magic Numbers"
      }
    ]
end
