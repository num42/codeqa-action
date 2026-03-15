defmodule CodeQA.Metrics.BlockRules.BlankLineRule do
  @moduledoc """
  Detects top-level block boundaries at 2 or more consecutive blank lines.
  A blank line is <NL> optionally followed by <WS> tokens before the next <NL>.
  Returns {:split, idx} for the first substantive token after each blank-line run.
  """
  @behaviour CodeQA.Metrics.BlockRule

  @impl true
  def detect(tokens, _opts) do
    {_, _, _, splits} =
      tokens
      |> Enum.with_index()
      |> Enum.reduce({0, false, false, []}, fn {token, idx}, {nl_run, seen_content, _last_was_nl, splits} ->
        case token do
          "<NL>" ->
            {nl_run + 1, seen_content, true, splits}
          "<WS>" ->
            {nl_run, seen_content, false, splits}
          _ ->
            if seen_content and nl_run >= 2 do
              {0, true, false, [{:split, idx} | splits]}
            else
              {0, true, false, splits}
            end
        end
      end)

    Enum.reverse(splits)
  end
end
