defmodule CodeQA.Languages.Code.Native.Zig do
  use CodeQA.Language

  @impl true
  def name, do: "zig"

  @impl true
  def extensions, do: ~w[zig]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    const var fn if else for while switch return pub try catch error defer errdefer
    comptime inline struct enum union test break continue null undefined unreachable
    async await suspend resume orelse anytype anyerror bool void noreturn type
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || = += -= *= /= %= orelse catch
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[fn struct enum union]

  @impl true
  def branch_keywords, do: ~w[else]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: ~w[pub inline comptime]

  @impl true
  def function_keywords, do: ~w[fn]

  @impl true
  def module_keywords, do: ~w[struct enum union]

  @impl true
  def test_keywords, do: ~w[test]
end
