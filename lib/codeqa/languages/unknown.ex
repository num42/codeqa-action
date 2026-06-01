defmodule CodeQA.Languages.Unknown do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "unknown"

  @impl true
  def extensions, do: []

  @impl true
  def comment_prefixes, do: []

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if else
  ]

  @impl true
  def operators, do: ~w[
    == !=
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { }
  ]
end
