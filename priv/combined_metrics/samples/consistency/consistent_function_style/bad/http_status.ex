defmodule HttpStatus do
  @moduledoc "Maps HTTP status codes to reason phrases and classifies them"

  def reason(200), do: "OK"

  def reason(201) do
    "Created"
  end

  def reason(204), do: "No Content"
  def reason(400), do: "Bad Request"

  def reason(404) do
    "Not Found"
  end

  def reason(500), do: "Internal Server Error"

  def reason(_other) do
    "Unknown"
  end

  def category(code) when code in 200..299, do: :success

  def category(code) when code in 300..399 do
    :redirect
  end

  def category(code) when code in 400..499, do: :client_error

  def category(code) when code in 500..599 do
    :server_error
  end

  def category(_code), do: :invalid

  def success?(code) do
    category(code) == :success
  end

  def error?(code), do: category(code) in [:client_error, :server_error]
end
