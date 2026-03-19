defmodule Mix.Tasks.Codeqa.SignalDebug do
  use Mix.Task

  @shortdoc "Shows structural signal emissions when splitting a file into blocks"

  @moduledoc """
  Runs each structural signal over a file and prints its emissions step by step.

      mix codeqa.signal_debug path/to/file.ex
      mix codeqa.signal_debug path/to/file.py --signal keyword
      mix codeqa.signal_debug path/to/file.ex --show-tokens

  Options:
    --signal <name>    Only show a specific signal (e.g. keyword, blank, bracket)
    --show-tokens      Print the full token list before signal output
  """

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.SignalStream
  alias CodeQA.Language

  alias CodeQA.AST.Signals.Structural.{
    AccessModifierSignal,
    BlankLineSignal,
    BracketSignal,
    BranchSplitSignal,
    ColonIndentSignal,
    CommentDividerSignal,
    KeywordSignal,
    SQLBlockSignal,
    TripleQuoteSignal
  }

  @switches [signal: :string, show_tokens: :boolean]

  @all_signals [
    %TripleQuoteSignal{},
    %BlankLineSignal{},
    %KeywordSignal{},
    %BranchSplitSignal{},
    %AccessModifierSignal{},
    %CommentDividerSignal{},
    %SQLBlockSignal{},
    %BracketSignal{},
    %ColonIndentSignal{}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, strict: @switches)

    path =
      case positional do
        [p | _] -> p
        [] -> Mix.raise("Usage: mix codeqa.signal_debug <file> [--signal <name>] [--show-tokens]")
      end

    unless File.exists?(path), do: Mix.raise("File not found: #{path}")

    content = File.read!(path)
    lang_mod = Language.detect(path)
    tokens = TokenNormalizer.normalize_structural(content)
    lines = String.split(content, "\n")

    Mix.shell().info("File: #{path}")
    Mix.shell().info("Language: #{lang_mod.name()}")
    Mix.shell().info("Tokens: #{length(tokens)}")
    Mix.shell().info("Lines: #{length(lines)}")
    Mix.shell().info("")

    if opts[:show_tokens] do
      print_tokens(tokens)
    end

    signals = filter_signals(@all_signals, opts[:signal])

    emissions_per_signal =
      SignalStream.run(tokens, signals, lang_mod)

    Enum.zip(signals, emissions_per_signal)
    |> Enum.each(fn {signal, emissions} ->
      print_signal_section(signal, emissions, tokens, lines)
    end)
  end

  defp filter_signals(signals, nil), do: signals

  defp filter_signals(signals, name_filter) do
    Enum.filter(signals, fn signal ->
      module_name =
        signal.__struct__
        |> Module.split()
        |> List.last()
        |> String.downcase()

      String.contains?(module_name, String.downcase(name_filter))
    end)
  end

  defp print_tokens(tokens) do
    Mix.shell().info("=== TOKEN LIST ===")

    tokens
    |> Enum.with_index()
    |> Enum.each(fn {token, idx} ->
      Mix.shell().info(
        "  [#{idx}] line #{token.line} col #{token.col}  #{inspect(token.kind)}  #{inspect(token.content)}"
      )
    end)

    Mix.shell().info("")
  end

  defp print_signal_section(signal, emissions, tokens, lines) do
    name = signal.__struct__ |> Module.split() |> List.last()
    separator = String.duplicate("─", 60)

    Mix.shell().info(separator)
    Mix.shell().info("SIGNAL: #{name}")
    Mix.shell().info("Emissions: #{length(emissions)}")
    Mix.shell().info("")

    if Enum.empty?(emissions) do
      Mix.shell().info("  (no emissions)")
    else
      Enum.each(emissions, fn {_source, group, emission_name, value} ->
        print_emission(group, emission_name, value, tokens, lines)
      end)
    end

    Mix.shell().info("")
  end

  defp print_emission(:split, name, token_idx, tokens, lines) do
    token = Enum.at(tokens, token_idx)

    line_num = token && token.line
    line_src = line_num && Enum.at(lines, line_num - 1)

    Mix.shell().info("  [SPLIT :#{name}]  token[#{token_idx}] → line #{line_num}")

    if line_src do
      Mix.shell().info("    #{String.trim_trailing(line_src)}")
    end

    if token do
      Mix.shell().info("    ^ #{inspect(token.kind)} #{inspect(token.content)}")
    end

    Mix.shell().info("")
  end

  defp print_emission(:enclosure, name, {start_idx, end_idx}, tokens, lines) do
    start_token = Enum.at(tokens, start_idx)
    end_token = Enum.at(tokens, end_idx)

    start_line = start_token && start_token.line
    end_line = end_token && end_token.line

    Mix.shell().info(
      "  [ENCLOSURE :#{name}]  tokens[#{start_idx}..#{end_idx}]  lines #{start_line}–#{end_line}"
    )

    if start_line do
      Mix.shell().info(
        "    open:  #{inspect(Enum.at(lines, start_line - 1) |> String.trim_trailing())}"
      )
    end

    if end_line && end_line != start_line do
      Mix.shell().info(
        "    close: #{inspect(Enum.at(lines, end_line - 1) |> String.trim_trailing())}"
      )
    end

    Mix.shell().info("")
  end

  defp print_emission(group, name, value, _tokens, _lines) do
    Mix.shell().info("  [:#{group} :#{name}]  #{inspect(value)}")
    Mix.shell().info("")
  end
end
