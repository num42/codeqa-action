defmodule MyApp.Billing.Account do
  @moduledoc """
  Ecto schema for a billing account — GOOD: a schema definition with no
  debug output. `field`/`belongs_to`/`has_many` declare structure; the
  changeset validates. Nothing here prints.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "accounts" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: [:active, :suspended, :closed])
    field(:balance_cents, :integer, default: 0)
    field(:currency, :string, default: "EUR")

    belongs_to(:owner, MyApp.Accounts.User)
    has_many(:invoices, MyApp.Billing.Invoice)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :status, :balance_cents, :currency, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_number(:balance_cents, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:owner_id)
  end
end
