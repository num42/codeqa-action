defmodule Contact.Bad do
  @moduledoc """
  Contact and profile management with overly short variable names.
  BAD: variables like u, pr, ct, nm, st, em, ph are cryptic non-loop identifiers.
  """

  @spec create(map()) :: {:ok, map()} | {:error, String.t()}
  def create(attrs) do
    nm = Map.get(attrs, :name)
    em = Map.get(attrs, :email)
    ph = Map.get(attrs, :phone)
    st = Map.get(attrs, :status, :active)

    with :ok <- validate_em(em),
         :ok <- validate_ph(ph) do
      ct = %{name: nm, email: em, phone: ph, status: st, id: generate_id()}
      {:ok, ct}
    end
  end

  @spec update(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def update(ct, attrs) do
    nm = Map.get(attrs, :name, ct.name)
    em = Map.get(attrs, :email, ct.email)
    ph = Map.get(attrs, :phone, ct.phone)
    st = Map.get(attrs, :status, ct.status)

    with :ok <- validate_em(em),
         :ok <- validate_ph(ph) do
      {:ok, %{ct | name: nm, email: em, phone: ph, status: st}}
    end
  end

  @spec search(list(map()), String.t()) :: list(map())
  def search(ct_list, qr) do
    Enum.filter(ct_list, fn ct ->
      String.contains?(String.downcase(ct.name), String.downcase(qr)) ||
        String.contains?(String.downcase(ct.email), String.downcase(qr))
    end)
  end

  @spec group_by_status(list(map())) :: map()
  def group_by_status(ct_list) do
    Enum.group_by(ct_list, fn ct -> ct.status end)
  end

  @spec send_message(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def send_message(ct, mg) do
    em = ct.email
    nm = ct.name

    case deliver_email(em, nm, mg) do
      :ok -> {:ok, %{to: em, body: mg, sent_at: DateTime.utc_now()}}
      {:error, rs} -> {:error, rs}
    end
  end

  @spec format_display(map()) :: String.t()
  def format_display(ct) do
    nm = ct.name
    em = ct.email
    ph = ct.phone
    st = ct.status

    "#{nm} <#{em}> | #{ph} [#{st}]"
  end

  defp validate_em(em) do
    if String.contains?(em, "@"), do: :ok, else: {:error, "Invalid email"}
  end

  defp validate_ph(ph) do
    if Regex.match?(~r/^\+?\d{7,15}$/, ph), do: :ok, else: {:error, "Invalid phone"}
  end

  defp generate_id, do: System.unique_integer([:positive])
  defp deliver_email(_em, _nm, _mg), do: :ok
end
