# Semver vs Commit Message Analysis — Research Review

**Date:** 2026-03-20
**Context:** 10 independent expert agents reviewed a plan to classify version transitions (bugfix / feature / major revision) using codebase metric deltas at semver boundaries, and use those signatures to classify PRs.

This document captures all findings for reference. It informs the design of the repo analysis scripts in this branch.

---

## The Plan That Was Reviewed

1. Collect popular open-source repos using semantic versioning
2. Extract codebase metrics at each semver version tag
3. Compute metric deltas between consecutive versions
4. Label deltas by semver jump type: MAJOR = major revision, MINOR = feature, PATCH = bugfix
5. Average delta vectors per language per change type
6. Use signatures to classify incoming PRs

---

## Review 1: Semver Signal Validity

**Verdict:** Semver is a usable signal but not reliable ground truth. Expect 20–50% label noise depending on ecosystem.

**Key findings:**
- Strict semver compliance is only ~15–30% of popular repos
- **Marketing MAJORs** are common: Angular 2/4/5/6, React 16→18, Vue 2→3 — MAJOR bumped for developer experience, not API breaks
- **0.x.x exemption**: semver explicitly says pre-1.0 is "anything goes". MINOR in 0.x.x has MAJOR semantics. Must be excluded.
- **PATCH inflation**: Many Python/JS projects tag small features as patches under corporate release pressure
- **MINOR ambiguity**: A MINOR bump can be a large new API surface, a single optional parameter, or just a deprecation notice. Within-class variance can exceed between-class variance.
- **Bot-generated PATCH releases**: Dependabot/Renovate produce near-zero-delta patches — corrupt the "bugfix" centroid
- **Projects that never bump MAJOR**: Django (4.x, 5.x), Python 3.x for 15+ years — MINOR bumps contain architectural changes

**Recommendations:**
- Filter to high-compliance repos using cross-validation with independent signals
- Use conventional commits as co-labels (cross-validate against semver)
- Exclude 0.x.x history unconditionally
- Exclude pre-release tags (alpha/beta/rc) from transitions

---

## Review 2: Statistical Methodology

**Verdict:** Core intuition is sound; execution requires careful normalization. Using raw deltas without normalization will produce signatures reflecting corpus size distribution, not change type.

**Key findings:**
- Raw metric deltas are NOT comparable across repos — "+500 lines" in a 1k-line vs 500k-line project is different
- Cross-repo averaging will be dominated by large repos if not normalized
- Outlier contamination: a single "rewrite in Go" MAJOR bump dominates the average for that class
- Class imbalance: PATCH outnumbers MAJOR ~50:1. Simple averaging ignores this
- Raw delta vectors conflate direction and magnitude — should use relative deltas

**Critical fixes:**
- Use **relative change (% delta)**, not absolute delta
- Use **median + IQR** rather than mean (robust to outliers)
- Stratify by language before averaging — cross-language averages are meaningless
- For MAJOR bump signatures: need 30–50 examples minimum. Requires hundreds of repos per language since MAJOR bumps are rare.
- Don't use nearest-centroid classification — use Gaussian Mixture Model or Bayesian classifier with learned covariance for calibrated probabilities

---

## Review 3: Edge Cases and Semver Variants

**Summary table (all edge cases, by priority):**

| Edge Case | Risk | Recommendation |
|---|---|---|
| Pre-release identifiers (`-rc.1`, `-alpha`) | High | Separate label or exclude |
| 0.x.x minor bumps | High | Exclude unconditionally |
| Build metadata (`+20240101`) | High | Strip before comparison |
| **4+ position versions (1.2.3.4)** | Medium | Truncate to 3; if only pos 4 differs → "hotfix" label or discard |
| Version skips (1.0 → 1.2) | Medium | Flag; isolate or exclude |
| CalVer (2024.01.15) | Medium | Detect MAJOR ≥ 2000; exclude entirely |
| Non-semver tags | Medium | Strict regex allowlist; repo-level exclusion if >20% non-semver |
| Multi-package monorepos | Medium | Exclude or per-package grouping |
| Irregular tagging | Low-Medium | Minimum tag density threshold |
| RC chain iterations (`rc.1 → rc.2`) | Low | Separate label if keeping pre-release data |

