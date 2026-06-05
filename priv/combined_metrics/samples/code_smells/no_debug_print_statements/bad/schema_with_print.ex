defmodule MyApp.Billing.Account do
  @moduledoc """
  Billing account schema — BAD: a debug print leaks inside the changeset.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field(:name, :string)
    field(:balance_cents, :integer, default: 0)
    timestamps()
  end

  def changeset(account, attrs) do
    IO.puts("changeset called with #{inspect(attrs)}")

    account
    |> cast(attrs, [:name, :balance_cents])
    |> validate_required([:name])
  end
end
