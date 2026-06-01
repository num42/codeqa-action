defmodule Data.Loader do
  @moduledoc """
  Data loader — BAD: variables initialized to nil then conditionally assigned.
  """

  def load_user_profile(user_id) do
    profile = nil
    avatar = nil
    preferences = nil

    user = fetch_user(user_id)

    if user != nil do
      profile = build_profile(user)

      if user.has_avatar do
        avatar = fetch_avatar(user.id)
      end

      if user.preferences_enabled do
        preferences = load_preferences(user.id)
      end
    end

    %{profile: profile, avatar: avatar, preferences: preferences}
  end

  def resolve_config(env) do
    db_url = nil
    pool_size = nil
    log_level = nil

    if env == :prod do
      db_url = System.get_env("DATABASE_URL")
      pool_size = 20
      log_level = :warn
    end

    if env == :dev do
      db_url = "postgres://localhost/myapp_dev"
      pool_size = 5
      log_level = :debug
    end

    %{db_url: db_url, pool_size: pool_size, log_level: log_level}
  end

  def fetch_report(report_id, opts) do
    result = nil
    cached = nil

    if opts[:cache] do
      cached = lookup_cache(report_id)
    end

    if cached != nil do
      result = cached
    else
      result = generate_report(report_id)
    end

    result
  end

  def load_order_details(order_id) do
    order = nil
    items = nil
    shipping = nil

    order = fetch_order(order_id)

    if order != nil do
      items = fetch_items(order.id)
      shipping = fetch_shipping(order.id)
    end

    {order, items, shipping}
  end

  defp fetch_user(id), do: %{id: id, has_avatar: true, preferences_enabled: false}
  defp build_profile(u), do: %{id: u.id}
  defp fetch_avatar(id), do: "avatar_#{id}.png"
  defp load_preferences(id), do: %{theme: :dark, id: id}
  defp lookup_cache(_id), do: nil
  defp generate_report(id), do: %{id: id, data: []}
  defp fetch_order(id), do: %{id: id}
  defp fetch_items(id), do: [%{order_id: id}]
  defp fetch_shipping(id), do: %{order_id: id}
end
