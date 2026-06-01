# Query/struct builder — GOOD: intermediate results are inlined or chained.

require "uri"

class QueryBuilder
  def build_search_query(filters)
    Query.from("products")
         .where(category: filters[:category])
         .where_lte(:price, filters[:max_price])
         .where_gt(:stock, 0)
         .order_by(:inserted_at)
         .limit(filters[:limit])
  end

  def build_user_hash(attrs)
    {
      name: attrs[:name].strip,
      email: attrs[:email].downcase,
      role: attrs[:role] || :guest
    }
  end

  def format_report(data)
    header = "=== #{data[:title].upcase} ==="
    body = data[:rows].map { |r| format_row(r) }.join("\n")
    "#{header}\n#{body}"
  end

  def build_notification(event)
    {
      subject: "Event: #{event[:name]}",
      to: event[:user][:email],
      body: render_template(load_template(event[:type]), event)
    }
  end

  def compose_url(base_url, path, query_params)
    "#{base_url}#{path}?#{URI.encode_www_form(query_params)}"
  end

  private

  def format_row(row)
    "#{row[:label]}: #{row[:value]}"
  end

  def load_template(type)
    "template_#{type}"
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
