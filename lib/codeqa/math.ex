defmodule CodeQA.Math do
  @moduledoc "Shared mathematical utilities using Nx."

  def linear_regression(x, y) do
    n = Nx.size(x) |> Nx.tensor(type: :f64)
    sum_x = Nx.sum(x)
    sum_y = Nx.sum(y)
    sum_xy = Nx.sum(Nx.multiply(x, y))
    sum_x2 = Nx.sum(Nx.multiply(x, x))

    slope =
      Nx.divide(
        Nx.subtract(Nx.multiply(n, sum_xy), Nx.multiply(sum_x, sum_y)),
        Nx.subtract(Nx.multiply(n, sum_x2), Nx.multiply(sum_x, sum_x))
      )

    intercept =
      Nx.divide(
        Nx.subtract(sum_y, Nx.multiply(slope, sum_x)),
        n
      )

    # R² calculation
    predicted = Nx.add(Nx.multiply(slope, x), intercept)
    ss_res = Nx.sum(Nx.pow(Nx.subtract(y, predicted), 2))
    mean_y = Nx.divide(sum_y, n)
    ss_tot = Nx.sum(Nx.pow(Nx.subtract(y, mean_y), 2))
    r_squared = Nx.subtract(1.0, Nx.divide(ss_res, Nx.add(ss_tot, 1.0e-10)))

    {slope, intercept, r_squared}
  end

  def pearson_correlation_list(x, y) do
    n = length(x)

    {sum_x, sum_y, sum_xy, sum_x2, sum_y2} =
      Enum.zip_reduce(x, y, {0.0, 0.0, 0.0, 0.0, 0.0}, fn vx, vy, {sx, sy, sxy, sx2, sy2} ->
        vx_f = vx * 1.0
        vy_f = vy * 1.0
        {sx + vx_f, sy + vy_f, sxy + vx_f * vy_f, sx2 + vx_f * vx_f, sy2 + vy_f * vy_f}
      end)

    num = n * sum_xy - sum_x * sum_y
    den_x = n * sum_x2 - sum_x * sum_x
    den_y = n * sum_y2 - sum_y * sum_y

    den = :math.sqrt(max(den_x * den_y, 0.0))

    if den == 0.0 do
      0.0
    else
      Float.round(num / den, 4)
    end
  end

  def pearson_correlation(x, y) do
    n = Nx.size(x) |> Nx.tensor(type: :f64)
    x = Nx.as_type(x, :f64)
    y = Nx.as_type(y, :f64)

    sum_x = Nx.sum(x)
    sum_y = Nx.sum(y)
    sum_xy = Nx.sum(Nx.multiply(x, y))
    sum_x2 = Nx.sum(Nx.multiply(x, x))
    sum_y2 = Nx.sum(Nx.multiply(y, y))

    num = Nx.subtract(Nx.multiply(n, sum_xy), Nx.multiply(sum_x, sum_y))
    den_x = Nx.subtract(Nx.multiply(n, sum_x2), Nx.multiply(sum_x, sum_x))
    den_y = Nx.subtract(Nx.multiply(n, sum_y2), Nx.multiply(sum_y, sum_y))

    den = Nx.sqrt(Nx.max(Nx.multiply(den_x, den_y), 0.0))

    # avoid division by zero
    if Nx.to_number(den) == 0.0 do
      0.0
    else
      Nx.to_number(Nx.divide(num, den)) |> Float.round(4)
    end
  end
end