**On 4+ position semver specifically:**
The fourth position (e.g., `1.2.3.4`) appears in .NET, Python micro releases, and Java. Semantics are project-specific. Recommendation: compare using only the first 3 positions. If only position 4 differs, treat as "hotfix" (distinct from PATCH) or discard. Do not attempt to fit into 3-position semver logic.

---

## Review 4: Repository Selection and Data Collection

**Scale guidance:**
- 30–50 repos per language minimum for statistically stable per-language signatures
- Minimum 20 published semver tags per repo; at least 3 MAJOR, 10 MINOR, 20 PATCH transitions
- Active maintenance: last tag within 24 months; minimum 10 contributors

**Selection criteria:**
- Stars ≥ 100 (proxy for community validation)
- Tags must match `^v?(\d+)\.(\d+)\.(\d+)` consistently
- Exclude: monorepos, CalVer, bot-only repos, forks

**Start with Rust and Go** — cleanest semver semantics in any ecosystem, due to tooling enforcement. Validate approach there before expanding to noisier ecosystems.

**Data collection architecture:**
1. Use GitHub Search API to discover qualifying repos (22 API calls for 22 languages)
2. Shallow/bare clone per repo; checkout each tag to temp directory
3. Run analysis; write results keyed by `commit_sha` (not tag name — tags can be force-pushed)
4. SQLite or JSON files; not distributed storage needed at MVP scale

**Languages most amenable (ranked by signal quality):**
1. Rust — `cargo-semver-checks` enforces semver correctness
2. Go — module system enforces major version paths; strong norms
3. Elixir/Hex — Hex.pm enforces semver
4. Python — large ecosystem, mature metric tooling
5. JavaScript/TypeScript — most data but highest noise

---

## Review 5: Metric Design (grounded in actual tool metrics)

**The tool's metric inventory includes:**
- `branching_density`, `branch_count`, `max_nesting_depth`
- `function_metrics` (count, avg/max lines, params)
- `halstead` (volume, difficulty, effort, estimated_bugs)
- `rfc` (RFC count, distinct_call_count, function_def_count) — CK-suite coupling
- `compression` (zlib_ratio, redundancy, unique_line_ratio)
- `near_duplicate_blocks_file` and `near_duplicate_blocks_codebase` (d0–d8 exact/near-dup pair counts)
- `cross_file_density` (NCD-based whole-codebase compression ratio)
- `vocabulary` (mattr, unique_identifiers)
- `comment_structure` (todo_fixme_count)
- Corpus linguistics: `entropy`, `zipf`, `heaps`, `bradford`, `brevity`, `menzerath`

**Top discriminative metrics (ranked):**

| Rank | Metric | Signal | Status |
|---|---|---|---|
| 1 | **File count delta** | PATCH≈0, MINOR>0, MAJOR±large | **MISSING — must add** |
| 2 | `function_count` total delta (normalized) | same pattern | Available |
| 3 | `rfc.distinct_call_count` mean delta | PATCH≈0 (no new deps), MINOR↑ | Available |
| 4 | `near_dup_block_d0` codebase count delta | PATCH≈0, MINOR↑ (copy patterns), MAJOR↓ (consolidation) | Available |
| 5 | `cross_file_density` delta | PATCH stable, MAJOR large swing | Available |
| 6 | **New file ratio** | PATCH≈0, MINOR>0 | **MISSING — must add** |
| 7 | Import count per file delta | PATCH≈0, MINOR↑ | Partially available |
| 8 | `vocabulary.mattr` delta | MAJOR-specific (vocabulary turnover) | Available |

**Skip entirely:** `zipf`, `heaps`, `bradford`, `entropy`, `ngram` — too stable over small changes.

**Key insight on near-duplicate blocks:** The *direction* of the delta is informative:
- MINOR (feature): `d1–d3` counts rise — new code copies existing patterns
- MAJOR (rewrite): `d0` exact duplicates drop — consolidation removes copies
- PATCH: near-flat

**Normalization requirements:**
- All absolute counts → divide by total file count or total LOC
- Pair counts (`near_dup_block_*`) → divide by `n*(n-1)/2`
- Ratio metrics (`cross_file_density`, `branching_density`) → no normalization needed

