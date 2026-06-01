# Report generation with type suffixes in variable names.
# BAD: variables include redundant type suffixes like _string, _list, _integer, _array, _hash.

class ReportBad
  def generate(params)
    user_string = format_user_string(params[:user])
    date_string = params[:date].strftime('%Y-%m-%d')
    title_string = build_title_string(params[:report_type])

    row_array = fetch_row_array(params[:filters])
    column_array = params[:columns]
    tag_array = params[:tags] || []

    count_integer = row_array.length
    page_count_integer = (count_integer.to_f / params[:page_size]).ceil
    total_integer = sum_total_integer(row_array)

    result_hash = build_result_hash(row_array, column_array)
    summary_hash = compute_summary_hash(row_array)

    {
      title: title_string,
      generated_by: user_string,
      generated_on: date_string,
      rows: row_array,
      tags: tag_array,
      count: count_integer,
      pages: page_count_integer,
      total: total_integer,
      result: result_hash,
      summary: summary_hash
    }
  end

  def export_report(report, format_string)
    header_array = extract_header_array(report)
    data_array = extract_data_array(report)

    case format_string
    when 'csv'
      csv_string = render_csv_string(header_array, data_array)
      { ok: true, data: csv_string }
    when 'json'
      json_string = report.to_json
      { ok: true, data: json_string }
    else
      { ok: false, error: "Unsupported format: #{format_string}" }
    end
  end

  def filter_rows(row_array, criteria_hash)
    row_array.select do |row|
      criteria_hash.all? { |key_string, value| row[key_string.to_sym] == value }
    end
  end

  def aggregate(row_array, group_by_array)
    result_hash = {}
    row_array.each do |row|
      key_string = group_by_array.map { |field| row[field] }.join('|')
      result_hash[key_string] = (result_hash[key_string] || 0) + 1
    end
    result_hash
  end

  def paginate(row_array, page_integer, page_size_integer)
    start_integer = (page_integer - 1) * page_size_integer
    row_array[start_integer, page_size_integer] || []
  end

  private

  def format_user_string(user) = "#{user[:first_name]} #{user[:last_name]}"
  def build_title_string(type) = "#{type} Report"
  def fetch_row_array(_filters) = []
  def sum_total_integer(rows) = rows.sum { |r| r[:amount] || 0 }
  def build_result_hash(rows, cols) = { rows: rows, columns: cols }
  def compute_summary_hash(rows) = { count: rows.length }
  def extract_header_array(report) = report.keys
  def extract_data_array(report) = [report.values]
  def render_csv_string(headers, data) = "#{headers.join(',')}\n#{data.inspect}"
end
