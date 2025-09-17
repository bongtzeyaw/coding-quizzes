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

class Collector
  def initialize(service)
    @service = service
  end

  def collect
    raise NotImplementedError, "#{self.class} must implement #collect"
  end
end

class PerformanceCollector < Collector
  def collect
    start_time = Time.now.utc
    cpu_before = cpu_usage
    memory_before = memory_usage

    result = @service.call

    end_time = Time.now.utc
    cpu_after = cpu_usage
    memory_after = memory_usage

    {
      execution_time: end_time - start_time,
      cpu_usage: cpu_after - cpu_before,
      memory_usage: memory_after - memory_before,
      result:
    }
  end

  private

  def cpu_usage
    rand(0..100)
  end

  def memory_usage
    rand(100..1000)
  end
end

class AvailabilityCollector < Collector
  def collect
    success_count = 0
    total_count = 10

    total_count.times do
      success_count += 1 if @service.check_health
      sleep(1)
    end

    success_rate = (success_count.to_f / total_count) * 100

    {
      success_rate:,
      failed_checks: total_count - success_count
    }
  end
end

class ErrorRateCollector < Collector
  def collect
    errors = @service.errors

    error_count = errors.length
    error_types = errors.group_by { |e| e[:type] || 'Unknown' }
                        .transform_values(&:count)

    {
      error_count: error_count,
      error_types: error_types
    }
  end
end

class CollectorDispatcher
  COLLECTOR_MAP = {
    performance: PerformanceCollector,
    availability: AvailabilityCollector,
    error_rate: ErrorRateCollector
  }.freeze

  class << self
    def dispatch(metric_type)
      COLLECTOR_MAP[metric_type.to_sym]
    end
  end
end

class MetricsCollector
  def collect_and_report(service_name, metric_type)
    collector_class = CollectorDispatcher.dispatch(metric_type)
    return nil unless collector_class

    service_class = ServiceDispatcher.dispatch(service_name)
    return nil unless service_class

    metrics = collector_class.new(service_class).collect

    if metric_type == 'performance'
      execution_time = metrics[:execution_time]
      cpu_usage = metrics[:cpu_usage]
      memory_usage = metrics[:memory_usage]
      result = metrics[:result]

      report = ''
      report += "Performance Report for #{service_name}\n"
      report += "=====================================\n"
      report += "Execution Time: #{execution_time} seconds\n"
      report += "CPU Usage: #{cpu_usage}%\n"
      report += "Memory Usage: #{memory_usage} MB\n"
      report += "Result: #{result}\n"

      File.open('metrics.log', 'a') do |f|
        f.puts "[#{Time.now}] #{report}"
      end

      send_email('admin@example.com', 'Performance Alert', report) if execution_time > 5.0

      report

    elsif metric_type == 'availability'
      success_rate = metrics[:success_rate]
      failed_checks = metrics[:failed_checks]

      report = ''
      report += "Availability Report for #{service_name}\n"
      report += "=====================================\n"
      report += "Success Rate: #{success_rate}%\n"
      report += "Failed Checks: #{failed_checks}\n"

      File.open('metrics.log', 'a') do |f|
        f.puts "[#{Time.now}] #{report}"
      end

      send_email('admin@example.com', 'Availability Alert', report) if availability < 90.0

      report

    elsif metric_type == 'error_rate'
      error_count = metrics[:error_count]
      error_types = metrics[:error_types]

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

  def send_email(to, subject, body)
    puts "Email sent to #{to}: #{subject}"
  end
end
