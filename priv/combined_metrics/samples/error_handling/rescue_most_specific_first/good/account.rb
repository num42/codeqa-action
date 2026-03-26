class AccountImporter
  def initialize(csv_parser, repository, logger)
    @csv_parser = csv_parser
    @repository = repository
    @logger = logger
  end

  def import(file_path)
    results = { imported: 0, skipped: 0, errors: [] }

    @csv_parser.each_row(file_path) do |row|
      import_row(row, results)
    end

    results
  end

  private

  def import_row(row, results)
    account = build_account(row)

    begin
      @repository.save!(account)
      results[:imported] += 1
    rescue ActiveRecord::RecordInvalid => e
      # Most specific: validation failures are expected and recoverable
      @logger.warn("Validation failed for row #{row[:email]}: #{e.record.errors.full_messages.join(', ')}")
      results[:skipped] += 1
    rescue ActiveRecord::RecordNotUnique => e
      # More specific than StatementInvalid but less than RecordInvalid
      @logger.warn("Duplicate account skipped: #{row[:email]}")
      results[:skipped] += 1
    rescue ActiveRecord::StatementInvalid => e
      # Less specific DB error
      @logger.error("DB statement error for #{row[:email]}: #{e.message}")
      results[:errors] << { email: row[:email], reason: :database_error }
    rescue ActiveRecord::ActiveRecordError => e
      # Broad ActiveRecord error — catches anything above not already matched
      @logger.error("ActiveRecord error for #{row[:email]}: #{e.message}")
      results[:errors] << { email: row[:email], reason: :active_record_error }
    rescue StandardError => e
      # Catch-all for unexpected errors
      @logger.error("Unexpected error for #{row[:email]}: #{e.message}")
      results[:errors] << { email: row[:email], reason: :unexpected }
    end
  end

  def build_account(row)
    Account.new(
      email: row[:email],
      name: row[:name],
      plan: row[:plan] || :free,
      source: :csv_import
    )
  end
end
