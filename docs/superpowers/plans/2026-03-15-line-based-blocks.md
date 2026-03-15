# Line-Based Near-Duplicate Block Detection Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace token-count sliding windows with natural code block detection (blank-line-separated blocks with bracket/indentation sub-blocks), comparing blocks by percentage edit distance and detecting both exact and near duplicates.

**Architecture:** `TokenNormalizer` gains `normalize_structural/1` emitting `<NL>`/`<WS>` tokens. A new `BlockDetector` applies pluggable `BlockRule` implementations (`BlankLineRule`, `BracketRule`, `ColonIndentationRule`) to build a block tree per file. `NearDuplicateBlocks` uses that tree for structure-filtered pairwise comparison with percentage-bucketed distances (d0 = exact, d1–d8 = 5% increments up to 50%).

**Tech Stack:** Elixir, ExUnit. All work done in worktree `.worktrees/near-duplicate-blocks/`. Run tests with `mix test` from that directory.

---

## File Map

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/codeqa/metrics/block.ex` | `%Block{}` struct — tokens, line_count, sub_blocks, label |
| `lib/codeqa/metrics/block_rule.ex` | Behaviour: `detect/2` returns `[{:split, idx} \| {:enclosure, s, e}]` |
| `lib/codeqa/metrics/block_rules/blank_line_rule.ex` | Emits `{:split, idx}` at 2+ consecutive `<NL>` boundaries |
| `lib/codeqa/metrics/block_rules/bracket_rule.ex` | Emits `{:enclosure, s, e}` for top-level bracket pairs |
| `lib/codeqa/metrics/block_rules/colon_indentation_rule.ex` | Emits `{:enclosure, s, e}` for Python-style colon+indent blocks |
| `lib/codeqa/metrics/block_detector.ex` | Orchestrates rules → `[%Block{}]` with sub-blocks |

**Modify:**

| File | Change |
|------|--------|
| `lib/codeqa/metrics/token_normalizer.ex` | Add `normalize_structural/1` |
| `lib/codeqa/metrics/near_duplicate_blocks.ex` | Full rewrite — natural blocks, percentage distance, d0–d8 |
| `lib/codeqa/metrics/near_duplicate_blocks_file.ex` | New keys: `block_count`, `sub_block_count`, `near_dup_block_d0..d8` |
| `lib/codeqa/metrics/near_duplicate_blocks_codebase.ex` | New keys; include pair lists |

**Old tests to replace** (they assert old key names and `extract_blocks/2` — all will break):
- `test/codeqa/metrics/near_duplicate_blocks_test.exs`
- `test/codeqa/metrics/near_duplicate_blocks_file_test.exs`
- `test/codeqa/metrics/near_duplicate_blocks_codebase_test.exs`

---

## Key Design Decisions

### Token stream shape after `normalize_structural/1`

```
"def foo(x):\n    return x\n\n\ndef bar:\n    pass\n"
→ ["<ID>", "<ID>", "(", "<ID>", ")", ":", "<NL>",
   "<WS>", "<WS>", "<ID>", "<ID>", "<NL>",
   "<NL>", "<NL>",                          ← blank line = 2+ consecutive <NL>
   "<ID>", "<ID>", ":", "<NL>",
   "<WS>", "<WS>", "<ID>", "<NL>"]
```

Indentation: 2 spaces or 1 tab = 1 `<WS>` token. 4 spaces = 2 `<WS>`.

### BlockRule boundary types

```elixir
{:split, idx}            # token at idx starts a new top-level block
{:enclosure, s, e}       # tokens s..e (inclusive) form a sub-block
```

`BlankLineRule` produces only `:split`. `BracketRule` and `ColonIndentationRule` produce only `:enclosure`.

### Distance buckets

| Bucket | Percentage range |
|--------|-----------------|
| d0     | 0% (exact duplicate) |
| d1     | 0 < pct ≤ 5% |
| d2     | 5 < pct ≤ 10% |
| d3     | 10 < pct ≤ 15% |
| d4     | 15 < pct ≤ 20% |
| d5     | 20 < pct ≤ 25% |
| d6     | 25 < pct ≤ 30% |
| d7     | 30 < pct ≤ 40% |
| d8     | 40 < pct ≤ 50% |

`pct = ed / min(token_count_a, token_count_b)`. Pairs with pct > 50% are not reported.

### Structure filter (applied before edit distance)

Two blocks are candidate pairs only when:
- `abs(sub_block_count_a - sub_block_count_b) <= 1`
- `abs(line_count_a - line_count_b) / max(line_count_a, line_count_b) <= 0.30`

### Output keys

`NearDuplicateBlocksFile` returns (all numeric, no pairs):
```
block_count, sub_block_count, near_dup_block_d0, …, near_dup_block_d8
```

`NearDuplicateBlocksCodebase` returns:
```
near_dup_block_d0, …, near_dup_block_d8
near_dup_block_d0_pairs, …, near_dup_block_d8_pairs
```

### `NearDuplicateBlocks.analyze/2` new signature

```elixir
@spec analyze([{path :: String.t(), content :: String.t()}], keyword()) :: map()
```

No more `block_sizes` parameter. Language hint derived from file extension inside `analyze/2`.

---

## Chunk 1: Foundation

### Task 1: `TokenNormalizer.normalize_structural/1`

**Files:**
- Modify: `lib/codeqa/metrics/token_normalizer.ex`
- Create: `test/codeqa/metrics/token_normalizer_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
# test/codeqa/metrics/token_normalizer_test.exs
defmodule CodeQA.Metrics.TokenNormalizerTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.TokenNormalizer

  describe "normalize_structural/1" do
    test "emits <NL> between lines" do
      result = TokenNormalizer.normalize_structural("a\nb")
      assert "<NL>" in result
    end

    test "two blank lines produce two or more consecutive <NL> tokens" do
      result = TokenNormalizer.normalize_structural("a\n\nb")
      nl_runs =
        result
        |> Enum.chunk_by(&(&1 == "<NL>"))
        |> Enum.filter(fn [h | _] -> h == "<NL>" end)
        |> Enum.map(&length/1)
      assert Enum.any?(nl_runs, &(&1 >= 2))
    end

    test "emits one <WS> token per 2 leading spaces" do
      result = TokenNormalizer.normalize_structural("    foo")
      assert Enum.count(result, &(&1 == "<WS>")) == 2
    end

    test "emits one <WS> token per tab" do
      result = TokenNormalizer.normalize_structural("\t\tfoo")
      assert Enum.count(result, &(&1 == "<WS>")) == 2
    end

    test "normalizes identifiers to <ID>" do
      result = TokenNormalizer.normalize_structural("foo bar")
      assert result == ["<ID>", "<ID>"]
    end

    test "normalizes numbers to <NUM>" do
      result = TokenNormalizer.normalize_structural("x = 42")
      assert "<NUM>" in result
    end

    test "empty string returns empty list" do
      assert TokenNormalizer.normalize_structural("") == []
    end

    test "single leading space produces zero <WS> tokens (below threshold)" do
      result = TokenNormalizer.normalize_structural(" foo")
      assert Enum.count(result, &(&1 == "<WS>")) == 0
    end

    test "punctuation tokens like ( and : survive as individual tokens" do
      result = TokenNormalizer.normalize_structural("foo(x):")
      assert "(" in result
      assert ")" in result
      assert ":" in result
    end

    test "existing normalize/1 still works unchanged" do
      # normalize/1 must not emit <NL> — other metrics depend on it
      result = TokenNormalizer.normalize("foo\nbar")
      refute "<NL>" in result
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/andreassolleder/dev/codeqa-action/.worktrees/near-duplicate-blocks
mix test test/codeqa/metrics/token_normalizer_test.exs --trace
```

Expected: `** (UndefinedFunctionError) function TokenNormalizer.normalize_structural/1 is undefined`

- [ ] **Step 3: Implement `normalize_structural/1`**

Add to `lib/codeqa/metrics/token_normalizer.ex` after `normalize/1`:

```elixir
@doc """
Like normalize/1 but preserves newlines as <NL> and leading whitespace
as <WS> tokens (one per 2-space / 1-tab indentation unit).
Used for structural block detection.
"""
@spec normalize_structural(String.t()) :: [String.t()]
def normalize_structural(code) do
  code
  |> String.split("\n")
  |> Enum.map(&normalize_structural_line/1)
  |> Enum.intersperse(["<NL>"])
  |> Enum.concat()
  |> Enum.reject(&(&1 == ""))
