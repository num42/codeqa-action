defmodule Forms.FormValidator do
  @moduledoc """
  Form field validation — BAD: validity booleans computed through nested
  conditionals returning true/false instead of direct comparisons.
  """

  def validate(field) do
    is_present =
      if field.value != nil do
        if field.value != "" do
          true
        else
          false
        end
      else
        false
      end

    is_valid_length =
      cond do
        not is_present -> false
        String.length(field.value) < field.min -> false
        String.length(field.value) > field.max -> false
        true -> true
      end

    is_required_ok =
      if field.required do
        if is_present do
          true
        else
          false
        end
      else
        true
      end

    %{present: is_present, valid_length: is_valid_length, required_ok: is_required_ok}
  end

  def email_flags(input) do
    has_at =
      case String.contains?(input, "@") do
        true -> true
        false -> false
      end

    has_domain =
      if has_at do
        if String.contains?(input, ".") do
          true
        else
          false
        end
      else
        false
      end

    %{has_at: has_at, has_domain: has_domain}
  end
end
