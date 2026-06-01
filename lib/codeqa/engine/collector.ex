defmodule CodeQA.Engine.Collector do
  alias CodeQA.Config
  alias CodeQA.Git
  alias CodeQA.Language
  @moduledoc false

  @skip_dirs MapSet.new(~w[
    .git .hg .svn node_modules __pycache__ _build dist build vendor
    .tox .venv venv target .mypy_cache .pytest_cache deps .elixir_ls
    .next coverage
  ])

  @default_ignore_patterns ~w[**/*.md **/*.mdx]

  @spec source_extensions() :: MapSet.t()
  def source_extensions do
    Language.all()
    |> Enum.flat_map(& &1.extensions())
    |> Enum.map(&".#{&1}")
    |> MapSet.new()
  end

  @spec collect_files(String.t(), [String.t()]) :: %{String.t() => String.t()}
  def collect_files(root, extra_ignore_patterns \\ []) do
    root_path = Path.expand(root)
    Config.load(root_path)
    patterns = all_ignore_patterns(extra_ignore_patterns)
    extensions = source_extensions()

    unless File.dir?(root_path) do
      raise File.Error, reason: :enoent, path: root, action: "find directory"
    end

    files_map =
      root_path
      |> walk_directory(extensions)
      |> Map.new(fn path ->
        rel = Path.relative_to(path, root_path)
        {rel, File.read!(path)}
      end)
      |> do_reject_ignored_map(patterns)

    gitignored = Git.gitignored_files(root_path, Map.keys(files_map))
    Map.reject(files_map, fn {path, _} -> MapSet.member?(gitignored, path) end)
  end

  @doc false
  def ignored?(path, patterns) do
    patterns
    |> Enum.any?(&match_pattern?(path, &1))
  end

  @doc false
  def reject_ignored_map(files_map, extra_patterns \\ []) do
    do_reject_ignored_map(files_map, all_ignore_patterns(extra_patterns))
  end

  @doc false
  def reject_ignored(list, key_fn, extra_patterns \\ []) do
    patterns = all_ignore_patterns(extra_patterns)
    list |> Enum.reject(&ignored?(key_fn.(&1), patterns))
  end

  defp all_ignore_patterns(extra),
    do: extra ++ @default_ignore_patterns ++ Config.ignore_paths()

  defp do_reject_ignored_map(files_map, patterns) do
    Map.reject(files_map, fn {path, _} -> ignored?(path, patterns) end)
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

  defp walk_directory(dir, extensions) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn name ->
      full_path = Path.join(dir, name)

      cond do
        File.dir?(full_path) and not skip_dir?(name) ->
          walk_directory(full_path, extensions)

        File.regular?(full_path) and source_file?(name, extensions) and
            not String.starts_with?(name, ".") ->
          [full_path]

        true ->
          []
      end
    end)
  end

  defp skip_dir?(name), do: MapSet.member?(@skip_dirs, name) or String.starts_with?(name, ".")

  defp source_file?(name, extensions),
    do: MapSet.member?(extensions, Path.extname(name) |> String.downcase())
end