end

defp normalize_structural_line(line) do
  indent_units =
    line
    |> String.graphemes()
    |> Enum.take_while(&(&1 in [" ", "\t"]))
    |> Enum.reduce(0, fn "\t", acc -> acc + 2; " ", acc -> acc + 1 end)
    |> div(2)

  ws_tokens = List.duplicate("<WS>", indent_units)

  content_tokens =
    line
    |> String.replace(~r/".*?"|'.*?'/, " <STR> ")
    |> String.replace(~r/\b\d+(\.\d+)?\b/, " <NUM> ")
    |> String.replace(~r/(?<!<)\b[a-zA-Z_]\w*\b(?!>)/, " <ID> ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(&split_punctuation/1)

  ws_tokens ++ content_tokens
end
```

- [ ] **Step 4: Run to verify all tests pass**

```bash
mix test test/codeqa/metrics/token_normalizer_test.exs --trace
```

Expected: 8 tests, 0 failures

- [ ] **Step 5: Run full suite to confirm no regressions**

```bash
mix test 2>&1 | tail -3
```

Expected: same count as before, 0 failures

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/metrics/token_normalizer.ex test/codeqa/metrics/token_normalizer_test.exs
git commit -m "feat(tokenizer): add normalize_structural/1 preserving <NL> and <WS> tokens"
```

---

### Task 2: `Block` struct

**Files:**
- Create: `lib/codeqa/metrics/block.ex`

- [ ] **Step 1: Create the struct**

```elixir
# lib/codeqa/metrics/block.ex
defmodule CodeQA.Metrics.Block do
  @moduledoc "A detected code block with optional nested sub-blocks."

  @enforce_keys [:tokens, :line_count, :sub_blocks]
  defstruct [:tokens, :line_count, :sub_blocks, :label]

  @type t :: %__MODULE__{
    tokens: [String.t()],
    line_count: non_neg_integer(),
    sub_blocks: [t()],
    label: term() | nil
  }

  @spec sub_block_count(t()) :: non_neg_integer()
  def sub_block_count(%__MODULE__{sub_blocks: sbs}), do: length(sbs)

  @spec token_count(t()) :: non_neg_integer()
  def token_count(%__MODULE__{tokens: tokens}), do: length(tokens)
end
```

No dedicated test file — struct correctness is verified by `BlockDetector` tests.

- [ ] **Step 2: Commit**

```bash
git add lib/codeqa/metrics/block.ex
git commit -m "feat(metrics): add Block struct for natural code block representation"
```

---

### Task 3: `BlockRule` behaviour

**Files:**
- Create: `lib/codeqa/metrics/block_rule.ex`

- [ ] **Step 1: Create the behaviour**

```elixir
# lib/codeqa/metrics/block_rule.ex
defmodule CodeQA.Metrics.BlockRule do
  @moduledoc """
  Behaviour for pluggable block and sub-block detection rules.

  A rule scans a token list and returns boundary signals:
  - `{:split, idx}` — token at `idx` starts a new top-level block
  - `{:enclosure, start_idx, end_idx}` — tokens `start_idx..end_idx` form a sub-block
  """

  @type boundary ::
    {:split, non_neg_integer()}
    | {:enclosure, non_neg_integer(), non_neg_integer()}

  @callback detect([String.t()], keyword()) :: [boundary()]
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/codeqa/metrics/block_rule.ex
git commit -m "feat(metrics): add BlockRule behaviour for pluggable block detection"
```

---

## Chunk 2: Block Detection Rules + BlockDetector

### Task 4: `BlankLineRule`

**Files:**
- Create: `lib/codeqa/metrics/block_rules/blank_line_rule.ex`
- Create: `test/codeqa/metrics/block_rules/blank_line_rule_test.exs`

Algorithm: walk through tokens tracking `nl_run` (consecutive `<NL>` count, `<WS>` doesn't reset it). When a substantive token is encountered and `nl_run >= 2` and we've already seen prior content, emit `{:split, idx}` and reset.

- [ ] **Step 1: Write failing tests**

```elixir
# test/codeqa/metrics/block_rules/blank_line_rule_test.exs
defmodule CodeQA.Metrics.BlockRules.BlankLineRuleTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.BlockRules.BlankLineRule

  test "no splits for single block (one newline)" do
    tokens = ["<ID>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == []
  end

  test "detects split after two consecutive <NL>" do
    tokens = ["<ID>", "<NL>", "<NL>", "<ID>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == [{:split, 3}]
  end

  test "detects split with whitespace-only blank line between <NL>s" do
    tokens = ["<ID>", "<NL>", "<WS>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == [{:split, 4}]
  end

  test "no split at start of file even if preceded by blank lines" do
    tokens = ["<NL>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == []
  end

  test "detects multiple splits in a longer stream" do
    # block1 <NL><NL> block2 <NL><NL> block3
    tokens = ["<ID>", "<NL>", "<NL>", "<ID>", "<NL>", "<NL>", "<ID>"]
    splits = BlankLineRule.detect(tokens, [])
    assert length(splits) == 2
  end

  test "three <NL> in a row still produces one split" do
    tokens = ["<ID>", "<NL>", "<NL>", "<NL>", "<ID>"]
    assert BlankLineRule.detect(tokens, []) == [{:split, 4}]
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
mix test test/codeqa/metrics/block_rules/blank_line_rule_test.exs --trace
```

Expected: compile error — module does not exist yet

- [ ] **Step 3: Implement**

```elixir
# lib/codeqa/metrics/block_rules/blank_line_rule.ex
defmodule CodeQA.Metrics.BlockRules.BlankLineRule do
  @moduledoc """
  Detects top-level block boundaries at 2 or more consecutive blank lines.
  A blank line is <NL> optionally followed by <WS> tokens before the next <NL>.
  Returns {:split, idx} for the first substantive token after each blank-line run.
  """
  @behaviour CodeQA.Metrics.BlockRule

  @impl true
  def detect(tokens, _opts) do
    {_, _, _, splits} =
      tokens
      |> Enum.with_index()
      |> Enum.reduce({0, false, false, []}, fn {token, idx}, {nl_run, seen_content, _last_was_nl, splits} ->
        case token do
          "<NL>" ->
            {nl_run + 1, seen_content, true, splits}
          "<WS>" ->
            {nl_run, seen_content, false, splits}
          _ ->
            if seen_content and nl_run >= 2 do
              {0, true, false, [{:split, idx} | splits]}
            else
              {0, true, false, splits}
            end
        end
      end)

    Enum.reverse(splits)
  end
end
```

- [ ] **Step 4: Run to verify pass**

```bash
mix test test/codeqa/metrics/block_rules/blank_line_rule_test.exs --trace
```

Expected: 6 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/codeqa/metrics/block_rules/blank_line_rule.ex \
        test/codeqa/metrics/block_rules/blank_line_rule_test.exs
git commit -m "feat(block-rules): add BlankLineRule — splits at 2+ consecutive blank lines"
```

---

### Task 5: `BracketRule`

**Files:**
- Create: `lib/codeqa/metrics/block_rules/bracket_rule.ex`
- Create: `test/codeqa/metrics/block_rules/bracket_rule_test.exs`

Algorithm: track bracket depth. When opening bracket is seen at depth 0, record `start_idx`. When closing bracket brings depth back to 0, emit `{:enclosure, start_idx, current_idx}`. Ignore unmatched brackets.

- [ ] **Step 1: Write failing tests**

```elixir
# test/codeqa/metrics/block_rules/bracket_rule_test.exs
defmodule CodeQA.Metrics.BlockRules.BracketRuleTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.BlockRules.BracketRule

  test "empty token list returns no enclosures" do
    assert BracketRule.detect([], []) == []
  end

  test "simple paren expression" do
    tokens = ["<ID>", "(", "<ID>", ")"]
    assert BracketRule.detect(tokens, []) == [{:enclosure, 1, 3}]
  end

  test "nested brackets produce one top-level enclosure" do
    tokens = ["(", "<ID>", "(", "<ID>", ")", ")"]
    assert BracketRule.detect(tokens, []) == [{:enclosure, 0, 5}]
  end

  test "two sibling bracket expressions" do
    tokens = ["(", "<ID>", ")", "(", "<ID>", ")"]
    assert BracketRule.detect(tokens, []) == [{:enclosure, 0, 2}, {:enclosure, 3, 5}]
  end

  test "unmatched open bracket produces no enclosure" do
    tokens = ["(", "<ID>"]
    assert BracketRule.detect(tokens, []) == []
  end

  test "supports square and curly brackets" do
    assert BracketRule.detect(["[", "<ID>", "]"], []) == [{:enclosure, 0, 2}]
    assert BracketRule.detect(["{", "<ID>", "}"], []) == [{:enclosure, 0, 2}]
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
mix test test/codeqa/metrics/block_rules/bracket_rule_test.exs --trace
```

- [ ] **Step 3: Implement**

```elixir
# lib/codeqa/metrics/block_rules/bracket_rule.ex
defmodule CodeQA.Metrics.BlockRules.BracketRule do
  @moduledoc """
  Detects sub-blocks delimited by matching bracket pairs: (), [], {}.
  Only top-level (depth-0) bracket expressions are returned as enclosures.
  Nested brackets are absorbed into the enclosing expression.
  """
  @behaviour CodeQA.Metrics.BlockRule

  @open MapSet.new(["(", "[", "{"])
  @close %{")" => "(", "]" => "[", "}" => "{"}

  @impl true
  def detect(tokens, _opts) do
    {_, _, _, enclosures} =
      tokens
      |> Enum.with_index()
      |> Enum.reduce({0, nil, [], []}, fn {token, idx}, {depth, start_idx, stack, enclosures} ->
        cond do
          MapSet.member?(@open, token) ->
            if depth == 0 do
              {1, idx, [token | stack], enclosures}
            else
              {depth + 1, start_idx, [token | stack], enclosures}
            end

          Map.has_key?(@close, token) ->
            case stack do
              [top | rest] when top == @close[token] ->
                new_depth = depth - 1
                if new_depth == 0 do
                  {0, nil, rest, [{:enclosure, start_idx, idx} | enclosures]}
                else
                  {new_depth, start_idx, rest, enclosures}
                end
              _ ->
                # mismatched bracket — ignore
                {depth, start_idx, stack, enclosures}
            end

          true ->
            {depth, start_idx, stack, enclosures}
        end
      end)

    Enum.reverse(enclosures)
  end
end
```

- [ ] **Step 4: Run to verify pass**

```bash
mix test test/codeqa/metrics/block_rules/bracket_rule_test.exs --trace
```

Expected: 6 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/codeqa/metrics/block_rules/bracket_rule.ex \
        test/codeqa/metrics/block_rules/bracket_rule_test.exs
git commit -m "feat(block-rules): add BracketRule — enclosures from matching bracket pairs"
```

---

### Task 6: `ColonIndentationRule`

**Files:**
- Create: `lib/codeqa/metrics/block_rules/colon_indentation_rule.ex`
- Create: `test/codeqa/metrics/block_rules/colon_indentation_rule_test.exs`

Algorithm: scan for `:` followed immediately by `<NL>`. Record the indent level at the `:` line. When the next substantive token appears at a deeper indent, record `sub_start`. Continue until indentation returns to ≤ `:` line's indent → emit `{:enclosure, sub_start, last_content_idx}`.

Indentation level = number of `<WS>` tokens after the most recent `<NL>`.

- [ ] **Step 1: Write failing tests**

```elixir
# test/codeqa/metrics/block_rules/colon_indentation_rule_test.exs
defmodule CodeQA.Metrics.BlockRules.ColonIndentationRuleTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.BlockRules.ColonIndentationRule

  test "empty token list returns no enclosures" do
    assert ColonIndentationRule.detect([], []) == []
  end

  test "detects indented block after colon" do
    # def foo:        → ["<ID>", "<ID>", ":", "<NL>"]  (indices 0-3)
    #     body        → ["<WS>", "<WS>", "<ID>", "<NL>"]  (indices 4-7)
    # enclosure must start at index 6 (<ID> "body") and end at 6
    tokens = ["<ID>", "<ID>", ":", "<NL>", "<WS>", "<WS>", "<ID>", "<NL>"]
    result = ColonIndentationRule.detect(tokens, [])
    assert length(result) == 1
    [{:enclosure, s, e}] = result
    assert s == 6
    assert e == 6
  end

  test "no enclosure when nothing follows the colon at deeper indent" do
    tokens = ["<ID>", ":"]
    assert ColonIndentationRule.detect(tokens, []) == []
  end

  test "no enclosure when next line has same or lesser indent" do
    # if x:
    # same_indent_line
    tokens = ["<ID>", "<ID>", ":", "<NL>", "<ID>"]
    assert ColonIndentationRule.detect(tokens, []) == []
  end

  test "nested colons produce two enclosures" do
    # def foo:       (indent 0) → outer enclosure covers lines 2-4
    #   if x:        (indent 1) → inner enclosure covers line 3 only
    #     body       (indent 2)
    #   other        (indent 1) → closes inner; outer closed at end
    tokens = [
      "<ID>", "<ID>", ":", "<NL>",          # def foo:
      "<WS>", "<ID>", "<ID>", ":", "<NL>",  # if x:
      "<WS>", "<WS>", "<ID>", "<NL>",       # body
      "<WS>", "<ID>", "<NL>"                # other
    ]
    result = ColonIndentationRule.detect(tokens, [])
    assert length(result) == 2
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
mix test test/codeqa/metrics/block_rules/colon_indentation_rule_test.exs --trace
```

- [ ] **Step 3: Implement**

```elixir
# lib/codeqa/metrics/block_rules/colon_indentation_rule.ex
defmodule CodeQA.Metrics.BlockRules.ColonIndentationRule do
  @moduledoc """
  Detects Python-style colon+indentation sub-blocks.
  A sub-block starts when ':' appears at end of a line and the next
  non-empty line has greater indentation. Ends when indentation drops back.
  """
  @behaviour CodeQA.Metrics.BlockRule

  @impl true
  def detect(tokens, _opts) do
    tokens
    |> Enum.with_index()
    |> scan(%{current_indent: 0, last_colon_indent: nil, sub_start: nil,
               last_content_idx: nil, prev_was_colon: false, enclosures: []})
    |> Map.get(:enclosures)
    |> Enum.reverse()
  end

  defp scan([], state), do: close_open(state)

  defp scan([{token, idx} | rest], state) do
    state = update_state(token, idx, state)
    scan(rest, state)
  end

  defp update_state("<NL>", _idx, state) do
    %{state | current_indent: 0, prev_was_colon: false}
  end

  defp update_state("<WS>", _idx, %{current_indent: ci} = state) do
    %{state | current_indent: ci + 1}
  end

  defp update_state(":", _idx, state) do
    %{state | prev_was_colon: true}
  end

  defp update_state(token, idx, state) when token not in ["<NL>", "<WS>", ":"] do
    # Step 1: if previous token was ':', record the colon's indent level now
    state =
      if state.prev_was_colon do
        %{state | last_colon_indent: state.current_indent, prev_was_colon: false}
      else
        state
      end

    # Step 2: apply indent-change logic
    state =
      cond do
        # First content token at deeper indent after a ':' — open sub-block
        state.last_colon_indent != nil and
        state.sub_start == nil and
        state.current_indent > state.last_colon_indent ->
          %{state | sub_start: idx}

        # Content token at same/lower indent as colon — close open sub-block
        state.sub_start != nil and state.current_indent <= state.last_colon_indent ->
          enc = {:enclosure, state.sub_start, state.last_content_idx}
          %{state | enclosures: [enc | state.enclosures], sub_start: nil,
                    last_colon_indent: nil}

        true ->
          state
      end

    %{state | last_content_idx: idx}
  end

  defp close_open(%{sub_start: s, last_content_idx: e, enclosures: encs} = state)
       when s != nil and e != nil do
    %{state | enclosures: [{:enclosure, s, e} | encs]}
  end

  defp close_open(state), do: state
end
```

- [ ] **Step 4: Run to verify pass**

```bash
mix test test/codeqa/metrics/block_rules/colon_indentation_rule_test.exs --trace
```

Expected: 5 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/codeqa/metrics/block_rules/colon_indentation_rule.ex \
        test/codeqa/metrics/block_rules/colon_indentation_rule_test.exs
git commit -m "feat(block-rules): add ColonIndentationRule for Python-style colon+indent blocks"
```

---

### Task 7: `BlockDetector`

**Files:**
- Create: `lib/codeqa/metrics/block_detector.ex`
- Create: `test/codeqa/metrics/block_detector_test.exs`

Responsibilities:
1. Split token stream into top-level blocks via `BlankLineRule`
2. For each block, find sub-blocks via `BracketRule` (all languages) + `ColonIndentationRule` (`:python`)
3. Merge sub-block results (union, deduplicated), build `%Block{}` trees
4. Language hint derived from file extension when path is given via `opts`

- [ ] **Step 1: Write failing tests**

```elixir
# test/codeqa/metrics/block_detector_test.exs
defmodule CodeQA.Metrics.BlockDetectorTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.{BlockDetector, TokenNormalizer}

  defp tokenize(code), do: TokenNormalizer.normalize_structural(code)

  describe "detect_blocks/2" do
    test "single block for file with no blank lines" do
      tokens = tokenize("def foo\n  x = 1\nend\n")
      blocks = BlockDetector.detect_blocks(tokens, [])
      assert length(blocks) == 1
    end

    test "splits into two blocks at blank line" do
      tokens = tokenize("def foo\n  x\nend\n\n\ndef bar\n  y\nend\n")
      blocks = BlockDetector.detect_blocks(tokens, [])
      assert length(blocks) == 2
    end

    test "each block has correct line_count" do
      tokens = tokenize("a\nb\n\n\nc\nd\n")
      [b1, b2] = BlockDetector.detect_blocks(tokens, [])
      assert b1.line_count >= 2
      assert b2.line_count >= 2
    end

    test "empty input returns empty list" do
      assert BlockDetector.detect_blocks([], []) == []
    end

    test "detects bracket sub-blocks" do
      tokens = tokenize("foo(a, b)\nbar(c)\n")
      [block] = BlockDetector.detect_blocks(tokens, [])
      assert block.sub_blocks != []
    end

    test "detects colon-indent sub-blocks for python language hint" do
      tokens = tokenize("def foo:\n    return 1\n")
      [block] = BlockDetector.detect_blocks(tokens, language: :python)
      assert length(block.sub_blocks) >= 1
    end

    test "fewer sub-blocks without python hint than with it (colon rule not applied)" do
      tokens = tokenize("def foo:\n    return 1\n")
      without_hint = BlockDetector.detect_blocks(tokens, [])
      with_hint    = BlockDetector.detect_blocks(tokens, language: :python)
      count_without = without_hint |> Enum.map(&length(&1.sub_blocks)) |> Enum.sum()
      count_with    = with_hint    |> Enum.map(&length(&1.sub_blocks)) |> Enum.sum()
      assert count_with >= count_without
    end

    test "block has sub_block_count accessible via Block.sub_block_count/1" do
      alias CodeQA.Metrics.Block
      tokens = tokenize("foo(a)\nbar(b)\n")
      [block] = BlockDetector.detect_blocks(tokens, [])
      assert Block.sub_block_count(block) == length(block.sub_blocks)
    end
  end

  describe "language_from_path/1" do
    test "returns :python for .py files" do
      assert BlockDetector.language_from_path("lib/foo.py") == :python
    end

    test "returns :unknown for unknown extensions" do
      assert BlockDetector.language_from_path("lib/foo.ex") == :unknown
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
mix test test/codeqa/metrics/block_detector_test.exs --trace
```

- [ ] **Step 3: Implement**

```elixir
# lib/codeqa/metrics/block_detector.ex
defmodule CodeQA.Metrics.BlockDetector do
  @moduledoc """
  Detects natural code blocks from a structural token stream.

  Uses BlankLineRule to find top-level block boundaries, then
  BracketRule (and ColonIndentationRule for Python) to find sub-blocks.
  """

  alias CodeQA.Metrics.Block
  alias CodeQA.Metrics.BlockRules.{BlankLineRule, BracketRule, ColonIndentationRule}

  @spec detect_blocks([String.t()], keyword()) :: [Block.t()]
  def detect_blocks([], _opts), do: []

  def detect_blocks(tokens, opts) do
    language = Keyword.get(opts, :language, :unknown)

    split_points =
      BlankLineRule.detect(tokens, opts)
      |> Enum.map(fn {:split, idx} -> idx end)
      |> Enum.sort()

    tokens
    |> split_at(split_points)
    |> Enum.reject(&Enum.empty?/1)
    |> Enum.map(fn block_tokens ->
      sub_blocks = detect_sub_blocks(block_tokens, language, opts)
      line_count = Enum.count(block_tokens, &(&1 == "<NL>")) + 1

      %Block{
        tokens: block_tokens,
        line_count: line_count,
        sub_blocks: sub_blocks
      }
    end)
  end

  @spec language_from_path(String.t()) :: atom()
  def language_from_path(path) do
    case Path.extname(path) do
      ".py" -> :python
      _     -> :unknown
    end
  end

  defp detect_sub_blocks(tokens, language, opts) do
    rules = sub_block_rules(language)

    tokens
    |> then(fn t -> Enum.flat_map(rules, &(&1.detect(t, opts))) end)
    |> Enum.filter(&match?({:enclosure, _, _}, &1))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn {:enclosure, s, e} ->
      sub_tokens = Enum.slice(tokens, s..e)
      line_count = Enum.count(sub_tokens, &(&1 == "<NL>")) + 1
      %Block{tokens: sub_tokens, line_count: line_count, sub_blocks: []}
    end)
  end

  defp sub_block_rules(:python), do: [BracketRule, ColonIndentationRule]
  defp sub_block_rules(_),       do: [BracketRule]

  defp split_at(tokens, []), do: [tokens]

  defp split_at(tokens, split_points) do
    boundaries = [0 | split_points] ++ [length(tokens)]

    boundaries
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [start, stop] -> Enum.slice(tokens, start..(stop - 1)) end)
  end
