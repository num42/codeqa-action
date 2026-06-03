defmodule ConfigLoader do
  def load(raw) do
    if raw != nil do
      if Map.has_key?(raw, "env") do
        if is_binary(raw["env"]) do
          if raw["env"] in ["dev", "test", "prod"] do
            port =
              case Map.get(raw, "port") do
                nil -> 4000
                p -> p
              end

            if is_integer(port) and port > 0 do
              host = Map.get(raw, "host", "localhost")

              if is_binary(host) do
                {:ok, %{env: raw["env"], port: port, host: host}}
              else
                {:error, "invalid host"}
              end
            else
              {:error, "invalid port"}
            end
          else
            {:error, "unknown env"}
          end
        else
          {:error, "env must be a string"}
        end
      else
        {:error, "missing env"}
      end
    else
      {:error, "config is nil"}
    end
  end
end
