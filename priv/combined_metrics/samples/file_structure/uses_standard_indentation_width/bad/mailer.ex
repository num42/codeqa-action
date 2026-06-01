defmodule Mailer do
    @moduledoc """
    Sends transactional emails.
    """

    @from_address "noreply@example.com"

    def send_welcome(user) do
        body = build_welcome_body(user)
        dispatch(%{
            to: user.email,
            from: @from_address,
            subject: "Welcome to the platform",
            body: body
        })
    end

    def send_password_reset(user, token) do
        link = reset_link(token)
        body = build_reset_body(user, link)
        dispatch(%{
            to: user.email,
            from: @from_address,
            subject: "Reset your password",
            body: body
        })
    end

    def send_invoice(user, invoice) do
        case format_invoice(invoice) do
            {:ok, formatted} ->
                dispatch(%{
                    to: user.email,
                    from: @from_address,
                    subject: "Your invoice ##{invoice.id}",
                    body: formatted
                })
            {:error, reason} ->
                {:error, reason}
        end
    end

    def send_notification(user, message) do
        if String.length(message) > 0 do
            dispatch(%{
                to: user.email,
                from: @from_address,
                subject: "Notification",
                body: message
            })
        else
            {:error, :empty_message}
        end
    end

    def send_bulk(users, subject, body) do
        Enum.map(users, fn user ->
            dispatch(%{
                to: user.email,
                from: @from_address,
                subject: subject,
                body: body
            })
        end)
    end

    defp build_welcome_body(user) do
        "Hi #{user.name}, welcome aboard!"
    end

    defp build_reset_body(user, link) do
        "Hi #{user.name}, reset your password here: #{link}"
    end

    defp reset_link(token) do
        "https://example.com/reset?token=#{token}"
    end

    defp format_invoice(invoice) do
        {:ok, "Invoice ##{invoice.id}: $#{invoice.total}"}
    end

    defp dispatch(email) do
        {:ok, email}
    end
end