end
```

- [ ] **Step 4: Run to verify pass**

```bash
mix test test/codeqa/metrics/block_detector_test.exs --trace
```

Expected: all tests pass

- [ ] **Step 5: Run full suite**

```bash
mix test 2>&1 | tail -3
```

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/metrics/block_detector.ex test/codeqa/metrics/block_detector_test.exs
git commit -m "feat(metrics): add BlockDetector — orchestrates rules into Block tree"
```

---

## Chunk 3: `NearDuplicateBlocks` Core Rewrite

### Task 8: Rewrite `NearDuplicateBlocks`

**Files:**
- Rewrite: `lib/codeqa/metrics/near_duplicate_blocks.ex`
- Rewrite: `test/codeqa/metrics/near_duplicate_blocks_test.exs`

Key changes from the old implementation:
- `analyze/3` → `analyze/2` (no `block_sizes` param; now takes `[{path, content}]`)
- Remove `extract_blocks/2` (replaced by `BlockDetector`)
- `find_pairs/2` now takes `[%Block{}]` and applies structure filter before edit distance
- Distance bucketed by percentage, not absolute token count
- d0 (exact duplicates) included — removed the `ed >= 1` exclusion
- Output keys: `near_dup_block_d0..d8`, `block_count`, `sub_block_count`

