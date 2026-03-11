defmodule CodeQA.Collector do
  @moduledoc false

  @source_extensions MapSet.new(~w[
    .py .js .ts .jsx .tsx .java .rs .go .c .cpp .h .hpp .rb .ex .exs
    .swift .kt .scala .sh .css .scss .html .vue .svelte .zig .lua .pl
    .pm .r .jl .cs .fs .ml .hs .erl .clj .dart
  ])

  @skip_dirs MapSet.new(~w[
    .git .hg .svn node_modules __pycache__ _build dist build vendor
    .tox .venv venv target .mypy_cache .pytest_cache deps .elixir_ls
    .next coverage
  ])

  @spec collect_files(String.t(), keyword()) :: %{String.t() => String.t()}
  def collect_files(root, opts \\ []) do
    root_path = Path.expand(root)
    ignore_patterns = Keyword.get(opts, :ignore_patterns, [])

    unless File.dir?(root_path) do
      raise File.Error, reason: :enoent, path: root, action: "find directory"
    end

    root_path
    |> walk_directory()
    |> Map.new(fn path ->
      rel = Path.relative_to(path, root_path)
      {rel, File.read!(path)}
    end)
    |> reject_ignored_map(ignore_patterns)
  end

  def source_extensions, do: @source_extensions

  @doc false
  def ignored?(path, patterns) do
    Enum.any?(patterns, fn pattern ->
      match_pattern?(path, pattern)
    end)
  end

  @doc false
  def reject_ignored_map(files_map, []), do: files_map
  def reject_ignored_map(files_map, patterns) do
    Map.reject(files_map, fn {path, _} -> ignored?(path, patterns) end)
  end

  @doc false
  def reject_ignored(list, [], _key_fn), do: list
  def reject_ignored(list, patterns, key_fn) do
    Enum.reject(list, fn item -> ignored?(key_fn.(item), patterns) end)
  end

  defp match_pattern?(path, pattern) do
    # Convert glob pattern to regex:
    # - ** matches any number of directories
    # - * matches anything except /
    # - ? matches a single character except /
    regex_str =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("**", "\0GLOBSTAR\0")
      |> String.replace("*", "[^/]*")
      |> String.replace("?", "[^/]")
      |> String.replace("\0GLOBSTAR\0", ".*")

    case Regex.compile("^#{regex_str}$") do
      {:ok, regex} -> Regex.match?(regex, path)
      _ -> false
    end
  end

  defp walk_directory(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      full_path = Path.join(dir, entry)

      cond do
        File.dir?(full_path) and not skip_dir?(entry) ->
          walk_directory(full_path)

        File.regular?(full_path) and source_file?(entry) ->
          [full_path]

        true ->
          []
      end
    end)
  end

  defp skip_dir?(name), do: MapSet.member?(@skip_dirs, name) or String.starts_with?(name, ".")
  defp source_file?(name), do: MapSet.member?(@source_extensions, Path.extname(name) |> String.downcase())
end
