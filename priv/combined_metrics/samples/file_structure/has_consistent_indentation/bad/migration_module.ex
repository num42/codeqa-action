defmodule MyApp.Repo.Migrations.AddIndexToItems do
  @moduledoc """
  Migration module — BAD: mixes 2-space, 4-space and tab indentation.
  """

  use Ecto.Migration

  def up do
      prefix = Application.get_env(:my_app, :schema_prefix)
    table = if prefix, do: ~s("#{prefix}".items), else: "items"

	execute "CREATE INDEX IF NOT EXISTS items_type_idx ON #{table} (type)"
        execute "CREATE INDEX IF NOT EXISTS items_color_idx ON #{table} (manufacturer_color)"
  end

  def down do
    prefix = Application.get_env(:my_app, :schema_prefix)
        table = if prefix, do: ~s("#{prefix}".items), else: "items"

	execute "DROP INDEX IF EXISTS items_type_idx"
      execute "DROP INDEX IF EXISTS items_color_idx"
  end
end
