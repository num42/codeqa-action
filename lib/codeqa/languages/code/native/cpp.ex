defmodule CodeQA.Languages.Code.Native.Cpp do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "cpp"

  @impl true
  def extensions, do: ~w[c cpp cc cxx hpp h hh]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while do class struct namespace using include template typename
    return new delete this public private protected virtual override static
    const constexpr inline extern try catch throw switch case break continue
    default auto void true false nullptr
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || = += -= *= /= %= -> ::
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # *
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[class struct namespace template]

  @impl true
  def branch_keywords, do: ~w[else catch case default]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: ~w[public private protected static virtual override inline]

  @impl true
  def module_keywords, do: ~w[class struct namespace enum]
end
