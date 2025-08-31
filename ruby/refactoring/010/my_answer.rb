# frozen_string_literal: true

class ValidationResult
  attr_reader :info

  def initialize(success:, info: '')
    @success = success
    @info = info
  end

  def success?
    @success
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

      columns = line.split(',')

      if columns.length != header_columns.length
        @errors << "Line #{line_number}: Column count mismatch"
        next
      end

      row = {}
      for j in 0..header_columns.length - 1
        row[header_columns[j]] = columns[j]
      end

      if row['email'] && !row['email'].match(/\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)
        @errors << "Line #{line_number}: Invalid email format"
        next
      end

      if row['age'] && row['age'].to_i < 0
        @errors << "Line #{line_number}: Invalid age"
        next
      end

      row['name'] = row['name'].upcase if row['name']

      if row['created_at']
        begin
          row['created_at'] = Time.parse(row['created_at']).strftime('%Y-%m-%d')
        rescue StandardError
          @errors << "Line #{line_number}: Invalid date format"
          next
        end
      end
      @results << row
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

    return 'Error: File not found' unless File.exist?(file_path)

    CSVFileProcessor.new(file_path).process
  end
end
