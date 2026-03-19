defmodule CodeQA.Languages.Config.Makefile do
  use CodeQA.Language

  @impl true
  def name, do: "makefile"

  @impl true
  def extensions, do: ~w[Makefile GNUmakefile mk]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    ifeq ifneq ifdef ifndef else endif define endef include export unexport
    override private vpath all clean install
  ]

  @impl true
  def operators, do: ~w[
    = := ::= ?= += !=
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) { } , . : ; @ $ % # \
  ] ++ ~w( [ ] )
end
