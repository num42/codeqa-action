defmodule CodeQA.Analysis.FileContextServer do
  @moduledoc """
  Per-run GenServer that memoizes `Pipeline.build_file_context/2` by
  `{MD5(content), language_name}`.

  Cache key includes the resolved language name because different languages
  produce different keyword/operator sets, yielding different identifiers from
  the same content.

  ETS layout: `{md5_binary, language_name} => FileContext.t()`

  On a cache miss, the calling process builds the context directly and inserts
  it into the shared ETS table — no GenServer mailbox round-trip for the
  computation itself.
  """

  use GenServer

  alias CodeQA.Engine.{FileContext, Pipeline}
  alias CodeQA.Language
  alias CodeQA.Languages.Unknown

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Returns the ETS table id. Callers may read directly from it."
  @spec get_tid(pid()) :: :ets.tid()
  def get_tid(pid), do: GenServer.call(pid, :get_tid)

  @doc """
  Returns a cached (or freshly built) `FileContext` for `content`.

  The language is resolved from `opts` (`:language` or `:path`); defaults to
  `Unknown`.
  """
  @spec get(pid(), String.t(), keyword()) :: FileContext.t()
  def get(pid, content, opts \\ []) do
    tid = get_tid(pid)
    language_name = resolve_language_name(opts)
    key = {md5(content), language_name}

    case :ets.lookup(tid, key) do
      [{_, ctx}] ->
        ctx

      [] ->
        ctx = Pipeline.build_file_context(content, opts)
        :ets.insert(tid, {key, ctx})
        ctx
    end
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    tid = :ets.new(:file_context, [:set, :public, read_concurrency: true])
    {:ok, %{tid: tid}}
  end

  @impl true
  def handle_call(:get_tid, _from, state) do
    {:reply, state.tid, state}
  end

  # --- Private helpers ---

  defp md5(content), do: :crypto.hash(:md5, content)

  defp resolve_language_name(opts) do
    cond do
      lang = Keyword.get(opts, :language) ->
        mod = Language.find(lang) || Unknown
        mod.name()

      path = Keyword.get(opts, :path) ->
        Language.detect(path).name()

      true ->
        Unknown.name()
    end
  end
end
