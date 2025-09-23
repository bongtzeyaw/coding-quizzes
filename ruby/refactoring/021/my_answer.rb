# frozen_string_literal: true

class Task
  attr_reader :id, :type, :data, :priority, :retry_count, :attempts, :status 

  def initialize(type:, data:, priority:, retry_count:, attempts:, status:, created_at:)
    @id = generate_id
    @type = type
    @data = data
    @priority = priority
    @retry_count = retry_count
    @attempts = attempts
    @status = status
    @created_at = created_at

    initialize_start_attr
    initialize_completion_attr
    initialize_failure_attr
    initialize_retry_attr
  end

  def record_start
    @status = 'running'
    @started_at = Time.now.utc
  end

  def record_completion(result)
    @status = 'completed'
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
    @status = 'failed'
  end

  def record_retry
    @status = 'pending'
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

    result = nil

    case task.type
    when 'email'
      puts "Sending email to #{task.data[:to]}"
      raise 'Invalid email address' if task.data[:to].nil? || task.data[:to].empty?

      sleep(1)
      result = 'Email sent'

    when 'http_request'
      puts "Making HTTP request to #{task.data[:url]}"
      raise 'Invalid URL' unless task.data[:url].start_with?('http')

      sleep(2)
      result = 'Response: 200 OK'

    when 'data_processing'
      puts "Processing data: #{task.data[:input]}"
      raise 'No input data' if task.data[:input].nil?

      processed = task.data[:input].upcase
      sleep(0.5)
      result = "Processed: #{processed}"

    when 'report_generation'
      puts "Generating report: #{task.data[:report_type]}"
      raise 'Invalid report type' unless %w[daily weekly monthly].include?(task.data[:report_type])

      sleep(3)
      result = "Report generated: #{task.data[:report_type]}_report.pdf"

    else
      raise "Unknown task type: #{task.type}"
    end

    task.status = 'completed'
    task.completed_at = Time.now
    task.result = result
    task.duration = task.completed_at - task.started_at

    @completed_tasks << task

    task.data[:on_success].call(result) if task.data[:on_success]

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

  def enqueue(task)
    insert_position = @tasks.bsearch_index { |task_in_queue| task.priority >= task_in_queue.priority } || @tasks.length
    @tasks.insert(insert_position, task)
  end
end

class TaskQueue
  def initialize
    @priority_queue = PriorityQueue.new
    @tasks_executor = TasksExecutor.new
  end

  def add_task(type, data, priority = 5, retry_count = 3)
    task = Task.new(
      type: type,
      data: data,
      priority: priority,
      retry_count: retry_count,
      attempts: 0,
      status: 'pending',
      created_at: Time.now.utc
    )

    @priority_queue.enqueue(task)

    task.id
  end

  def process_tasks
    @tasks_executor.setup

    while @tasks_executor.running? && !@priority_queue.empty?
      task = @priority_queue.dequeue

      with_error_handling(task) do
        @tasks_executor.execute(task)
      end

      sleep(0.1)
    end

    @tasks_executor.teardown
  end

  def stop
    @tasks_executor.teardown
  end

  def get_status
    pending_count = @tasks.count { |t| t[:status] == 'pending' }

    {
      pending: pending_count,
      completed: @completed_tasks.length,
      failed: @failed_tasks.length,
      total: pending_count + @completed_tasks.length + @failed_tasks.length
    }
  end

  def get_task_info(task_id)
    task = @tasks.find { |t| t[:id] == task_id }
    task ||= @completed_tasks.find { |t| t[:id] == task_id }
    task ||= @failed_tasks.find { |t| t[:id] == task_id }

    return nil unless task

    {
      id: task[:id],
      type: task[:type],
      status: task[:status],
      attempts: task[:attempts],
      created_at: task[:created_at],
      duration: task[:duration],
      error: task[:last_error]
    }
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
  rescue StandardError => error
    task.record_error(error)

    task.retry? ? retry_task(task) : fail_task(task, error)
  end
end
