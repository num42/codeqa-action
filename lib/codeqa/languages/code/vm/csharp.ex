defmodule CodeQA.Languages.Code.Vm.CSharp do
  use CodeQA.Language

  @impl true
  def name, do: "csharp"

  @impl true
  def extensions, do: ~w[cs csx]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for foreach while do class interface struct enum namespace using
    return var new this base public private protected internal static abstract
    virtual override sealed async await try catch finally throw switch case
    break continue default in out ref void true false null readonly const
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || ?? = += -= *= /= %=
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # =>
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[class interface struct enum namespace]

  @impl true
  def branch_keywords, do: ~w[else catch finally case default]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers,
    do:
      ~w[public private protected internal static abstract virtual override sealed readonly const async]

  @impl true
  def module_keywords, do: ~w[class interface struct enum namespace]

  @impl true
  def import_keywords, do: ~w[using namespace]
end