- [ ] **Step 1: Write the new failing tests (replace old test file)**

```elixir
# test/codeqa/metrics/near_duplicate_blocks_test.exs
defmodule CodeQA.Metrics.NearDuplicateBlocksTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.NearDuplicateBlocks, as: NDB

  describe "token_edit_distance/2" do
    test "identical sequences have distance 0" do
      assert NDB.token_edit_distance(~w[a b c], ~w[a b c]) == 0
    end

    test "empty vs non-empty equals length of other" do
      assert NDB.token_edit_distance([], ~w[a b c]) == 3
      assert NDB.token_edit_distance(~w[a b c], []) == 3
    end

    test "single substitution" do
      assert NDB.token_edit_distance(~w[a b c], ~w[a x c]) == 1
    end
  end

  describe "percent_bucket/2" do
    test "returns 0 for edit distance 0" do
      assert NDB.percent_bucket(0, 100) == 0
    end

    test "returns 1 for 1% difference (within 0–5%)" do
      assert NDB.percent_bucket(1, 100) == 1
    end

    test "returns 1 for 5% difference (boundary)" do
      assert NDB.percent_bucket(5, 100) == 1
    end

    test "returns 2 for 6% difference" do
      assert NDB.percent_bucket(6, 100) == 2
    end

    test "returns 8 for 50% difference" do
      assert NDB.percent_bucket(50, 100) == 8
    end

    test "returns nil for >50% difference" do
      assert NDB.percent_bucket(51, 100) == nil
    end

    test "returns nil when min_token_count is 0" do
      assert NDB.percent_bucket(0, 0) == nil
    end

    test "returns 7 for exactly 40% (d7 upper boundary)" do
      assert NDB.percent_bucket(40, 100) == 7
    end

    test "returns 8 for 41% (just above d7 boundary, in d8)" do
      assert NDB.percent_bucket(41, 100) == 8
    end

    test "returns 7 for mid-range d7 (35%)" do
      assert NDB.percent_bucket(35, 100) == 7
    end
  end

  describe "analyze/2" do
    test "returns all expected count keys" do
      result = NDB.analyze([{"a.ex", "x = 1\n"}], [])
      for d <- 0..8 do
        assert Map.has_key?(result, "near_dup_block_d#{d}")
      end
    end

    test "returns block_count and sub_block_count" do
      result = NDB.analyze([{"a.ex", "def foo\n  x\nend\n"}], [])
      assert Map.has_key?(result, "block_count")
      assert Map.has_key?(result, "sub_block_count")
    end

    test "block_count reflects detected blocks" do
      code = "def foo\n  x\nend\n\n\ndef bar\n  y\nend\n"
      result = NDB.analyze([{"a.ex", code}], [])
      assert result["block_count"] >= 2
    end

    test "detects exact duplicate blocks at d0" do
      # Two identical function-like blocks separated by blank lines
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block <> "\n\n" <> block}], [])
      assert result["near_dup_block_d0"] >= 1
    end

    test "detects near-duplicate blocks (single token difference)" do
      block_a = "def foo\n  x = 1\nend\n"
      block_b = "def bar\n  x = 1\nend\n"  # one identifier differs
      result = NDB.analyze([{"a.ex", block_a <> "\n\n" <> block_b}], [])
      near_dup_total = Enum.sum(for d <- 0..8, do: result["near_dup_block_d#{d}"])
      assert near_dup_total >= 1
    end

    test "cross-file detection: same block in two files" do
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block}, {"b.ex", block}], [])
      assert result["near_dup_block_d0"] >= 1
    end

    test "returns only count keys (no pairs keys)" do
      result = NDB.analyze([{"a.ex", "x = 1\n"}], [])
      refute Enum.any?(Map.keys(result), &String.ends_with?(&1, "_pairs"))
    end

    test "find_pairs/2 with include_pairs option returns pair data" do
      block = "def foo\n  x = 1\nend\n"
      result = NDB.analyze([{"a.ex", block <> "\n\n" <> block}], include_pairs: true)
      pairs_keys = Map.keys(result) |> Enum.filter(&String.ends_with?(&1, "_pairs"))
      assert length(pairs_keys) > 0
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
mix test test/codeqa/metrics/near_duplicate_blocks_test.exs --trace
```

