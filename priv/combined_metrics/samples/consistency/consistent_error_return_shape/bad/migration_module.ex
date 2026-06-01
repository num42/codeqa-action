defmodule MyApp.Repo.Migrations.ReplaceOtherWithService do
  @moduledoc """
  Migration module — BAD: helpers within the migration return mixed
  error shapes (`:error` vs `{:error, _}` vs raising).
  """

  use Ecto.Migration

  def up do
    case fetch_table_name() do
      :error ->
        :error

      {:error, reason} ->
        raise "could not resolve table: #{reason}"

      {:ok, table} ->
        execute "UPDATE #{table} SET type = 'service' WHERE type = 'other'"
    end
  end

  def down do
    case fetch_table_name() do
      nil -> false
      "" -> {:error, "empty table name"}
      table -> execute "UPDATE #{table} SET type = 'other' WHERE type = 'service'"
    end
  end

  defp fetch_table_name do
    case Application.get_env(:my_app, :schema_prefix) do
      nil -> {:ok, "items"}
      "" -> :error
      prefix when is_binary(prefix) -> {:ok, ~s("#{prefix}".items)}
      _other -> {:error, "unexpected prefix"}
    end
  end
end
