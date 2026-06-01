defmodule Checks do
  def is_enabled(feature, config) do
    MapSet.member?(config.features, feature)
  end

  def check_stale(record, ttl) do
    DateTime.diff(DateTime.utc_now(), record.updated_at, :second) > ttl
  end

  def check_blank(value) when is_binary(value), do: String.trim(value) == ""
  def check_blank(nil), do: true
  def check_blank(_), do: false

  def check_present(value), do: not check_blank(value)

  def check_between(value, low, high) when is_number(value) do
    value >= low and value <= high
  end

  def check_allowed(user, action) do
    action in user.permissions
  end
end
