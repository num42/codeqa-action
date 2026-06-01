defmodule CodeQA.CLI do
  @moduledoc false

  @commands %{
    "analyze" => CodeQA.CLI.Analyze,
    "history" => CodeQA.CLI.History,
    "correlate" => CodeQA.CLI.Correlate,
    "health-report" => CodeQA.CLI.HealthReport,
    "diagnose" => CodeQA.CLI.Diagnose
  }

  def main(args) do
    case args do
      [cmd | rest] when is_map_key(@commands, cmd) ->
        output = @commands[cmd].run(rest)
        unless output == "", do: IO.puts(output)
        output

      _ ->
        output = build_usage()
        IO.puts(output)
        output
    end
  end

  defp build_usage do
    command_usages =
      @commands
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map_join("\n", fn {_name, mod} -> mod.usage() end)

    "Usage: codeqa <command> [options]\n\n" <> command_usages
  end
end
