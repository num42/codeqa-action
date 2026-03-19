defmodule CodeQA.AST.Parsing.SignalRegistry do
  @moduledoc """
  Registry for structural and classification signals.

  Use `default/0` for the standard signal set. Compose custom registries
  with `register_structural/2` and `register_classification/2` for
  language-specific or analysis-specific configurations.
  """

  alias CodeQA.AST.Signals.Structural.{
    AccessModifierSignal,
    AssignmentFunctionSignal,
    BlankLineSignal,
    BranchSplitSignal,
    BracketSignal,
    ColonIndentSignal,
    CommentDividerSignal,
    DecoratorSignal,
    DedentToZeroSignal,
    DocCommentLeadSignal,
    KeywordSignal,
    SQLBlockSignal,
    TripleQuoteSignal
  }

  alias CodeQA.AST.Signals.Classification.{
    AttributeSignal,
    CommentDensitySignal,
    ConfigSignal,
    DataSignal,
    DocSignal,
    FunctionSignal,
    ImportSignal,
    ModuleSignal,
    TestSignal,
    TypeSignal
  }

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
  def default do
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
  end

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
