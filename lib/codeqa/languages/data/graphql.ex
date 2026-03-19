defmodule CodeQA.Languages.Data.GraphQL do
  use CodeQA.Language

  @impl true
  def name, do: "graphql"

  @impl true
  def extensions, do: ~w[graphql gql]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    query mutation subscription fragment on type interface union enum input
    scalar schema directive extend implements true false null
  ]

  @impl true
  def operators, do: ~w[
    = : ! | &
  ]

  @impl true
  def delimiters, do: ~w[
    { } ( ) , . : # @ !
  ] ++ ~w( [ ] )
end
