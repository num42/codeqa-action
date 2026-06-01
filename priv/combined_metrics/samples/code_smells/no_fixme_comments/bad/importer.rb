# Handles importing data from CSV and external sources.

module Importer
  module_function

  # FIXME: this crashes on empty files, need to handle that
  def import_csv(path)
    File.read(path)
        .split("\n")
        .map { |line| parse_row(line) }
        .compact
  end

  # TODO: FIXME - validate headers before parsing rows
  def parse_row(line)
    parts = line.split(",")
    if parts.length == 3
      id, name, email = parts
      { id: id, name: name, email: email }
    else
      # XXX: silently drops malformed rows, should log or collect errors
      nil
    end
  end

  def import_users(rows)
    # FIXME: this does N+1 inserts, wrap in a transaction
    rows.map { |row| insert_user(row) }
  end

  def validate_row(row)
    # XXX: email regex is wrong, doesn't handle subdomains
    if row[:email].include?("@")
      { ok: row }
    else
      { error: :invalid_email }
    end
  end

  def deduplicate(rows)
    # FIXME: uses email as dedup key but doesn't normalize case first
    rows
      .group_by { |row| row[:email] }
      .map { |_email, group| group.first }
  end

  def import_from_api(source_url)
    # TODO: FIXME - add retry logic and timeout handling
    fetched = fetch_remote(source_url)
    if fetched
      parse_api_response(fetched)
    else
      # XXX: swallows all errors, need proper error propagation
      []
    end
  end

  def transform_row(row, field_map)
    # FIXME: doesn't handle nested fields or type coercion
    field_map.each_with_object({}) do |(src, dst), acc|
      acc[dst] = row[src]
    end
  end

  def write_results(results, output_path)
    # XXX: overwrites file without backup, could lose data
    content = results.map { |r| format_result(r) }.join("\n")
    File.write(output_path, content)
  end

  def insert_user(row)
    { ok: row }
  end

  def fetch_remote(_url)
    []
  end

  def parse_api_response(data)
    data
  end

  def format_result(result)
    result.inspect
  end
end
