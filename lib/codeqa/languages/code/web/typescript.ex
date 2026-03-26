defmodule CodeQA.Languages.Code.Web.TypeScript do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "typescript"

  @impl true
  def extensions, do: ~w[ts tsx]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while function class return var let const import export from
    new this typeof instanceof try catch finally throw switch case break
    continue default delete in of async await yield true false null undefined
    type interface enum namespace declare abstract override readonly implements
    extends satisfies as keyof typeof infer never unknown any void
  ]

  @impl true
  def operators, do: ~w[
    == === != !== <= >= + - * / % ** << >> >>> & | ^ ~ && || ?? = += -= *= /= %=
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # => <
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[function class async interface enum namespace type declare]

  @impl true
  def branch_keywords, do: ~w[else catch finally case default]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers,
    do: ~w[export public private protected static abstract override readonly sealed]

  @impl true
  def function_keywords, do: ~w[function async]

  @impl true
  def module_keywords, do: ~w[class interface enum namespace]

  @impl true
  def import_keywords, do: ~w[import]

  @impl true
  def test_keywords, do: ~w[test it describe context scenario feature given]
end
