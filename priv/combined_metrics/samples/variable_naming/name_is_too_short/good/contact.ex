defmodule Contact.Good do
  @moduledoc """
  Contact and profile management with clear, readable variable names.
  GOOD: user, price, count, name, status, email, phone — obvious at a glance.
  """

  @spec create(map()) :: {:ok, map()} | {:error, String.t()}
  def create(attrs) do
    name = Map.get(attrs, :name)
    email = Map.get(attrs, :email)
    phone = Map.get(attrs, :phone)
    status = Map.get(attrs, :status, :active)

    with :ok <- validate_email(email),
         :ok <- validate_phone(phone) do
      contact = %{name: name, email: email, phone: phone, status: status, id: generate_id()}
      {:ok, contact}
    end
  end

  @spec update(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def update(contact, attrs) do
    name = Map.get(attrs, :name, contact.name)
    email = Map.get(attrs, :email, contact.email)
    phone = Map.get(attrs, :phone, contact.phone)
    status = Map.get(attrs, :status, contact.status)

    with :ok <- validate_email(email),
         :ok <- validate_phone(phone) do
      {:ok, %{contact | name: name, email: email, phone: phone, status: status}}
    end
  end

  @spec search(list(map()), String.t()) :: list(map())
  def search(contacts, query) do
    Enum.filter(contacts, fn contact ->
      String.contains?(String.downcase(contact.name), String.downcase(query)) ||
        String.contains?(String.downcase(contact.email), String.downcase(query))
    end)
  end

  @spec group_by_status(list(map())) :: map()
  def group_by_status(contacts) do
    Enum.group_by(contacts, fn contact -> contact.status end)
  end

  @spec send_message(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def send_message(contact, message) do
    email = contact.email
    name = contact.name

    case deliver_email(email, name, message) do
      :ok -> {:ok, %{to: email, body: message, sent_at: DateTime.utc_now()}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec format_display(map()) :: String.t()
  def format_display(contact) do
    name = contact.name
    email = contact.email
    phone = contact.phone
    status = contact.status

    "#{name} <#{email}> | #{phone} [#{status}]"
  end

  defp validate_email(email) do
    if String.contains?(email, "@"), do: :ok, else: {:error, "Invalid email"}
  end

  defp validate_phone(phone) do
    if Regex.match?(~r/^\+?\d{7,15}$/, phone), do: :ok, else: {:error, "Invalid phone"}
  end

  defp generate_id, do: System.unique_integer([:positive])
  defp deliver_email(_email, _name, _message), do: :ok
end
