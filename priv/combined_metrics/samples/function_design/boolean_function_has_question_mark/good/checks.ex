defmodule Checks do
  def enabled?(feature, config) do
    MapSet.member?(config.features, feature)
  end

  def stale?(record, ttl) do
    DateTime.diff(DateTime.utc_now(), record.updated_at, :second) > ttl
  end

  def blank?(value) when is_binary(value), do: String.trim(value) == ""
  def blank?(nil), do: true
  def blank?(_), do: false

  def present?(value), do: not blank?(value)

  def between?(value, low, high) when is_number(value) do
    value >= low and value <= high
  end

  def allowed?(user, action) do
    action in user.permissions
  end
end
