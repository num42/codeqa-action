defmodule CodeQA.Languages.Data.Toml do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "toml"

  @impl true
  def extensions, do: ~w[toml]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    true false
  ]

  @impl true
  def operators, do: ~w[
    =
  ]

  @impl true
  def delimiters, do: ~w[
    { } , . : # " '
  ] ++ ~w( [ ] )
end
