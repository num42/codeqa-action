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
    rescue StandardError => e
      # Too broad — this catches everything below and the specific rescues are unreachable
      @logger.error("Unexpected error for #{row[:email]}: #{e.message}")
      results[:errors] << { email: row[:email], reason: :unexpected }
    rescue ActiveRecord::ActiveRecordError => e
      # Dead code — StandardError already matched this
      @logger.error("ActiveRecord error for #{row[:email]}: #{e.message}")
      results[:errors] << { email: row[:email], reason: :active_record_error }
    rescue ActiveRecord::StatementInvalid => e
      # Dead code — caught by StandardError above
      @logger.error("DB statement error for #{row[:email]}: #{e.message}")
      results[:errors] << { email: row[:email], reason: :database_error }
    rescue ActiveRecord::RecordNotUnique
      # Dead code — caught by StandardError above
      results[:skipped] += 1
    rescue ActiveRecord::RecordInvalid
      # Dead code — caught by StandardError above
      results[:skipped] += 1
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
