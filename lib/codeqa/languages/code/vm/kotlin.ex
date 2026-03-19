defmodule CodeQA.Languages.Code.Vm.Kotlin do
  use CodeQA.Language

  @impl true
  def name, do: "kotlin"

  @impl true
  def extensions, do: ~w[kt kts]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while do fun class object interface data sealed abstract enum
    companion import package return val var when is as in out by override open
    final private protected public internal suspend inline reified crossinline
    noinline try catch finally throw break continue null true false this super init
  ]

  @impl true
  def operators, do: ~w[
    == === != !== <= >= + - * / % << >> & | ^ ~ && || ?: = += -= *= /= %= -> => ::
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # |
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[fun class object interface data sealed abstract enum]

  @impl true
  def branch_keywords, do: ~w[else when catch finally]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: ~w[public private protected internal override open abstract final]

  @impl true
  def function_keywords, do: ~w[fun]

  @impl true
  def module_keywords, do: ~w[class interface object]

  @impl true
  def import_keywords, do: ~w[import package]
end
