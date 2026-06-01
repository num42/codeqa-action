defprotocol CodeQA.AST.Parsing.Signal do
  @moduledoc """
  Protocol for token-stream signal emitters.

  A signal is a stateful detector that receives one token at a time and emits
  zero or more named values. All signals run independently over the same token
  stream — each gets its own full pass, carrying its own state.

  ## Protocol functions

  - `source/1`  — the implementing module; used for debugging emission traces
  - `group/1`   — atom grouping this signal's emissions (e.g. `:split`, `:enclosure`)
  - `init/2`    — returns initial state; called once before the token stream starts
  - `emit/3`    — called per token; returns `{MapSet.t({name, value}), new_state}`

  ## State

  State is owned externally (in `SignalStream`) as a positionally-aligned list.
  The signal defines the shape; the orchestrator threads it through unchanged.

  ## No-op emission

  To emit nothing for a token, return `{MapSet.new(), state}`.
  """

  @doc "The module that implements this signal — for debugging traces."
  @spec source(t) :: module()
  def source(signal)

  @doc "Group atom for all emissions from this signal (e.g. :split, :enclosure)."
  @spec group(t) :: atom()
  def group(signal)

  @doc "Returns the initial state for this signal."
  @spec init(t, module()) :: term()
  def init(signal, lang_mod)

  @doc """
  Called once per token. Returns a MapSet of `{name, value}` emission pairs
  and the updated state.
  """
  @spec emit(t, token :: term(), state :: term()) :: {MapSet.t(), term()}
  def emit(signal, token, state)
end
