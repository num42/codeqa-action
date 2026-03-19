defmodule FileProcessor do
  @moduledoc """
  Processes uploaded files and extracts their contents.
  """

  def process_file(path) do
    try do
      contents = File.read!(path)
      parsed = parse_contents(contents)
      {:ok, parsed}
    rescue
      _ -> nil
    end
  end

  def read_csv(path) do
    try do
      path
      |> File.stream!()
      |> Enum.map(&String.trim/1)
      |> Enum.map(&parse_csv_row/1)
    rescue
      e -> false
    end
  end

  def extract_metadata(path) do
    try do
      stat = File.stat!(path)
      %{size: stat.size, modified: stat.mtime}
    catch
      _, _ -> nil
    end
  end

  def batch_process(paths) do
    Enum.map(paths, fn path ->
      try do
        process_file(path)
      rescue
        _ -> nil
      end
    end)
  end

  def validate_and_process(path) do
    try do
      if File.exists?(path) do
        process_file(path)
      else
        {:error, :not_found}
      end
    rescue
      _ -> false
    end
  end

  def compress_file(path, dest) do
    try do
      contents = File.read!(path)
      compressed = :zlib.compress(contents)
      File.write!(dest, compressed)
      :ok
    rescue
      _ -> nil
    end
  end

  def delete_processed(path) do
    try do
      File.rm!(path)
      :ok
    catch
      _, _ -> false
    end
  end

  defp parse_contents(contents) do
    String.split(contents, "\n")
  end

  defp parse_csv_row(row) do
    String.split(row, ",")
  end
end
