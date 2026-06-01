defmodule CodeQA.AST.Parsing.SignalRegistry do
  @moduledoc """
  Registry for structural and classification signals.

  Use `default/0` for the standard signal set. Compose custom registries
  with `register_structural/2` and `register_classification/2` for
  language-specific or analysis-specific configurations.
  """

  alias CodeQA.AST.Signals.Structural.AccessModifierSignal
  alias CodeQA.AST.Signals.Structural.AssignmentFunctionSignal
  alias CodeQA.AST.Signals.Structural.BlankLineSignal
  alias CodeQA.AST.Signals.Structural.BracketSignal
  alias CodeQA.AST.Signals.Structural.BranchSplitSignal
  alias CodeQA.AST.Signals.Structural.ColonIndentSignal
  alias CodeQA.AST.Signals.Structural.CommentDividerSignal
  alias CodeQA.AST.Signals.Structural.DecoratorSignal
  alias CodeQA.AST.Signals.Structural.DedentToZeroSignal
  alias CodeQA.AST.Signals.Structural.DocCommentLeadSignal
  alias CodeQA.AST.Signals.Structural.KeywordSignal
  alias CodeQA.AST.Signals.Structural.SQLBlockSignal
  alias CodeQA.AST.Signals.Structural.TripleQuoteSignal

  alias CodeQA.AST.Signals.Classification.AttributeSignal
  alias CodeQA.AST.Signals.Classification.CommentDensitySignal
  alias CodeQA.AST.Signals.Classification.ConfigSignal
  alias CodeQA.AST.Signals.Classification.DataSignal
  alias CodeQA.AST.Signals.Classification.DocSignal
  alias CodeQA.AST.Signals.Classification.FunctionSignal
  alias CodeQA.AST.Signals.Classification.ImportSignal
  alias CodeQA.AST.Signals.Classification.ModuleSignal
  alias CodeQA.AST.Signals.Classification.TestSignal
  alias CodeQA.AST.Signals.Classification.TypeSignal

  defstruct structural: [], classification: []

  @type t :: %__MODULE__{
          structural: [term()],
          classification: [term()]
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec register_structural(t(), term()) :: t()
  def register_structural(%__MODULE__{} = r, signal),
    do: %{r | structural: r.structural ++ [signal]}

  @spec register_classification(t(), term()) :: t()
  def register_classification(%__MODULE__{} = r, signal),
    do: %{r | classification: r.classification ++ [signal]}

  @spec default() :: t()
  def default,
    do:
      new()
      |> register_structural(%TripleQuoteSignal{})
      |> register_structural(%BlankLineSignal{})
      |> register_structural(%KeywordSignal{})
      |> register_structural(%AccessModifierSignal{})
      |> register_structural(%DecoratorSignal{})
      |> register_structural(%CommentDividerSignal{})
      |> register_structural(%DocCommentLeadSignal{})
      |> register_structural(%AssignmentFunctionSignal{})
      |> register_structural(%DedentToZeroSignal{})
      |> register_structural(%BranchSplitSignal{})
      |> register_structural(%BracketSignal{})
      |> register_classification(%DocSignal{})
      |> register_classification(%TestSignal{})
      |> register_classification(%FunctionSignal{})
      |> register_classification(%ModuleSignal{})
      |> register_classification(%ImportSignal{})
      |> register_classification(%AttributeSignal{})
      |> register_classification(%TypeSignal{})
      |> register_classification(%ConfigSignal{})
      |> register_classification(%DataSignal{})
      |> register_classification(%CommentDensitySignal{})

  @spec python() :: t()
  def python do
    r = default()
    %{r | structural: r.structural ++ [%ColonIndentSignal{}]}
  end

  @spec sql() :: t()
  def sql do
    r = default()
    %{r | structural: r.structural ++ [%SQLBlockSignal{}]}
  end
end
