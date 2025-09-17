require 'minitest/autorun'
require 'tempfile'
require_relative 'my_answer'

class MetricsCollectorTest < Minitest::Test
  def setup
    @collector = MetricsCollector.new
    @cpu_usage_values = [10, 30]
    @memory_usage_values = [100, 300]
    @time_now_values = [Time.at(100), Time.at(103)]
    @api_health_values = [true] * 3 + [false] * 7
    @temp_file = Tempfile.new(['metrics', '.log'])
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  def read_log_file
    @temp_file.rewind
    @temp_file.read
  end

  def test_performance_report_for_api_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :get_cpu_usage, -> { @cpu_usage_values.shift } do
        @collector.stub :get_memory_usage, -> { @memory_usage_values.shift } do
          @collector.stub :send_email, nil do
            Time.stub :now, -> { @time_now_values.shift } do
              report = @collector.collect_and_report('api', 'performance')
              expected_report = <<~REPORT
                Performance Report for api
                =====================================
                Execution Time: 3.0 seconds
                CPU Usage: 20%
                Memory Usage: 200 MB
                Result: API Response
              REPORT
              assert_equal expected_report, report

              log_content = read_log_file
              assert_includes log_content, expected_report
            end
          end
        end
      end
    end
  end

  def test_performance_report_for_database_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :get_cpu_usage, -> { @cpu_usage_values.shift } do
        @collector.stub :get_memory_usage, -> { @memory_usage_values.shift } do
          @collector.stub :send_email, nil do
            Time.stub :now, -> { @time_now_values.shift } do
              report = @collector.collect_and_report('database', 'performance')
              expected_report = <<~REPORT
                Performance Report for database
                =====================================
                Execution Time: 3.0 seconds
                CPU Usage: 20%
                Memory Usage: 200 MB
                Result: DB Response
              REPORT
              assert_equal expected_report, report

              log_content = read_log_file
              assert_includes log_content, expected_report
            end
          end
        end
      end
    end
  end

  def test_performance_report_for_cache_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :get_cpu_usage, -> { @cpu_usage_values.shift } do
        @collector.stub :get_memory_usage, -> { @memory_usage_values.shift } do
          @collector.stub :send_email, nil do
            Time.stub :now, -> { @time_now_values.shift } do
              report = @collector.collect_and_report('cache', 'performance')
              expected_report = <<~REPORT
                Performance Report for cache
                =====================================
                Execution Time: 3.0 seconds
                CPU Usage: 20%
                Memory Usage: 200 MB
                Result: Cache Response
              REPORT
              assert_equal expected_report, report

              log_content = read_log_file
              assert_includes log_content, expected_report
            end
          end
        end
      end
    end
  end

  def test_availability_report_for_api_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :check_api_health, -> { @api_health_values.shift } do
        @collector.stub :send_email, nil do
          @collector.stub :sleep, nil do
            report = @collector.collect_and_report('api', 'availability')
            expected_report = <<~REPORT
              Availability Report for api
              =====================================
              Success Rate: 30.0%
              Failed Checks: 7
            REPORT
            assert_equal expected_report, report

            log_content = read_log_file
            assert_includes log_content, expected_report
          end
        end
      end
    end
  end

  def test_availability_report_for_database_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :check_database_health, -> { @api_health_values.shift } do
        @collector.stub :send_email, nil do
          @collector.stub :sleep, nil do
            report = @collector.collect_and_report('database', 'availability')
            expected_report = <<~REPORT
              Availability Report for database
              =====================================
              Success Rate: 30.0%
              Failed Checks: 7
            REPORT
            assert_equal expected_report, report

            log_content = read_log_file
            assert_includes log_content, expected_report
          end
        end
      end
    end
  end

  def test_availability_report_for_cache_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :check_cache_health, -> { @api_health_values.shift } do
        @collector.stub :send_email, nil do
          @collector.stub :sleep, nil do
            report = @collector.collect_and_report('cache', 'availability')
            expected_report = <<~REPORT
              Availability Report for cache
              =====================================
              Success Rate: 30.0%
              Failed Checks: 7
            REPORT
            assert_equal expected_report, report

            log_content = read_log_file
            assert_includes log_content, expected_report
          end
        end
      end
    end
  end

  def test_error_rate_report_for_api_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :send_email, nil do
        report = @collector.collect_and_report('api', 'error_rate')
        expected_report = <<~REPORT
          Error Report for api
          =====================================
          Total Errors: 2
          Error Types:
            Timeout: 1
            NotFound: 1
        REPORT
        assert_equal expected_report, report

        log_content = read_log_file
        assert_includes log_content, expected_report
      end
    end
  end

  def test_error_rate_report_for_database_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :send_email, nil do
        report = @collector.collect_and_report('database', 'error_rate')
        expected_report = <<~REPORT
          Error Report for database
          =====================================
          Total Errors: 1
          Error Types:
            ConnectionError: 1
        REPORT
        assert_equal expected_report, report

        log_content = read_log_file
        assert_includes log_content, expected_report
      end
    end
  end

  def test_error_rate_report_for_cache_service
    File.stub :open, ->(_path, _mode, &block) { block.call(@temp_file) } do
      @collector.stub :send_email, nil do
        report = @collector.collect_and_report('cache', 'error_rate')
        expected_report = <<~REPORT
          Error Report for cache
          =====================================
          Total Errors: 0
          Error Types:
        REPORT
        assert_equal expected_report, report

        log_content = read_log_file
        assert_includes log_content, expected_report
      end
    end
  end
end
