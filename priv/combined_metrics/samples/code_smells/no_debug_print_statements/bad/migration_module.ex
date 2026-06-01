defmodule MyApp.Repo.Migrations.UnifyManufacturerColor do
  @moduledoc """
  Migration module — BAD: actual debug prints left in committed code.
  """

  use Ecto.Migration

  def up do
    IO.puts("running unify_manufacturer_color up migration")
    prefix = Application.get_env(:my_app, :schema_prefix)
    table = if prefix, do: ~s("#{prefix}".items), else: "items"
    IO.inspect(table, label: "target table")

    execute """
    UPDATE #{table}
    SET manufacturer_color = manufacturer_color_name
    WHERE manufacturer_color IS NULL AND manufacturer_color_name IS NOT NULL
    """

    IO.puts("done")
  end

  def down do
    IO.inspect("rolling back")
    prefix = Application.get_env(:my_app, :schema_prefix)
    table = if prefix, do: ~s("#{prefix}".items), else: "items"
    IO.puts("clearing manufacturer_color in #{table}")

    execute "UPDATE #{table} SET manufacturer_color = NULL"
  end
end
