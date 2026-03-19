defmodule CodeQA.Languages.Config.Dockerfile do
  use CodeQA.Language

  @impl true
  def name, do: "dockerfile"

  @impl true
  def extensions, do: ~w[Dockerfile]

  @impl true
  def comment_prefixes, do: ~w[#]

  @impl true
  def block_comments, do: []

  @impl true
  def keywords, do: ~w[
    FROM RUN CMD LABEL EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR ARG
    ONBUILD STOPSIGNAL HEALTHCHECK SHELL AS
  ]

  @impl true
  def operators, do: ~w[
    = \
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) , : #
  ] ++ ~w( [ ] )

  @impl true
  def declaration_keywords, do: ~w[FROM]
end
