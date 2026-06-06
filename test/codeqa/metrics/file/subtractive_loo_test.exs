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
  15/15 blocks in `mega_service.ex`. A metric that cannot satisfy this invariant
  must NOT implement `analyze_loo/2`; the full re-analyze fallback is correct.

  The harness fixtures are chosen because `reconstruct_without` collapses
  whitespace there (the normalized join differs from the source), which is the
  exact condition that exposes a bad subtractive metric. `guards the invariant`
  asserts the fixtures actually exercise that condition, so this test can never
  silently become a no-op the way an over-clean fixture would.
  """
  use ExUnit.Case, async: true

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.BlockImpact.FileImpact
  alias CodeQA.Engine.Analyzer
  alias CodeQA.Engine.Pipeline
  alias CodeQA.Languages.Unknown

  # Real sample files with deep nesting, so reconstruct_without yields many
  # non-trivial strict-subset reconstructions that collapse whitespace.
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

  test "fixtures actually collapse whitespace on reconstruction (guard is not vacuous)" do
    for path <- @fixtures do
      content = File.read!(path)

      normalized =
        content |> TokenNormalizer.normalize_structural() |> Enum.map_join("", & &1.content)

      assert normalized != content,
             "#{path} reconstructs byte-identically — it would not expose a bad subtractive metric"

      assert subset_blocks(content) != [], "#{path} yields no strict-subset blocks"
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
      root = TokenNormalizer.normalize_structural(content)
      base_ctx = Pipeline.build_file_context(content, skip_structural: true)
      baseline_metrics = Map.new(loo_metrics, fn mod -> {mod.name(), mod.analyze(base_ctx)} end)

      for node <- subset_blocks(content), mod <- loo_metrics do
        block_content = node.tokens |> Enum.map_join("", & &1.content)
        reconstructed = FileImpact.reconstruct_without(root, node)

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
