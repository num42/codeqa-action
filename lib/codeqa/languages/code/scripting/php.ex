defmodule CodeQA.Languages.Code.Scripting.PHP do
  use CodeQA.Language

  @impl true
  def name, do: "php"

  @impl true
  def extensions, do: ~w[php phtml php3 php4 php5 php7 php8]

  @impl true
  def comment_prefixes, do: ~w[// #]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    if else elseif for foreach while do function class interface trait namespace
    use return new echo print public private protected static abstract final
    try catch finally throw switch case break continue default include require
    include_once require_once extends implements null true false
  ]

  @impl true
  def operators, do: ~w[
    == === != !== <= >= + - * / % ** << >> & | ^ ~ && || ?? = += -= *= /= %= -> :: =>
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ # $
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[function class interface trait namespace]

  @impl true
  def branch_keywords, do: ~w[else elseif catch finally case default]

  @impl true
  def block_end_tokens, do: ~w[} endif endfor endforeach endwhile endswitch]

  @impl true
  def access_modifiers, do: ~w[public private protected static abstract final]

  @impl true
  def function_keywords, do: ~w[function fn]

  @impl true
  def module_keywords, do: ~w[class interface trait namespace]

  @impl true
  def import_keywords, do: ~w[use namespace]
end
