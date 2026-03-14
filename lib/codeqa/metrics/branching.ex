defmodule CodeQA.Metrics.Branching do
  @moduledoc """
  Measures branching density as a proxy for cyclomatic complexity.

  Counts control-flow keywords relative to non-blank lines. High branching
  density indicates complex decision logic that is harder to test and reason about.

  Covers Python (if/elif/except/match), Ruby (elsif/unless/until/rescue/ensure),
  JavaScript (switch/catch/foreach), Elixir (cond/rescue/after), and
  C# (foreach/when).

  See [cyclomatic complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity).
  """

  @behaviour CodeQA.Metrics.FileMetric

  # Python:     if elif else for while try except finally with match case
  # Ruby:       if elsif else unless for while until case when begin rescue ensure
  # JavaScript: if else for while switch case try catch finally
  # Elixir:     if else unless case when cond with try rescue catch after
  # C#:         if else for foreach while switch case try catch finally when
  # Java:       if else for while switch case try catch finally instanceof synchronized
  # C++:        if else for while switch case try catch
  # Go:         if else for switch case select fallthrough
  # Rust:       if else for while loop match
  # PHP:        if elseif else for foreach while switch match try catch finally
  # Swift:      if else for while switch case guard repeat
  # Shell:      if then elif else fi for while until case esac
  # Kotlin:     if else for while when try catch finally
  # Note: `do` excluded — appears in every Elixir/Ruby/Kotlin block and inflates density.
  @branching_keywords MapSet.new(~w[
    if elif elsif elseif else unless
    for foreach while until loop repeat
    case when switch cond match select
    try catch rescue except finally ensure after
    begin with guard fallthrough
    then fi esac
  ])

  @doc "Returns the set of keywords counted as branching tokens."
  def branching_keywords, do: @branching_keywords

  @impl true
  def name, do: "branching"

  @impl true
  def analyze(%{lines: lines, tokens: tokens}) do
    non_blank_count =
      lines
      |> Tuple.to_list()
      |> Enum.count(&(String.trim(&1) != ""))

    branch_count =
      tokens
      |> Tuple.to_list()
      |> Enum.count(&MapSet.member?(@branching_keywords, &1))

    density =
      if non_blank_count > 0,
        do: Float.round(branch_count / non_blank_count, 4),
        else: 0.0

    %{"branching_density" => density}
  end
end
