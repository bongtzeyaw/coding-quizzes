# frozen_string_literal: true

class Step
  def execute(input_data)
    raise NotImplementedError, "#{self.class} must implement #execute"
  end
end

class FileReader
  def initialize(file_path)
    @file_path = file_path
  end

  def read
    File.readlines(@file_path).map(&:strip)
  end
end

class FileReadingStep < Step
  def initialize(file_path)
    @file_reader = FileReader.new(file_path)
  end

  def execute(_input_data)
    output_data = @file_reader.read
    metric = { total_length: output_data.length }

    [output_data, metric]
  end
end

class LineValidator
  def initialize(options)
    @options = options
  end

  def valid?(line)
    return false if line.empty?
    return false if @options[:max_length] && line.length > @options[:max_length]
    return false if @options[:pattern] && !line.match(@options[:pattern])

    true
  end
end

class DataValidationStep < Step
  def initialize(options)
    @line_validator = LineValidator.new(options)
  end

  def execute(input_data)
    output_data = []
    invalid_count = 0

    input_data.each do |line|
      if @line_validator.valid?(line)
        output_data << line
      else
        invalid_count += 1
      end
    end

    metric = { invalid_count: invalid_count }

    [output_data, metric]
  end
end

class LineTransformer
  def initialize(options)
    @options = options
  end

  def transform(line)
    transformations.inject(line) { |transformed_line, method| send(method, transformed_line) }
  end

  private

  def transformations
    %i[uppercase lowercase prefix suffix replace]
  end

  def uppercase(line)
    return line unless @options[:uppercase]

    line.upcase
  end

  def lowercase(line)
    return line unless @options[:lowercase]

    line.downcase
  end

  def prefix(line)
    return line unless @options[:prefix]

    @options[:prefix] + line
  end

  def suffix(line)
    return line unless @options[:suffix]

    line + @options[:suffix]
  end

  def replace(line)
    return line unless @options[:replace_from] && @options[:replace_to]

    line.gsub(@options[:replace_from], @options[:replace_to])
  end
end

class DataTransformationStep < Step
  def initialize(options)
    @line_transformer = LineTransformer.new(options)
  end

  def execute(input_data)
    output_data = input_data.map { |line| @line_transformer.transform(line) }

    [output_data, {}]
  end
end

class LineFilter
  def initialize(options)
    @options = options
    @seen_lines = []
  end

  def filter_passed?(line)
    return false unless passes_unique?(line)
    return false unless passes_include_keyword?(line)
    return false unless passes_exclude_keyword?(line)

    true
  end

  private

  def passes_unique?(line)
    return true unless @options[:unique]

    unless @seen_lines.include?(line)
      @seen_lines << line
      return true
    end

    false
  end

  def passes_include_keyword?(line)
    return true unless @options[:include_keyword]

    line.include?(@options[:include_keyword])
  end

  def passes_exclude_keyword?(line)
    return true unless @options[:exclude_keyword]

    !line.include?(@options[:exclude_keyword])
  end
end

class DataFilteringStep < Step
  def initialize(options)
    @filter = LineFilter.new(options)
  end

  def execute(input_data)
    output_data = input_data.filter_map do |line|
      line if @filter.filter_passed?(line)
    end

    [output_data, {}]
  end
end

class DataSorter
  def initialize(options)
    @options = options
  end

  def sort(data)
    return data unless @options[:sort]

    data.sort
  end
end

class DataSortingStep < Step
  def initialize(options)
    @data_sorter = DataSorter.new(options)
  end

  def execute(input_data)
    output_data = @data_sorter.sort(input_data)

    [output_data, {}]
  end
end

class FileWriter
  def initialize(file_path)
    @file_path = file_path
  end

  def write(data)
    File.open(@file_path, 'w') do |file|
      data.each { |line| file.puts(line) }
    end
  end
end

class FileWritingStep < Step
  def initialize(output_file)
    @file_writer = FileWriter.new(output_file)
  end

  def execute(data)
    @file_writer.write(data)
    metric = { output_length: data.length }

    [data, metric]
  end
end

class DataPipeline
  def initialize
    @steps = []
  end

  def add_step(step)
    @steps << step
    self
  end

  def execute
    _data, metrics = @steps.inject([[], {}]) do |(data, metrics), step|
      data, metric = step.execute(data)

      [data, metrics.merge(metric)]
    end

    metrics
  end
end

class Report
  def initialize(metrics)
    @total_length = metrics[:total_length] || 0
    @invalid_count = metrics[:invalid_count] || 0
    @output_length = metrics[:output_length] || 0
  end

  def print
    puts 'Processing completed:'
    puts "  Total lines: #{@total_length}"
    puts "  Invalid lines: #{@invalid_count}"
    puts "  Output lines: #{@output_length}"
  end

  def to_h
    {
      total: @total_length,
      invalid: @invalid_count,
      output: @output_length
    }
  end
end

class FileValidator
  def initialize(file_path)
    @file_path = file_path
  end

  def validate
    raise NotImplementedError, "#{self.class} must implement #validate"
  end

  private

  def validation_error(message)
    { success: false, error: message }
  end
end

class InputFileValidator < FileValidator
  def validate
    return validation_error('Error: Input file cannot be nil') if @file_path.nil?
    return validation_error('Error: Input file does not exist') unless File.exist?(@file_path)
    return validation_error('Error: Input file is not readable') unless File.readable?(@file_path)

    { success: true }
  end
end

class OutputFileValidator < FileValidator
  def validate
    return validation_error('Error: Output file cannot be nil') if @file_path.nil?

    output_dir = File.dirname(File.expand_path(@file_path))

    return validation_error('Error: Output directory does not exist') unless Dir.exist?(output_dir)
    return validation_error('Error: Output directory is not writable') unless File.writable?(output_dir)

    { success: true }
  end
end

class DataProcessor
  def process_data(input_file, output_file, options = {})
    input_file_validation_result = InputFileValidator.new(input_file).validate
    return input_file_validation_result[:error] unless input_file_validation_result[:success]

    output_file_validation_result = OutputFileValidator.new(output_file).validate
    return output_file_validation_result[:error] unless output_file_validation_result[:success]

    pipeline = DataPipeline.new
                           .add_step(FileReadingStep.new(input_file))
                           .add_step(DataValidationStep.new(options))
                           .add_step(DataTransformationStep.new(options))
                           .add_step(DataFilteringStep.new(options))
                           .add_step(DataSortingStep.new(options))
                           .add_step(FileWritingStep.new(output_file))

    metrics = pipeline.execute
    report = Report.new(metrics)

    report.print
    report.to_h
  end
end
