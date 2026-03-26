defmodule CodeQA.Languages.Code.Scripting.Ruby do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "ruby"

  @impl true
  def extensions, do: ~w[rb rake gemspec]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if else elsif unless for while until def class module do end return begin
    rescue ensure raise yield include extend require require_relative
    attr_accessor attr_reader attr_writer then case when next break in
    and or not true false nil self super
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % ** << >> & | ^ ~ = += -= *= /= %= **= <=> === =~
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ | # ?
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[def class module]

  @impl true
  def branch_keywords, do: ~w[else elsif rescue ensure when]

  @impl true
  def block_end_tokens, do: ~w[end]

  @impl true
  def access_modifiers, do: []

  @impl true
  def function_keywords, do: ~w[def]

  @impl true
  def module_keywords, do: ~w[class module]

  @impl true
  def import_keywords, do: ~w[require require_relative include]

  @impl true
  def test_keywords, do: ~w[it describe context scenario feature given]
end