**Hardest distinction: PATCH vs. MINOR**
File count delta + `rfc.distinct_call_count` + `near_dup_block_d1–d3` are the best combination. Even combined, expect highest misclassification rate here. Plan for confidence threshold / abstention.

---

## Review 6: PR Classification Validity

**Verdict:** The PR classification use case is structurally unsound as the primary goal. Reframe around scope/risk estimation.

**The core mismatch:**
- Training signal is at version level (all changes between v1.0.0 and v1.0.1)
- Inference target is PR level (a single pull request)
- A patch release aggregates 20+ PRs; the aggregate delta looks nothing like any individual PR

**This is not a solvable noise problem — it is a structural attribution problem.**

**Additional issues:**
- PRs routinely contain mixed-type changes (bugfix + test addition + refactor)
- Realistic accuracy: ~55–65% (barely above majority-class baseline)
- Security hotfixes that touch many files get classified as "major revision" — dangerous false positive

**Better uses for the metric-delta signal:**
- **Release risk estimation**: aggregate metric deltas across all PRs in a release candidate, compare to historical release-level signatures
- **Anomaly detection**: flag PRs whose metric delta is an outlier for that module's history
- **Changelog generation assistance**: estimate scope/impact of a PR for ordering changelog entries
- **Review effort estimation**: predict review time from metric delta profile

**Recommendation:** Frame as continuous risk/scope estimation, not categorical labeling. Add commit message / PR title NLP as primary classifier; use metric deltas as a confidence modifier.

---

## Review 7: Implementation Complexity and Phases

**Phased plan (validated order):**

### Phase 0: Hypothesis validation (1–2 weeks, no infrastructure)
Pick 5 known repos. Run analysis tool on 3 consecutive releases per jump type. Plot metric deltas. Do they visually separate? If not, stop.

**Gate: do delta patterns look distinguishable by jump type on a small sample?**

### Phase 0b (parallel): Run commit message baseline
On the same repos, check if commit message parsing gives ~80% accurate type labeling. If yes, metric approach is supplementary, not primary.

### Phase 1: MVP data collection (3–4 weeks)
- 20–30 Rust or Go repos (cleanest semver)
- Sequential checkout + analysis loop with commit_sha caching
- SQLite / JSON storage
- No parallelism yet — verify correctness first

**Deliverable: database of metric vectors across tags for 20–30 repos**

### Phase 2: Signature extraction (2 weeks)
- Compute consecutive deltas, label by semver jump type
- Aggregate per language per jump type with **median** (not mean)
- Visualize — do signatures cluster?
- **Gate: are signatures statistically distinct (t-test or KS test)?**

### Phase 3: Classification and evaluation (2–3 weeks)
- Simple nearest-centroid or k-NN classifier
- Evaluate on held-out repos
- **Gate: does classification beat random baseline by meaningful margin?**

### Phase 4: Scale and parallelization (only if Phase 3 succeeds)
- Parallel worker pool
- Expand to 200+ repos across more languages
- Continuous update pipeline

---

## Review 8: Per-Language Stratification

**Metrics are NOT portable across languages.** Examples:
- Go: cyclomatic complexity inflated by `if err != nil` boilerplate — will appear more "major" than it is
- Python: coupling is loose at module level, tight at duck-type boundary — static tools miss implicit coupling
- Elixir/OTP: process boundaries isolate coupling intentionally; different structural patterns

**Architectural recommendation:** Use hierarchical model — shared prior over per-language specialization layers. Handles low-data languages by falling back to shared prior.

**Minimum qualifying repos per language:** 30–50 with strict filtering:
- At least 3 MAJOR, 10 MINOR, 20 PATCH transitions
- Active maintenance within 24 months

**Language-specific conventions to handle:**
- **Go v2+**: module path changes in `go.mod` (`/v2` suffix) — must detect alongside tags
- **Python PEP 440**: `.dev`, `.a`, `.b`, `.rc`, `.post` segments — needs PEP 440 parser, not generic semver
- **npm**: pre-release (`-alpha`, `-beta`, `-rc`) common; many packages bump MAJOR for marketing
- **Rust/Cargo**: strictest ecosystem; `cargo-semver-checks` provides ground truth — use as validation
- **Java/Maven**: `SNAPSHOT` versions must be excluded entirely

