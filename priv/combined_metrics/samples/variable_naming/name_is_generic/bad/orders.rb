class OrderProcessor
  def process(data)
    result = data.reduce([]) do |acc, item|
      val = item[:price] * item[:quantity]
      tmp = { id: item[:id], total: val, status: item[:status] }

      obj = if val > 100
        x = apply_discount(tmp, 0.1)
        add_tax(x, 0.2)
      else
        add_tax(tmp, 0.2)
      end

      acc + [obj]
    end

    result
  end

  def apply_discount(obj, val)
    tmp = obj[:total] * (1 - val)
    obj.merge(total: tmp)
  end

  def add_tax(obj, val)
    tmp = obj[:total] * (1 + val)
    obj.merge(total: tmp)
  end

  def filter(data, val)
    data.select { |item| item[:total] > val }
  end

  def summarize(data)
    result = data.map do |item|
      tmp = item[:total].round(2)
      { id: item[:id], total: tmp, status: item[:status] }
    end

    info = result.reduce(0.0) { |acc, item| acc + item[:total] }

    { items: result, sum: info }
  end

  def group(data, val)
    data.group_by do |item|
      item[:total] > val ? :high : :low
    end
  end

  def validate(data)
    data.select do |item|
      result = item[:price] > 0 && item[:quantity] > 0 && !item[:status].nil?
      result
    end
  end

  def enrich(data, obj)
    data.map do |item|
      tmp = obj[item[:id]] || {}
      val = item.merge(tmp)
      val
    end
  end

  def format_output(data)
    data.map do |item|
      tmp = {
        id: item[:id],
        total: "$#{format('%.2f', item[:total])}",
        status: item[:status].to_s.upcase
      }
      tmp
    end
  end

  def sort(data, val)
    data.sort_by { |item| item[val] }
  end

  def paginate(data, obj)
    info = obj[:page] || 1
    tmp = obj[:per_page] || 10
    val = (info - 1) * tmp
    data[val, tmp] || []
  end
end
