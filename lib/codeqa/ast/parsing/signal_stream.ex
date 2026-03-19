defmodule CodeQA.AST.Parsing.SignalStream do
  @moduledoc """
  Runs a list of `Signal` implementations over a token stream.

  Each signal receives its own full pass over the token stream and accumulates
  its own state. Signals are independent — no shared state, no cross-signal
  coordination.

  ## Return value

  Returns a list of emission lists, one per signal, in the same order as the
  input signal list. Each emission is a 4-tuple:

      {source, group, name, value}

  ## Usage

      SignalStream.run(tokens, [%BlankLineSignal{}, %KeywordSignal{}], [])
      # => [[{BlankLineSignal, :split, :blank_split, 5}, ...], [...]]
  """

  alias CodeQA.AST.Parsing.Signal

  @spec run([term()], [term()], module()) :: [list()]
  def run(tokens, signals, lang_mod) do
    prevs = [nil | tokens]
    nexts = Enum.drop(tokens, 1) ++ [nil]
    triples = Enum.zip_with([prevs, tokens, nexts], fn [p, c, n] -> {p, c, n} end)

    Enum.map(signals, fn signal ->
      init_state = Signal.init(signal, lang_mod)
      source = Signal.source(signal)
      group = Signal.group(signal)

      {_final_state, emissions} =
        Enum.reduce_while(triples, {init_state, []}, fn triple, {state, acc} ->
          {emitted, new_state} = Signal.emit(signal, triple, state)

          new_acc =
            emitted
            |> Enum.map(fn {name, value} -> {source, group, name, value} end)
            |> Enum.reduce(acc, fn e, a -> [e | a] end)

          if new_state == :halt do
            {:halt, {new_state, new_acc}}
          else
            {:cont, {new_state, new_acc}}
          end
        end)

      Enum.reverse(emissions)
    end)
  end
end
