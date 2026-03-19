defmodule CodeQA.Languages.Code.Native.Go do
  use CodeQA.Language

  @impl true
  def name, do: "go"

  @impl true
  def extensions, do: ~w[go]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for func type struct interface package import return var const
    map chan go defer select switch case break continue default fallthrough
    range make new append len cap close nil true false
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || = += -= *= /= %= :=
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ;
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[func type struct interface]

  @impl true
  def branch_keywords, do: ~w[else case default]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: []

  @impl true
  def function_keywords, do: ~w[func]

  @impl true
  def import_keywords, do: ~w[import package]
end
