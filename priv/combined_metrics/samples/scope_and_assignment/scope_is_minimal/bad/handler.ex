defmodule Web.Handler do
  @moduledoc """
  Request handler — BAD: variables bound in outer scope and passed deep into nested blocks.
  """

  def handle_request(conn, params) do
    user_id = conn.assigns.current_user.id
    request_id = conn.assigns.request_id
    ip_address = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    timestamp = DateTime.utc_now()
    log_prefix = "[#{request_id}]"

    action = params["action"]
    resource = params["resource"]
    payload = params["data"]

    # user_id, ip_address, timestamp, log_prefix all carried far down
    case action do
      "create" ->
        case validate_payload(payload) do
          {:ok, validated} ->
            case check_permissions(user_id, resource, :write) do
              :allowed ->
                # log_prefix, timestamp, ip_address passed even deeper
                case persist(resource, validated, user_id) do
                  {:ok, record} ->
                    log_access(log_prefix, user_id, ip_address, timestamp, :create, :success)
                    {:ok, record}

                  {:error, reason} ->
                    log_access(log_prefix, user_id, ip_address, timestamp, :create, :failure)
                    {:error, reason}
                end

              :denied ->
                log_access(log_prefix, user_id, ip_address, timestamp, :create, :denied)
                {:error, :forbidden}
            end

          {:error, errors} ->
            {:error, {:validation, errors}}
        end

      "delete" ->
        case check_permissions(user_id, resource, :delete) do
          :allowed ->
            case persist_delete(resource, user_id) do
              {:ok, _} ->
                log_access(log_prefix, user_id, ip_address, timestamp, :delete, :success)
                :ok

              {:error, reason} ->
                log_access(log_prefix, user_id, ip_address, timestamp, :delete, :failure)
                {:error, reason}
            end

          :denied ->
            {:error, :forbidden}
        end

      _ ->
        {:error, :unknown_action}
    end
  end

  defp validate_payload(payload), do: {:ok, payload}
  defp check_permissions(_uid, _res, _mode), do: :allowed
  defp persist(_res, data, _uid), do: {:ok, data}
  defp persist_delete(_res, _uid), do: {:ok, nil}
  defp log_access(_prefix, _uid, _ip, _ts, _action, _result), do: :ok
end
