# Issue Templates Design

**Date:** 2026-03-15
**Branch:** `main` → new PR branch
**Status:** Approved for implementation

---

## Overview

Add structured GitHub Issue Forms templates to `num42/codeqa-action`, with separate templates for human users and AI agents/bots. Add issue links to the README for humans and a dedicated `AGENT.md` for bots. Bootstrap required labels and add CI validation for README link consistency.

---

## Template Inventory

11 templates total: 8 human + 3 bot mirrors (only for types automation will realistically use now).

### Human templates (`.github/ISSUE_TEMPLATE/`)

| File | Purpose | Labels |
|---|---|---|
| `bug-report.yml` | CLI or general bugs | `bug` |
| `action-bug-report.yml` | GitHub Action-specific bugs (different reproduction fields: runner OS, Action version, input params) | `bug`, `action` |
| `feature-request.yml` | New features or improvements | `enhancement` |
| `docs-issue.yml` | README or documentation unclear/wrong | `documentation` |
| `metric-accuracy-report.yml` | Metric scoring wrong for a language/file | `bug`, `metrics` |
| `new-language-request.yml` | Request support for a new language | `enhancement`, `languages` |
| `combined-metrics-sample-submission.yml` | Submit a curated file pattern used in combined-metrics health scoring | `enhancement`, `samples` |
| `question.yml` | How-to / support questions — GitHub Issue Form with a single `textarea` for the question; no dropdown fields needed | `question` |

### Bot templates

| File | Purpose | Labels |
|---|---|---|
| `bot-bug-report.yml` | Automated bug reports from CI/agent runs | `bug`, `bot` |
| `bot-metric-accuracy-report.yml` | Automated metric regression reports | `bug`, `metrics`, `bot` |
| `bot-feature-request.yml` | Agent-generated feature requests | `enhancement`, `bot` |

Bot mirrors for `action-bug-report`, `docs-issue`, `new-language-request`, `combined-metrics-sample-submission`, and `question` are deferred until there is demonstrated need.

---

## Machine-Readability Design

### Primary signal: labels

Labels are the canonical machine-readable discriminator. They survive issue body edits, are queryable at the REST API level without body parsing, and support server-side filtering.

Bot templates use a richer label set encoding type and schema version:

```yaml
labels: ["bug", "bot", "type:bug-report", "schema:v1"]
```

This allows a bot to filter `label:bot+label:type:bug-report` and version-dispatch based on `schema:v1` without touching the issue body.

### Secondary signal: AGENT-SCHEMA comment (documentation only)

Each bot template body begins with a `markdown` block containing an HTML comment:

```
<!-- AGENT-SCHEMA: {"version":"1.0","type":"bug-report","required":["agent_type","agent_version","affected_area","reproduction_path"]} -->
```

This comment is **documentation only** — not a runtime parse target. It is stripped from GitHub's rendered HTML but survives in raw API responses (`GET /repos/.../issues/{n}`) and `raw.githubusercontent.com`. Consuming automation must use labels as the primary parse signal and treat the body comment as a hint for field discovery.

### Bot template field specs

**`bot-bug-report.yml`** required fields: `agent_type`, `agent_version`, `agent_run_id` (opt), `affected_area` (dropdown: CLI / GitHub Action / metrics / output formatting / Other), `reproduction_path` (input), `description` (textarea)

**`bot-metric-accuracy-report.yml`** required fields: `agent_type`, `agent_version`, `agent_run_id` (opt), `metric_name` (dropdown: see sample list above), `language` (dropdown: see sample list above), `expected_value` (input, numeric), `actual_value` (input, numeric), `reproduction_path` (input), `description` (textarea)

**`bot-feature-request.yml`** required fields: `agent_type`, `agent_version`, `agent_run_id` (opt), `feature_area` (dropdown: CLI / GitHub Action / metrics / output formatting / languages / Other), `description` (textarea)

### Bot identity fields (all bot templates)

