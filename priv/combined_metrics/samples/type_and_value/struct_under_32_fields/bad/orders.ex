defmodule MyApp.Orders.Order do
  @moduledoc """
  Core order struct. Contains far too many fields, pushing the struct
  beyond 32 fields and causing the BEAM to use a hash map internally
  instead of a tagged tuple — losing structural pattern matching speed.
  """

  defstruct [
    # Core fields
    :id,
    :customer_id,
    :status,
    :total_cents,
    :currency,
    # Address
    :shipping_address_id,
    :billing_address_id,
    :shipping_street,
    :shipping_city,
    :shipping_state,
    :shipping_postal_code,
    :shipping_country,
    :billing_street,
    :billing_city,
    :billing_state,
    :billing_postal_code,
    :billing_country,
    # Promotion
    :coupon_code,
    :discount_cents,
    :discount_type,
    # Lifecycle timestamps
    :placed_at,
    :confirmed_at,
    :shipped_at,
    :delivered_at,
    :cancelled_at,
    :refunded_at,
    :inserted_at,
    :updated_at,
    # Marketing / analytics — these should be in OrderMeta
    :referral_source,
    :utm_campaign,
    :utm_medium,
    :utm_source,
    :user_agent,
    :ip_address,
    :locale,
    :ab_test_variant,
    # Audit
    :created_by_user_id,
    :last_modified_by_user_id,
    :notes,
    :internal_notes
  ]

  # This struct has 41 fields — well above the 32-field BEAM threshold.
  # The BEAM will store this as a hash map, making pattern matching slower
  # and memory layout less cache-friendly.
end
