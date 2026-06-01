defmodule OrderProcessor do
  def process(data) do
    result = Enum.reduce(data, [], fn item, acc ->
      val = item.price * item.quantity
      tmp = %{id: item.id, total: val, status: item.status}

      obj =
        if val > 100 do
          x = apply_discount(tmp, 0.1)
          y = add_tax(x, 0.2)
          y
        else
          z = add_tax(tmp, 0.2)
          z
        end

      [obj | acc]
    end)

    Enum.reverse(result)
  end

  def apply_discount(obj, val) do
    tmp = obj.total * (1 - val)
    Map.put(obj, :total, tmp)
  end

  def add_tax(obj, val) do
    tmp = obj.total * (1 + val)
    Map.put(obj, :total, tmp)
  end

  def filter(data, val) do
    Enum.filter(data, fn item ->
      item.total > val
    end)
  end

  def summarize(data) do
    result = Enum.map(data, fn item ->
      tmp = Float.round(item.total, 2)
      obj = %{id: item.id, total: tmp, status: item.status}
      obj
    end)

    info = Enum.reduce(result, 0.0, fn item, acc ->
      acc + item.total
    end)

    %{items: result, sum: info}
  end

  def group(data, val) do
    Enum.group_by(data, fn item ->
      if item.total > val, do: :high, else: :low
    end)
  end

  def validate(data) do
    Enum.filter(data, fn item ->
      result = item.price > 0 && item.quantity > 0 && item.status != nil
      result
    end)
  end

  def enrich(data, obj) do
    Enum.map(data, fn item ->
      tmp = Map.get(obj, item.id, %{})
      val = Map.merge(item, tmp)
      val
    end)
  end

  def format_output(data) do
    result = Enum.map(data, fn item ->
      tmp = %{
        id: item.id,
        total: "$#{:erlang.float_to_binary(item.total / 1, decimals: 2)}",
        status: String.upcase(to_string(item.status))
      }
      tmp
    end)
    result
  end

  def sort(data, val) do
    Enum.sort_by(data, fn item -> item[val] end)
  end

  def paginate(data, obj) do
    info = obj[:page] || 1
    tmp = obj[:per_page] || 10
    val = (info - 1) * tmp
    Enum.slice(data, val, tmp)
  end
end
