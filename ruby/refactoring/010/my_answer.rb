# frozen_string_literal: true

require 'uri'

class OperationResult
  def initialize(success:)
    @success = success
  end

  def success?
    @success
  end
end

class ValidationResult < OperationResult
  attr_reader :info

  def initialize(success:, info: '')
    super(success:)
    @info = info
  end
end

class ProcessingResult < OperationResult
  attr_reader :data

  def initialize(success:, data: {})
    super(success:)
    @data = data
  end
end

class FileValidator
  MAX_FILE_SIZE = 10 * 1024 * 1024 # 10MB

  def initialize(file_path)
    @file_path = file_path
  end

  def validate
    return error_response('File not found') unless file_exists?
    return error_response('File too large') if file_too_large?
    return error_response('Empty file') if file_empty?

    ValidationResult.new(success: true)
  end

  private

  def file_exists?
    File.exist?(@file_path)
  end

  def file_too_large?
    File.size(@file_path) > MAX_FILE_SIZE
  end

  def file_empty?
    File.zero?(@file_path)
  end

  def error_response(message)
    ValidationResult.new(
      success: false,
      info: "Error: #{message}"
    )
  end
end

class CSVRowColumnsValidator
  def initialize(columns:, line_number:)
    @columns = columns
    @line_number = line_number
  end

  def validate(header_columns:)
    if @columns.length == header_columns.length
      ValidationResult.new(success: true)
    else
      error_response('Column count mismatch')
    end
  end

  private

  def error_response(message)
    ValidationResult.new(
      success: false,
      info: "Line #{@line_number}: #{message}"
    )
  end
end

class CSVRowDataValidator
  VALID_EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP
  VALID_CREATED_AT_FORMAT = '%Y-%m-%d'

  def initialize(row:, line_number:)
    @row = row
    @line_number = line_number
  end

  def validate
    return error_response('Invalid email format') if data_exists?('email') && invalid_email?
    return error_response('Invalid age') if data_exists?('age') && invalid_age?
    return error_response('Invalid date format') if data_exists?('created_at') && invalid_created_at?

    ValidationResult.new(success: true)
  end

  private

  def data_exists?(column_name)
    !@row[column_name].nil?
  end

  def invalid_email?
    !@row['email'].match(VALID_EMAIL_FORMAT)
  end

  def invalid_age?
    @row['age'].to_i.negative?
  end

  def invalid_created_at?
    Time.parse(@row['created_at']).strftime(VALID_CREATED_AT_FORMAT)
    false
  rescue StandardError
    true
  end

  def error_response(message)
    ValidationResult.new(
      success: false,
      info: "Line #{@line_number}: #{message}"
    )
  end
end

class CSVRowProcessor
  def initialize(line:, line_number:, header_columns:)
    @line = line
    @line_number = line_number
    @header_columns = header_columns
    @columns = extract_columns(line)
  end

  def process
    columns_validation_result = CSVRowColumnsValidator.new(
      columns: @columns,
      line_number: @line_number
    ).validate(header_columns: @header_columns)

    return columns_validation_result unless columns_validation_result.success?

    row = @header_columns.zip(@columns).to_h

    row_data_validation_result = CSVRowDataValidator.new(
      row:,
      line_number: @line_number
    ).validate

    return row_data_validation_result unless row_data_validation_result.success?

    process_name!(row)
    process_created_at!(row)

    ProcessingResult.new(success: true, data: row)
  end

  private

  def extract_columns(line)
    line.split(',')
  end

  def process_name!(row)
    row['name'] = row['name'].upcase if row['name']
  end

  def process_created_at!(row)
    row['created_at'] = Time.parse(row['created_at']).strftime(CSVRowDataValidator::VALID_CREATED_AT_FORMAT)
  end
end

class CSVFileProcessor
  def initialize(file_path)
    @file_path = file_path
    @results = []
    @errors = []
  end

  def process
    lines = read_lines
    header_columns = extract_header_columns(lines)

    header_offset = 1
    lines.drop(header_offset).each.with_index(header_offset) do |line, index|
      line_number = index + 1

      csv_row_processor = CSVRowProcessor.new(line:, line_number:, header_columns:)
      operation_result = csv_row_processor.process

      if operation_result.success?
        @results << operation_result.data
      else
        @errors << operation_result.info
      end
    end

    summary
  end

  private

  def read_lines
    File.readlines(@file_path).map(&:strip)
  end

  def extract_header_columns(lines)
    lines[0].split(',')
  end

  def summary
    {
      success: true,
      data: @results,
      errors: @errors,
      total_lines: @results.length + @errors.length,
      processed: @results.length,
      failed: @errors.length
    }
  end
end

class FileProcessor
  def process_csv(file_path)
    validation_result = FileValidator.new(file_path).validate
    return validation_result.info unless validation_result.success?

    CSVFileProcessor.new(file_path).process
  end
end
