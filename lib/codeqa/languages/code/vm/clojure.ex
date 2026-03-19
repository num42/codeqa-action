defmodule CodeQA.Languages.Code.Vm.Clojure do
  use CodeQA.Language

  @impl true
  def name, do: "clojure"

  @impl true
  def extensions, do: ~w[clj cljs cljc edn]

  @impl true
  def comment_prefixes, do: ~w[;]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    def defn defmacro let fn if do when cond case for loop recur ns require use
    import try catch finally throw quote defprotocol defrecord deftype reify
    extend-type extend-protocol nil true false and or not
  ]

  @impl true
  def operators, do: ~w[
    = == not= < > <= >= + - * / mod rem quot and or not
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; # @ ^
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[def defn defmacro defprotocol defrecord deftype]

  @impl true
  def branch_keywords, do: ~w[else]

  @impl true
  def block_end_tokens, do: ~w[)]

  @impl true
  def function_keywords, do: ~w[defn fn]

  @impl true
  def module_keywords, do: ~w[ns defprotocol defrecord]

  @impl true
  def import_keywords, do: ~w[ns require use import]

  @impl true
  def test_keywords, do: ~w[deftest is testing]
end
