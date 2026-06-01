class Account
  # @@var is shared across the entire inheritance hierarchy
  @@default_plan = :free
  @@max_team_size = 5
  @@registered_count = 0

  def self.default_plan
    @@default_plan
  end

  def self.default_plan=(plan)
    @@default_plan = plan
  end

  def self.max_team_size
    @@max_team_size
  end

  def self.registered_count
    @@registered_count
  end

  attr_reader :email, :plan, :team_size

  def initialize(email:, plan: @@default_plan, team_size: 1)
    @email = email
    @plan = plan
    @team_size = team_size
    @@registered_count += 1
  end

  def upgrade_plan(new_plan)
    @plan = new_plan
  end

  def within_team_limit?
    team_size <= @@max_team_size
  end
end

class EnterpriseAccount < Account
  # Attempting to set subclass defaults, but @@vars are shared with Account
  # Setting @@default_plan here also changes Account.default_plan — a surprise
  @@default_plan = :enterprise
  @@max_team_size = 500
end
