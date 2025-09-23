# frozen_string_literal: true

class DataValidator
  def initialize(data)
    @data = data
  end

  def validate
    raise NotImplementedError, "#{self.class} must implement #validate"
  end
end

class EmailValidator < DataValidator
  def validate
    raise 'Invalid email address' if @data[:to].nil? || @data[:to].empty?
  end
end

class HttpRequestValidator < DataValidator
  def validate
    raise 'Invalid URL' unless @data[:url].start_with?('http')
  end
end

class DataProcessingValidator < DataValidator
  def validate
    raise 'Invalid input data' if @data[:input].nil? || @data[:input].empty?
  end
end

class ReportGenerationValidator < DataValidator
  def validate
    raise 'Invalid report type' if @data[:report_type].nil? || @data[:report_type].empty?
  end
end

class TaskHandler
  def handle(data)
    raise NotImplementedError, "#{self.class} must implement #handle"
  end
end

class EmailHandler < TaskHandler
  def handle(data)
    validator = EmailValidator.new(data)
    validator.validate

    puts "Sending email to #{data[:to]}"
    sleep(5)

    'Email sent'
  end
end

class HttpRequestHandler < TaskHandler
  def handle(data)
    validator = HttpRequestValidator.new(data)
    validator.validate

    puts "Making HTTP request to #{data[:url]}"
    sleep(2)

    'Response: 200 OK'
  end
end

class DataProcessingHandler < TaskHandler
  def handle(data)
    validator = DataProcessingValidator.new(data)
    validator.validate

    puts "Processing data: #{data[:input]}"
    sleep(1.5)

    "Processed: #{data[:input].upcase}"
  end
end

class ReportGenerationHandler < TaskHandler
  def handle(data)
    validator = ReportGenerationValidator.new(data)
    validator.validate

    puts "Generating #{data[:report_type]} report"
    sleep(1.5)

    "Report generated: #{data[:report_type]}_report.pdf"
  end
end

class TaskHandlerDispatcher
  HANDLER_MAP = {
    email: EmailHandler.new,
    http_request: HttpRequestHandler.new,
    data_processing: DataProcessingHandler.new,
    report_generation: ReportGenerationHandler.new
  }.freeze

  def self.find(task_type)
    handler = HANDLER_MAP[task_type.to_sym]
    raise 'Unknown task type' unless handler

    handler
  end
end

class Task
  STATUS = {
    pending: 'pending',
    running: 'running',
    completed: 'completed',
    failed: 'failed'
  }.freeze

  attr_reader :id, :type, :data, :priority, :retry_count, :attempts

  def initialize(type:, data:, priority:, retry_count:, attempts:, created_at:)
    @id = generate_id
    @type = type
    @data = data
    @priority = priority
    @retry_count = retry_count
    @attempts = attempts
    @created_at = created_at
    @status = STATUS[:pending]

    initialize_start_attr
    initialize_completion_attr
    initialize_failure_attr
    initialize_retry_attr
  end

  def change_status(new_status)
    raise 'Invalid status' unless STATUS.key?(new_status)

    @status = STATUS[new_status]
  end

  def status_equal?(other_status)
    @status == STATUS[other_status]
  end

  def record_start
    change_status(:running)
    @started_at = Time.now.utc
  end

  def record_completion(result)
    change_status(:completed)
    @completed_at = Time.now.utc
    @result = result
    @duration = @completed_at - @started_at
  end

  def record_error(error)
    @attempts += 1
    @last_error = error.message
    @failed_at = Time.now.utc
  end

  def record_failure
    change_status(:failed)
  end

  def record_retry
    change_status(:pending)
    @retry_after = Time.now.utc + (@attempts * 5)
  end

  def retry?
    @attempts < @retry_count
  end

  private

  def initialize_start_attr
    @started_at = nil
  end

  def initialize_completion_attr
    @completed_at = nil
    @result = nil
    @duration = nil
  end

  def initialize_failure_attr
    @last_error = nil
    @failed_at = nil
  end

  def initialize_retry_attr
    @retry_after = nil
  end

  def generate_id
    "task_#{Time.now.utc.to_i}_#{Kernel.rand(1000)}"
  end
