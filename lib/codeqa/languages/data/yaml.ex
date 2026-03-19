defmodule CodeQA.Languages.Data.Yaml do
  use CodeQA.Language

  @impl true
  def name, do: "yaml"

  @impl true
  def extensions, do: ~w[yml yaml]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    true false null yes no on off
  ]

  @impl true
  def operators, do: ~w[
    : | > & * !
  ]

  @impl true
  def delimiters, do: ~w[
    { } , . # @ ---
  ] ++ ~w( [ ] )
end
