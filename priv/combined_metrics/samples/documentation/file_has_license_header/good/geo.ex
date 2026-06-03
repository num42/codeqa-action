# Copyright (c) 2026 Cartographa Labs. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

defmodule MyApp.Geo do
  @moduledoc """
  Geospatial helpers for distance and bounding-box calculations.

  Operates on {latitude, longitude} tuples in decimal degrees.
  """

  @earth_radius_km 6_371.0

  @type coord :: {float(), float()}

  @spec haversine(coord(), coord()) :: float()
  def haversine({lat1, lon1}, {lat2, lon2}) do
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)

    a =
      :math.sin(dlat / 2) ** 2 +
        :math.cos(radians(lat1)) * :math.cos(radians(lat2)) * :math.sin(dlon / 2) ** 2

    @earth_radius_km * 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
  end

  @spec within?(coord(), coord(), float()) :: boolean()
  def within?(center, point, radius_km) do
    haversine(center, point) <= radius_km
  end

  @spec radians(float()) :: float()
  defp radians(degrees), do: degrees * :math.pi() / 180.0
end
