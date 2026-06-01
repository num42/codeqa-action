defmodule MyApp.Repo.Migrations.UnifyManufacturerColor do
  @moduledoc """
  Migration module — GOOD: `execute/1` runs SQL, not debug output.

  `execute` is the Ecto migration API for raw SQL; it is not a print
  statement. Likewise heredoc strings inside migrations are SQL bodies,
  not log lines.
  """

  use Ecto.Migration

  def up do
    prefix = Application.get_env(:my_app, :schema_prefix)
    table = if prefix, do: ~s("#{prefix}".items), else: "items"

    execute """
    UPDATE #{table}
    SET manufacturer_color = manufacturer_color_name
    WHERE manufacturer_color IS NULL AND manufacturer_color_name IS NOT NULL
    """
  end

  def down do
    prefix = Application.get_env(:my_app, :schema_prefix)
    table = if prefix, do: ~s("#{prefix}".items), else: "items"

    execute "UPDATE #{table} SET manufacturer_color = NULL"
  end
end
