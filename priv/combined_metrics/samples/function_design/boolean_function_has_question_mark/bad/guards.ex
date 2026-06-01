defmodule Guards do
  def valid(value) when is_binary(value) do
    String.length(value) > 0
  end

  def active(user) do
    user.status == :active && !user.banned
  end

  def empty(list) when is_list(list) do
    length(list) == 0
  end

  def expired(token) do
    DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt
  end

  def admin(user) do
    user.role == :admin
  end

  def verified(user) do
    user.email_verified && user.phone_verified
  end

  def authorized(user, resource) do
    user.role == :admin || resource.owner_id == user.id
  end

  def pending(order) do
    order.status == :pending
  end

  def within_limit(count, limit) do
    count < limit
  end

  def matching(a, b) do
    a == b
  end
end
