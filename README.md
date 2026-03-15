# CodeQA

Static code analysis tends to enforce style but miss structural problems: functions growing too complex, naming conventions drifting, copy-paste spreading quietly across files. CodeQA surfaces these patterns using statistical metrics — entropy, compression ratios, vocabulary analysis, cyclomatic complexity proxies — without requiring language-specific parsers.

Works with Python, Ruby, JavaScript, TypeScript, Elixir, C#, Java, C++, Go, Rust, PHP, Swift, Kotlin, and Shell.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [GitHub Action](#github-action)
  - [Inputs](#inputs)
  - [Outputs](#outputs)
- [Configuration](#configuration)
- [CLI Reference](#cli-reference)
  - [analyze](#analyze)
  - [health-report](#health-report)
  - [compare](#compare)
  - [history](#history)
  - [correlate](#correlate)
  - [stopwords](#stopwords)
- [Metrics Reference](#metrics-reference)
  - [Raw Metrics](#raw-metrics)
  - [Health Report Categories](#health-report-categories)
  - [Behavior Checks](#behavior-checks)
- [Output Formats](#output-formats)
- [Grading](#grading)

---

## Prerequisites

- Elixir 1.16+ and Erlang/OTP 26+ (only needed for building from source or running the CLI directly)
- For GitHub Actions usage: no local setup required

## Quick Start

**As a GitHub Action (recommended):**

```yaml
- uses: num42/codeqa-action@v1
  with:
    command: health-report
    comment: true
```

**As a CLI (build from source):**

```sh
mix deps.get && mix escript.build

# Graded health report
./codeqa health-report --format plain ./lib

# Compare current branch against main
./codeqa compare --base-ref origin/main --head-ref HEAD --format markdown ./

# Full raw metrics (JSON)
./codeqa analyze ./lib > metrics.json
```

## GitHub Action

The composite action downloads (or builds) the `codeqa` binary and runs a command against your repository. It can post results as a sticky PR comment.

### Basic usage

```yaml
name: Code Quality

on: [push, pull_request]

jobs:
  health-report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: num42/codeqa-action@v1
        with:
          command: health-report
          comment: true
          fail-grade: C
```

### PR quality diff

```yaml
name: Code Quality Diff

on: pull_request

jobs:
  compare:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Get fork point
        id: fork-point
        run: echo "sha=$(git merge-base HEAD ${{ github.event.pull_request.base.sha }})" >> "$GITHUB_OUTPUT"
      - uses: num42/codeqa-action@v1
        with:
          command: compare
          base-ref: ${{ steps.fork-point.outputs.sha }}
          comment: true
```

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `command` | yes | — | CLI command to run: `health-report`, `compare`, or `analyze` |
| `path` | no | `.` | Directory to analyze |
| `comment` | no | `false` | Post results as a sticky PR comment |
| `fail-grade` | no | — | Fail the action if overall grade is below this (e.g. `C`) |
| `base-ref` | no | PR base SHA | Base git ref for `compare` command |
| `detail` | no | `default` | Detail level for `health-report`: `summary`, `default`, or `full` |
| `top` | no | `5` | Worst-offender files to show per category |
| `format` | no | `markdown` | Output format for `compare`: `json` or `markdown` |
| `config` | no | — | Path to `.codeqa.yml` config file |
| `ignore-paths` | no | — | YAML list of glob patterns to exclude |
| `extra-args` | no | — | Additional CLI flags passed through to codeqa |
| `version` | no | `latest` | Version of codeqa binary to download |
| `build` | no | `release` | `release` (download prebuilt binary) or `source` (build from source) |

### Outputs

| Output | Description |
|--------|-------------|
| `report-file` | Path to the output file |
| `grade` | Overall grade from `health-report` (e.g. `B+`) |

## Configuration

CodeQA reads `.codeqa.yml` from the project root automatically. CLI flags always take precedence over file values.

### ignore_paths

```yaml
ignore_paths:
  - priv/samples/**
  - tools/**
  - test/**
  - deps/**
```

`ignore_paths` is a YAML list of glob patterns. Paths matching any pattern are excluded from all analysis.

### Custom categories (health-report)

```yaml
categories:
  - name: Naming
    weight: 1.5
    metrics:
      - name: vowel_density
        good: 0.4
        thresholds: [0.35, 0.3, 0.25]
```

### Grade scale override

```yaml
grade_scale:
  - [90, "A"]
  - [80, "B"]
  - [70, "C"]
  - [0,  "F"]
```

## CLI Reference

> Build the escript first: `mix deps.get && mix escript.build`

### analyze

Computes raw statistical metrics for every file and outputs JSON.

```sh
./codeqa analyze [OPTIONS] <path>
```

| Option | Description |
|--------|-------------|
| `--workers N` | Parallel worker count |
| `--progress` | Show per-file progress |
| `--cache` | Cache computed metrics to disk |
| `--cache-dir PATH` | Directory for cached metrics (default: `.codeqa_cache`) |
| `--timeout MS` | Per-file timeout in milliseconds (default: `5000`) |
| `--show-files` | Include per-file metrics in output |
| `--show-file-paths PATHS` | Comma-separated list of specific file paths to include |
| `--ignore-paths GLOBS` | Comma-separated glob patterns to exclude |
| `--show-ncd` | Include NCD similarity matrix |
| `--ncd-top N` | Top similar pairs per file |
| `--ncd-paths PATHS` | Comma-separated paths to compare for NCD |
| `--output FILE` | Write output to file (default: stdout) |

**Example:**

```sh
./codeqa analyze --workers 8 --show-files ./src > metrics.json
```

### health-report

Produces a graded quality report grouped into behavior categories with worst-offender file lists.

```sh
./codeqa health-report [OPTIONS] <path>
```

| Option | Description |
|--------|-------------|
| `--format FORMAT` | Output format: `plain` or `github` (default: `plain`) |
| `--config PATH` | Path to config file (default: `.codeqa.yml`) |
| `--detail LEVEL` | Report detail: `summary`, `default`, or `full` (default: `default`) |
| `--top N` | Worst-offender files to show per category (default: `5`) |
| `--progress` | Show per-file progress |
| `--ignore-paths GLOBS` | Comma-separated glob patterns to exclude |
| `--output FILE` | Write output to file (default: stdout) |

**Example:**

```sh
./codeqa health-report --detail full --top 10 --format github ./lib
```

### compare

Compares code quality metrics between two git refs. Designed for PR workflows.

```sh
./codeqa compare [OPTIONS] <path>
```

`--base-ref` is **required**.

| Option | Description |
|--------|-------------|
| `--base-ref REF` | **(Required)** Git ref for the base (e.g. `origin/main`) |
| `--head-ref REF` | Git ref for the head (default: `HEAD`) |
| `--format FORMAT` | Output format: `json`, `markdown`, or `github` (default: `json`) |
| `--output MODE` | Output mode: `auto`, `summary`, or `changes` (default: `auto`) |
| `--changes-only` | Show only files with metric changes (default) |
| `--all-files` | Include all files regardless of changes |
| `--ignore-paths GLOBS` | Comma-separated glob patterns to exclude |

**Example:**

```sh
./codeqa compare --base-ref origin/main --head-ref HEAD --format markdown ./
```

### history

Tracks codebase metrics across multiple commits, writing per-commit JSON snapshots to disk.

```sh
./codeqa history [OPTIONS] <path>
```

`--output-dir` is **required**. Either `--commits` or `--commit-list` is **required**.

| Option | Description |
|--------|-------------|
| `--output-dir PATH` | **(Required)** Directory to write JSON snapshots |
| `--commits N` | Number of recent commits to analyze |
| `--commit-list SHAS` | Comma-separated list of explicit commit SHAs |
| `--ignore-paths GLOBS` | Comma-separated glob patterns to exclude |

### correlate

Finds metric correlations across history snapshots produced by `history`. Run `history` first.

```sh
./codeqa correlate [OPTIONS] <history_dir>
```

| Option | Description |
|--------|-------------|
| `--top N` | Number of top correlations to show (default: `20`) |
| `--hide-exact` | Hide perfect 1.0 correlations |
| `--all-groups` | Show all metric groups |
| `--min FLOAT` | Minimum correlation threshold |
| `--max FLOAT` | Maximum correlation threshold |
| `--combined-only` | Show only combined-metric correlations |
| `--max-steps N` | Limit history steps used |

### stopwords

Extracts codebase-specific vocabulary stopwords and fingerprints. Use the output to reduce noise from project-specific boilerplate tokens in subsequent metric analysis.

```sh
./codeqa stopwords [OPTIONS] <path>
```

| Option | Description |
|--------|-------------|
| `--workers N` | Parallel worker count |
| `--stopwords-threshold FLOAT` | Minimum frequency ratio (default: `0.01`) |
| `--progress` | Show per-file progress |
| `--ignore-paths GLOBS` | Comma-separated glob patterns to exclude |

## Metrics Reference

All metrics are computed per file and aggregated at the codebase level.

### Raw Metrics

| Metric | Description |
|--------|-------------|
| **Entropy** | Shannon entropy at character and token level — measures information density |
| **Halstead** | Software-science metrics: operators, operands, vocabulary, volume, difficulty, effort, estimated bugs |
| **Readability** | Adapted Flesch and Fog indices based on identifier and token complexity |
| **Branching density** | Cyclomatic-complexity proxy — ratio of branching constructs to total tokens |
| **Compression ratio** | zlib compression ratio — **higher** ratios indicate more repetitive or boilerplate-heavy code |
| **Vocabulary (TTR)** | Type-to-token ratio — ratio of unique tokens to total tokens |
| **Zipf** | How closely token frequency follows Zipf's law |
| **N-gram analysis** | Bigram/trigram total count, unique count, repetition rate, and hapax fraction — high repetition may indicate copy-paste patterns |
| **Heaps law** | Fits power-law curve `V = k·N^β` to vocabulary growth; reports `beta`, `k`, and R-squared — `beta` near 0.5 is typical |
| **Casing entropy** | Shannon entropy of identifier casing styles (camelCase, snake_case, PascalCase, MACRO_CASE, kebab-case) — high entropy = mixed conventions, low = consistent |
| **Indentation variance** | Standard deviation of indentation depth across lines |
| **Identifier length variance** | Standard deviation of identifier lengths |
| **Symbol density** | Ratio of punctuation/operator symbols to total tokens |
| **Vowel density** | Ratio of vowels in identifiers — low values correlate with terse or abbreviated naming |
| **Magic number density** | Ratio of numeric literals that appear to be unnamed constants |
| **Function metrics** | Function count, average and maximum function line count, average and maximum parameter count |
| **Cross-file similarity** | `cross_file_density`: overall codebase redundancy via combined compression ratio. `ncd_pairs` (opt-in via `--show-ncd`): Normalized Compression Distance between similar file pairs using winnowing fingerprints |

### Health Report Categories

The `health-report` command grades your codebase against 6 primary categories. Each category aggregates raw metrics using configurable weights and thresholds.

| Category | What it measures |
|----------|-----------------|
| **Readability** | Flesch/Fog indices, avg tokens per line, avg line length |
| **Complexity** | Halstead difficulty, effort, volume, and estimated bugs |
| **Structure** | Branching density, indentation depth, function length, parameter counts |
| **Duplication** | Compression redundancy, bigram/trigram repetition rates |
| **Naming** | Casing entropy, identifier length variance, avg sub-words per identifier |
| **Magic Numbers** | Magic number density |

> Category definitions and thresholds are configurable via `.codeqa.yml`.

### Behavior Checks

In addition to the 6 graded categories, `health-report` evaluates additional behavior check categories using a separate multiplicative scoring model. These appear in the report as "Top Issues" diagnostics.

| Category | Checks |
|----------|--------|
| **Code Smells** | Debug prints, dead code after return, FIXME comments, nested ternaries, inconsistent quote style |
| **Naming Conventions** | Class name is a noun, file name matches primary export, function naming patterns, test name starts with verb |
| **Variable Naming** | Clarity, length, and consistency of variable names |
| **Function Design** | Function length and complexity |
| **Documentation** | Comment and docstring presence and quality |
| **File Structure** | File length and organization |
| **Scope & Assignment** | Variable scope and assignment patterns |
| **Type & Value** | Type annotation and value literal usage |
| **Consistency** | Cross-file style consistency |
| **Testing** | Test file coverage and naming patterns |
| **Dependencies** | Import and dependency patterns |
| **Error Handling** | Error handling completeness |

## Output Formats

| Format | Commands | Description |
|--------|----------|-------------|
| `json` | `analyze`, `compare` | Full metrics structure, suitable for tooling |
| `markdown` | `compare`, `health-report` | GitHub-flavored markdown tables |
| `plain` | `health-report` | Human-readable terminal output (Markdown) |
| `github` | `health-report`, `compare` | Markdown optimized for GitHub PR comments |

## Grading

`health-report` assigns grades based on weighted-average scores (0–100) per category and for the overall codebase.

**Grade scale (15 grades):**

| Grade | Score range |
|-------|-------------|
| A     | ≥ 93        |
| A-    | ≥ 85        |
| B+    | ≥ 78        |
| B     | ≥ 72        |
| B-    | ≥ 67        |
| C+    | ≥ 63        |
| C     | ≥ 55        |
| C-    | ≥ 48        |
| D+    | ≥ 42        |
| D     | ≥ 35        |
| D-    | ≥ 25        |
| E+    | ≥ 18        |
| E     | ≥ 12        |
| E-    | ≥ 6         |
| F     | < 6         |

The `fail-grade` action input causes a non-zero exit when the overall grade falls below the specified threshold.

## Contributing & Issues

Found a bug? [Open a bug report](https://github.com/num42/codeqa-action/issues/new?template=bug-report.yml)
GitHub Action not behaving? [File an Action bug report](https://github.com/num42/codeqa-action/issues/new?template=action-bug-report.yml)
Have an idea? [Request a feature](https://github.com/num42/codeqa-action/issues/new?template=feature-request.yml)
Metric scoring wrong? [File a metric accuracy report](https://github.com/num42/codeqa-action/issues/new?template=metric-accuracy-report.yml)
New language? [Request language support](https://github.com/num42/codeqa-action/issues/new?template=new-language-request.yml)
New combined-metrics sample? [Submit a sample](https://github.com/num42/codeqa-action/issues/new?template=combined-metrics-sample-submission.yml)
Docs unclear? [Report a documentation issue](https://github.com/num42/codeqa-action/issues/new?template=docs-issue.yml)
Have a question? [Ask in Discussions](https://github.com/num42/codeqa-action/discussions)

Want to contribute code? Fork the repo, make your changes, and open a pull request. See [Quick Start](#quick-start) for build instructions.

<details>
<summary>🤖 Automated tool integration</summary>

See [AUTOMATION.md](./AUTOMATION.md) for machine-readable issue template links and label schema.

</details>
