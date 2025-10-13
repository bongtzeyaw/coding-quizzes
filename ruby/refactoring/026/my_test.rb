require 'minitest/autorun'
require_relative 'my_answer'

class DynamicConfigTest < Minitest::Test
  def setup
    @config = DynamicConfig.new
  end

  def test_initialization_with_data
    initial_data = { 'database_host' => 'test_host' }
    config = DynamicConfig.new(initial_data)
    assert_equal 'test_host', config.database_host
  end

  def test_database_host_accessor
    @config.database_host = 'new_host'
    assert_equal 'new_host', @config.database_host
  end

  def test_database_port_accessor
    @config.database_port = 5432
    assert_equal 5432, @config.database_port
  end

  def test_api_key_accessor
    @config.api_key = 'new_api_key'
    assert_equal 'new_api_key', @config.api_key
  end

  def test_cache_enabled_accessor
    @config.cache_enabled = true
    assert_equal true, @config.cache_enabled
  end

  def test_log_level_accessor
    @config.log_level = 'info'
    assert_equal 'info', @config.log_level
  end

  def test_timeout_accessor
    @config.timeout = 100
    assert_equal 100, @config.timeout
  end

  def test_observers_are_notified_on_change
    observer_calls = []
    @config.add_observer do |key, old_value, new_value|
      observer_calls << [key, old_value, new_value]
    end
    @config.database_host = 'updated_host'
    assert_equal [['database_host', nil, 'updated_host']], observer_calls
  end

  def test_get_environment_config_development
    config_data = @config.get_environment_config('development')
    assert_equal 'localhost', config_data['database_host']
    assert_equal 5432, config_data['database_port']
    assert_equal 'dev_key_123', config_data['api_key']
  end

  def test_get_environment_config_staging
    config_data = @config.get_environment_config('staging')
    assert_equal 'staging.db.com', config_data['database_host']
    assert_equal true, config_data['cache_enabled']
  end

  def test_get_environment_config_production
    config_data = @config.get_environment_config('production')
    assert_equal 'prod_key_789', config_data['api_key']
    assert_equal 120, config_data['timeout']
  end

  def test_get_environment_config_test
    config_data = @config.get_environment_config('test')
    assert_equal 'test_key_000', config_data['api_key']
    assert_equal 5433, config_data['database_port']
  end

  def test_get_environment_config_unknown
    config_data = @config.get_environment_config('unknown')
    assert_equal({}, config_data)
  end

  def test_validate_config_with_all_valid_fields
    @config.database_host = 'valid_host'
    @config.database_port = 8080
    @config.api_key = 'long_enough_api_key'
    @config.cache_enabled = true
    @config.log_level = 'info'
    @config.timeout = 50
    assert_empty @config.validate_config
  end

  def test_validate_config_with_missing_database_host
    @config.database_host = ''
    errors = @config.validate_config
    assert_includes errors, 'database_host is required'
  end

  def test_validate_config_with_invalid_database_port
    @config.database_port = 'not_a_number'
    errors = @config.validate_config
    assert_includes errors, 'database_port must be an integer between 1 and 65535'
    @config.database_port = 0
    errors = @config.validate_config
    assert_includes errors, 'database_port must be an integer between 1 and 65535'
    @config.database_port = 65_536
    errors = @config.validate_config
    assert_includes errors, 'database_port must be an integer between 1 and 65535'
  end

  def test_validate_config_with_short_api_key
    @config.api_key = 'short'
    errors = @config.validate_config
    assert_includes errors, 'api_key must be at least 8 characters'
  end

  def test_validate_config_with_invalid_log_level
    @config.log_level = 'critical'
    errors = @config.validate_config
    assert_includes errors, 'log_level must be one of: debug, info, warn, error'
  end

  def test_validate_config_with_invalid_timeout
    @config.timeout = 0
    errors = @config.validate_config
    assert_includes errors, 'timeout must be a positive integer'
  end

  def test_method_missing
    assert_nil @config.non_existent_method
  end
end
