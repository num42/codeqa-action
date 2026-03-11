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

  @spec collect_files(String.t()) :: %{String.t() => String.t()}
  def collect_files(root) do
    root_path = Path.expand(root)

    unless File.dir?(root_path) do
      raise File.Error, reason: :enoent, path: root, action: "find directory"
    end

    root_path
    |> walk_directory()
    |> Map.new(fn path ->
      rel = Path.relative_to(path, root_path)
      {rel, File.read!(path)}
    end)
  end

  def source_extensions, do: @source_extensions

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
