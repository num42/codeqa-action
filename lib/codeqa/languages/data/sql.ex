defmodule CodeQA.Languages.Data.Sql do
  @moduledoc false
  use CodeQA.Language

  @impl true
  def name, do: "sql"

  @impl true
  def extensions, do: ~w[sql]

  @impl true
  def comment_prefixes, do: ~w[--]

  @impl true
  def block_comments, do: [{"/*", "*/"}]

  @impl true
  def keywords, do: ~w[
    SELECT FROM WHERE INSERT INTO UPDATE DELETE SET CREATE DROP ALTER TABLE
    INDEX VIEW JOIN LEFT RIGHT INNER OUTER FULL CROSS ON AND OR NOT IN EXISTS
    AS GROUP BY ORDER HAVING LIMIT OFFSET DISTINCT NULL TRUE FALSE PRIMARY KEY
    FOREIGN REFERENCES CASCADE UNIQUE DEFAULT VALUES RETURNING WITH UNION
    INTERSECT EXCEPT CASE WHEN THEN ELSE END IF BEGIN COMMIT ROLLBACK
  ]

  @impl true
  def operators, do: ~w[
    = != <> <= >= + - * / % LIKE BETWEEN IS IN
  ]

  @impl true
  def delimiters, do: ~w[
    ( ) , . ; ' " -- /*
  ] ++ ~w( [ ] )

  @impl true
  def statement_keywords,
    do:
      ~w[select insert update delete create drop alter truncate begin commit rollback call execute]
end
