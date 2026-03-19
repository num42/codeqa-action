defprotocol CodeQA.AST.Lexing.TokenProtocol do
  @moduledoc """
  Protocol for token structs emitted by `TokenNormalizer`.

  Both `Token` and `StringToken` implement this protocol, so code that
  processes token streams does not need to branch on the concrete struct type.

  ## Functions

  - `kind/1`    — normalized structural kind (`<ID>`, `<STR>`, `<NL>`, …)
  - `content/1` — original source text before normalization
  - `line/1`    — 1-based line number in the source file (`nil` for synthetic tokens)
  - `col/1`     — 0-based byte offset from the start of the line (`nil` for synthetic tokens)
  """

  @doc "Returns the normalized structural kind of the token."
  @spec kind(t) :: String.t()
  def kind(token)

  @doc "Returns the original source text of the token."
  @spec content(t) :: String.t()
  def content(token)

  @doc "Returns the 1-based line number of the token, or `nil` for synthetic tokens."
  @spec line(t) :: non_neg_integer() | nil
  def line(token)

  @doc "Returns the 0-based column offset of the token, or `nil` for synthetic tokens."
  @spec col(t) :: non_neg_integer() | nil
  def col(token)
end

defimpl CodeQA.AST.Lexing.TokenProtocol, for: CodeQA.AST.Lexing.Token do
  def kind(%CodeQA.AST.Lexing.Token{kind: k}), do: k
  def content(%CodeQA.AST.Lexing.Token{content: c}), do: c
  def line(%CodeQA.AST.Lexing.Token{line: l}), do: l
  def col(%CodeQA.AST.Lexing.Token{col: c}), do: c
end

defimpl CodeQA.AST.Lexing.TokenProtocol, for: CodeQA.AST.Lexing.StringToken do
  def kind(%CodeQA.AST.Lexing.StringToken{kind: k}), do: k
  def content(%CodeQA.AST.Lexing.StringToken{content: c}), do: c
  def line(%CodeQA.AST.Lexing.StringToken{line: l}), do: l
  def col(%CodeQA.AST.Lexing.StringToken{col: c}), do: c
end

defimpl CodeQA.AST.Lexing.TokenProtocol, for: CodeQA.AST.Lexing.NewlineToken do
  def kind(%CodeQA.AST.Lexing.NewlineToken{kind: k}), do: k
  def content(%CodeQA.AST.Lexing.NewlineToken{content: c}), do: c
  def line(%CodeQA.AST.Lexing.NewlineToken{line: l}), do: l
  def col(%CodeQA.AST.Lexing.NewlineToken{col: c}), do: c
end

defimpl CodeQA.AST.Lexing.TokenProtocol, for: CodeQA.AST.Lexing.WhitespaceToken do
  def kind(%CodeQA.AST.Lexing.WhitespaceToken{kind: k}), do: k
  def content(%CodeQA.AST.Lexing.WhitespaceToken{content: c}), do: c
  def line(%CodeQA.AST.Lexing.WhitespaceToken{line: l}), do: l
  def col(%CodeQA.AST.Lexing.WhitespaceToken{col: c}), do: c
end
