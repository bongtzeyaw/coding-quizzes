# frozen_string_literal: true

class Service
  class << self
    def call
      raise NotImplementedError, "#{self.class} must implement #call"
    end

    def check_health
      raise NotImplementedError, "#{self.class} must implement #check_health"
    end

    def errors
      raise NotImplementedError, "#{self.class} must implement #errors"
    end
  end
end

class ApiService < Service
  class << self
    def call
      'API Response'
    end

    def check_health
      rand > 0.1
    end

    def errors
      [{ type: 'Timeout', message: 'Request timeout' }, { type: 'NotFound', message: 'Not found' }]
    end
  end
end

class DatabaseService < Service
  class << self
    def call
      'DB Response'
    end

    def check_health
      rand > 0.1
    end

    def errors
      [{ type: 'ConnectionError', message: 'Connection failed' }]
    end
  end
end

class CacheService < Service
  class << self
    def call
      'Cache Response'
    end

    def check_health
      rand > 0.1
    end

    def errors
      []
    end
  end
end

class ServiceDispatcher
  SERVICE_MAP = {
    api: ApiService,
    database: DatabaseService,
    cache: CacheService
  }.freeze

  class << self
    def dispatch(service_name)
      SERVICE_MAP[service_name.to_sym]
    end
  end
end

class MetricsCollector
  def collect_and_report(service_name, metric_type)
    service_class = ServiceDispatcher.dispatch(service_name)
    return nil unless service_class

    if metric_type == 'performance'
      start_time = Time.now
      cpu_before = get_cpu_usage
      memory_before = get_memory_usage

      result = service_class.call

      end_time = Time.now
      cpu_after = get_cpu_usage
      memory_after = get_memory_usage

      report = ''
      report += "Performance Report for #{service_name}\n"
      report += "=====================================\n"
      report += "Execution Time: #{end_time - start_time} seconds\n"
      report += "CPU Usage: #{cpu_after - cpu_before}%\n"
      report += "Memory Usage: #{memory_after - memory_before} MB\n"
      report += "Result: #{result}\n"

      File.open('metrics.log', 'a') do |f|
        f.puts "[#{Time.now}] #{report}"
      end

      send_email('admin@example.com', 'Performance Alert', report) if end_time - start_time > 5.0

      report

    elsif metric_type == 'availability'
      success_count = 0
      total_count = 10

      for i in 0..total_count - 1
        success_count += 1 if service_class.check_health

        sleep(1)
      end

      availability = (success_count.to_f / total_count) * 100

      report = ''
      report += "Availability Report for #{service_name}\n"
      report += "=====================================\n"
      report += "Success Rate: #{availability}%\n"
      report += "Failed Checks: #{total_count - success_count}\n"

      File.open('metrics.log', 'a') do |f|
        f.puts "[#{Time.now}] #{report}"
      end

      send_email('admin@example.com', 'Availability Alert', report) if availability < 90.0

      report

    elsif metric_type == 'error_rate'
      errors = service_class.errors

      error_count = errors.length
      error_types = {}

      for i in 0..errors.length - 1
        error = errors[i]
        type = error[:type] || 'Unknown'
        if error_types[type]
          error_types[type] += 1
        else
          error_types[type] = 1
        end
      end

      report = ''
      report += "Error Report for #{service_name}\n"
      report += "=====================================\n"
      report += "Total Errors: #{error_count}\n"
      report += "Error Types:\n"

      error_types.each do |type, count|
        report += "  #{type}: #{count}\n"
      end

      File.open('metrics.log', 'a') do |f|
        f.puts "[#{Time.now}] #{report}"
      end

      send_email('admin@example.com', 'Error Alert', report) if error_count > 10

      report
    end
  end

  private

  def get_cpu_usage
    rand(0..100)
  end

  def get_memory_usage
    rand(100..1000)
  end

  def send_email(to, subject, body)
    puts "Email sent to #{to}: #{subject}"
  end
end
