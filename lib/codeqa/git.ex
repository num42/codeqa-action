defmodule CodeQA.Git do
  @moduledoc "Git operations for reading files at different refs."

  defmodule ChangedFile do
    @moduledoc false

    @enforce_keys [:path, :status]
    defstruct @enforce_keys
  end

  alias CodeQA.Engine.Collector

  @status_map %{"A" => "added", "M" => "modified", "D" => "deleted"}

  @spec gitignored_files(String.t(), [String.t()]) :: MapSet.t()
  def gitignored_files(_repo_path, []), do: MapSet.new()

  def gitignored_files(repo_path, paths) do
    {output, _exit_code} =
      System.cmd("git", ["check-ignore", "--no-index" | paths],
        cd: repo_path,
        stderr_to_stdout: false
      )

    output
    |> String.trim()
    |> String.split("\n", trim: true)
    |> MapSet.new()
  end

  def changed_files(repo_path, base_ref, head_ref) do
    {output, 0} =
      System.cmd(
        "git",
        ["diff", "--name-status", "--diff-filter=ADM", "#{base_ref}..#{head_ref}"],
        cd: repo_path,
        stderr_to_stdout: false
      )

    output
    |> String.trim()
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&parse_change_line/1)
  end

  @doc """
  Returns a map of file paths to lists of changed line ranges in the head version.

  Each range is a tuple `{start_line, end_line}` representing lines that were
  added or modified in the diff between base_ref and head_ref.
  """
  @spec diff_line_ranges(String.t(), String.t(), String.t()) ::
          {:ok, %{String.t() => [{pos_integer(), pos_integer()}]}} | {:error, term()}
  def diff_line_ranges(repo_path, base_ref, head_ref) do
    case System.cmd(
           "git",
           ["diff", "-U0", "#{base_ref}..#{head_ref}"],
           cd: repo_path,
           stderr_to_stdout: false
         ) do
      {output, 0} ->
        {:ok, parse_diff_hunks(output)}

      {_output, code} ->
        {:error, "git diff exited with code #{code}"}
    end
  end

  @typep parse_state :: {String.t() | nil, %{String.t() => [{pos_integer(), pos_integer()}]}}

  @spec parse_diff_hunks(String.t()) :: %{String.t() => [{pos_integer(), pos_integer()}]}
  defp parse_diff_hunks(diff_output) do
    diff_output
    |> String.split("\n")
    |> Enum.reduce({nil, %{}}, &parse_diff_line/2)
    |> elem(1)
    |> Map.new(fn {path, ranges} -> {path, Enum.reverse(ranges)} end)
  end

  @spec parse_diff_line(String.t(), parse_state()) :: parse_state()
  defp parse_diff_line("diff --git a/" <> rest, {_current_file, acc}) do
    # Extract the "b/..." path from the diff header
    case Regex.run(~r/ b\/(.+)$/, rest) do
      [_, path] -> {path, acc}
      nil -> {nil, acc}
    end
  end

  defp parse_diff_line("@@ " <> rest, {current_file, acc}) when is_binary(current_file) do
    # Parse hunk header: @@ -old_start,old_count +new_start,new_count @@
    case Regex.run(~r/\+(\d+)(?:,(\d+))?/, rest) do
      [_, start_str] ->
        # Single line change (no count means 1 line)
        start = String.to_integer(start_str)
        updated = Map.update(acc, current_file, [{start, start}], &[{start, start} | &1])
        {current_file, updated}

      [_, start_str, count_str] ->
        start = String.to_integer(start_str)
        count = String.to_integer(count_str)

        if count == 0 do
          # Deletion only, no new lines
          {current_file, acc}
        else
          end_line = start + count - 1
          updated = Map.update(acc, current_file, [{start, end_line}], &[{start, end_line} | &1])
          {current_file, updated}
        end

      nil ->
        {current_file, acc}
    end
  end

  defp parse_diff_line(_line, state), do: state

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

      _ ->
        []
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
    MapSet.member?(Collector.source_extensions(), ext)
  end
end
