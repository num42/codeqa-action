# Query/struct builder — BAD: intermediate variables used exactly once.

require "uri"

class QueryBuilder
  def build_search_query(filters)
    base = Query.from("products")
    with_category = base.where(category: filters[:category])
    with_price = with_category.where_lte(:price, filters[:max_price])
    with_stock = with_price.where_gt(:stock, 0)
    ordered = with_stock.order_by(:inserted_at)
    limited = ordered.limit(filters[:limit])
    limited
  end

  def build_user_hash(attrs)
    name = attrs[:name].strip
    email = attrs[:email].downcase
    role = attrs[:role] || :guest
    user = { name: name, email: email, role: role }
    user
  end

  def format_report(data)
    title = data[:title].upcase
    header = "=== #{title} ==="
    rows = data[:rows].map { |r| format_row(r) }
    body = rows.join("\n")
    report = "#{header}\n#{body}"
    report
  end

  def build_notification(event)
    subject = "Event: #{event[:name]}"
    recipient = event[:user][:email]
    template = load_template(event[:type])
    rendered = render_template(template, event)
    notification = { subject: subject, to: recipient, body: rendered }
    notification
  end

  def compose_url(base_url, path, query_params)
    encoded = URI.encode_www_form(query_params)
    full_path = "#{path}?#{encoded}"
    url = "#{base_url}#{full_path}"
    url
  end

  private

  def format_row(row)
    label = row[:label]
    value = row[:value]
    line = "#{label}: #{value}"
    line
  end

  def load_template(type)
    name = "template_#{type}"
    name
  end

  def render_template(template, _event)
    template
  end
end

class Query
  def self.from(_); new; end
  def where(*); self; end
  def where_lte(*); self; end
  def where_gt(*); self; end
  def order_by(*); self; end
  def limit(*); self; end
end
