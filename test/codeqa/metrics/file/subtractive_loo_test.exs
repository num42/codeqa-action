defmodule CodeQA.Metrics.File.SubtractiveLooTest do
  @moduledoc """
  Regression guard for the leave-one-out path in block-impact analysis.

  Any file metric that implements `analyze_loo/2` claims it can derive the
  file-minus-block value subtractively. This asserts that claim holds: for every
  top-level and nested block in real sample files, a metric's LOO value (via
  `Analyzer.analyze_file_for_loo_partial/4`) must equal a full re-analyze of the
  reconstructed file.

  This caught a real bug: `separator_counts` had an `analyze_loo/2` that
  subtracted counts from an original-file baseline using a block string rebuilt
  from normalized structural tokens (inter-token whitespace collapsed) — wrong on
  15/15 blocks in `mega_service.ex`. The fix was `slice_without_original/2`: it
  cuts the block out of the original bytes, so `block_content` is the verbatim
  source span and `reconstructed` is the original file minus that span. A
  subtractive metric (baseline ⊖ block) now matches a full re-analyze; one that
  still cannot must NOT implement `analyze_loo/2` — the re-analyze fallback is
  correct.

  The harness validates against the same original-byte slice the analyzer uses
  (`FileImpact.slice_without_original/2`), and `guards the invariant` asserts the
  fixtures yield real strict-subset blocks so this test can never silently become
  a no-op the way an over-clean fixture would.
  """
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.BlockImpact.FileImpact
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Engine.Pipeline
  alias CodeQA.Languages.Unknown

  # Real sample files with deep nesting, so slice_without_original yields many
  # non-trivial strict-subset reconstructions.
  @fixtures [
    "priv/combined_metrics/samples/file_structure/line_count_under_300/bad/mega_service.ex",
    "priv/combined_metrics/samples/file_structure/single_responsibility/bad/user_handler.ex"
  ]

  defp subset_blocks(content) do
    root = TokenNormalizer.normalize_structural(content)

    root
    |> Parser.detect_blocks(Unknown)
    |> Enum.flat_map(fn node -> [node | node.children] end)
    |> Enum.filter(&(length(&1.tokens) >= 10 and length(&1.tokens) < length(root) - 5))
  end

  test "fixtures yield real strict-subset blocks (guard is not vacuous)" do
    for path <- @fixtures do
      content = File.read!(path)
      blocks = subset_blocks(content)
      assert blocks != [], "#{path} yields no strict-subset blocks"

      # Each block must be a verbatim original span removed from the file — the
      # condition a subtractive metric is validated against.
      for node <- blocks do
        {block, reconstructed} = FileImpact.slice_without_original(content, node)
        assert byte_size(block) > 0
        assert byte_size(block) + byte_size(reconstructed) == byte_size(content)
      end
    end
  end

  test "every analyze_loo metric matches a full re-analyze on file-minus-block" do
    loo_metrics =
      Analyzer.build_registry().file_metrics
      |> Enum.filter(fn mod ->
        Code.ensure_loaded?(mod) and function_exported?(mod, :analyze_loo, 2)
      end)

    for path <- @fixtures do
      content = File.read!(path)
      base_ctx = Pipeline.build_file_context(content, skip_structural: true)
      baseline_metrics = Map.new(loo_metrics, fn mod -> {mod.name(), mod.analyze(base_ctx)} end)

      for node <- subset_blocks(content), mod <- loo_metrics do
        {block_content, reconstructed} = FileImpact.slice_without_original(content, node)

        loo =
          Analyzer.analyze_file_for_loo_partial(
            path,
            reconstructed,
            baseline_metrics,
            block_content
          )

        truth = mod.analyze(Pipeline.build_file_context(reconstructed, skip_structural: true))

        assert loo[mod.name()] == truth,
               "#{mod.name()}.analyze_loo/2 diverges from a full re-analyze on a real block in " <>
                 "#{path} — remove analyze_loo/2 (use the re-analyze fallback) unless it matches exactly"
      end
    end
  end
end
