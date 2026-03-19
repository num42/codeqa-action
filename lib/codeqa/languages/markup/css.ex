defmodule CodeQA.Languages.Markup.Css do
  use CodeQA.Language

  @impl true
  def name, do: "css"

  @impl true
  def extensions, do: ~w[css scss sass less]

  @impl true
  def comment_prefixes, do: []

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    media keyframes import charset supports layer font-face from to
    auto none inherit initial unset normal bold italic
  ]

  @impl true
  def operators, do: ~w[
    : ; > + ~ * = ^= $= *= ~= |=
  ]

  @impl true
  def delimiters, do: ~w[
    { } ( ) , . # : ; @
  ] ++ ~w( [ ] )
end
