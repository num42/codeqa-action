defmodule GameScoring do
  def grade(score) do
    cond do
      score >= 90 -> :s
      score >= 75 -> :a
      score >= 50 -> :b
      score >= 25 -> :c
      true -> :d
    end
  end

  def bonus(%{combo: combo}) when combo >= 10, do: 500
  def bonus(%{combo: combo}) when combo >= 5, do: 200
  def bonus(%{combo: _combo}), do: 0

  def life_label(0), do: "Game Over"
  def life_label(1), do: "Last Life"
  def life_label(lives), do: "#{lives} lives"

  def difficulty_multiplier(:easy), do: 1.0
  def difficulty_multiplier(:normal), do: 1.5
  def difficulty_multiplier(:hard), do: 2.0

  def can_advance?(%{score: score, lives: lives}) when score >= 100 and lives > 0, do: true
  def can_advance?(%{}), do: false
end
