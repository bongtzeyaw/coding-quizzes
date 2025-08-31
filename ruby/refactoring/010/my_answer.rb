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

class FileProcessor
  def process_csv(file_path)
    validation_result = FileValidator.new(file_path).validate
    return validation_result.info unless validation_result.success?

    return 'Error: File not found' unless File.exist?(file_path)

    lines = []
    File.open(file_path, 'r') do |file|
      file.each_line do |line|
        lines << line.strip
      end
    end

    header = lines[0].split(',')

    results = []
    errors = []

    for i in 1..lines.length - 1
      columns = lines[i].split(',')

      if columns.length != header.length
        errors << "Line #{i + 1}: Column count mismatch"
        next
      end

      row = {}
      for j in 0..header.length - 1
        row[header[j]] = columns[j]
      end

      if row['email'] && !row['email'].match(/\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)
        errors << "Line #{i + 1}: Invalid email format"
        next
      end

      if row['age'] && row['age'].to_i < 0
        errors << "Line #{i + 1}: Invalid age"
        next
      end

      row['name'] = row['name'].upcase if row['name']

      if row['created_at']
        begin
          row['created_at'] = Time.parse(row['created_at']).strftime('%Y-%m-%d')
        rescue StandardError
          errors << "Line #{i + 1}: Invalid date format"
          next
        end
      end

      results << row
    end

    {
      success: true,
      data: results,
      errors: errors,
      total_lines: lines.length - 1,
      processed: results.length,
      failed: errors.length
    }
  end
end
