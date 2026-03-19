defmodule CodeQA.Languages.Code.Scripting.Shell do
  use CodeQA.Language

  @impl true
  def name, do: "shell"

  @impl true
  def extensions, do: ~w[sh bash zsh fish]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if else elif fi for while do done case esac function return then in until
    select break continue exit local export readonly unset
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % && || | & > < >> << = += -= *= /= %= -eq -ne -lt -gt -le -ge
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # $ ! ? |
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[function]

  @impl true
  def branch_keywords, do: ~w[else elif case]

  @impl true
  def block_end_tokens, do: ~w[fi done esac]

  @impl true
  def access_modifiers, do: []

  @impl true
  def function_keywords, do: ~w[function]
end