Replace the single `agent_id` field with three structured fields:

| Field ID | Type | Required | Description |
|---|---|---|---|
| `agent_type` | input | yes | Logical bot type, e.g. `codeqa-health-reporter` (stable, never changes across versions) |
| `agent_version` | input | yes | Semver of the bot, e.g. `1.2.3` |
| `agent_run_id` | input | no | GitHub Actions `${{ github.run_id }}` for workflow traceability. Leave blank if filing from outside GitHub Actions. |

**Prompt injection note:** `agent_type` and `agent_version` are public free-text fields visible to all. Any downstream automation that passes these values into an LLM prompt must sanitize them first. Document this in the template description.

### Dropdowns: representative sample + "Other"

All dropdown fields listing metrics or languages use a short representative list plus `Other / not listed`. Never exhaustive — exhaustive lists become a 4th copy of truth and drift out of sync with `collector.ex` and the README.

Metric dropdown sample (5–6 entries):
- `entropy`
- `halstead`
- `compression_ratio`
- `branching_density`
- `vocabulary_ttr`
- `Other / not listed`

Language dropdown sample:
- `Python`
- `TypeScript`
- `Elixir`
- `Go`
- `Rust`
- `Other / not listed`

---

## Supporting Files

### `.github/ISSUE_TEMPLATE/config.yml`

```yaml
blank_issues_enabled: false
contact_links:
  - name: Discussions
    url: https://github.com/num42/codeqa-action/discussions
    about: Questions and ideas that don't fit an issue template
```

Disabling blank issues enforces structured submissions and reduces noise.

### `AGENT.md` (repo root)

Dedicated machine-readable file for bot/agent discovery. More robust than README embedding: directly fetchable by path, no HTML parsing, no dependency on comment-preservation behavior.

Structure:
```markdown
# Agent Integration Guide

## Issue Templates

<!-- AGENT-ISSUE-LINKS
{
  "schema": "1.0",
  "templates": {
    "bug": "https://github.com/num42/codeqa-action/issues/new?template=bot-bug-report.yml",
    "metric-accuracy": "https://github.com/num42/codeqa-action/issues/new?template=bot-metric-accuracy-report.yml",
    "feature": "https://github.com/num42/codeqa-action/issues/new?template=bot-feature-request.yml"
  }
}
-->

| Type | Template URL |
|---|---|
| Bug | `...?template=bot-bug-report.yml` |
| Metric accuracy | `...?template=bot-metric-accuracy-report.yml` |
| Feature request | `...?template=bot-feature-request.yml` |

## Labels

Bot-submitted issues carry `bot` + `type:<name>` + `schema:v1` labels for API-level filtering.
```

### `.github/labels.yml`

Define all custom labels with names, colors, and descriptions. Consumed by a one-time bootstrap GitHub Actions workflow (`.github/workflows/bootstrap-labels.yml`) using `actions/github-script`. The workflow triggers on `workflow_dispatch` only (manual, one-time run). It reads `.github/labels.yml` and creates any missing labels via the GitHub API — it does not delete existing labels.

Labels to create:

| Name | Description | Color |
|---|---|---|
| `action` | GitHub Action-specific issues | `#0075ca` |
| `metrics` | Metric scoring or accuracy issues | `#e4e669` |
| `languages` | Language support requests | `#d93f0b` |
| `samples` | Combined-metrics sample submissions | `#0e8a16` |
| `bot` | Submitted by an automated tool or AI agent | `#5319e7` |
| `type:bug-report` | Schema discriminator: bug report | `#ee0701` |
| `type:metric-accuracy` | Schema discriminator: metric accuracy | `#ee0701` |
| `type:feature-request` | Schema discriminator: feature request | `#84b6eb` |
| `schema:v1` | Issue schema version 1 | `#cccccc` |
| `question` | How-to or support question | `#cc317c` |

---

## README Changes

### New "Contributing & Issues" section

