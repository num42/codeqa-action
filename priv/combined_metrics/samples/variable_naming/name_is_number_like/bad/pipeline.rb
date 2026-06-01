# Data pipeline with number-suffixed variable names.
# BAD: variables like var1, user2, item3, step2 give no hint about their purpose.

class PipelineBad
  def run(input)
    var1 = validate(input)
    var2 = normalize(var1)
    var3 = enrich(var2)
    var4 = transform(var3)
    var5 = format_output(var4)
    { ok: true, data: var5 }
  rescue => e
    { ok: false, error: e.message }
  end

  def process_users(users)
    user1 = filter_active(users)
    user2 = load_profiles(user1)
    user3 = apply_permissions(user2)
    user4 = sort_users(user3)
    user4
  end

  def deduplicate(items)
    item1 = items.sort
    item2 = item1.uniq
    item3 = item2.compact
    item3
  end

  def retry_operation(func, max_attempts)
    result1 = attempt(func)
    return result1 if result1[:ok]

    result2 = attempt(func)
    return result2 if result2[:ok]

    result3 = attempt(func)
    return result3 if result3[:ok]

    { ok: false, error: 'All retries failed' }
  end

  def merge_records(record1, record2)
    step1 = record1.merge(record2)
    step2 = clean_nulls(step1)
    step3 = add_metadata(step2)
    phase1 = validate_merged(step3)
    phase1
  end

  def batch_process(items, size)
    value1 = items.each_slice(size).to_a
    value2 = value1.map { |batch| process_batch(batch) }
    value3 = value2.flatten(1)
    value3
  end

  def build_pipeline(stage1, stage2, stage3)
    lambda do |thing1|
      thing2 = stage1.call(thing1)
      thing3 = stage2.call(thing2)
      stage3.call(thing3)
    end
  end

  private

  def validate(input) = input
  def normalize(data) = data
  def enrich(data) = data
  def transform(data) = data
  def format_output(data) = data
  def filter_active(users) = users.select { |u| u[:active] }
  def load_profiles(users) = users
  def apply_permissions(users) = users
  def sort_users(users) = users.sort_by { |u| u[:name] }
  def attempt(func)
    { ok: true, data: func.call }
  rescue
    { ok: false }
  end
  def clean_nulls(hash) = hash.compact
  def add_metadata(hash) = hash.merge(processed_at: Time.now)
  def validate_merged(hash) = hash
  def process_batch(batch) = batch
end
