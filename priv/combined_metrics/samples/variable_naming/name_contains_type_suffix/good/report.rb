# Report generation without type suffixes in variable names.
# GOOD: variable names express what the data is, not what type it has.

class ReportGood
  def generate(params)
    user = format_user(params[:user])
    date = params[:date].strftime('%Y-%m-%d')
    title = build_title(params[:report_type])

    rows = fetch_rows(params[:filters])
    columns = params[:columns]
    tags = params[:tags] || []

    count = rows.length
    page_count = (count.to_f / params[:page_size]).ceil
    total = sum_total(rows)

    result = build_result(rows, columns)
    summary = compute_summary(rows)

    {
      title: title,
      generated_by: user,
      generated_on: date,
      rows: rows,
      tags: tags,
      count: count,
      pages: page_count,
      total: total,
      result: result,
      summary: summary
    }
  end

  def export_report(report, format)
    headers = extract_headers(report)
    data = extract_data(report)

    case format
    when 'csv'
      csv = render_csv(headers, data)
      { ok: true, data: csv }
    when 'json'
      json = report.to_json
      { ok: true, data: json }
    else
      { ok: false, error: "Unsupported format: #{format}" }
    end
  end

  def filter_rows(rows, criteria)
    rows.select do |row|
      criteria.all? { |key, value| row[key.to_sym] == value }
    end
  end

  def aggregate(rows, group_by)
    result = {}
    rows.each do |row|
      key = group_by.map { |field| row[field] }.join('|')
      result[key] = (result[key] || 0) + 1
    end
    result
  end

  def paginate(rows, page, page_size)
    start = (page - 1) * page_size
    rows[start, page_size] || []
  end

  private

  def format_user(user) = "#{user[:first_name]} #{user[:last_name]}"
  def build_title(type) = "#{type} Report"
  def fetch_rows(_filters) = []
  def sum_total(rows) = rows.sum { |r| r[:amount] || 0 }
  def build_result(rows, cols) = { rows: rows, columns: cols }
  def compute_summary(rows) = { count: rows.length }
  def extract_headers(report) = report.keys
  def extract_data(report) = [report.values]
  def render_csv(headers, data) = "#{headers.join(',')}\n#{data.inspect}"
end
