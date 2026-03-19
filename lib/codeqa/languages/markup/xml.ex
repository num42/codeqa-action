defmodule CodeQA.Languages.Markup.Xml do
  use CodeQA.Language

  @impl true
  def name, do: "xml"

  @impl true
  def extensions, do: ~w[xml svg xsl xslt xsd wsdl plist]

  @impl true
  def comment_prefixes, do: []

  @impl true
  def block_comments, do: [{"<!--", "-->"}]

  @impl true
  def keywords, do: ~w[
    xmlns version encoding standalone
  ]

  @impl true
  def operators, do: ~w[
    < > / = &
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) , . : ; " ' # ! ?
  ] ++ ~w( [ ] )
end