end

class TasksExecutor
  def initialize
    @completed_tasks = []
    @failed_tasks = []
    @running = true
  end

  def find_executed_task_by(id)
    (@completed_tasks + @failed_tasks).find { |task| task.id == id }
  end

  def setup
    @running = true
  end

  def teardown
    @running = false
  end

  def running?
    @running
  end

  def execute(task)
    task.record_start

    handler = handler(task.type)
    result = handler.handle(task.data)

    task.record_completion(result)

    handle_completion(task, result)

    result
  end

  def completed_count
    @completed_tasks.length
  end

  def failed_count
    @failed_tasks.length
  end

  def add_failed_task(task)
    @failed_tasks << task
  end

  private

  def handler(task_type)
    TaskHandlerDispatcher.find(task_type)
  end

  def add_completed_task(task)
    @completed_tasks << task
  end

  def execute_success_callback(task, result)
    task.data[:on_success]&.call(result)
  end

  def handle_completion(task, result)
    add_completed_task(task)
    execute_success_callback(task, result)
  end
end

class PriorityQueue
  def initialize
    @tasks = []
  end

  def find_task_in_queue_by(id)
    @tasks.find { |task| task.id == id }
  end

  def enqueue(task)
    insert_position = @tasks.bsearch_index { |task_in_queue| task.priority >= task_in_queue.priority } || @tasks.length
    @tasks.insert(insert_position, task)
  end

  def dequeue
    @tasks.shift
  end

  def pending_count
    @tasks.count { |task| task.status_equal?(:pending) }
  end

  def empty?
    @tasks.empty?
  end
end

class QueueTasksProcessor
  def initialize(queue:, executor:)
    @queue = queue
    @executor = executor
  end

  def process_all_tasks
    @executor.setup

    while @executor.running? && !@queue.empty?
      task = @queue.dequeue

      with_error_handling(task) do
        @executor.execute(task)
      end

      sleep(0.1)
    end

    @executor.teardown
  end

  private

  def retry_task(task)
    task.record_retry
    @queue.enqueue(task)

    puts "Task #{task.id} failed, retrying (#{task.attempts}/#{task.retry_count})"
  end

  def execute_failure_callback(task, error)
    task.data[:on_failure]&.call(error.message)
  end

  def fail_task(task, error)
    task.record_failure
    @executor.add_failed_task(task)
    execute_failure_callback(task, error)

    puts "Task #{task.id} failed permanently: #{error.message}"
  end

  def with_error_handling(task)
    yield
  rescue StandardError => e
    task.record_error(e)

    task.retry? ? retry_task(task) : fail_task(task, e)
  end
end

class TaskQueue
  def initialize
    @priority_queue = PriorityQueue.new
    @tasks_executor = TasksExecutor.new
  end

  def add_task(type:, data:, priority: 5, retry_count: 3)
    task = Task.new(
      type: type,
      data: data,
      priority: priority,
      retry_count: retry_count,
      attempts: 0,
      created_at: Time.now.utc
    )

    @priority_queue.enqueue(task)

    task.id
  end

  def process_tasks
    QueueTasksProcessor.new(
      queue: @priority_queue,
      executor: @tasks_executor
    ).process_all_tasks
  end

  def stop
    @tasks_executor.teardown
  end

  def get_status
    pending_count = @priority_queue.pending_count

    completed_count = @tasks_executor.completed_count
    failed_count = @tasks_executor.failed_count

    {
      pending: pending_count,
      completed: completed_count,
      failed: failed_count,
      total: pending_count + completed_count + failed_count
    }
  end

  def get_task_info(task_id)
    task = @priority_queue.find_task_in_queue_by(task_id) || @tasks_executor.find_executed_task_by(task_id)
    return nil unless task

    task.to_h
  end
end
