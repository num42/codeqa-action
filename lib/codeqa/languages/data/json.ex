defmodule CodeQA.Languages.Data.Json do
  use CodeQA.Language

  @impl true
  def name, do: "json"

  @impl true
  def extensions, do: ~w[json jsonc]

  @impl true
  def comment_prefixes, do: []

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    true false null
  ]

  @impl true
  def operators, do: ~w[
    :
  ]

  @impl true
  def delimiters, do: ~w[
    { } , " '
  ] ++ ~w( [ ] )
end
