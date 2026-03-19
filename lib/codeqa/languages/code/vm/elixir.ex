defmodule CodeQA.Languages.Code.Vm.Elixir do
  use CodeQA.Language

  @impl true
  def name, do: "elixir"

  @impl true
  def extensions, do: ~w[ex exs]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if else unless for do end def defp defmodule defmacro defmacrop defprotocol
    defimpl defguard defdelegate defstruct case cond with when fn try rescue
    catch raise receive in not and or true false nil
  ]

  @impl true
  def operators, do: ~w[
    == === != !== <= >= + - * / % << >> & | ^ ~ && || |> <> <- -> = ! not and or in
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ |
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords,
    do:
      ~w[def defp defmodule defmacro defmacrop defprotocol defimpl defdelegate defoverridable defguard]

  @impl true
  def branch_keywords, do: ~w[else rescue catch ensure cond when case]

  @impl true
  def block_end_tokens, do: ~w[end]

  @impl true
  def access_modifiers, do: []

  @impl true
  def function_keywords, do: ~w[def defp defmacro defmacrop defdelegate defguard]

  @impl true
  def module_keywords, do: ~w[defmodule defprotocol defimpl]

  @impl true
  def import_keywords, do: ~w[import require use alias]

  @impl true
  def test_keywords, do: ~w[test describe]
end
