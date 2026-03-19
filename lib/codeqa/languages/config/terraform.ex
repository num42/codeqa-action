defmodule CodeQA.Languages.Config.Terraform do
  use CodeQA.Language

  @impl true
  def name, do: "terraform"

  @impl true
  def extensions, do: ~w[tf tfvars]

  @impl true
  def comment_prefixes, do: ~w[# //]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    resource data variable output locals module provider terraform
    required_providers backend for_each count depends_on lifecycle
    source version true false null for if
  ]

  @impl true
  def operators, do: ~w[
    = == != <= >= && || ! ? :
  ]

  @impl true
  def delimiters, do: ~w[
    { } ( ) , . : = " # //
  ] ++ ~w( [ ] )
end
