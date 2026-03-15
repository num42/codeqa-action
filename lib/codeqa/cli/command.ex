defmodule CodeQA.CLI.Command do
  @moduledoc "Behaviour for CLI commands."

  @callback run([String.t()]) :: :ok
  @callback usage() :: String.t()
end
