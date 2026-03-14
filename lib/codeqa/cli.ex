defmodule CodeQA.CLI do
  @moduledoc false

  @commands %{
    "analyze" => CodeQA.CLI.Analyze,
    "compare" => CodeQA.CLI.Compare,
    "history" => CodeQA.CLI.History,
    "correlate" => CodeQA.CLI.Correlate,
    "stopwords" => CodeQA.CLI.Stopwords,
    "health-report" => CodeQA.CLI.HealthReport
  }

  def main(args) do
    case args do
      [cmd | rest] when is_map_key(@commands, cmd) -> @commands[cmd].run(rest)
      _ -> print_usage()
    end
  end

  defp print_usage do
    command_usages =
      @commands
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map(fn {_name, mod} -> mod.usage() end)
      |> Enum.join("\n")

    IO.puts("Usage: codeqa <command> [options]\n\n" <> command_usages)
  end
end
