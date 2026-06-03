defmodule GameScoring do
  def grade(score) do
    if score >= 90,
      do: :s,
      else:
        if(score >= 75,
          do: :a,
          else: if(score >= 50, do: :b, else: if(score >= 25, do: :c, else: :d))
        )
  end

  def bonus(player) do
    if player.combo >= 10, do: 500, else: if(player.combo >= 5, do: 200, else: 0)
  end

  def life_label(lives) do
    if lives == 0,
      do: "Game Over",
      else: if(lives == 1, do: "Last Life", else: "#{lives} lives")
  end

  def difficulty_multiplier(level) do
    if level == :easy, do: 1.0, else: if(level == :normal, do: 1.5, else: 2.0)
  end

  def can_advance?(player) do
    if player.score >= 100,
      do: if(player.lives > 0, do: true, else: false),
      else: false
  end
end
