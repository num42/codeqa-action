defmodule CodeQA.Languages.Code.Vm.Fsharp do
  use CodeQA.Language

  @impl true
  def name, do: "fsharp"

  @impl true
  def extensions, do: ~w[fs fsi fsx]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"(*", "*)"}]

  @impl true
  def keywords, do: ~w[
    let rec if then else for while do match with type module open namespace val
    mutable abstract member override new return yield async await try finally
    raise true false null and or not in when downto to
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % << >> & | ^ ~ && || = |> <| >> << -> <- :: @ ?
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; | @ # ->
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[let type module]

  @impl true
  def branch_keywords, do: ~w[else with]

  @impl true
  def block_end_tokens, do: []

  @impl true
  def access_modifiers, do: ~w[public private protected internal static abstract override]

  @impl true
  def function_keywords, do: ~w[let fun]

  @impl true
  def module_keywords, do: ~w[module namespace type]

  @impl true
  def import_keywords, do: ~w[open]

  @impl true
  def test_keywords, do: ~w[testCase test testProperty]

  @impl true
  def uses_colon_indent?, do: true
end
