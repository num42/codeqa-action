defmodule CodeQA.Language do
  @callback name() :: String.t()
  @callback extensions() :: [String.t()]
  @callback comment_prefixes() :: [String.t()]
  @callback block_comments() :: [{String.t(), String.t()}]
  @callback keywords() :: [String.t()]
  @callback operators() :: [String.t()]
  @callback delimiters() :: [String.t()]

  @callback declaration_keywords() :: [String.t()]
  @callback branch_keywords() :: [String.t()]
  @callback block_end_tokens() :: [String.t()]
  @callback access_modifiers() :: [String.t()]
  @callback statement_keywords() :: [String.t()]

  @callback function_keywords() :: [String.t()]
  @callback module_keywords() :: [String.t()]
  @callback import_keywords() :: [String.t()]
  @callback test_keywords() :: [String.t()]
  @callback uses_colon_indent?() :: boolean()
  @callback divider_indicators() :: [String.t()]

  @optional_callbacks [
    declaration_keywords: 0,
    branch_keywords: 0,
    block_end_tokens: 0,
    access_modifiers: 0,
    statement_keywords: 0,
    function_keywords: 0,
    module_keywords: 0,
    import_keywords: 0,
    test_keywords: 0,
    uses_colon_indent?: 0,
    divider_indicators: 0
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour CodeQA.Language
      def declaration_keywords, do: []
      def branch_keywords, do: []
      def block_end_tokens, do: []
      def access_modifiers, do: []
      def statement_keywords, do: []
      def function_keywords, do: []
      def module_keywords, do: []
      def import_keywords, do: []
      def test_keywords, do: []
      def uses_colon_indent?, do: false
      def divider_indicators, do: ~w[-- - == === ~ * ** # // / =]

      defoverridable declaration_keywords: 0,
                     branch_keywords: 0,
                     block_end_tokens: 0,
                     access_modifiers: 0,
                     statement_keywords: 0,
                     function_keywords: 0,
                     module_keywords: 0,
                     import_keywords: 0,
                     test_keywords: 0,
                     uses_colon_indent?: 0,
                     divider_indicators: 0
    end
  end

  @spec all() :: [module()]
  def all do
    {:ok, modules} = :application.get_key(:codeqa, :modules)
    Enum.filter(modules, &implements?/1)
  end

  @spec all_keywords() :: [String.t()]
  def all_keywords do
    all()
    |> Enum.flat_map(& &1.keywords())
    |> Enum.uniq()
  end

  @spec keywords(atom() | String.t()) :: MapSet.t()
  def keywords(language) do
    case find(language) do
      nil -> MapSet.new()
      mod -> MapSet.new(mod.keywords())
    end
  end

  @spec operators(atom() | String.t()) :: MapSet.t()
  def operators(language) do
    case find(language) do
      nil -> MapSet.new()
      mod -> MapSet.new(mod.operators())
    end
  end

  @spec delimiters(atom() | String.t()) :: MapSet.t()
  def delimiters(language) do
    case find(language) do
      nil -> MapSet.new()
      mod -> MapSet.new(mod.delimiters())
    end
  end

  @spec declaration_keywords(module()) :: MapSet.t()
  def declaration_keywords(mod), do: MapSet.new(mod.declaration_keywords())

  @spec branch_keywords(module()) :: MapSet.t()
  def branch_keywords(mod), do: MapSet.new(mod.branch_keywords())

  @spec block_end_tokens(module()) :: MapSet.t()
  def block_end_tokens(mod), do: MapSet.new(mod.block_end_tokens())

  @spec access_modifiers(module()) :: MapSet.t()
  def access_modifiers(mod), do: MapSet.new(mod.access_modifiers())

  @spec statement_keywords(module()) :: MapSet.t()
  def statement_keywords(mod), do: MapSet.new(mod.statement_keywords())

  @spec function_keywords(module()) :: MapSet.t()
  def function_keywords(mod), do: MapSet.new(mod.function_keywords())

  @spec module_keywords(module()) :: MapSet.t()
  def module_keywords(mod), do: MapSet.new(mod.module_keywords())

  @spec import_keywords(module()) :: MapSet.t()
  def import_keywords(mod), do: MapSet.new(mod.import_keywords())

  @spec test_keywords(module()) :: MapSet.t()
  def test_keywords(mod), do: MapSet.new(mod.test_keywords())

  @spec divider_indicators(module()) :: MapSet.t()
  def divider_indicators(mod), do: MapSet.new(mod.divider_indicators())

  @spec find(atom() | String.t()) :: module()
  def find(language) do
    name = to_string(language)
    Enum.find(all(), fn mod -> mod.name() == name end) || CodeQA.Languages.Unknown
  end

  @spec detect(String.t()) :: module()
  def detect(path) do
    basename = Path.basename(path)
    ext = path |> Path.extname() |> String.trim_leading(".")

    Enum.find(all(), fn mod ->
      ext in mod.extensions() or (ext == "" and basename in mod.extensions())
    end) || CodeQA.Languages.Unknown
  end

  @spec strip_comments(String.t(), module()) :: String.t()
  def strip_comments(content, language_mod) do
    content
    |> strip_block_comments(language_mod.block_comments())
    |> strip_line_comments(language_mod.comment_prefixes())
  end

  defp strip_block_comments(content, []), do: content

  defp strip_block_comments(content, pairs) do
    Enum.reduce(pairs, content, fn {open, close}, acc ->
      regex = Regex.compile!(Regex.escape(open) <> ".*?" <> Regex.escape(close), [:dotall])

      Regex.replace(regex, acc, fn match ->
        String.replace(match, ~r/[^\n]/, "")
      end)
    end)
  end

  defp strip_line_comments(content, []), do: content

  defp strip_line_comments(content, prefixes) do
    pattern = prefixes |> Enum.map(&Regex.escape/1) |> Enum.join("|")
    Regex.replace(Regex.compile!("(#{pattern}).*$", [:multiline]), content, "")
  end

  defp implements?(module) do
    CodeQA.Language in (module.__info__(:attributes)[:behaviour] || [])
  rescue
    _ -> false
  end
end
