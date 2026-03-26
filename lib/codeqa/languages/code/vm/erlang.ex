defmodule CodeQA.Languages.Code.Vm.Erlang do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "erlang"

  @impl true
  def extensions, do: ~w[erl hrl]

  @impl true
  def comment_prefixes, do: ~w[%]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if case when of begin end receive after fun try catch throw error exit
    module export import define record true false ok undefined andalso orelse
    not band bor bxor bnot bsl bsr div rem
  ]

  @impl true
  def operators, do: ~w[
    == /= =< >= =:= =/= + - * / ! <- -> :: | . , ; :
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; | ->
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[-module -record -define]

  @impl true
  def branch_keywords, do: ~w[of after catch]

  @impl true
  def block_end_tokens, do: ~w[end]

  @impl true
  def function_keywords, do: ~w[fun]

  @impl true
  def module_keywords, do: ~w[-module]

  @impl true
  def import_keywords, do: ~w[-import -include]

  @impl true
  def test_keywords, do: ~w[_test_ _test]
end
