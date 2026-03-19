defmodule CodeQA.Languages.Code.Native.Swift do
  use CodeQA.Language

  @impl true
  def name, do: "swift"

  @impl true
  def extensions, do: ~w[swift]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while repeat func class struct enum protocol extension import
    return let var guard defer do try catch throw switch case break continue
    default in as is init self super nil true false async await
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || ?? = += -= *= /= %= -> =>
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # |
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[func class struct enum protocol extension]

  @impl true
  def branch_keywords, do: ~w[else catch case default]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: ~w[public private internal fileprivate open]

  @impl true
  def function_keywords, do: ~w[func]

  @impl true
  def module_keywords, do: ~w[class struct protocol extension enum]

  @impl true
  def import_keywords, do: ~w[import]
end
