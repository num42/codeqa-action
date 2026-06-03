defmodule SlugGenerator do
  @moduledoc """
  Turns titles into URL slugs. One job: string normalization.
  """

  @spec slugify(String.t()) :: String.t()
  def slugify(title) do
    title
    |> String.downcase()
    |> transliterate()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  @spec unique_slug(String.t(), list(String.t())) :: String.t()
  def unique_slug(title, existing) do
    base = slugify(title)
    if base in existing, do: disambiguate(base, existing, 2), else: base
  end

  defp disambiguate(base, existing, suffix) do
    candidate = "#{base}-#{suffix}"
    if candidate in existing, do: disambiguate(base, existing, suffix + 1), else: candidate
  end

  defp transliterate(string) do
    string
    |> String.replace("ä", "ae")
    |> String.replace("ö", "oe")
    |> String.replace("ü", "ue")
    |> String.replace("ß", "ss")
  end
end
