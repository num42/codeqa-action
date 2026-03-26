defmodule CodeQA.Languages.Code.Vm.Scala do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "scala"

  @impl true
  def extensions, do: ~w[scala sc]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while do def class object trait extends with new return import
    package val var type match case sealed abstract override final protected
    private implicit lazy yield try catch finally throw true false null this super
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || = += -= *= /= => <- <: >: :
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # =>
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[def class object trait type]

  @impl true
  def branch_keywords, do: ~w[else catch case finally]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers,
    do: ~w[public private protected override abstract final sealed implicit lazy]

  @impl true
  def function_keywords, do: ~w[def]

  @impl true
  def module_keywords, do: ~w[class object trait package]

  @impl true
  def import_keywords, do: ~w[import package]

  @impl true
  def test_keywords, do: ~w[test it describe should]
end
