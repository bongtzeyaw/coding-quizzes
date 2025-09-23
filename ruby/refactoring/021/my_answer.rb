class TaskQueue
  def initialize
    @tasks = []
    @failed_tasks = []
    @completed_tasks = []
    @running = false
  end

  def add_task(type, data, priority = 5, retry_count = 3)
    task = {
      id: generate_id,
      type: type,
      data: data,
      priority: priority,
      retry_count: retry_count,
      attempts: 0,
      status: 'pending',
      created_at: Time.now
    }

    inserted = false
    for i in 0..@tasks.length - 1
      next unless @tasks[i][:priority] < priority

      @tasks.insert(i, task)
      inserted = true
      break
    end

    @tasks << task unless inserted

    task[:id]
  end

  def process_tasks
    @running = true

    while @running && @tasks.length > 0
      task = @tasks.shift

      task[:status] = 'running'
      task[:started_at] = Time.now

      begin
        result = nil

        case task[:type]
        when 'email'
          puts "Sending email to #{task[:data][:to]}"
          raise 'Invalid email address' if task[:data][:to].nil? || task[:data][:to].empty?

          sleep(1)
          result = 'Email sent'

        when 'http_request'
          puts "Making HTTP request to #{task[:data][:url]}"
          raise 'Invalid URL' unless task[:data][:url].start_with?('http')

          sleep(2)
          result = 'Response: 200 OK'

        when 'data_processing'
          puts "Processing data: #{task[:data][:input]}"
          raise 'No input data' if task[:data][:input].nil?

          processed = task[:data][:input].upcase
          sleep(0.5)
          result = "Processed: #{processed}"

        when 'report_generation'
          puts "Generating report: #{task[:data][:report_type]}"
          raise 'Invalid report type' unless %w[daily weekly monthly].include?(task[:data][:report_type])

          sleep(3)
          result = "Report generated: #{task[:data][:report_type]}_report.pdf"

        else
          raise "Unknown task type: #{task[:type]}"
        end

        task[:status] = 'completed'
        task[:completed_at] = Time.now
        task[:result] = result
        task[:duration] = task[:completed_at] - task[:started_at]

        @completed_tasks << task

        task[:data][:on_success].call(result) if task[:data][:on_success]
      rescue StandardError => e
        task[:attempts] += 1
        task[:last_error] = e.message
        task[:failed_at] = Time.now

        if task[:attempts] < task[:retry_count]
          task[:status] = 'pending'
          task[:retry_after] = Time.now + (task[:attempts] * 5)

          @tasks.unshift(task)

          puts "Task #{task[:id]} failed, retrying (#{task[:attempts]}/#{task[:retry_count]})"
        else
          task[:status] = 'failed'
          @failed_tasks << task

          # コールバック実行
          task[:data][:on_failure].call(e.message) if task[:data][:on_failure]

          puts "Task #{task[:id]} failed permanently: #{e.message}"
        end
      end

      sleep(0.1)
    end

    @running = false
  end

  def stop
    @running = false
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

  def generate_id
    "task_#{Time.now.to_i}_#{rand(1000)}"
  end
end
