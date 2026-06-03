defmodule HttpRouter do
  def status_message(200), do: "OK"
  def status_message(201), do: "Created"
  def status_message(code) when code in 200..299, do: "Success"
  def status_message(code) when code in 300..399, do: "Redirect"
  def status_message(code) when code in 400..499, do: "Client Error"
  def status_message(_code), do: "Server Error"

  def cache_header(:get), do: "public, max-age=60"
  def cache_header(_method), do: "no-store"

  def auth_required?(%{path: "/admin" <> _}), do: true
  def auth_required?(%{path: "/account" <> _}), do: true
  def auth_required?(%{path: _}), do: false

  def retry_after(attempt) do
    cond do
      attempt <= 0 -> 0
      attempt >= 5 -> 60
      true -> attempt * 5
    end
  end

  def content_type(%{accept: "application/json"}), do: "application/json"
  def content_type(%{accept: "text/html"}), do: "text/html"
  def content_type(%{}), do: "text/plain"
end
