defmodule MyApp.Repo.Migrations.ChangeUValueToFloat do
  @moduledoc """
  Migration module — GOOD: no empty-string sentinels.
  String literals here are SQL bodies and table names, not init-as-`""`
  variables that get reassigned.
  """

  use Ecto.Migration

  def up do
    prefix = Application.get_env(:my_app, :schema_prefix)
    items = if prefix, do: ~s("#{prefix}".items), else: "items"

    execute "UPDATE #{items} SET u_value = NULL"
    execute "ALTER TABLE #{items} ALTER COLUMN u_value TYPE double precision USING NULL"
  end

  def down do
    prefix = Application.get_env(:my_app, :schema_prefix)
    items = if prefix, do: ~s("#{prefix}".items), else: "items"

    execute "ALTER TABLE #{items} ALTER COLUMN u_value TYPE varchar USING u_value::varchar"
  end
end
