defmodule Message.Builder do
  @moduledoc """
  String/message builder — GOOD: nil or pattern matching used instead of empty string sentinels.
  """

  def build_greeting(%{gender: :female} = user) do
    name = user.preferred_name || user.first_name
    "Dear Ms. #{name},"
  end

  def build_greeting(user) do
    name = user.preferred_name || user.first_name
    "Dear Mr. #{name},"
  end

  def format_address(address) do
    parts =
      [
        address.street,
        unit_line(address.unit),
        "#{address.city}, #{address.state} #{address.zip}"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, "\n")
  end

  def build_subject(event) do
    prefix = if event.priority == :high, do: "[URGENT] ", else: nil
    suffix = if event.reference, do: " (ref: #{event.reference})", else: nil

    [prefix, event.title, suffix]
    |> Enum.reject(&is_nil/1)
    |> Enum.join()
  end

  def compose_footer(opts) do
    [
      if(opts.legal, do: "This message is confidential.", else: nil),
      if(opts.marketing, do: "Unsubscribe at any time.", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" | ")
  end

  defp unit_line(nil), do: nil
  defp unit_line(unit), do: "Unit #{unit}"
end
