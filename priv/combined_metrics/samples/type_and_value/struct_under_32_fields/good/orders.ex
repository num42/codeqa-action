defmodule MyApp.Orders.Order do
  @moduledoc """
  Core order struct. Kept focused with fewer than 32 fields so the BEAM
  stores it as a tagged tuple rather than a hash map.

  Extended attributes and audit metadata are stored in separate structs.
  """

  @enforce_keys [:id, :customer_id, :status]
  defstruct [
    :id,
    :customer_id,
    :status,
    :total_cents,
    :currency,
    :shipping_address_id,
    :billing_address_id,
    :coupon_code,
    :notes,
    :placed_at,
    :confirmed_at,
    :shipped_at,
    :delivered_at,
    :cancelled_at,
    inserted_at: nil,
    updated_at: nil
  ]

  @type status :: :draft | :pending | :confirmed | :shipped | :delivered | :cancelled

  @type t :: %__MODULE__{
    id: integer(),
    customer_id: integer(),
    status: status(),
    total_cents: integer() | nil,
    currency: atom() | nil,
    shipping_address_id: integer() | nil,
    billing_address_id: integer() | nil,
    coupon_code: String.t() | nil,
    notes: String.t() | nil,
    placed_at: DateTime.t() | nil,
    confirmed_at: DateTime.t() | nil,
    shipped_at: DateTime.t() | nil,
    delivered_at: DateTime.t() | nil,
    cancelled_at: DateTime.t() | nil,
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }
end

defmodule MyApp.Orders.OrderMeta do
  @moduledoc """
  Optional metadata for an order, kept separate to avoid inflating the
  core Order struct beyond the BEAM's 32-field tuple optimisation boundary.
  """

  defstruct [
    :order_id,
    :referral_source,
    :utm_campaign,
    :utm_medium,
    :user_agent,
    :ip_address,
    :locale,
    :ab_test_variant
  ]
end
