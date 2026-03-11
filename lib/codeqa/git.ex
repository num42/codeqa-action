defmodule CodeQA.Git do
  @moduledoc "Git operations for reading files at different refs."

  defmodule ChangedFile do
    @moduledoc false

    @enforce_keys [:path, :status]
    defstruct @enforce_keys
  end

  @status_map %{"A" => "added", "M" => "modified", "D" => "deleted"}

  def changed_files(repo_path, base_ref, head_ref) do
    {output, 0} =
      System.cmd("git", ["diff", "--name-status", "--diff-filter=ADM", "#{base_ref}..#{head_ref}"],
        cd: repo_path, stderr_to_stdout: false)

    output
    |> String.trim()
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&parse_change_line/1)
  end

  def read_file_at_ref(repo_path, ref, path) do
    case System.cmd("git", ["show", "#{ref}:#{path}"], cd: repo_path, stderr_to_stdout: true) do
      {output, 0} -> output
      {_error, _code} -> nil
    end
  end

  def collect_files_at_ref(repo_path, ref, paths \\ nil) do
    paths = paths || list_source_files_at_ref(repo_path, ref)

    paths
    |> Enum.reduce(%{}, fn path, acc ->
      case read_file_at_ref(repo_path, ref, path) do
        nil -> acc
        content -> Map.put(acc, path, content)
      end
    end)
  end

  defp parse_change_line(line) do
    case String.split(line, "\t", parts: 2) do
      [status_code, path] when byte_size(status_code) > 0 ->
        status = Map.get(@status_map, String.first(status_code), "modified")
        if source_file?(path), do: [%ChangedFile{path: path, status: status}], else: []
      _ -> []
    end
  end

  defp list_source_files_at_ref(repo_path, ref) do
    {output, 0} = System.cmd("git", ["ls-tree", "-r", "--name-only", ref], cd: repo_path)

    output
    |> String.trim()
    |> String.split("\n", trim: true)
    |> Enum.filter(&source_file?/1)
  end

  defp source_file?(path) do
    ext = path |> Path.extname() |> String.downcase()
    MapSet.member?(CodeQA.Collector.source_extensions(), ext)
  end
end
