defmodule CodeQA.Languages.Code.Scripting.Python do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "python"

  @impl true
  def extensions, do: ~w[py pyi]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if else elif for while def class import from return pass break continue
    not and or in is lambda with as try except finally raise yield async await
    global nonlocal del assert True False None
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % ** // << >> & | ^ ~ = += -= *= /= %= **= //=
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ #
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[def class async]

  @impl true
  def branch_keywords, do: ~w[elif else except finally]

  @impl true
  def block_end_tokens, do: []

  @impl true
  def access_modifiers, do: []

  @impl true
  def function_keywords, do: ~w[def async]

  @impl true
  def module_keywords, do: ~w[class]

  @impl true
  def import_keywords, do: ~w[import from]

  @impl true
  def uses_colon_indent?, do: true
end