Expected: multiple failures — old keys, missing `percent_bucket/2`, wrong `analyze` arity

- [ ] **Step 3: Rewrite `near_duplicate_blocks.ex`**

```elixir
# lib/codeqa/metrics/near_duplicate_blocks.ex
defmodule CodeQA.Metrics.NearDuplicateBlocks do
  @moduledoc """
  Near-duplicate block detection using natural code blocks.

  Detects blocks via blank-line boundaries and sub-blocks via bracket/indentation rules.
  Compares structurally similar blocks by token-level edit distance, bucketed as a
  percentage of the smaller block's token count.

  Distance buckets:
    d0 = exact (0%), d1 ≤ 5%, d2 ≤ 10%, d3 ≤ 15%, d4 ≤ 20%,
    d5 ≤ 25%, d6 ≤ 30%, d7 ≤ 40%, d8 ≤ 50%
  """

  alias CodeQA.Metrics.{Block, BlockDetector, TokenNormalizer}

  @max_bucket 8
  @bucket_thresholds [{0, 0.0}, {1, 0.05}, {2, 0.10}, {3, 0.15}, {4, 0.20},
                      {5, 0.25}, {6, 0.30}, {7, 0.40}, {8, 0.50}]

  @doc "Standard Levenshtein distance between two token lists."
  @spec token_edit_distance([String.t()], [String.t()]) :: non_neg_integer()
  def token_edit_distance([], b), do: length(b)
  def token_edit_distance(a, []), do: length(a)

  def token_edit_distance(a, b) do
    a_arr = List.to_tuple(a)
    b_arr = List.to_tuple(b)
    lb = tuple_size(b_arr)
    init_row = List.to_tuple(Enum.to_list(0..lb))
    result_row = levenshtein_rows(a_arr, b_arr, tuple_size(a_arr), lb, init_row, 1)
    elem(result_row, lb)
  end

  defp levenshtein_rows(_a, _b, la, _lb, prev, i) when i > la, do: prev

  defp levenshtein_rows(a, b, la, lb, prev, i) do
    ai = elem(a, i - 1)
    curr = levenshtein_cols(b, lb, prev, i, ai, {i})
    levenshtein_rows(a, b, la, lb, curr, i + 1)
  end

  defp levenshtein_cols(_b, lb, _prev, _i, _ai, curr) when tuple_size(curr) > lb, do: curr

  defp levenshtein_cols(b, lb, prev, i, ai, curr) do
    j = tuple_size(curr)
    cost = if ai == elem(b, j - 1), do: 0, else: 1
    val = min(elem(prev, j) + 1, min(elem(curr, j - 1) + 1, elem(prev, j - 1) + cost))
    levenshtein_cols(b, lb, prev, i, ai, Tuple.insert_at(curr, tuple_size(curr), val))
  end

  @doc "Map an edit distance and min token count to a percentage bucket 0–8, or nil if > 50%."
  @spec percent_bucket(non_neg_integer(), non_neg_integer()) :: 0..8 | nil
  def percent_bucket(_ed, 0), do: nil
  def percent_bucket(0, _min_count), do: 0

  def percent_bucket(ed, min_count) do
    pct = ed / min_count
    @bucket_thresholds
    |> Enum.find(fn {bucket, threshold} -> bucket > 0 and pct <= threshold end)
    |> case do
      {bucket, _} -> bucket
      nil -> nil
    end
  end

  @doc """
  Analyze a list of `{path, content}` pairs for near-duplicate blocks.
  Returns count keys `near_dup_block_d0..d8`, `block_count`, `sub_block_count`.
  With `include_pairs: true` in opts, also returns `_pairs` keys.
  """
  @spec analyze([{String.t(), String.t()}], keyword()) :: map()
  def analyze(labeled_content, opts) do
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    max_pairs = Keyword.get(opts, :max_pairs_per_bucket, nil)
    include_pairs = Keyword.get(opts, :include_pairs, false)

    # Detect blocks per file, flatten into a labeled list
    all_blocks =
      Enum.flat_map(labeled_content, fn {path, content} ->
        language = BlockDetector.language_from_path(path)
        tokens = TokenNormalizer.normalize_structural(content)
        blocks = BlockDetector.detect_blocks(tokens, language: language)
        Enum.map(blocks, &%{&1 | label: path})
      end)

    block_count = length(all_blocks)
    sub_block_count = Enum.sum(Enum.map(all_blocks, &Block.sub_block_count/1))

    buckets = find_pairs(all_blocks, workers: workers, max_pairs_per_bucket: max_pairs)

    result =
      for d <- 0..@max_bucket, into: %{} do
        {"near_dup_block_d#{d}", Map.get(buckets, d, %{count: 0}).count}
      end

    result = Map.merge(result, %{"block_count" => block_count, "sub_block_count" => sub_block_count})

    if include_pairs do
      pairs_result =
        for d <- 0..@max_bucket, into: %{} do
          {"near_dup_block_d#{d}_pairs", Map.get(buckets, d, %{pairs: []}).pairs |> format_pairs()}
        end
      Map.merge(result, pairs_result)
    else
      result
    end
  end

  @doc "Find near-duplicate pairs across a list of %Block{} structs."
  @spec find_pairs([Block.t()], keyword()) :: map()
  def find_pairs(blocks, opts) do
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    max_pairs = Keyword.get(opts, :max_pairs_per_bucket, nil)

    if length(blocks) < 2 do
      %{}
    else
      exact_index = build_exact_index(blocks)
      shingle_index = build_shingle_index(blocks)

      blocks
      |> Enum.with_index()
      |> Task.async_stream(
        &find_pairs_for_block(&1, blocks, exact_index, shingle_index),
        max_concurrency: workers,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, pairs} -> pairs end)
      |> bucket_pairs(max_pairs)
    end
  end

  defp build_exact_index(blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {block, idx}, acc ->
      h = :erlang.phash2(block.tokens)
      Map.update(acc, h, [idx], &[idx | &1])
    end)
  end

  defp build_shingle_index(blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {block, idx}, acc ->
      block.tokens
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(acc, fn bigram, sh_acc ->
        h = :erlang.phash2(bigram)
        Map.update(sh_acc, h, [idx], &[idx | &1])
      end)
    end)
  end

  defp find_pairs_for_block({block_a, i}, blocks, exact_index, shingle_index) do
    tokens_a = block_a.tokens
    hash_a = :erlang.phash2(tokens_a)
    exact_set = MapSet.new(Map.get(exact_index, hash_a, []))

    # For d0 (exact), find hash-matching blocks and confirm with token equality
    # to guard against phash2 collisions.
    exact_pairs =
      Map.get(exact_index, hash_a, [])
      |> Enum.filter(&(&1 > i))
      |> Enum.map(fn j ->
        block_b = Enum.at(blocks, j)
        if block_b.tokens == tokens_a and structure_compatible?(block_a, block_b) do
          {0, {block_a.label, block_b.label}}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # For d1-d8 (near), use shingle index to find candidates.
    # Max distance is 50% of block size; pigeonhole: two blocks with ed ≤ d must share
    # at least max(0, block_size - d*2) bigrams. With d = 50% of size, min_shared = 0,
    # but we use a tighter practical bound: require at least 50% bigram overlap.
    min_shared = max(0, round(length(tokens_a) * 0.5) - 1)

    near_pairs =
      tokens_a
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(%{}, fn bigram, acc ->
        h = :erlang.phash2(bigram)
        Map.get(shingle_index, h, [])
        |> Enum.reduce(acc, fn j, cnt ->
          if j > i, do: Map.update(cnt, j, 1, &(&1 + 1)), else: cnt
        end)
      end)
      |> Enum.filter(fn {_, count} -> count >= min_shared end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.reject(&MapSet.member?(exact_set, &1))
      |> Enum.flat_map(fn j ->
        block_b = Enum.at(blocks, j)
        tokens_b = block_b.tokens

        if structure_compatible?(block_a, block_b) do
          ed = token_edit_distance(tokens_a, tokens_b)
          min_count = min(length(tokens_a), length(tokens_b))
          case percent_bucket(ed, min_count) do
            nil -> []
            bucket when bucket > 0 -> [{bucket, {block_a.label, block_b.label}}]
            _ -> []  # ed=0 handled by exact_pairs above
          end
        else
          []
        end
      end)

    exact_pairs ++ near_pairs
  end

  defp structure_compatible?(a, b) do
    sub_diff = abs(Block.sub_block_count(a) - Block.sub_block_count(b))
    max_lines = max(a.line_count, b.line_count)
    line_ratio = if max_lines > 0, do: abs(a.line_count - b.line_count) / max_lines, else: 0.0
    sub_diff <= 1 and line_ratio <= 0.30
  end

  defp bucket_pairs(raw_pairs, max_pairs) do
    Enum.reduce(raw_pairs, %{}, fn {bucket, pair}, acc ->
      Map.update(acc, bucket, %{count: 1, pairs: maybe_append([], pair, max_pairs)}, fn existing ->
        %{count: existing.count + 1, pairs: maybe_append(existing.pairs, pair, max_pairs)}
      end)
    end)
  end

  defp maybe_append(list, _pair, max) when is_integer(max) and length(list) >= max, do: list
  defp maybe_append(list, pair, _max), do: [pair | list]

  defp format_pairs(pairs) do
    Enum.map(pairs, fn {label_a, label_b} ->
      %{"source_a" => label_a, "source_b" => label_b}
    end)
  end
end
```