**Strip generated code before any metric analysis:**
- protobuf/gRPC stubs, OpenAPI clients, `vendor/`, `generated/` directories

**Treat JavaScript + TypeScript as one language** for stratification.
**Treat Go v1 and v2+ as separate categories** within Go.
**Library vs. application matters** as much as language — semver contract is defined for library consumers.

---

## Review 9: Biases and Failure Modes

**Priority matrix:**

| Failure Mode | Severity | Fixable? |
|---|---|---|
| Semver semantic drift (marketing versions) | Critical | Partially — audit + filter |
| Cheaper signal exists (commit messages) | Critical | Yes — benchmark first |
| Survivorship bias (only well-maintained repos) | High | Document; don't claim general applicability |
| Covariate shift (OSS ≠ internal codebases) | High | Per-codebase normalization required |
| Popularity bias (top repos ≠ average repos) | High | Stratified sampling |
| Feedback/gaming (developers adapt when classifier is used) | Moderate | Design as hint, not gate |
| Temporal bias (old code → different style norms) | Moderate | Recency weighting; decay >3 years |
| Granularity mismatch (version-level training → PR inference) | Moderate | Rethink training data source |
| Security fix misclassified as "major revision" | Low probability, high impact | Override mechanism + uncertainty output |

**Most important single recommendation:** Run the conventional-commits baseline FIRST. If commit message parsing gives ~80% accuracy on labeled PRs, metric-delta approach must demonstrate it adds signal before further investment.

---

## Review 10: Alternative Approaches and Prior Art

**Relevant literature:**
- **Raemaekers et al. (2014)** — "Semantic Versioning versus Breaking Changes": semver poorly adhered to in practice; significant fraction of PATCH releases contain breaking changes
- **Levin & Yehudai (2017)** — "Boosting Automatic Commit Classification": commit message features dominate over code metrics. Code metrics add marginal signal only.
- **Hindle et al. (2008)** — "On the Naturalness of Software": natural language in commit messages is the strongest classification signal
- **SZZ Algorithm (2005)** — bug-inducing commit identification via blame traversal; establishes that metric deltas are noisy signals for bug prediction

**Existing approaches to benchmark against:**
- Conventional commits parsing (deterministic, near-perfect on adopting repos) — the baseline
- GitHub PR labels (`bug`, `enhancement`, `breaking change`) — human-applied, existing ground truth
- GHTorrent / PROMISE repository — labeled defect datasets for validation

**What is genuinely novel in this plan:**
Using the project's own structural metrics (coupling, near-duplicate blocks, compression ratios) as features. These capture *what kind* of change happened, not just *how much*. This is differentiated from generic MSR approaches that use only churn/LOC.

**Validation approach:**
1. Benchmark vs. commit message parsing baseline (on repos with conventional commits)
2. Manual audit of 100–200 version boundaries for semver label noise
3. Cross-repo generalization: train on repo A, evaluate on repo B
4. Use repos with `semantic-release` (ground truth labels) as held-out test set
5. Report per-class precision/recall (not aggregate accuracy — class imbalance inflates it)

---

## Consolidated Recommendations for Script Design

These directly inform the analysis scripts being built in this branch:

1. **Fetch top 20 repos per language** — use GitHub Search API sorted by stars
2. **Filter repos** before analysis: ≥10 valid semver tags, ≥10 contributors, last tag within 24 months, strict semver tag pattern
3. **Exclude from semver analysis**: 0.x.x history, pre-release tags, CalVer repos, monorepos
4. **For 4+ position semver**: truncate to 3 positions; if only pos 4 differs, label "hotfix" and report separately
5. **Commit message analysis**: count `feat:`, `fix:`, `BREAKING CHANGE:`, `refactor:`, `chore:` prefixes between version tags
6. **Comparison metric**: agreement rate between semver label and commit-message majority vote label, where both are available
7. **Report per language**: semver coverage %, conventional commit coverage %, agreement rate, confusion matrix
8. **Start with Rust + Go** for highest-quality signal validation before expanding

---

*Generated from 10 parallel expert reviews — 2026-03-20*
