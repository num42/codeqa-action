defmodule CodeQA.Languages.Markup.Markdown do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "markdown"

  @impl true
  def extensions, do: ~w[md mdx]

  @impl true
  def comment_prefixes, do: []

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    TODO NOTE FIXME WARNING IMPORTANT
  ]

  @impl true
  def operators, do: ~w[
    # ## ### #### ##### ###### > ``` ** * _ __ ~~
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) . ! ? ` * _ ~
  ] ++ ~w( [ ] )
end
