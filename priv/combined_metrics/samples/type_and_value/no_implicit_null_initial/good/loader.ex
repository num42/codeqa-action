defmodule Data.Loader do
  @moduledoc """
  Data loader — GOOD: values assigned directly from expressions, with/case used for branching.
  """

  def load_user_profile(user_id) do
    case fetch_user(user_id) do
      nil ->
        %{profile: nil, avatar: nil, preferences: nil}

      user ->
        avatar = if user.has_avatar, do: fetch_avatar(user.id), else: nil
        preferences = if user.preferences_enabled, do: load_preferences(user.id), else: nil

        %{profile: build_profile(user), avatar: avatar, preferences: preferences}
    end
  end

  def resolve_config(:prod) do
    %{
      db_url: System.get_env("DATABASE_URL"),
      pool_size: 20,
      log_level: :warn
    }
  end

  def resolve_config(:dev) do
    %{
      db_url: "postgres://localhost/myapp_dev",
      pool_size: 5,
      log_level: :debug
    }
  end

  def resolve_config(_env) do
    %{db_url: nil, pool_size: nil, log_level: nil}
  end

  def fetch_report(report_id, opts) do
    if opts[:cache] do
      lookup_cache(report_id) || generate_report(report_id)
    else
      generate_report(report_id)
    end
  end

  def load_order_details(order_id) do
    case fetch_order(order_id) do
      nil ->
        {nil, nil, nil}

      order ->
        items = fetch_items(order.id)
        shipping = fetch_shipping(order.id)
        {order, items, shipping}
    end
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
