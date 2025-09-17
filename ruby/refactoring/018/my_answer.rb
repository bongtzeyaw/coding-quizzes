# frozen_string_literal: true

class ReportLogger
  DEFAULT_LOG_PATH = File.expand_path('metrics.log', __dir__)

  def initialize(log_path: DEFAULT_LOG_PATH)
    @log_path = log_path
  end

  def log(generated_report:)
    File.open(@log_path, 'a') do |f|
      f.puts "[#{Time.now.utc}] #{generated_report}"
    end
  end
end

class ReportMailer
  DEFAULT_RECIPIENT = 'admin@example.com'

  def initialize(recipient: DEFAULT_RECIPIENT)
    @recipient = recipient
  end

  def send_if_needed(report:)
    return unless report.alert_triggered?

    send(report.alert_type)
  end

  private

  def send(subject)
    puts "Email sent to #{@recipient}: #{subject}"
  end
end

class Report
  def initialize(metrics)
    @metrics = metrics
  end

  def generate(service_name)
    raise NotImplementedError, "#{self.class} must implement #generate"
  end

  def alert_triggered?
    raise NotImplementedError, "#{self.class} must implement #alert_triggered?"
  end

  def alert_type
    raise NotImplementedError, "#{self.class} must implement #alert_type"
  end
end

class PerformanceReport < Report
  def generate(service_name)
    <<~REPORT
      Performance Report for #{service_name}
      =====================================
      Execution Time: #{@metrics[:execution_time]} seconds
      CPU Usage: #{@metrics[:cpu_usage]}%
      Memory Usage: #{@metrics[:memory_usage]} MB
      Result: #{@metrics[:result]}
    REPORT
  end

  def alert_triggered?
    @metrics[:execution_time] > 5.0
  end

  def alert_type
    'Performance Alert'
  end
end

class AvailabilityReport < Report
  def generate(service_name)
    <<~REPORT
      Availability Report for #{service_name}
      =====================================
      Success Rate: #{@metrics[:success_rate]}%
      Failed Checks: #{@metrics[:failed_checks]}
    REPORT
  end

  def alert_triggered?
    @metrics[:success_rate] < 90.0
  end

  def alert_type
    'Availability Alert'
  end
end

class ErrorRateReport < Report
  def generate(service_name)
    <<~REPORT
      Error Report for #{service_name}
      =====================================
      Total Errors: #{@metrics[:error_count]}
      Error Types:
      #{error_type_text}
    REPORT
  end

  def alert_triggered?
    @metrics[:error_count] > 10
  end

  def alert_type
    'Error Alert'
  end

  private

  def error_type_text
    @metrics[:error_types].map do |type, count|
      "  #{type}: #{count}"
    end.join("\n")
  end
end

class ReportDispatcher
  REPORT_MAP = {
    performance: PerformanceReport,
    availability: AvailabilityReport,
    error_rate: ErrorRateReport
  }.freeze

  class << self
    def dispatch(metric_type)
      REPORT_MAP[metric_type.to_sym]
    end
  end
end

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
  def initialize(logger: ReportLogger.new, mailer: ReportMailer.new)
    @logger = logger
    @mailer = mailer
  end

  def collect_and_report(service_name, metric_type)
    collector_class = CollectorDispatcher.dispatch(metric_type)
    return nil unless collector_class

    service_class = ServiceDispatcher.dispatch(service_name)
    return nil unless service_class

    report_class = ReportDispatcher.dispatch(metric_type)
    return nil unless report_class

    metrics = collector_class.new(service_class).collect

    report = report_class.new(metrics)
    generated_report = report.generate(service_name)

    @logger.log(generated_report:)
    @mailer.send_if_needed(report:)

    generated_report
  end
end
