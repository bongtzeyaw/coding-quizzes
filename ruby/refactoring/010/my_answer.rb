class FileProcessor
  def process_csv(file_path)
    return 'Error: File not found' unless File.exist?(file_path)

    file_size = File.size(file_path)
    return 'Error: File too large' if file_size > 10_485_760

    lines = []
    File.open(file_path, 'r') do |file|
      file.each_line do |line|
        lines << line.strip
      end
    end

    return 'Error: Empty file' if lines.empty?

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
