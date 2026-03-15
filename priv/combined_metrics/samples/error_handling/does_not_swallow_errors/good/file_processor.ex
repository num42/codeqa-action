defmodule FileProcessor do
  @moduledoc """
  Processes uploaded files and extracts their contents.
  """

  require Logger

  def process_file(path) do
    try do
      contents = File.read!(path)
      parsed = parse_contents(contents)
      {:ok, parsed}
    rescue
      e in File.Error ->
        Logger.error("Failed to read file at #{path}: #{Exception.message(e)}")
        {:error, {:read_failed, path}}
    end
  end

  def read_csv(path) do
    try do
      rows =
        path
        |> File.stream!()
        |> Enum.map(&String.trim/1)
        |> Enum.map(&parse_csv_row/1)

      {:ok, rows}
    rescue
      e in File.Error ->
        Logger.error("CSV read failed for #{path}: #{Exception.message(e)}")
        {:error, {:csv_read_failed, path}}
    end
  end

  def extract_metadata(path) do
    try do
      stat = File.stat!(path)
      {:ok, %{size: stat.size, modified: stat.mtime}}
    rescue
      e in File.Error ->
        Logger.warning("Could not stat file #{path}: #{Exception.message(e)}")
        {:error, {:stat_failed, path}}
    end
  end

  def batch_process(paths) do
    Enum.map(paths, fn path ->
      case process_file(path) do
        {:ok, result} -> {:ok, result}
        {:error, reason} ->
          Logger.warning("Skipping #{path} due to error: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  def validate_and_process(path) do
    if File.exists?(path) do
      process_file(path)
    else
      Logger.warning("Attempted to process non-existent file: #{path}")
      {:error, {:file_not_found, path}}
    end
  end

  def compress_file(path, dest) do
    try do
      contents = File.read!(path)
      compressed = :zlib.compress(contents)
      File.write!(dest, compressed)
      :ok
    rescue
      e in File.Error ->
        Logger.error("Compression failed for #{path} -> #{dest}: #{Exception.message(e)}")
        reraise e, __STACKTRACE__
    end
  end

  def delete_processed(path) do
    case File.rm(path) do
      :ok ->
        Logger.info("Deleted processed file: #{path}")
        :ok
      {:error, reason} ->
        Logger.error("Failed to delete #{path}: #{inspect(reason)}")
        {:error, {:delete_failed, reason}}
    end
  end

  defp parse_contents(contents) do
    String.split(contents, "\n")
  end

  defp parse_csv_row(row) do
    String.split(row, ",")
  end
end
