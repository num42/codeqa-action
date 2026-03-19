defmodule CodeQA.Metrics.File.Compression do
  @moduledoc """
  Measures file redundancy via zlib compression ratio.

  Compresses the raw source with zlib and compares compressed size to the
  original. A high compression ratio signals repetitive or boilerplate-heavy
  code.

  See [Kolmogorov complexity](https://en.wikipedia.org/wiki/Kolmogorov_complexity)
  and [data compression ratio](https://en.wikipedia.org/wiki/Data_compression_ratio).
  """

  @behaviour CodeQA.Metrics.File.FileMetric

  @impl true
  def name, do: "compression"

  @impl true
  def keys, do: ["raw_bytes", "zlib_bytes", "zlib_ratio", "redundancy", "unique_line_ratio"]

  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{content: "", byte_count: 0}) do
    %{
      "raw_bytes" => 0,
      "zlib_bytes" => 0,
      "zlib_ratio" => 0.0,
      "redundancy" => 0.0,
      "unique_line_ratio" => 0.0
    }
  end

  def analyze(ctx) do
    raw_size = ctx.byte_count
    zlib_data = :zlib.compress(ctx.content)
    zlib_size = byte_size(zlib_data)

    non_blank = ctx.lines |> Enum.reject(&(String.trim(&1) == ""))

    unique_line_ratio =
      case length(non_blank) do
        0 -> 0.0
        n -> Float.round(length(Enum.uniq(non_blank)) / n, 4)
      end

    %{
      "raw_bytes" => raw_size,
      "zlib_bytes" => zlib_size,
      "zlib_ratio" => Float.round(raw_size / max(1, zlib_size), 4),
      "redundancy" => Float.round(max(0.0, 1.0 - zlib_size / raw_size), 4),
      "unique_line_ratio" => unique_line_ratio
    }
  end
end
