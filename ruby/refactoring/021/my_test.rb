require 'minitest/autorun'
require_relative 'my_answer'

class TaskQueueTest < Minitest::Test
  def setup
    @queue = TaskQueue.new
    def @queue.sleep(_); end
  end

  def test_add_task_default_priority
    id = nil
    Time.stub :now, Time.at(100).utc do
      Kernel.stub :rand, 1 do
        id = @queue.add_task(type: 'email', data: { to: 'user@example.com' })
      end
    end
    tasks_in_queue = @queue.instance_variable_get(:@priority_queue).instance_variable_get(:@tasks)
    assert_equal 1, tasks_in_queue.size
    assert_equal 'task_100_1', id
  end

  def test_add_task_priority_order
    low = @queue.add_task(type: 'email', data: { to: 'low@example.com' }, priority: 1)
    high = @queue.add_task(type: 'email', data: { to: 'high@example.com' }, priority: 10)
    tasks = @queue.instance_variable_get(:@priority_queue).instance_variable_get(:@tasks)
    tasks_in_queue = @queue.instance_variable_get(:@priority_queue).instance_variable_get(:@tasks)
    assert_equal 2, tasks_in_queue.size
    assert_equal high, tasks.first.id
    assert_equal low, tasks.last.id
  end

  def test_email_task_success
    result = nil
    id = @queue.add_task(type: 'email', data: { to: 'ok@example.com', on_success: ->(r) { result = r } })
    mock_handler = Minitest::Mock.new
    mock_handler.expect(:handle, 'Email sent', [Hash])
    TaskHandlerDispatcher.stub :find, mock_handler do
      @queue.process_tasks
    end
    mock_handler.verify
    tasks_in_queue = @queue.instance_variable_get(:@priority_queue).instance_variable_get(:@tasks)
    assert_equal 0, tasks_in_queue.size
    completed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@completed_tasks)
    assert_equal 1, completed_tasks.size
    assert_equal id, completed_tasks.first.id
    assert_equal 'completed', completed_tasks.first.status
    assert_equal 'Email sent', completed_tasks.first.instance_variable_get(:@result)
    assert_equal 'Email sent', result
  end

  def test_http_request_success
    id = @queue.add_task(type: 'http_request', data: { url: 'http://example.com', on_success: ->(_r) { nil } })
    mock_handler = Minitest::Mock.new
    mock_handler.expect(:handle, 'Response: 200 OK', [Hash])
    TaskHandlerDispatcher.stub :find, mock_handler do
      @queue.process_tasks
    end
    mock_handler.verify
    completed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@completed_tasks)
    assert_equal 1, completed_tasks.size
    assert_equal id, completed_tasks.first.id
    assert_equal 'completed', completed_tasks.first.status
    assert_equal 'Response: 200 OK', completed_tasks.first.instance_variable_get(:@result)
  end

  def test_data_processing_success
    id = @queue.add_task(type: 'data_processing', data: { input: 'abc', on_success: ->(_r) { nil } })
    mock_handler = Minitest::Mock.new
    mock_handler.expect(:handle, 'Processed: ABC', [Hash])
    TaskHandlerDispatcher.stub :find, mock_handler do
      @queue.process_tasks
    end
    mock_handler.verify
    completed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@completed_tasks)
    assert_equal 1, completed_tasks.size
    assert_equal id, completed_tasks.first.id
    assert_equal 'completed', completed_tasks.first.status
    assert_equal 'Processed: ABC', completed_tasks.first.instance_variable_get(:@result)
  end

  def test_report_generation_success
    id = @queue.add_task(type: 'report_generation', data: { report_type: 'daily', on_success: ->(_r) { nil } })
    mock_handler = Minitest::Mock.new
    mock_handler.expect(:handle, 'Report generated: daily_report.pdf', [Hash])
    TaskHandlerDispatcher.stub :find, mock_handler do
      @queue.process_tasks
    end
    mock_handler.verify
    completed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@completed_tasks)
    assert_equal 1, completed_tasks.size
    assert_equal id, completed_tasks.first.id
    assert_equal 'completed', completed_tasks.first.status
    assert_equal 'Report generated: daily_report.pdf', completed_tasks.first.instance_variable_get(:@result)
  end

  def test_task_failure
    result = nil
    id = @queue.add_task(type: 'email', data: { to: 'invalid', on_failure: ->(msg) { result = msg } })
    mock_handler = Minitest::Mock.new
    3.times { mock_handler.expect(:handle, nil) { raise 'Invalid email address' } }
    TaskHandlerDispatcher.stub :find, mock_handler do
      3.times do
        @queue.process_tasks
      end
    end
    mock_handler.verify
    completed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@completed_tasks)
    assert_equal 0, completed_tasks.size
    failed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@failed_tasks)
    assert_equal 1, failed_tasks.size
    assert_equal id, failed_tasks.first.id
    assert_equal 'failed', failed_tasks.first.status
    assert_equal 3, failed_tasks.first.attempts
    assert_equal 'Invalid email address', failed_tasks.first.instance_variable_get(:@last_error)
    assert_equal 'Invalid email address', result
  end

  def test_task_failure_and_retry
    id = @queue.add_task(type: 'email', data: { to: 'ok@example.com', on_success: ->(_r) { nil } })
    mock_handler = Minitest::Mock.new
    2.times { mock_handler.expect(:handle, nil) { raise 'Invalid email address' } }
    mock_handler.expect(:handle, 'Email sent', [Hash])
    TaskHandlerDispatcher.stub :find, mock_handler do
      3.times do
        @queue.process_tasks
      end
    end
    mock_handler.verify
    completed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@completed_tasks)
    assert_equal 1, completed_tasks.size
    assert_equal id, completed_tasks.first.id
    assert_equal 'completed', completed_tasks.first.status
    assert_equal 2, completed_tasks.first.attempts
    assert_equal 'Invalid email address', completed_tasks.first.instance_variable_get(:@last_error)
  end

  def test_stop_sets_executor_to_not_running
    executor = @queue.instance_variable_get(:@tasks_executor)
    executor.setup
    assert executor.running?
    @queue.stop
    refute executor.running?
  end

  def test_unknown_task_type
    id = @queue.add_task(type: 'unknown', data: {})
    @queue.process_tasks
    failed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@failed_tasks)
    assert_equal 1, failed_tasks.size
    assert_equal id, failed_tasks.first.id
    completed_tasks = @queue.instance_variable_get(:@tasks_executor).instance_variable_get(:@completed_tasks)
    assert_equal 0, completed_tasks.size
    assert_equal 'failed', failed_tasks.first.status
    assert_equal('Unknown task type', failed_tasks.first.instance_variable_get(:@last_error))
  end

  def test_get_status_counts
    @queue.add_task(type: 'email', data: { to: 'invalid', on_success: ->(_r) { nil } })
    @queue.add_task(type: 'email', data: { to: 'ok@example.com', on_success: ->(_r) { nil } })
    mock_handler = Minitest::Mock.new
    3.times { mock_handler.expect(:handle, nil) { raise 'Invalid email address' } }
    mock_handler.expect(:handle, 'Email sent', [Hash])
    TaskHandlerDispatcher.stub :find, mock_handler do
      4.times do
        @queue.process_tasks
      end
    end
    mock_handler.verify
    status = @queue.get_status
    assert_equal 0, status[:pending]
    assert_equal 1, status[:completed]
    assert_equal 1, status[:failed]
    assert_equal 2, status[:total]
  end

  def test_get_task_info_nil_when_not_found
    assert_nil @queue.get_task_info('not_exist')
  end
end
