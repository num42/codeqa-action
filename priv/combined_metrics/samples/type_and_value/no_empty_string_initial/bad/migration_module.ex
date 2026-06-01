defmodule MyApp.Repo.Migrations.ChangeUValueToFloat do
  @moduledoc """
  Migration module — BAD: empty-string sentinels for accumulated SQL fragments.
  """

  use Ecto.Migration

  def up do
    sql_prefix = ""
    columns_clause = ""
    schema = ""

    sql_prefix = "ALTER TABLE"
    schema = Application.get_env(:my_app, :schema_prefix) || ""
    table = if schema == "", do: "items", else: ~s("#{schema}".items)

    columns_clause = ""

    columns_clause =
      if columns_clause == "" do
        "ALTER COLUMN u_value TYPE double precision USING NULL"
      else
        columns_clause
      end

    execute "#{sql_prefix} #{table} #{columns_clause}"
  end

  def down do
    schema = ""
    schema = Application.get_env(:my_app, :schema_prefix) || ""
    table = if schema == "", do: "items", else: ~s("#{schema}".items)

    revert_clause = ""
    revert_clause = "ALTER COLUMN u_value TYPE varchar USING u_value::varchar"

    execute "ALTER TABLE #{table} #{revert_clause}"
  end
end
