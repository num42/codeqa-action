defmodule CodeQA.CLI.Command do
  @moduledoc "Behaviour for CLI commands."

  @callback run([String.t()]) :: String.t()
  @callback usage() :: String.t()
end
