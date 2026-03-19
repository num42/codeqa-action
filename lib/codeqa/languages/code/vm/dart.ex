defmodule CodeQA.Languages.Code.Vm.Dart do
  use CodeQA.Language

  @impl true
  def name, do: "dart"

  @impl true
  def extensions, do: ~w[dart]

  @impl true
  def comment_prefixes, do: ~w[//]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else for while do switch case break continue return class extends implements
    with new final const var void null true false import export part library
    abstract static dynamic async await yield try catch finally throw rethrow
    enum typedef mixin factory is as in
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / % ~/ << >> & | ^ ~ && || ?? = += -= *= /= %= ??= -> =>
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # =>
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[class enum typedef mixin]

  @impl true
  def branch_keywords, do: ~w[else catch finally case]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def access_modifiers, do: ~w[static final const abstract]

  @impl true
  def function_keywords, do: ~w[void async]

  @impl true
  def module_keywords, do: ~w[class enum mixin]

  @impl true
  def import_keywords, do: ~w[import export]

  @impl true
  def test_keywords, do: ~w[test group setUp tearDown expect]
end
