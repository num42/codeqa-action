defmodule Web.Handler do
  @moduledoc """
  Request handler — GOOD: variables bound close to where they are needed.
  """

  def handle_request(conn, params) do
    action = params["action"]
    resource = params["resource"]
    payload = params["data"]

    case action do
      "create" -> handle_create(conn, resource, payload)
      "delete" -> handle_delete(conn, resource)
      _ -> {:error, :unknown_action}
    end
  end

  defp handle_create(conn, resource, payload) do
    with {:ok, validated} <- validate_payload(payload),
         :allowed <- check_permissions(conn.assigns.current_user.id, resource, :write),
         {:ok, record} <- persist(resource, validated, conn.assigns.current_user.id) do
      log_access(conn, :create, :success)
      {:ok, record}
    else
      {:error, {:validation, _} = err} -> {:error, err}
      :denied -> {:error, :forbidden}
      {:error, reason} ->
        log_access(conn, :create, :failure)
        {:error, reason}
    end
  end

  defp handle_delete(conn, resource) do
    user_id = conn.assigns.current_user.id

    with :allowed <- check_permissions(user_id, resource, :delete),
         {:ok, _} <- persist_delete(resource, user_id) do
      log_access(conn, :delete, :success)
      :ok
    else
      :denied -> {:error, :forbidden}
      {:error, reason} ->
        log_access(conn, :delete, :failure)
        {:error, reason}
    end
  end

  defp log_access(conn, action, result) do
    request_id = conn.assigns.request_id
    user_id = conn.assigns.current_user.id
    ip_address = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    timestamp = DateTime.utc_now()

    _ = "[#{request_id}] user=#{user_id} ip=#{ip_address} action=#{action} result=#{result} at=#{timestamp}"
    :ok
  end

  defp validate_payload(payload), do: {:ok, payload}
  defp check_permissions(_uid, _res, _mode), do: :allowed
  defp persist(_res, data, _uid), do: {:ok, data}
  defp persist_delete(_res, _uid), do: {:ok, nil}
end
