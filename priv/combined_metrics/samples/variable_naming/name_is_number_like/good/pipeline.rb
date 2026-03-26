# Data pipeline with meaningful variable names.
# GOOD: variables like validated_input, normalized_data, enriched_record describe their state.

class PipelineGood
  def run(input)
    validated_input = validate(input)
    normalized_data = normalize(validated_input)
    enriched_record = enrich(normalized_data)
    transformed_record = transform(enriched_record)
    formatted_output = format_output(transformed_record)
    { ok: true, data: formatted_output }
  rescue => error
    { ok: false, error: error.message }
  end

  def process_users(users)
    active_users = filter_active(users)
    users_with_profiles = load_profiles(active_users)
    authorized_users = apply_permissions(users_with_profiles)
    sorted_users = sort_users(authorized_users)
    sorted_users
  end

  def deduplicate(items)
    sorted_items = items.sort
    unique_items = sorted_items.uniq
    present_items = unique_items.compact
    present_items
  end

  def retry_operation(func, max_attempts)
    initial_result = attempt(func)
    return initial_result if initial_result[:ok]

    retry_result = attempt(func)
    return retry_result if retry_result[:ok]

    final_result = attempt(func)
    return final_result if final_result[:ok]

    { ok: false, error: 'All retries failed' }
  end

  def merge_records(primary_record, secondary_record)
    merged = primary_record.merge(secondary_record)
    cleaned = clean_nulls(merged)
    with_metadata = add_metadata(cleaned)
    validated_result = validate_merged(with_metadata)
    validated_result
  end

  def batch_process(items, batch_size)
    batches = items.each_slice(batch_size).to_a
    processed_batches = batches.map { |batch| process_batch(batch) }
    flattened_results = processed_batches.flatten(1)
    flattened_results
  end

  def build_pipeline(first_stage, second_stage, third_stage)
    lambda do |input|
      after_first = first_stage.call(input)
      after_second = second_stage.call(after_first)
      third_stage.call(after_second)
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
