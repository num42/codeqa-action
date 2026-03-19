defmodule CodeQA.AST.Lexing.TokenNormalizer do
  @moduledoc """
  Abstracts raw source code into language-agnostic structural tokens.

  See [lexical analysis](https://en.wikipedia.org/wiki/Lexical_analysis).
  """

  alias CodeQA.AST.Lexing.Token
  alias CodeQA.AST.Lexing.StringToken
  alias CodeQA.AST.Lexing.NewlineToken
  alias CodeQA.AST.Lexing.WhitespaceToken

  @doc """
  Normalizes source code into language-agnostic structural tokens, preserving
  newlines as `<NL>` and leading whitespace as `<WS>` tokens (one per
  2-space / 1-tab indentation unit).

  Returns `[Token.t()]` where each token carries its normalized `value`,
  original source `content`, 1-based `line` number, and 0-based `col` offset.
  Used for structural block detection.
  """
  @spec normalize_structural(String.t()) :: [Token.t()]
  def normalize_structural(code) do
    code = String.replace(code, ~r/[^\x00-\x7F]/, " ")
    lines = String.split(code, "\n")
    last_idx = length(lines) - 1

    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, idx} ->
      line_num = idx + 1
      {tokens, last_token} = tokenize_line(line, line_num)

      if idx < last_idx do
        # last_token is tracked during scanning — O(1) vs List.last/1 which is O(N).
        nl_col =
          case last_token do
            nil -> 0
            t -> t.col + String.length(t.content)
          end

        tokens ++ [%NewlineToken{content: "\n", line: line_num, col: nl_col}]
      else
        tokens
      end
    end)
  end

  # Returns {tokens, last_token} where last_token is the final token on the line
  # (or nil for an empty line), allowing normalize_structural to compute nl_col
  # in O(1) without calling List.last/1.
  defp tokenize_line(line, line_num) do
    indent_chars =
      line
      |> String.graphemes()
      |> Enum.take_while(&(&1 in [" ", "\t"]))

    indent_units =
      indent_chars
      |> Enum.reduce(0, fn
        "\t", acc -> acc + 2
        " ", acc -> acc + 1
      end)
      |> div(2)

    indent_col_width = length(indent_chars)

    ws_tokens =
      for i <- 1..indent_units//1 do
        %WhitespaceToken{content: "  ", line: line_num, col: (i - 1) * 2}
      end

    content = String.slice(line, indent_col_width..-1//1)
    {content_tokens, last_content} = scan_content(content, line_num, indent_col_width)

    # Last token on the line: prefer the last content token; fall back to the
    # last WS token (only possible when the content portion is empty).
    last_token = last_content || List.last(ws_tokens)

    {ws_tokens ++ content_tokens, last_token}
  end

  # Multi-char operators matched longest-first so that e.g. `===` beats `==`.
  # Tagged `:literal` so `next_token` uses the matched text as both value and content
  # (unlike `<ID>`, `<STR>`, `<NUM>` which normalise content away).
  @operator_regex ~r/^(?:===|!==|<=>|==|!=|<=|>=|\|>|<>|<-|->|=>|=~|!~|&&|\|\||\?\?|\?\.|:=|::|\.\.\.|\.\.|--|\+\+|\*\*|\/\/|\+=|-=|\*=|\/=|%=)/

  # --- Individual rule atoms so dispatch groups can reference them directly ---
  @skip_rule {:skip, ~r/^\s+/}
  @operator_rule {:literal, @operator_regex}
  @trip_quotes_rule {"<TRIP_QUOTES>", ~r/^"""|^'''/}
  @str_interp_rule {"<STR_INTERP>", ~r/^"(?=[^"]*#\{)(?:[^"\\#]|\\.|#(?!\{)|#\{[^}]*\})*"/}
  @str_dollar_interp_rule {"<STR_DOLLAR_INTERP>",
                           ~r/^"(?=[^"]*\$\{)(?:[^"\\$]|\\.|\\$(?!\{)|\$\{[^}]*\})*"/}
  @str_swift_interp_rule {"<STR_SWIFT_INTERP>", ~r/^"(?=[^"]*\\\()(?:[^"\\]|\\.)*"/}
  @str_rule {"<STR>", ~r/^"(?:[^"\\]|\\.)*"|^'(?:[^'\\]|\\.)*'/}
  @backtick_interp_rule {"<BACKTICK_INTERP>",
                         ~r/^`(?=[^`]*\$\{)(?:[^`\\$]|\\.|\\$(?!\{)|\$\{[^}]*\})*`/}
  @backtick_str_rule {"<BACKTICK_STR>", ~r/^`(?:[^`\\]|\\.)*`/}
  @num_rule {"<NUM>", ~r/^\d+(?:\.\d+)?/}
  @id_rule {"<ID>", ~r/^[a-zA-Z_]\w*/}

  # Dispatch rule subsets by first character so the common cases (identifiers,
  # numbers, whitespace, operators) skip irrelevant regex attempts entirely.
  @double_quote_rules [
    @trip_quotes_rule,
    @str_interp_rule,
    @str_dollar_interp_rule,
    @str_swift_interp_rule,
    @str_rule
  ]
  @single_quote_rules [@trip_quotes_rule, @str_rule]
  @backtick_rules [@backtick_interp_rule, @backtick_str_rule]

  # Returns the rule subset for the given first byte (ASCII codepoint).
  defp dispatch_rules(?"), do: @double_quote_rules
  defp dispatch_rules(?'), do: @single_quote_rules
  defp dispatch_rules(?`), do: @backtick_rules
  defp dispatch_rules(c) when c >= ?0 and c <= ?9, do: [@num_rule]

  defp dispatch_rules(c)
       when (c >= ?a and c <= ?z) or (c >= ?A and c <= ?Z) or c == ?_,
       do: [@id_rule]

  defp dispatch_rules(c)
       when c in [?=, ?!, ?<, ?>, ?|, ?&, ??, ?:, ?., ?-, ?+, ?*, ?/, ?%],
       do: [@operator_rule]

  defp dispatch_rules(c) when c <= 32, do: [@skip_rule]

  # Unknown first char — no rule applies; caller falls through to single-char token.
  defp dispatch_rules(_), do: []

  # Returns {tokens, last_token_or_nil} — last_token is tracked during scanning
  # so callers get O(1) access to the final token without List.last/1.
  defp scan_content(text, line_num, col_offset) do
    {reversed, last} = do_scan(text, line_num, col_offset, [], nil)
    {Enum.reverse(reversed), last}
  end

  defp do_scan("", _line, _col, acc, last), do: {acc, last}

  defp do_scan(<<first, _::binary>> = text, line, col, acc, last) do
    case next_token(first, text, line, col) do
      {:skip, rest, advance} -> do_scan(rest, line, col + advance, acc, last)
      {token, rest, advance} -> do_scan(rest, line, col + advance, [token | acc], token)
    end
  end

  # next_token/4: dispatches on the first byte to select only candidate rules,
  # avoiding regex attempts for rules whose first-char pattern can't possibly match.
  defp next_token(first, text, line, col) do
    rules = dispatch_rules(first)

    result =
      Enum.find_value(rules, fn {type, regex} ->
        case Regex.run(regex, text) do
          [m | _] -> {type, m}
          nil -> nil
        end
      end)

    case result do
      {:skip, m} ->
        len = String.length(m)
        {:skip, String.slice(text, len..-1//1), len}

      {:literal, m} ->
        len = String.length(m)
        {%Token{kind: m, content: m, line: line, col: col}, String.slice(text, len..-1//1), len}

      {value, m} ->
        len = String.length(m)
        token = postprocess(value, %Token{kind: value, content: m, line: line, col: col})
        {token, String.slice(text, len..-1//1), len}

      nil ->
        # No rule matched — emit the first character as a literal single-char token.
        char = String.first(text)
        {%Token{kind: char, content: char, line: line, col: col}, String.slice(text, 1..-1//1), 1}
    end
  end

  # Extract #{...} interpolation expressions into `interpolations` and strip
  # them from `content` so downstream consumers see only the static string parts.
  # Nested braces (e.g. #{foo(%{a: 1})}) are left as-is in content — the
  # lookahead in the scan rule ensures a match only when simple interpolations
  # are present.
  defp postprocess("<STR_INTERP>", token),
    do: extract_interpolations(token, ~r/#\{([^}]*)\}/, ~r/#\{[^}]*\}/, quotes: :double)

  defp postprocess("<STR_DOLLAR_INTERP>", token),
    do: extract_interpolations(token, ~r/\$\{([^}]*)\}/, ~r/\$\{[^}]*\}/, quotes: :double)

  defp postprocess("<STR_SWIFT_INTERP>", token),
    do: extract_interpolations(token, ~r/\\\(([^)]*)\)/, ~r/\\\([^)]*\)/, quotes: :double)

  defp postprocess("<BACKTICK_INTERP>", token),
    do: extract_interpolations(token, ~r/\$\{([^}]*)\}/, ~r/\$\{[^}]*\}/, quotes: :backtick)

  defp postprocess("<TRIP_QUOTES>", %Token{content: ~s(""")} = token),
    do: %StringToken{
      kind: StringToken.doc_kind(),
      content: token.content,
      line: token.line,
      col: token.col,
      multiline: true,
      quotes: :double
    }

  defp postprocess("<TRIP_QUOTES>", token),
    do: %StringToken{
      kind: StringToken.doc_kind(),
      content: token.content,
      line: token.line,
      col: token.col,
      multiline: true,
      quotes: :single
    }

  defp postprocess("<BACKTICK_STR>", token),
    do: %StringToken{
      kind: StringToken.kind(),
      content: token.content,
      line: token.line,
      col: token.col,
      quotes: :backtick
    }

  defp postprocess("<STR>", token) do
    quotes = if String.starts_with?(token.content, "\""), do: :double, else: :single

    %StringToken{
      kind: StringToken.kind(),
      content: token.content,
      line: token.line,
      col: token.col,
      quotes: quotes
    }
  end

  defp postprocess(_value, token), do: token

  defp extract_interpolations(token, capture_regex, strip_regex, opts) do
    quotes = Keyword.get(opts, :quotes, :double)

    interpolations =
      Regex.scan(capture_regex, token.content, capture: :all_but_first)
      |> Enum.map(fn [expr] -> String.trim(expr) end)

    %StringToken{
      content: String.replace(token.content, strip_regex, ""),
      line: token.line,
      col: token.col,
      interpolations: interpolations,
      quotes: quotes
    }
  end
end
