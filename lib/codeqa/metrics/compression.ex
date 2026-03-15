defmodule CodeQA.Metrics.Compression do
  @moduledoc """
  Measures file redundancy via zlib compression ratio.

  Compresses the raw source with zlib and compares compressed size to the
  original. A high compression ratio signals repetitive or boilerplate-heavy
  code.

  `ctx.encoded` is the binary representation of the file content used for
  compression, distinct from `ctx.content` which is the UTF-8 string.

  See [Kolmogorov complexity](https://en.wikipedia.org/wiki/Kolmogorov_complexity)
  and [data compression ratio](https://en.wikipedia.org/wiki/Data_compression_ratio).
  """

  @behaviour CodeQA.Metrics.FileMetric

  @impl true
  def name, do: "compression"

  @impl true
  def keys, do: ["raw_bytes", "zlib_bytes", "zlib_ratio", "redundancy"]


  @spec analyze(map()) :: map()
  @impl true
  def analyze(%{content: "", byte_count: 0}) do
    %{"raw_bytes" => 0, "zlib_bytes" => 0, "zlib_ratio" => 0.0, "redundancy" => 0.0}
  end

  def analyze(ctx) do
    raw_size = ctx.byte_count
    zlib_data = :zlib.compress(ctx.encoded)
    zlib_size = byte_size(zlib_data)

    %{
      "raw_bytes" => raw_size,
      "zlib_bytes" => zlib_size,
      "zlib_ratio" => Float.round(raw_size / max(1, zlib_size), 4),
      "redundancy" => Float.round(max(0.0, 1.0 - zlib_size / raw_size), 4)
    }
  end
end
