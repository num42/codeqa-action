defmodule CodeQA.Languages.Code.Vm.Java do
  use CodeQA.Language

  @impl true
  def name, do: "java"

  @impl true
  def extensions, do: ~w[java]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while do class interface extends implements import package
    return new this super public private protected static abstract final
    synchronized volatile try catch finally throw throws switch case break
    continue default void true false null instanceof
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> >>> & | ^ ~ && || = += -= *= /= %=
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[class interface]

  @impl true
  def branch_keywords, do: ~w[else catch finally case default]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: ~w[public private protected static abstract final synchronized]

  @impl true
  def module_keywords, do: ~w[class interface enum]

  @impl true
  def import_keywords, do: ~w[import package]
end
