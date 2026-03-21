defmodule CodeQA.CombinedMetrics.YamlFormatter do
  @moduledoc """
  Serialises a combined-metrics behavior map back to the hand-authored YAML format.

  Intended for internal use by `SampleRunner`. The output format preserves the
  conventions used across `priv/combined_metrics/*.yml`:

  - Behaviors sorted alphabetically
  - Meta-keys (`_doc`, `_fix_hint`, `_languages`, `_log_baseline`) emitted before
    group sections
  - Groups and keys within groups sorted alphabetically
  - Floats written with four decimal places
  """

  @doc """
  Serialises a `%{behavior => groups}` map to a YAML string.
  """
  @spec format(map()) :: String.t()
  def format(data) do
    lines =
      data
      |> Enum.sort_by(fn {behavior, _} -> behavior end)
      |> Enum.flat_map(fn {behavior, groups} -> behavior_lines(behavior, groups) end)

    Enum.join(lines, "\n") <> "\n"
  end

  # --- Behavior-level serialisation ---

  defp behavior_lines(behavior, groups) do
    doc_line = doc_line(Map.get(groups, "_doc"))
    baseline_line = baseline_line(Map.get(groups, "_log_baseline"))
    fix_hint_line = fix_hint_line(Map.get(groups, "_fix_hint"))
    languages_line = languages_line(Map.get(groups, "_languages"))
    group_lines = group_lines(groups)

    ["#{behavior}:" | doc_line] ++
      fix_hint_line ++ languages_line ++ baseline_line ++ group_lines ++ [""]
  end

  defp doc_line(nil), do: []
  defp doc_line(doc), do: ["  _doc: #{inspect(doc)}"]

  defp baseline_line(nil), do: []
  defp baseline_line(val), do: ["  _log_baseline: #{fmt_scalar(val)}"]

  defp fix_hint_line(nil), do: []
  defp fix_hint_line(hint), do: ["  _fix_hint: #{inspect(hint)}"]

  defp languages_line(nil), do: []
  defp languages_line([]), do: []
  defp languages_line(langs), do: ["  _languages: [#{Enum.join(langs, ", ")}]"]

  defp group_lines(groups) do
    groups
    |> Enum.filter(fn {k, v} ->
      k not in ["_doc", "_log_baseline", "_fix_hint", "_languages"] and is_map(v)
    end)
    |> Enum.sort_by(fn {group, _} -> group end)
    |> Enum.flat_map(fn {group, keys} ->
      key_lines =
        keys
        |> Enum.sort_by(fn {key, _} -> key end)
        |> Enum.map(fn {key, scalar} -> "    #{key}: #{fmt_scalar(scalar)}" end)

      ["  #{group}:" | key_lines]
    end)
  end

  defp fmt_scalar(f) when is_float(f), do: :erlang.float_to_binary(f, decimals: 4)
  defp fmt_scalar(n) when is_integer(n), do: "#{n}.0"
end
