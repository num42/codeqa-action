# CodeQA Action

A GitHub Action for running [codeqa](https://github.com/num42/n42-agentic-helpers/tree/main/code-quality-analyzer-ex) code quality analysis on your repository.

Supports three commands:
- **health-report** — Graded health report with worst offenders
- **compare** — Metric comparison between git refs (e.g. PR vs base)
- **analyze** — Raw JSON metrics output

## Usage

### Health Report on PRs

```yaml
name: Code Health
on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: num42/codeqa-action@v1
        with:
          command: health-report
          comment: true
          fail-grade: C
```

### Compare PR Changes

```yaml
      - uses: num42/codeqa-action@v1
        with:
          command: compare
          comment: true
```

The base ref is auto-detected from the PR context. Override with `base-ref` if needed.

### Raw Analysis

```yaml
      - uses: num42/codeqa-action@v1
        id: analysis
        with:
          command: analyze

      - name: Use results
        run: cat ${{ steps.analysis.outputs.report-file }}
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `command` | yes | — | `health-report`, `compare`, or `analyze` |
| `path` | no | `.` | Directory to analyze |
| `comment` | no | `false` | Post result as sticky PR comment |
| `fail-grade` | no | — | Minimum grade for health-report (e.g. `C`). Fails if below |
| `base-ref` | no | PR base SHA | Base ref for `compare` |
| `detail` | no | `default` | Detail level: `summary`, `default`, `full` |
| `top` | no | `5` | Worst offenders per category |
| `format` | no | `markdown` | Compare output: `json` or `markdown` |
| `config` | no | — | Path to `.codeqa.yml` config |
| `extra-args` | no | — | Additional CLI flags |
| `version` | no | `latest` | Version of codeqa binary to use |

## Outputs

| Output | Description |
|--------|-------------|
| `report-file` | Path to the output file |
| `grade` | Overall grade (health-report only) |

## Grade Scale

Grades from best to worst: A, A-, B+, B, B-, C+, C, C-, D+, D, D-, F

When `fail-grade` is set, the action fails if the actual grade is worse than the threshold.

## Configuration

Create a `.codeqa.yml` in your repo to customize categories, weights, and thresholds:

```yaml
      - uses: num42/codeqa-action@v1
        with:
          command: health-report
          config: .codeqa.yml
          comment: true
```
