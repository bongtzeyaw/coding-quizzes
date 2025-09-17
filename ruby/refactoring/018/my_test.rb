require 'minitest/autorun'
require 'tempfile'
require_relative 'my_answer'

class ReportLoggerTest < Minitest::Test
  def setup
    @temp_file = Tempfile.new(['metrics', '.log'])
    @logger = ReportLogger.new(log_path: @temp_file.path)
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  def test_log_writes_to_file
    generated_report = 'Test report content'
    @logger.log(generated_report:)

    @temp_file.rewind
    log_content = @temp_file.read

    assert_includes log_content, generated_report
  end
end

class ReportMailerTest < Minitest::Test
  def setup
    @mailer = ReportMailer.new(recipient: 'test@example.com')
  end

  def test_send_if_needed_with_alert_triggered
    report = Minitest::Mock.new
    report.expect(:alert_triggered?, true)
    report.expect(:alert_type, 'Test Alert')

    original_stdout = $stdout
    $stdout = StringIO.new

    @mailer.send_if_needed(report:)

    assert_includes $stdout.string, 'Email sent to test@example.com: Test Alert'
  ensure
    $stdout = original_stdout
  end

  def test_send_if_needed_without_alert
    report = Minitest::Mock.new
    report.expect(:alert_triggered?, false)

    original_stdout = $stdout
    $stdout = StringIO.new

    @mailer.send_if_needed(report:)

    assert_empty $stdout.string
  ensure
    $stdout = original_stdout
  end
end

class PerformanceReportTest < Minitest::Test
  def setup
    @metrics = {
      execution_time: 3.0,
      cpu_usage: 20,
      memory_usage: 200,
      result: 'Test Result'
    }
    @report = PerformanceReport.new(@metrics)
  end

  def test_generate_report
    expected_report = <<~REPORT
      Performance Report for test_service
      =====================================
      Execution Time: 3.0 seconds
      CPU Usage: 20%
      Memory Usage: 200 MB
      Result: Test Result
    REPORT

    assert_equal expected_report, @report.generate('test_service')
  end

  def test_alert_triggered_returns_true_when_execution_time_exceeds_threshold
    metrics = { execution_time: 5.1 }
    report = PerformanceReport.new(metrics)

    assert report.alert_triggered?
  end

  def test_alert_triggered_returns_false_when_execution_time_below_threshold
    metrics = { execution_time: 4.9 }
    report = PerformanceReport.new(metrics)

    refute report.alert_triggered?
  end

  def test_alert_type
    assert_equal 'Performance Alert', @report.alert_type
  end
end

class AvailabilityReportTest < Minitest::Test
  def setup
    @metrics = {
      success_rate: 95.0,
      failed_checks: 2
    }
    @report = AvailabilityReport.new(@metrics)
  end

  def test_generate_report
    expected_report = <<~REPORT
      Availability Report for test_service
      =====================================
      Success Rate: 95.0%
      Failed Checks: 2
    REPORT

    assert_equal expected_report, @report.generate('test_service')
  end

  def test_alert_triggered_returns_true_when_success_rate_below_threshold
    metrics = { success_rate: 89.9 }
    report = AvailabilityReport.new(metrics)

    assert report.alert_triggered?
  end

  def test_alert_triggered_returns_false_when_success_rate_above_threshold
    metrics = { success_rate: 90.0 }
    report = AvailabilityReport.new(metrics)

    refute report.alert_triggered?
  end

  def test_alert_type
    assert_equal 'Availability Alert', @report.alert_type
  end
end

class ErrorRateReportTest < Minitest::Test
  def setup
    @metrics = {
      error_count: 5,
      error_types: {
        'ConnectionError' => 2,
        'Timeout' => 3
      }
    }
    @report = ErrorRateReport.new(@metrics)
  end

  def test_generate_report
    expected_report = <<~REPORT
      Error Report for test_service
      =====================================
      Total Errors: 5
      Error Types:
      #{@report.send(:error_type_text)}
    REPORT

    assert_equal expected_report, @report.generate('test_service')
  end

  def test_alert_triggered_returns_true_when_error_count_exceeds_threshold
    metrics = { error_count: 11 }
    report = ErrorRateReport.new(metrics)

    assert report.alert_triggered?
  end

  def test_alert_triggered_returns_false_when_error_count_below_threshold
    metrics = { error_count: 10 }
    report = ErrorRateReport.new(metrics)

    refute report.alert_triggered?
  end

  def test_alert_type
    assert_equal 'Error Alert', @report.alert_type
  end

  def test_error_type_text_with_empty_error_types
    metrics = { error_count: 0, error_types: {} }
    report = ErrorRateReport.new(metrics)

    assert_equal '', report.send(:error_type_text)
  end
