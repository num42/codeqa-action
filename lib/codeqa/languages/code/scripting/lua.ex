defmodule CodeQA.Languages.Code.Scripting.Lua do
  use CodeQA.Language

  @impl true
  def name, do: "lua"

  @impl true
  def extensions, do: ~w[lua]

  @impl true
  def comment_prefixes, do: ~w[--]

  @impl true
  def block_comments, do: [{"--[[", "]]"}]

  @impl true
  def keywords, do: ~w[
    and break do else elseif end false for function goto if in local nil not or
    repeat return then true until while
  ]

  @impl true
  def operators, do: ~w[
    == ~= <= >= + - * / % ^ # & | ~ << >> // .. = and or not
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ;
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[function local]

  @impl true
  def branch_keywords, do: ~w[else elseif]

  @impl true
  def block_end_tokens, do: ~w[end]

  @impl true
  def function_keywords, do: ~w[function]

  @impl true
  def import_keywords, do: ~w[require]
end
