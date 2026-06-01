# Handles importing data from CSV and external sources.

module Importer
  EMAIL_REGEX = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/.freeze

  module_function

  def import_csv(path)
    content = File.read(path)
    return { error: :empty_file } if content.empty?

    rows = content
           .split("\n")
           .reject { |line| line.strip.empty? }
           .map { |line| parse_row(line) }
           .compact

    { ok: rows }
  end

  def parse_row(line)
    parts = line.split(",")
    return nil unless parts.length == 3

    id, name, email = parts
    { id: id, name: name, email: email }
  end

  def import_users(rows)
    results = rows.map { |row| insert_user(row) }
    ok, errors = results.partition { |r| r.key?(:ok) }
    { ok: ok.length, errors: errors.length }
  end

  def validate_row(row)
    normalized = row[:email].downcase
    if EMAIL_REGEX.match?(normalized)
      { ok: row.merge(email: normalized) }
    else
      { error: :invalid_email }
    end
  end

  def deduplicate(rows)
    rows
      .map { |row| row.merge(email: row[:email].downcase) }
      .group_by { |row| row[:email] }
      .map { |_email, group| group.first }
  end

  def import_from_api(source_url)
    fetched = fetch_remote(source_url)
    return fetched if fetched.key?(:error)

    parse_api_response(fetched[:ok])
  end

  def transform_row(row, field_map)
    field_map.each_with_object({}) do |(src, dst), acc|
      acc[dst] = row[src]
    end
  end

  def write_results(results, output_path)
    backup_path = "#{output_path}.bak"
    FileUtils.cp(output_path, backup_path) if File.exist?(output_path)

    content = results.map { |r| format_result(r) }.join("\n")
    File.write(output_path, content)
    { ok: true }
  end

  def insert_user(row)
    { ok: row }
  end

  def fetch_remote(_url)
    { ok: [] }
  end

  def parse_api_response(data)
    { ok: data }
  end

  def format_result(result)
    result.inspect
  end
end
