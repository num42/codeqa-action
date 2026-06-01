class Account
  # Use instance variables on the class object instead of @@
  @default_plan = :free
  @max_team_size = 5
  @registered_count = 0

  class << self
    attr_accessor :default_plan, :max_team_size

    def registered_count
      @registered_count
    end

    def increment_registered_count
      @registered_count += 1
    end

    def reset_registered_count
      @registered_count = 0
    end
  end

  attr_reader :email, :plan, :team_size

  def initialize(email:, plan: Account.default_plan, team_size: 1)
    @email = email
    @plan = plan
    @team_size = team_size
    self.class.increment_registered_count
  end

  def upgrade_plan(new_plan)
    @plan = new_plan
  end

  def within_team_limit?
    team_size <= self.class.max_team_size
  end
end

class EnterpriseAccount < Account
  @default_plan = :enterprise
  @max_team_size = 500

  # Enterprise subclass has its own independent class-level state
  # This would not be possible with @@ which leaks across the hierarchy
end