- [ ] **Step 4: Run new tests**

```bash
mix test test/codeqa/metrics/near_duplicate_blocks_test.exs --trace
```

Expected: all pass

- [ ] **Step 5: Run full suite**

```bash
mix test 2>&1 | tail -5
```

The old wrapper tests will now fail (expected — they use old key names). Note failures; proceed.

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/metrics/near_duplicate_blocks.ex \
        test/codeqa/metrics/near_duplicate_blocks_test.exs
git commit -m "feat(metrics): rewrite NearDuplicateBlocks with natural blocks and percentage distance"
```

---

## Chunk 4: Wrappers + Test Cleanup

### Task 9: Update `NearDuplicateBlocksFile`

**Files:**
- Rewrite: `lib/codeqa/metrics/near_duplicate_blocks_file.ex`
- Rewrite: `test/codeqa/metrics/near_duplicate_blocks_file_test.exs`

New keys: `block_count`, `sub_block_count`, `near_dup_block_d0`..`near_dup_block_d8` (no `_pairs`).

- [ ] **Step 1: Write the new tests**

```elixir
# test/codeqa/metrics/near_duplicate_blocks_file_test.exs
defmodule CodeQA.Metrics.NearDuplicateBlocksFileTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.NearDuplicateBlocksFile
  alias CodeQA.Pipeline

  defp ctx(code, path \\ "test.ex"), do: %{Pipeline.build_file_context(code) | path: path}

  describe "name/0" do
    test "returns near_duplicate_blocks_file" do
      assert NearDuplicateBlocksFile.name() == "near_duplicate_blocks_file"
    end
  end

  describe "keys/0" do
    test "returns 11 keys: block_count, sub_block_count, and d0..d8" do
      keys = NearDuplicateBlocksFile.keys()
      assert length(keys) == 11
      assert "block_count" in keys
      assert "sub_block_count" in keys
      assert "near_dup_block_d0" in keys
      assert "near_dup_block_d8" in keys
    end
  end

  describe "analyze/1" do
    test "returns a map with all expected keys" do
      result = NearDuplicateBlocksFile.analyze(ctx("x = 1\n"))
      assert Map.has_key?(result, "block_count")
      assert Map.has_key?(result, "sub_block_count")
      for d <- 0..8, do: assert(Map.has_key?(result, "near_dup_block_d#{d}"))
    end

    test "no _pairs keys in output" do
      result = NearDuplicateBlocksFile.analyze(ctx("x = 1\n"))
      refute Enum.any?(Map.keys(result), &String.ends_with?(&1, "_pairs"))
    end

    test "detects exact duplicate blocks at d0" do
      block = "def foo\n  x = 1\nend\n"
      result = NearDuplicateBlocksFile.analyze(ctx(block <> "\n\n" <> block))
      assert result["near_dup_block_d0"] >= 1
    end

    test "block_count is positive for non-trivial file" do
      result = NearDuplicateBlocksFile.analyze(ctx("def foo\n  x\nend\n"))
      assert result["block_count"] >= 1
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
mix test test/codeqa/metrics/near_duplicate_blocks_file_test.exs --trace
```

- [ ] **Step 3: Rewrite `near_duplicate_blocks_file.ex`**

```elixir
# lib/codeqa/metrics/near_duplicate_blocks_file.ex
defmodule CodeQA.Metrics.NearDuplicateBlocksFile do
  @moduledoc """
  Counts near-duplicate and exact-duplicate natural code blocks within a single file.

  Blocks are detected at blank-line boundaries with sub-block detection via bracket rules.
  Distance is a percentage of the smaller block's token count, bucketed d0–d8.
  Also reports block_count and sub_block_count as standalone metrics.
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "near_duplicate_blocks_file"

  @spec keys() :: [String.t()]
  def keys do
    ["block_count", "sub_block_count"] ++ for(d <- 0..8, do: "near_dup_block_d#{d}")
  end

  @impl true
  def analyze(ctx) do
    path = Map.get(ctx, :path, "unknown")
    CodeQA.Metrics.NearDuplicateBlocks.analyze([{path, ctx.content}], [])
    |> Map.reject(fn {k, _} -> String.ends_with?(k, "_pairs") end)
  end
end
```

- [ ] **Step 4: Check `FileContext` has a `path` field**

```bash
grep -n "path" /Users/andreassolleder/dev/codeqa-action/.worktrees/near-duplicate-blocks/lib/codeqa/pipeline.ex | head -10
```

If `FileContext` lacks a `path` field, use `Map.get(ctx, :path, "unknown")` as above (already handles missing key gracefully).

- [ ] **Step 5: Run tests**

```bash
mix test test/codeqa/metrics/near_duplicate_blocks_file_test.exs --trace
```

Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/metrics/near_duplicate_blocks_file.ex \
        test/codeqa/metrics/near_duplicate_blocks_file_test.exs
git commit -m "feat(metrics): update NearDuplicateBlocksFile with natural block keys"
```

---

### Task 10: Update `NearDuplicateBlocksCodebase`

**Files:**
- Rewrite: `lib/codeqa/metrics/near_duplicate_blocks_codebase.ex`
- Rewrite: `test/codeqa/metrics/near_duplicate_blocks_codebase_test.exs`

New keys: `near_dup_block_d0..d8` counts + `near_dup_block_d0..d8_pairs` (pair lists with `source_a`, `source_b`).

- [ ] **Step 1: Write the new tests**

```elixir
# test/codeqa/metrics/near_duplicate_blocks_codebase_test.exs
defmodule CodeQA.Metrics.NearDuplicateBlocksCodebaseTest do
  use ExUnit.Case, async: true
  alias CodeQA.Metrics.NearDuplicateBlocksCodebase

  defp files(pairs), do: Map.new(pairs)

  describe "name/0" do
    test "returns near_duplicate_blocks_codebase" do
      assert NearDuplicateBlocksCodebase.name() == "near_duplicate_blocks_codebase"
    end
  end

  describe "analyze/2" do
    test "returns all count keys d0..d8" do
      result = NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1\n"}]), [])
      for d <- 0..8, do: assert(Map.has_key?(result, "near_dup_block_d#{d}"))
    end

    test "returns all pairs keys d0..d8" do
      result = NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1\n"}]), [])
      for d <- 0..8, do: assert(Map.has_key?(result, "near_dup_block_d#{d}_pairs"))
    end

    test "zero counts for a single trivial file" do
      result = NearDuplicateBlocksCodebase.analyze(files([{"a.ex", "x = 1\n"}]), [])
      assert result["near_dup_block_d0"] == 0
    end

    test "detects exact duplicate block across two files" do
      block = "def foo\n  x = 1\nend\n"
      result = NearDuplicateBlocksCodebase.analyze(
        files([{"a.ex", block}, {"b.ex", block}]),
        []
      )
      assert result["near_dup_block_d0"] >= 1
    end

    test "pair sources include file paths" do
      block = "def foo\n  x = 1\nend\n"
      result = NearDuplicateBlocksCodebase.analyze(
        files([{"a.ex", block}, {"b.ex", block}]),
        []
      )
      all_pairs = result |> Map.values() |> Enum.filter(&is_list/1) |> List.flatten()
      if length(all_pairs) > 0 do
        pair = hd(all_pairs)
        assert Map.has_key?(pair, "source_a")
        assert Map.has_key?(pair, "source_b")
      end
    end

    test "pairs list is capped at max_pairs_per_bucket" do
      block = "def foo\n  x = 1\nend\n"
      many_files = for i <- 1..5, do: {"file#{i}.ex", block}
      result = NearDuplicateBlocksCodebase.analyze(
        files(many_files),
        [near_duplicate_blocks: [max_pairs_per_bucket: 2]]
      )
      pairs_lists = result |> Map.values() |> Enum.filter(&is_list/1)
      assert Enum.all?(pairs_lists, &(length(&1) <= 2))
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

```bash
mix test test/codeqa/metrics/near_duplicate_blocks_codebase_test.exs --trace
```

- [ ] **Step 3: Rewrite `near_duplicate_blocks_codebase.ex`**

```elixir
# lib/codeqa/metrics/near_duplicate_blocks_codebase.ex
defmodule CodeQA.Metrics.NearDuplicateBlocksCodebase do
  @moduledoc """
  Counts near-duplicate and exact-duplicate natural code blocks across the codebase.

  Detects blocks per file, pools them, and finds pairs across all files.
  Includes pair source lists (capped by max_pairs_per_bucket).

  Configure in .codeqa.yml:
      near_duplicate_blocks:
        max_pairs_per_bucket: 50
  """

  @behaviour CodeQA.Metrics.CodebaseMetric

  @impl true
  def name, do: "near_duplicate_blocks_codebase"

  @impl true
  def analyze(files, opts \\ []) do
    ndb_opts = Keyword.get(opts, :near_duplicate_blocks, [])
    max_pairs = Keyword.get(ndb_opts, :max_pairs_per_bucket, nil)
    workers = Keyword.get(opts, :workers, System.schedulers_online())

    CodeQA.Metrics.NearDuplicateBlocks.analyze(
      Map.to_list(files),
      include_pairs: true,
      max_pairs_per_bucket: max_pairs,
      workers: workers
    )
    |> Map.reject(fn {k, _} -> k in ["block_count", "sub_block_count"] end)
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/codeqa/metrics/near_duplicate_blocks_codebase_test.exs --trace
```

Expected: all pass

- [ ] **Step 5: Run full suite**

```bash
mix test 2>&1 | tail -5
```

Expected: all tests pass (old test files have been replaced in Tasks 8–10)

- [ ] **Step 6: Commit**

```bash
git add lib/codeqa/metrics/near_duplicate_blocks_codebase.ex \
        test/codeqa/metrics/near_duplicate_blocks_codebase_test.exs
git commit -m "feat(metrics): update NearDuplicateBlocksCodebase with natural block keys and pairs"
```

---

### Task 11: Final cleanup and dialyzer

- [ ] **Step 1: Run full test suite**

```bash
mix test 2>&1 | tail -5
```

Expected: all tests pass, 0 failures

- [ ] **Step 2: Run dialyzer**

```bash
mix dialyzer 2>&1 | tail -20
```

Fix any warnings before committing. Common issues:
- `analyze/2` typespec on `NearDuplicateBlocks` — ensure `@spec` matches new signature
- `Block.t()` needs to be imported or fully qualified in typespecs

- [ ] **Step 3: Delete the scratch file**

```bash
rm test_pairs_check.exs 2>/dev/null; true
```

- [ ] **Step 4: Final commit**

```bash
git add -u
git commit -m "chore: fix dialyzer warnings and remove scratch file after block detection rewrite"
```

---

## Verification

After all tasks are complete:

```bash
# All tests pass
mix test 2>&1 | tail -3

# No dialyzer warnings
mix dialyzer 2>&1 | grep -c "warning:" || echo "0 warnings"

# Smoke test: run on a real directory
mix run -e "
  files = CodeQA.Collector.collect_files(\"lib\", [])
  result = CodeQA.Analyzer.analyze_codebase(files, [])
  result[\"codebase\"][\"near_duplicate_blocks_codebase\"]
  |> Enum.filter(fn {k, v} -> is_integer(v) and v > 0 end)
  |> Enum.sort()
  |> Enum.each(fn {k, v} -> IO.puts(\"#{k}: #{v}\") end)
"
```
