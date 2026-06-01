defmodule CodeQA.Engine.Pipeline do
  @moduledoc "Pre-computed shared context for file-level metrics."

  defmodule Token do
    @moduledoc "A lexical token with its string content, kind tag, and 1-based source line."
    defstruct [:content, :kind, :line]

    @type t :: %__MODULE__{
            content: String.t(),
            kind: String.t(),
            line: pos_integer()
          }
  end

  alias CodeQA.AST.Lexing.TokenNormalizer
  alias CodeQA.AST.Parsing.Parser
  alias CodeQA.Engine.FileContext
  alias CodeQA.Language

  @word_re ~r/\b[a-zA-Z_]\w*\b/u

  @spec build_file_context(String.t(), keyword()) :: FileContext.t()
  def build_file_context(content, opts \\ []) when is_binary(content) do
    tokens = tokenize(content)
    token_counts = tokens |> Enum.map(& &1.content) |> Enum.frequencies()

    keywords = cached_keywords()

    words =
      Regex.scan(@word_re, content)
      |> List.flatten()

    identifiers = words |> Enum.reject(&MapSet.member?(keywords, &1))
    lines = content |> String.split("\n") |> trim_trailing_empty()
    encoded = content

    skip_structural = Keyword.get(opts, :skip_structural, false)

    {path, blocks} =
      case Keyword.get(opts, :path) do
        nil ->
          {nil, nil}

        p when skip_structural ->
          {p, nil}

        p ->
          lang_mod = Language.detect(p)
          structural_tokens = TokenNormalizer.normalize_structural(content)
          {p, Parser.detect_blocks(structural_tokens, lang_mod)}
      end

    %FileContext{
      blocks: blocks,
      byte_count: byte_size(content),
      content: content,
      encoded: encoded,
      identifiers: identifiers,
      line_count: length(lines),
      lines: lines,
      path: path,
      token_counts: token_counts,
      tokens: tokens,
      words: words
    }
  end

  # Matches identifiers, integer/float literals, and single non-whitespace chars.
  @token_re ~r/[a-zA-Z_]\w*|[0-9]+(?:\.[0-9]+)?|[^\s]/u

  defp tokenize(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      @token_re
      |> Regex.scan(line)
      |> List.flatten()
      |> Enum.map(&%Token{content: &1, kind: classify(&1), line: line_num})
    end)
  end

  defp classify(tok) do
    cond do
      Regex.match?(~r/^[a-zA-Z_]\w*$/, tok) -> "<ID>"
      Regex.match?(~r/^[0-9]/, tok) -> "<NUM>"
      true -> "<PUNCT>"
    end
  end

  # Caches the all-languages keyword MapSet across calls. Without the cache,
  # MapSet.new(Language.all_keywords()) ran ~150ms per call (driven by the
  # :application.get_key reflection in Language.all/0) — multiplied by every
  # block-impact LOO call, this dominated the analyzer hot path.
  defp cached_keywords do
    case :persistent_term.get({__MODULE__, :keywords}, nil) do
      nil ->
        set = MapSet.new(Language.all_keywords())
        :persistent_term.put({__MODULE__, :keywords}, set)
        set

      set ->
        set
    end
  end

  defp trim_trailing_empty(lines) do
    # Match Python's str.splitlines() behavior
    case List.last(lines) do
      "" -> List.delete_at(lines, -1)
      _ -> lines
    end
  end
end
