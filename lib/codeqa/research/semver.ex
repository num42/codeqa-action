defmodule CodeQA.Research.Semver do
  @moduledoc """
  Semver parsing, transition extraction, and jump classification.

  Rules based on research review (see docs/research/semver-analysis-review.md):
  - Pre-release tags are excluded
  - ALL 0.x.x transitions are excluded (pre-1.0 semantics differ from stable semver)
  - CalVer (MAJOR >= 2000) is excluded
  - 4th-position-only changes are :hotfix (reported separately)
  - Multi-skip transitions are flagged but included
  """

  @calver_threshold 2000

  @typedoc "Parsed version: {major, minor, patch, pre_release, fourth_pos}"
  @type parsed ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), String.t() | nil,
           non_neg_integer() | nil}

  @doc "Parse a version string. Returns {:ok, parsed} or :error."
  @spec parse(String.t()) :: {:ok, parsed()} | :error
  def parse(version) do
    # Strip leading 'v'
    v = String.trim_leading(version, "v")

    cond do
      # 4-position: 1.2.3.4
      match = Regex.run(~r/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/, v) ->
        [_, maj, min, patch, fourth] = match

        {:ok,
         {String.to_integer(maj), String.to_integer(min), String.to_integer(patch), nil,
          String.to_integer(fourth)}}

      # Standard with optional pre-release
      match = Regex.run(~r/^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9._-]+))?$/, v) ->
        [_ | parts] = match
        [maj, min, patch | rest] = parts

        pre =
          case rest do
            [pre] when pre != "" -> pre
            _ -> nil
          end

        {:ok,
         {String.to_integer(maj), String.to_integer(min), String.to_integer(patch), pre, nil}}

      true ->
        :error
    end
  end

  @doc "Classify the jump between two parsed versions."
  @spec classify_jump(parsed(), parsed()) :: :major | :minor | :patch | :hotfix | :exclude
  def classify_jump(from, to) do
    {from_maj, from_min, from_patch, from_pre, from_fourth} = from
    {to_maj, to_min, to_patch, to_pre, to_fourth} = to

    cond do
      # Pre-release involved → exclude
      from_pre != nil or to_pre != nil ->
        :exclude

      # CalVer → exclude
      from_maj >= @calver_threshold or to_maj >= @calver_threshold ->
        :exclude

      # ALL 0.x.x transitions → exclude (pre-1.0: "anything may change", no semver guarantees)
      from_maj == 0 or to_maj == 0 ->
        :exclude

      # MAJOR bump
      to_maj > from_maj ->
        :major

      # MINOR bump
      to_maj == from_maj and to_min > from_min ->
        :minor

      # 4th-position-only
      to_maj == from_maj and to_min == from_min and to_patch == from_patch and
        from_fourth != nil and to_fourth != nil and to_fourth > from_fourth ->
        :hotfix

      # PATCH bump
      to_maj == from_maj and to_min == from_min and to_patch > from_patch ->
        :patch

      true ->
        :exclude
    end
  end

  @doc """
  Given a list of tag maps (%{name: String, sha: String}), extract consecutive
  valid semver transitions, sorted chronologically (oldest → newest).

  Returns list of transition maps.
  """
  @spec extract_transitions(list(map())) :: list(map())
  def extract_transitions(tags) do
    tags
    |> Enum.flat_map(fn tag ->
      case parse(tag.name) do
        {:ok, parsed} -> [{parsed, tag}]
        :error -> []
      end
    end)
    |> Enum.sort_by(fn {{maj, min, patch, _, fourth}, _} -> {maj, min, patch, fourth || 0} end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [{from_parsed, from_tag}, {to_parsed, to_tag}] ->
      jump = classify_jump(from_parsed, to_parsed)

      case jump do
        :exclude ->
          []

        jump ->
          {f_maj, f_min, f_patch, _, _} = from_parsed
          {t_maj, t_min, t_patch, _, _} = to_parsed

          multi_skip =
            case jump do
              :major -> t_maj - f_maj > 1
              :minor -> t_min - f_min > 1
              :patch -> t_patch - f_patch > 1
              _ -> false
            end

          [
            %{
              from_tag: from_tag.name,
              from_sha: from_tag.sha,
              to_tag: to_tag.name,
              to_sha: to_tag.sha,
              jump: jump,
              multi_skip: multi_skip
            }
          ]
      end
    end)
  end
end
