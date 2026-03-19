defmodule CodeQA.Languages.Code.Native.Ocaml do
  use CodeQA.Language

  @impl true
  def name, do: "ocaml"

  @impl true
  def extensions, do: ~w[ml mli]

  @impl true
  def comment_prefixes, do: []

  @impl true
  def block_comments, do: [{"(*", "*)"}]

  @impl true
  def keywords, do: ~w[
    let rec fun if then else for while do done begin end match with type module
    open struct sig functor val mutable exception raise try when and or not in
    of as include class object method inherit new virtual
  ]

  @impl true
  def operators, do: ~w[
    == = != <> <= >= + - * / mod << >> & | ^ ~ && || @ :: |> -> <- := !
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; | @ ->
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[let type module class]

  @impl true
  def branch_keywords, do: ~w[else with when]

  @impl true
  def block_end_tokens, do: ~w[end]

  @impl true
  def access_modifiers, do: ~w[mutable virtual]

  @impl true
  def function_keywords, do: ~w[let fun]

  @impl true
  def module_keywords, do: ~w[module struct functor class]

  @impl true
  def import_keywords, do: ~w[open include]
end
