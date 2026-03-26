defmodule CodeQA.Languages.Code.Scripting.Perl do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "perl"

  @impl true
  def extensions, do: ~w[pl pm t]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if else elsif unless for foreach while do until sub my our local use require
    package return last next redo goto print say die warn eval and or not defined
    undef true false
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= eq ne lt gt le ge + - * / % ** . x = += -= *= /= .= && || ! ~ & |
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ $ %
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[sub package]

  @impl true
  def branch_keywords, do: ~w[else elsif]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def function_keywords, do: ~w[sub]

  @impl true
  def module_keywords, do: ~w[package]

  @impl true
  def import_keywords, do: ~w[use require]

  @impl true
  def test_keywords, do: ~w[ok is isnt like unlike cmp_ok]
end
