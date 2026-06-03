defmodule ConfigLoader do
  def load(nil), do: {:error, "config is nil"}

  def load(raw) do
    with {:ok, env} <- fetch_env(raw),
         {:ok, port} <- fetch_port(raw),
         {:ok, host} <- fetch_host(raw),
         :ok <- validate_env(env) do
      {:ok, %{env: env, port: port, host: host}}
    end
  end

  defp fetch_env(%{"env" => env}) when is_binary(env), do: {:ok, env}
  defp fetch_env(%{"env" => _}), do: {:error, "env must be a string"}
  defp fetch_env(_), do: {:error, "missing env"}

  defp fetch_port(%{"port" => port}) when is_integer(port) and port > 0, do: {:ok, port}
  defp fetch_port(%{"port" => _}), do: {:error, "invalid port"}
  defp fetch_port(_), do: {:ok, 4000}

  defp fetch_host(%{"host" => host}) when is_binary(host), do: {:ok, host}
  defp fetch_host(%{"host" => _}), do: {:error, "invalid host"}
  defp fetch_host(_), do: {:ok, "localhost"}

  defp validate_env(env) when env in ["dev", "test", "prod"], do: :ok
  defp validate_env(_), do: {:error, "unknown env"}
end
