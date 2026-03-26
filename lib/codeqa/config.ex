defmodule CodeQA.Config do
  @moduledoc "Loads and caches .codeqa.yml configuration via :persistent_term."

  @key {__MODULE__, :config}

  @default_impact %{
    "complexity" => 5,
    "file_structure" => 4,
    "function_design" => 4,
    "code_smells" => 3,
    "naming_conventions" => 2,
    "error_handling" => 2,
    "consistency" => 2,
    "documentation" => 1,
    "testing" => 1
  }

  defstruct ignore_paths: [],
            impact_map: @default_impact,
            combined_top: 2,
            cosine_significance_threshold: 0.15,
            near_duplicate_blocks: []

  @spec load(String.t()) :: :ok
  def load(path) do
    if :persistent_term.get(@key, nil) == nil do
      config = parse(path)
      :persistent_term.put(@key, config)
    end

    :ok
  end

  @spec reset() :: :ok
  def reset do
    :persistent_term.erase(@key)
    :ok
  end

  @spec ignore_paths() :: [String.t()]
  def ignore_paths, do: fetch().ignore_paths

  @spec impact_map() :: %{String.t() => pos_integer()}
  def impact_map, do: fetch().impact_map

  @spec combined_top() :: pos_integer()
  def combined_top, do: fetch().combined_top

  @spec cosine_significance_threshold() :: float()
  def cosine_significance_threshold, do: fetch().cosine_significance_threshold

  @spec near_duplicate_blocks_opts() :: keyword()
  def near_duplicate_blocks_opts, do: fetch().near_duplicate_blocks

  defp fetch do
    :persistent_term.get(@key, %__MODULE__{})
  end

  defp parse(path) do
    config_file = Path.join(path, ".codeqa.yml")

    case File.read(config_file) do
      {:ok, contents} ->
        case YamlElixir.read_from_string(contents) do
          {:ok, yaml} -> from_yaml(yaml)
          _ -> %__MODULE__{}
        end

      {:error, _} ->
        %__MODULE__{}
    end
  end

  defp from_yaml(yaml) do
    %__MODULE__{
      ignore_paths: parse_ignore_paths(yaml),
      impact_map: parse_impact(yaml),
      combined_top: Map.get(yaml, "combined_top", 2),
      cosine_significance_threshold: Map.get(yaml, "cosine_significance_threshold", 0.15),
      near_duplicate_blocks: parse_near_duplicate_blocks(yaml)
    }
  end

  defp parse_ignore_paths(%{"ignore_paths" => patterns}) when is_list(patterns), do: patterns
  defp parse_ignore_paths(_), do: []

  defp parse_impact(%{"impact" => overrides}) when is_map(overrides) do
    string_overrides = Map.new(overrides, fn {k, v} -> {to_string(k), v} end)
    Map.merge(@default_impact, string_overrides)
  end

  defp parse_impact(_), do: @default_impact

  defp parse_near_duplicate_blocks(%{"near_duplicate_blocks" => %{"max_pairs_per_bucket" => n}})
       when is_integer(n),
       do: [max_pairs_per_bucket: n]

  defp parse_near_duplicate_blocks(_), do: []
end
