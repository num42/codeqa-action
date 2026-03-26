defmodule CodeQA.Languages.Code.Native.Rust do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "rust"

  @impl true
  def extensions, do: ~w[rs]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while loop fn struct enum trait impl use mod pub let mut const
    static return match type where as in ref move async await dyn unsafe extern
    crate self super true false
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || = += -= *= /= %= -> => ::
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # |
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[fn struct enum trait impl mod]

  @impl true
  def branch_keywords, do: ~w[else match]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: ~w[pub]

  @impl true
  def function_keywords, do: ~w[fn]

  @impl true
  def module_keywords, do: ~w[impl trait struct enum]

  @impl true
  def import_keywords, do: ~w[use extern]
end
