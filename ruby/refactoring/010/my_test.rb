require 'minitest/autorun'
require 'tempfile'
require 'time'
require_relative 'my_answer'

class FileProcessorTest < Minitest::Test
  def setup
    @processor = FileProcessor.new
  end

  def create_tempfile(content)
    file = Tempfile.new(['test', '.csv'])
    file.write(content)
    file.rewind
    file
  end

  def test_file_not_found
    result = @processor.process_csv('non_existent.csv')
    assert_equal 'Error: File not found', result
  end

  def test_file_too_large
    file = create_tempfile("name,email,age\n" + "a,b,c\n")
    File.stub(:size, 20_000_000) do
      result = @processor.process_csv(file.path)
      assert_equal 'Error: File too large', result
    end
    file.close
    file.unlink
  end

  def test_empty_file
    file = create_tempfile('')
    result = @processor.process_csv(file.path)
    assert_equal 'Error: Empty file', result
    file.close
    file.unlink
  end

  def test_valid_csv
    file = create_tempfile("name,email,age,created_at\nJohn,john@example.com,25,2023-08-01")
    result = @processor.process_csv(file.path)
    assert_equal true, result[:success]
    assert_equal 1, result[:processed]
    assert_empty result[:errors]
    assert_equal 'JOHN', result[:data][0]['name']
    assert_equal '2023-08-01', result[:data][0]['created_at']
    file.close
    file.unlink
  end

  def test_column_count_mismatch
    file = create_tempfile("name,email\nJohn")
    result = @processor.process_csv(file.path)
    refute_empty result[:errors]
    assert_match(/Column count mismatch/, result[:errors][0])
    file.close
    file.unlink
  end

  def test_invalid_email
    file = create_tempfile("name,email\nJane,jane[at]example.com")
    result = @processor.process_csv(file.path)
    refute_empty result[:errors]
    assert_match(/Invalid email format/, result[:errors][0])
    file.close
    file.unlink
  end

  def test_invalid_age
    file = create_tempfile("name,email,age\nBob,bob@example.com,-5")
    result = @processor.process_csv(file.path)
    refute_empty result[:errors]
    assert_match(/Invalid age/, result[:errors][0])
    file.close
    file.unlink
  end

  def test_invalid_date
    file = create_tempfile("name,email,created_at\nAlice,alice@example.com,not_a_date")
    result = @processor.process_csv(file.path)
    refute_empty result[:errors]
    assert_match(/Invalid date format/, result[:errors][0])
    file.close
    file.unlink
  end
end
