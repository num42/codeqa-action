defmodule CodeQA.Languages.Code.Scripting.Julia do
  use CodeQA.Language

  @impl true
  def name, do: "julia"

  @impl true
  def extensions, do: ~w[jl]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: [{"#=", "=#"}]

  @impl true
  def keywords, do: ~w[
    if else elseif for while do end function return module import using export
    struct mutable abstract type primitive begin let local global const try catch
    finally throw macro quote true false nothing
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % ^ << >> & | ~ && || = += -= *= /= ÷ → ← |>
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ |
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[function struct macro module]

  @impl true
  def branch_keywords, do: ~w[else elseif catch finally]

  @impl true
  def block_end_tokens, do: ~w[end]

  @impl true
  def function_keywords, do: ~w[function macro]

  @impl true
  def module_keywords, do: ~w[module struct]

  @impl true
  def import_keywords, do: ~w[import using]

  @impl true
  def test_keywords, do: ~w[@test @testset]
end
