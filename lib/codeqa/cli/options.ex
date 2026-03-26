defmodule CodeQA.CLI.Options do
  @moduledoc false

  alias CodeQA.CLI.Progress

  @common_strict [
    workers: :integer,
    cache: :boolean,
    cache_dir: :string,
    timeout: :integer,
    show_ncd: :boolean,
    ncd_top: :integer,
    ncd_paths: :string,
    combinations: :boolean,
    show_files: :boolean,
    show_file_paths: :string,
    ignore_paths: :string,
    progress: :boolean,
    nodes_top: :integer
  ]

  @common_aliases [w: :workers, t: :timeout]

  @spec common_strict() :: keyword()
  def common_strict, do: @common_strict

  @spec common_aliases() :: keyword()
  def common_aliases, do: @common_aliases

  @spec parse(list(String.t()), keyword(), keyword()) :: {keyword(), list(String.t()), list()}
  def parse(args, extra_strict \\ [], extra_aliases \\ []) do
    OptionParser.parse(args,
      strict: Keyword.merge(@common_strict, extra_strict),
      aliases: Keyword.merge(@common_aliases, extra_aliases)
    )
  end

  @spec validate_dir!(String.t()) :: :ok
  def validate_dir!(path) do
    unless File.dir?(path) do
      IO.puts(:stderr, "Error: '#{path}' is not a directory")
      exit({:shutdown, 1})
    end

    :ok
  end

  @spec parse_ignore_paths(String.t() | nil) :: list(String.t())
  def parse_ignore_paths(nil), do: []

  def parse_ignore_paths(paths_string) do
    paths_string
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  @spec build_analyze_opts(keyword()) :: keyword()
  def build_analyze_opts(opts) do
    start_time_progress = System.monotonic_time(:millisecond)

    passthrough_keys = [
      :workers,
      :show_ncd,
      :ncd_top,
      :combinations,
      :nodes_top
    ]

    base =
      [{:timeout, opts[:timeout] || 5000}]
      |> maybe_add(
        opts[:progress],
        {:on_progress, fn c, t, p, _tt -> Progress.callback(c, t, p, start_time_progress) end}
      )
      |> maybe_add(opts[:cache], {:cache_dir, opts[:cache_dir] || ".codeqa_cache"})
      |> maybe_add(
        opts[:ncd_paths],
        {:ncd_paths, opts[:ncd_paths] && String.split(opts[:ncd_paths], ",")}
      )

    Enum.reduce(passthrough_keys, base, fn key, acc ->
      if opts[key], do: [{key, opts[key]} | acc], else: acc
    end)
  end

  @spec maybe_add(keyword(), any(), {atom(), any()}) :: keyword()
  def maybe_add(opts, val, item) do
    if val, do: [item | opts], else: opts
  end
end
