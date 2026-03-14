defmodule CodeQA.Pipeline do
  @moduledoc "Pre-computed shared context for file-level metrics."

  defmodule FileContext do
    @moduledoc "Immutable pre-computed data shared across all file metrics."
    @enforce_keys [
      :content,
      :tokens,
      :token_counts,
      :words,
      :identifiers,
      :lines,
      :encoded,
      :byte_count,
      :line_count
    ]
    defstruct @enforce_keys
  end

  @word_re ~r/\b[a-zA-Z_]\w*\b/u

  # Reserved words and keywords for:
  # Python, Ruby, JavaScript, Elixir, C#,
  # Java, C++, Go, Rust, PHP, Swift, Shell, Kotlin
  @keywords MapSet.new(~w[
    if else elif elsif unless
    for foreach while until do
    return break continue yield pass
    try except finally rescue ensure after catch throw raise begin end throws
    case when switch cond match default fallthrough
    with as and or not in is
    import from require use using alias namespace package
    class def defp defmodule defmacro defmacrop defprotocol defimpl defguard defdelegate
    module interface struct enum delegate event protocol extension
    function fn func fun new delete typeof instanceof void
    var let val const static public private protected internal
    sealed override virtual abstract final readonly open
    async await receive suspend
    self super this Self
    extends implements
    null undefined nil None nullptr
    true false True False
    bool int float double long short byte char boolean string decimal object dynamic
    ref out params get set value inout
    lambda del global nonlocal assert
    type typealias
    synchronized volatile transient native strictfp
    auto register extern signed unsigned typedef sizeof union
    template typename operator inline friend explicit mutable constexpr decltype noexcept
    func chan go select defer range
    mut impl trait pub mod crate dyn unsafe loop where move
    echo print array list mixed never
    actor init deinit lazy open some any rethrows willSet didSet
    then fi done esac local export source unset declare
    fun val object data companion reified infix vararg expect actual
  ])

  @spec build_file_context(String.t(), keyword()) :: FileContext.t()
  def build_file_context(content, opts \\ []) when is_binary(content) do
    stopwords = Keyword.get(opts, :word_stopwords, MapSet.new())

    tokens = content |> String.split() |> List.to_tuple()
    token_list = Tuple.to_list(tokens)
    token_counts = Enum.frequencies(token_list)

    words =
      Regex.scan(@word_re, content)
      |> List.flatten()
      |> Enum.reject(&MapSet.member?(stopwords, &1))
      |> List.to_tuple()

    word_list = Tuple.to_list(words)
    identifiers = word_list |> Enum.reject(&MapSet.member?(@keywords, &1)) |> List.to_tuple()
    lines = content |> String.split("\n") |> trim_trailing_empty() |> List.to_tuple()
    encoded = content

    %FileContext{
      content: content,
      tokens: tokens,
      token_counts: token_counts,
      words: words,
      identifiers: identifiers,
      lines: lines,
      encoded: encoded,
      byte_count: byte_size(content),
      line_count: tuple_size(lines)
    }
  end

  defp trim_trailing_empty(lines) do
    # Match Python's str.splitlines() behavior
    case List.last(lines) do
      "" -> List.delete_at(lines, -1)
      _ -> lines
    end
  end
end
