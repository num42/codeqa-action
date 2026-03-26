defmodule CodeQA.Languages.Markup.Html do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "html"

  @impl true
  def extensions, do: ~w[html htm heex eex leex erb htmlbars hbs mustache jinja jinja2 njk liquid]

  @impl true
  def comment_prefixes, do: []

  @impl true
  def block_comments, do: [{"<!--", "-->"}]

  @impl true
  def keywords, do: ~w[
    html head body div span p a img input form button select option textarea
    script style link meta title h1 h2 h3 h4 h5 h6 ul ol li table tr td th
    header footer nav main section article aside figure figcaption
    class id href src type name value rel action method placeholder
  ]

  @impl true
  def operators, do: ~w[
    < > / = &
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; " ' # ! ?
  ] ++ ~w( [ ] )
end