end

class PerformanceCollectorTest < Minitest::Test
  def setup
    service_class = Minitest::Mock.new
    service_class.expect(:call, 'Test Result')

    @collector = PerformanceCollector.new(service_class)
  end

  def test_collect_returns_performance_metrics
    Time.stub :now, Time.at(100) do
      @collector.stub :cpu_usage, 50 do
        @collector.stub :memory_usage, 500 do
          metrics = @collector.collect

          assert_equal 0, metrics[:execution_time]
          assert_equal 0, metrics[:cpu_usage]
          assert_equal 0, metrics[:memory_usage]
          assert_equal 'Test Result', metrics[:result]
        end
      end
    end
  end
end

class AvailabilityCollectorTest < Minitest::Test
  def setup
    @service_class = Minitest::Mock.new
    10.times do
      @service_class.expect(:check_health, true)
    end

    @collector = AvailabilityCollector.new(@service_class)
  end

  def test_collect_returns_availability_metrics
    @collector.stub :sleep, nil do
      metrics = @collector.collect

      assert_equal 100.0, metrics[:success_rate]
      assert_equal 0, metrics[:failed_checks]
    end
  end
end

class ErrorRateCollectorTest < Minitest::Test
  def setup
    @service_class = Minitest::Mock.new
    @service_class.expect(:errors, [
                            { type: 'Timeout', message: 'Request timeout' },
                            { type: 'NotFound', message: 'Not found' }
                          ])

    @collector = ErrorRateCollector.new(@service_class)
  end

  def test_collect_returns_error_metrics
    metrics = @collector.collect

    assert_equal 2, metrics[:error_count]
    assert_equal({ 'Timeout' => 1, 'NotFound' => 1 }, metrics[:error_types])
  end
end

class MetricsCollectorTest < Minitest::Test
  def setup
    @temp_file = Tempfile.new(['metrics', '.log'])
    @logger = ReportLogger.new(log_path: @temp_file.path)
    @mailer = ReportMailer.new

    @collector = MetricsCollector.new(
      logger: @logger,
      mailer: @mailer
    )
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  def test_collect_and_report_for_performance_metrics
    collector_dispatch_mock = Minitest::Mock.new
    collector_dispatch_mock.expect(:call, PerformanceCollector, ['performance'])

    service_dispatch_mock = Minitest::Mock.new
    service_dispatch_mock.expect(:call, ApiService, ['api'])

    report_dispatch_mock = Minitest::Mock.new
    report_dispatch_mock.expect(:call, PerformanceReport, ['performance'])

    mock_collector = Minitest::Mock.new
    mock_collector.expect(:collect, {
                            execution_time: 3.0,
                            cpu_usage: 20,
                            memory_usage: 200,
                            result: 'API Response'
                          })

    mock_collector_class = Minitest::Mock.new
    mock_collector_class.expect(:new, mock_collector, [ApiService])

    CollectorDispatcher.stub(:dispatch, collector_dispatch_mock) do
      ServiceDispatcher.stub(:dispatch, service_dispatch_mock) do
        ReportDispatcher.stub(:dispatch, report_dispatch_mock) do
          PerformanceCollector.stub(:new, proc { |service| mock_collector_class.new(service) }) do
            expected_report = <<~REPORT
              Performance Report for api
              =====================================
              Execution Time: 3.0 seconds
              CPU Usage: 20%
              Memory Usage: 200 MB
              Result: API Response
            REPORT

            assert_equal expected_report, @collector.collect_and_report('api', 'performance')

            @temp_file.rewind
            log_content = @temp_file.read
            assert_includes log_content, expected_report
          end
        end
      end
    end

    collector_dispatch_mock.verify
    service_dispatch_mock.verify
    report_dispatch_mock.verify
    mock_collector.verify
    mock_collector_class.verify
  end
end