Position: bottom of README, after the Grading section. Added to the Table of Contents.

Human-visible content:

```markdown
## Contributing & Issues

Found a bug? [Open a bug report](…?template=bug-report.yml)
GitHub Action not behaving? [File an Action bug report](…?template=action-bug-report.yml)
Have an idea? [Request a feature](…?template=feature-request.yml)
Metric scoring wrong? [File a metric accuracy report](…?template=metric-accuracy-report.yml)
New language? [Request language support](…?template=new-language-request.yml)
New combined-metrics sample? [Submit a sample](…?template=combined-metrics-sample-submission.yml)
Docs unclear? [Report a documentation issue](…?template=docs-issue.yml)
Have a question? [Ask in Discussions](https://github.com/num42/codeqa-action/discussions)

Want to contribute code? Fork the repo, make your changes, and open a pull request. See [Quick Start](#quick-start) for build instructions.
```

Bot-visible collapsed section (hidden from humans by default):

```markdown
<details>
<summary>🤖 Automated tool integration</summary>

See [AGENT.md](./AGENT.md) for machine-readable issue template links and label schema.

</details>
```

The `<details>` block points to `AGENT.md` rather than embedding URLs directly, keeping the README stable when template filenames change.

---

## CI Validation Workflow

New workflow: `.github/workflows/validate-issue-links.yml`

Triggers on PRs touching `README.md`, `AGENT.md`, or `.github/ISSUE_TEMPLATE/**`.

Steps:
1. Extract all `?template=X.yml` URL references from `README.md` and `AGENT.md`
2. Check each referenced filename exists in `.github/ISSUE_TEMPLATE/`
3. On failure: exit with a non-zero status (fails the PR check) and print the broken link(s) to stdout. No PR comment needed — the workflow log is sufficient.

This eliminates the silent-breakage risk when templates are renamed.

---

## Sync Discipline for Bot Mirrors

Each human template that has a bot mirror includes a comment at the top of the YAML:

```yaml
# SYNC REQUIRED: structural changes must be mirrored in bot-bug-report.yml
```

Each bot mirror includes the reverse pointer:

```yaml
# SYNC REQUIRED: mirrors bug-report.yml — keep field set and dropdowns aligned
```

---

## Files Created / Modified

| Path | Action |
|---|---|
| `.github/ISSUE_TEMPLATE/bug-report.yml` | Create |
| `.github/ISSUE_TEMPLATE/action-bug-report.yml` | Create |
| `.github/ISSUE_TEMPLATE/feature-request.yml` | Create |
| `.github/ISSUE_TEMPLATE/docs-issue.yml` | Create |
| `.github/ISSUE_TEMPLATE/metric-accuracy-report.yml` | Create |
| `.github/ISSUE_TEMPLATE/new-language-request.yml` | Create |
| `.github/ISSUE_TEMPLATE/combined-metrics-sample-submission.yml` | Create |
| `.github/ISSUE_TEMPLATE/question.yml` | Create |
| `.github/ISSUE_TEMPLATE/bot-bug-report.yml` | Create |
| `.github/ISSUE_TEMPLATE/bot-metric-accuracy-report.yml` | Create |
| `.github/ISSUE_TEMPLATE/bot-feature-request.yml` | Create |
| `.github/ISSUE_TEMPLATE/config.yml` | Create |
| `.github/labels.yml` | Create |
| `.github/workflows/validate-issue-links.yml` | Create |
| `.github/workflows/bootstrap-labels.yml` | Create |
| `AGENT.md` | Create |
| `README.md` | Modify (add Contributing section + ToC entry) |

---

## Out of Scope

- Bot mirrors for `action-bug-report`, `docs-issue`, `new-language-request`, `combined-metrics-sample-submission`, `question` — deferred
- CONTRIBUTING.md — deferred (inline README section is sufficient now)
- `needs-triage` lifecycle label — deferred
- Automated issue triage workflow — deferred
