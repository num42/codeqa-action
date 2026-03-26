defmodule CodeQA.Languages.Code.Native.Haskell do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "haskell"

  @impl true
  def extensions, do: ~w[hs lhs]

  @impl true
  def comment_prefixes, do: ~w[--]

  @impl true
  def block_comments, do: [{"{-", "-}"}]

  @impl true
  def keywords, do: ~w[
    if else then for do let in where module import data type newtype class
    instance deriving case of return True False Nothing Just do
    infixl infixr infix qualified as hiding
  ]

  @impl true
  def operators, do: ~w[
    == /= <= >= + - * / ^ && || ! $ . <$> <*> >>= >> -> <- :: = | @ ~
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; | @ -> <- ::
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[data type newtype class instance]

  @impl true
  def branch_keywords, do: ~w[else]

  @impl true
  def block_end_tokens, do: []

  @impl true
  def function_keywords, do: ~w[where let]

  @impl true
  def module_keywords, do: ~w[module class instance]

  @impl true
  def import_keywords, do: ~w[import]

  @impl true
  def test_keywords, do: ~w[test it describe prop]

  @impl true
  def uses_colon_indent?, do: true
end
