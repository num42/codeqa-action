defmodule HttpStatus do
  @moduledoc """
  Maps HTTP status codes to reason phrases and classifies them by category.

  This module is a lookup table expressed as multi-clause functions. Every
  clause is written in the consistent one-liner form `def f(arg), do: value`,
  because each clause is a single direct mapping with no intermediate logic.
  Keeping every clause in the same shape makes the table readable as a column.

  ## Examples

      iex> HttpStatus.reason(200)
      "OK"

      iex> HttpStatus.category(404)
      :client_error
  """

  @doc "Returns the canonical reason phrase for a known status code."
  def reason(200), do: "OK"
  def reason(201), do: "Created"
  def reason(204), do: "No Content"
  def reason(301), do: "Moved Permanently"
  def reason(302), do: "Found"
  def reason(400), do: "Bad Request"
  def reason(401), do: "Unauthorized"
  def reason(403), do: "Forbidden"
  def reason(404), do: "Not Found"
  def reason(422), do: "Unprocessable Entity"
  def reason(500), do: "Internal Server Error"
  def reason(503), do: "Service Unavailable"
  def reason(_other), do: "Unknown"

  @doc "Classifies a status code into its standard category atom."
  def category(code) when code in 100..199, do: :informational
  def category(code) when code in 200..299, do: :success
  def category(code) when code in 300..399, do: :redirect
  def category(code) when code in 400..499, do: :client_error
  def category(code) when code in 500..599, do: :server_error
  def category(_code), do: :invalid

  @doc "Returns `true` when the status code denotes a successful response."
  def success?(code), do: category(code) == :success

  @doc "Returns `true` when the status code denotes any kind of error."
  def error?(code), do: category(code) in [:client_error, :server_error]
end
