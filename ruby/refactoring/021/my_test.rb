require 'minitest/autorun'
require 'stringio'
require_relative 'my_answer'

class TaskQueueTest < Minitest::Test
  def setup
    @queue = TaskQueue.new
    def @queue.sleep(_); end
  end

  def test_add_task_default_priority
    id = nil
    Time.stub :now, Time.at(100).utc do
      @queue.stub :rand, 1 do
        id = @queue.add_task('email', { to: 'user@example.com' })
      end
    end
    assert_equal 'task_100_1', id
  end

  def test_add_task_priority_order
    low = @queue.add_task('email', { to: 'low@example.com' }, 1)
    high = @queue.add_task('email', { to: 'high@example.com' }, 10)
    assert_equal high, @queue.instance_variable_get(:@tasks).first[:id]
    assert_equal low, @queue.instance_variable_get(:@tasks).last[:id]
  end

  def test_process_email_success
    result_holder = nil
    id = @queue.add_task('email', { to: 'ok@example.com', on_success: ->(r) { result_holder = r } })
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'completed', info[:status]
    assert_equal 'Email sent', result_holder
  end

  def test_process_email_failure_and_retry
    id = @queue.add_task('email', { to: '' }, 5, 2)
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'failed', info[:status]
    assert_equal 'Invalid email address', info[:error]
    assert_equal 2, info[:attempts]
  end

  def test_process_http_request_success
    id = @queue.add_task('http_request', { url: 'http://example.com' })
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'completed', info[:status]
  end

  def test_process_http_request_invalid_url
    id = @queue.add_task('http_request', { url: 'ftp://example.com' }, 5, 1)
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'failed', info[:status]
    assert_equal 'Invalid URL', info[:error]
  end

  def test_process_data_processing_success
    id = @queue.add_task('data_processing', { input: 'abc' })
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'completed', info[:status]
  end

  def test_process_data_processing_failure
    id = @queue.add_task('data_processing', { input: nil }, 5, 1)
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'failed', info[:status]
    assert_equal 'No input data', info[:error]
  end

  def test_process_report_generation_success
    id = @queue.add_task('report_generation', { report_type: 'daily' })
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'completed', info[:status]
  end

  def test_process_report_generation_failure
    id = @queue.add_task('report_generation', { report_type: 'yearly' }, 5, 1)
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'failed', info[:status]
    assert_equal 'Invalid report type', info[:error]
  end

  def test_unknown_task_type
    id = @queue.add_task('unknown', {})
    @queue.process_tasks
    info = @queue.get_task_info(id)
    assert_equal 'failed', info[:status]
    assert_match(/Unknown task type/, info[:error])
  end

  def test_failure_callback_called
    called = nil
    @queue.add_task('email', { to: '', on_failure: ->(e) { called = e } }, 5, 1)
    @queue.process_tasks
    assert_equal 'Invalid email address', called
  end

  def test_get_status_counts
    @queue.add_task('data_processing', { input: 'ok' })
    @queue.add_task('email', { to: '' }, 5, 1)
    @queue.process_tasks
    status = @queue.get_status
    assert_equal 0, status[:pending]
    assert_equal 1, status[:completed]
    assert_equal 1, status[:failed]
    assert_equal 2, status[:total]
  end

  def test_get_task_info_returns_nil_for_unknown_id
    assert_nil @queue.get_task_info('nonexistent')
  end
end
