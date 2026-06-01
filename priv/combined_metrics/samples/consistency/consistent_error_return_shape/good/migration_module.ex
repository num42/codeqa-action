defmodule MyApp.Repo.Migrations.ReplaceOtherWithService do
  @moduledoc """
  Migration module — GOOD: migrations don't return error shapes.

  `def up`/`def down` either succeed or raise. There are no
  `{:ok, _}` / `{:error, _}` tuples to be inconsistent about.
  """

  use Ecto.Migration

  def up do
    prefix = Application.get_env(:my_app, :schema_prefix)
    table = if prefix, do: ~s("#{prefix}".items), else: "items"

    execute "UPDATE #{table} SET type = 'service' WHERE type = 'other'"
  end

  def down do
    prefix = Application.get_env(:my_app, :schema_prefix)
    table = if prefix, do: ~s("#{prefix}".items), else: "items"

    execute "UPDATE #{table} SET type = 'other' WHERE type = 'service'"
  end
end
