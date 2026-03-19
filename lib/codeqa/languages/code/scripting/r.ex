defmodule CodeQA.Languages.Code.Scripting.R do
  use CodeQA.Language

  @impl true
  def name, do: "r"

  @impl true
  def extensions, do: ~w[r R Rmd rmd]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    if else for while repeat break next return function TRUE FALSE NULL NA Inf NaN
  ]

  @impl true
  def operators, do: ~w[
    == != <= >= + - * / ^ %% %/% %in% <- -> = & | ! && || ~ : ::
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ;
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[function]

  @impl true
  def branch_keywords, do: ~w[else]

  @impl true
  def block_end_tokens, do: ~w[}]

  @impl true
  def function_keywords, do: ~w[function]

  @impl true
  def import_keywords, do: ~w[library require source]

  @impl true
  def test_keywords, do: ~w[test_that expect_equal expect_true describe it]
end
