defmodule Message.Builder do
  @moduledoc """
  String/message builder — BAD: variables initialized to empty string as sentinel values.
  """

  def build_greeting(user) do
    salutation = ""
    name = ""

    salutation =
      if user.gender == :female do
        "Ms."
      else
        "Mr."
      end

    name =
      if user.preferred_name != nil do
        user.preferred_name
      else
        user.first_name
      end

    "Dear #{salutation} #{name},"
  end

  def format_address(address) do
    line1 = ""
    line2 = ""
    city_line = ""

    line1 = address.street

    line2 =
      if address.unit != nil do
        "Unit #{address.unit}"
      else
        ""
      end

    city_line = "#{address.city}, #{address.state} #{address.zip}"

    parts =
      if line2 == "" do
        [line1, city_line]
      else
        [line1, line2, city_line]
      end

    Enum.join(parts, "\n")
  end

  def build_subject(event) do
    prefix = ""
    suffix = ""

    prefix =
      if event.priority == :high do
        "[URGENT] "
      else
        ""
      end

    suffix =
      if event.reference != nil do
        " (ref: #{event.reference})"
      else
        ""
      end

    "#{prefix}#{event.title}#{suffix}"
  end

  def compose_footer(opts) do
    disclaimer = ""
    unsubscribe = ""

    if opts.legal do
      disclaimer = "This message is confidential."
    end

    if opts.marketing do
      unsubscribe = "Unsubscribe at any time."
    end

    Enum.join(Enum.reject([disclaimer, unsubscribe], &(&1 == "")), " | ")
  end
end
