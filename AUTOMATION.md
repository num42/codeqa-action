# Agent Integration Guide

This file provides machine-readable integration information for automated tools and AI agents working with `num42/codeqa-action`.

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
| Bug | `https://github.com/num42/codeqa-action/issues/new?template=bot-bug-report.yml` |
| Metric accuracy | `https://github.com/num42/codeqa-action/issues/new?template=bot-metric-accuracy-report.yml` |
| Feature request | `https://github.com/num42/codeqa-action/issues/new?template=bot-feature-request.yml` |

## Labels

Bot-submitted issues carry `bot` + `type:<name>` + `schema:v1` labels for API-level filtering.

Use the GitHub Issues API with label filters for server-side discrimination:

```
GET /repos/num42/codeqa-action/issues?labels=bot,type:bug-report,schema:v1
```

Available type labels:
- `type:bug-report`
- `type:metric-accuracy`
- `type:feature-request`

## Schema

Each bot template body begins with an HTML comment (stripped from rendered HTML, available in raw API responses):

```
<!-- AGENT-SCHEMA: {"version":"1.0","type":"...","required":[...]} -->
```

Use labels as the primary parse signal. Treat the body comment as a hint for field discovery only.

## Prompt Injection Warning

`agent_type` and `agent_version` are public free-text fields visible to all. Any downstream automation passing these values into an LLM prompt **must sanitize them first**.
