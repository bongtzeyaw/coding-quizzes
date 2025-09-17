require 'minitest/autorun'
require 'tempfile'
require_relative 'my_answer'

class TestDataProcessor < Minitest::Test
  def setup
    @processor = DataProcessor.new
    @input_file = Tempfile.new('input')
    @output_file = Tempfile.new('output')
  end

  def teardown
    @input_file.close
    @input_file.unlink
    @output_file.close
    @output_file.unlink
  end

  def test_no_options
    input_content = <<~INPUT
      hello world
      ruby is fun
      test
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      hello world
      ruby is fun
      test
    OUTPUT

    assert_equal expected_output, output
  end

  def test_empty_lines
    input_content = <<~INPUT
      line1

      line2

      line3
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      line1
      line2
      line3
    OUTPUT

    assert_equal expected_output, output
  end

  def test_max_length
    input_content = <<~INPUT
      short
      longline
      verylongline
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, max_length: 5)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      short
    OUTPUT

    assert_equal expected_output, output
  end

  def test_pattern
    input_content = <<~INPUT
      abcd
      efgh
      1234
      5678
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, pattern: /^[a-z]+$/)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      abcd
      efgh
    OUTPUT

    assert_equal expected_output, output
  end

  def test_uppercase
    input_content = <<~INPUT
      hello
      world
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, uppercase: true)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      HELLO
      WORLD
    OUTPUT

    assert_equal expected_output, output
  end

  def test_lowercase
    input_content = <<~INPUT
      HELLO
      WORLD
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, lowercase: true)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      hello
      world
    OUTPUT
    assert_equal expected_output, output
  end

  def test_prefix
    input_content = <<~INPUT
      line1
      line2
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, prefix: 'PREFIX-')
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      PREFIX-line1
      PREFIX-line2
    OUTPUT

    assert_equal expected_output, output
  end

  def test_suffix
    input_content = <<~INPUT
      line1
      line2
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, suffix: '-SUFFIX')
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      line1-SUFFIX
      line2-SUFFIX
    OUTPUT

    assert_equal expected_output, output
  end

  def test_replace
    input_content = <<~INPUT
      hello world
      goodbye world
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, replace_from: 'world', replace_to: 'ruby')
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      hello ruby
      goodbye ruby
    OUTPUT

    assert_equal expected_output, output
  end

  def test_unique
    input_content = <<~INPUT
      line1
      line2
      line1
      line3
      line2
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, unique: true)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      line1
      line2
      line3
    OUTPUT

    assert_equal expected_output, output
  end

  def test_include_keyword
    input_content = <<~INPUT
      apple
      banana
      cherry
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, include_keyword: 'a')
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      apple
      banana
    OUTPUT

    assert_equal expected_output, output
  end

  def test_exclude_keyword
    input_content = <<~INPUT
      apple
      banana
      cherry
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, exclude_keyword: 'a')
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      cherry
    OUTPUT

    assert_equal expected_output, output
  end

  def test_sort
    input_content = <<~INPUT
      cherry
      apple
      banana
    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, sort: true)
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      apple
      banana
      cherry
    OUTPUT

    assert_equal expected_output, output
  end

  def test_all_options
    input_content = <<~INPUT
      Hello World
      ruby is fun
      testing with long lines
      ruby

    INPUT

    @input_file.write(input_content)
    @input_file.rewind
    @processor.process_data(@input_file.path, @output_file.path, max_length: 15, pattern: /^ruby/, uppercase: true,
                                                                 prefix: 'PROCESSED-', unique: true, sort: true, exclude_keyword: 'WORLD')
    output = File.read(@output_file.path)

    expected_output = <<~OUTPUT
      PROCESSED-RUBY
      PROCESSED-RUBY IS FUN
    OUTPUT

    assert_equal expected_output, output
  end
end
