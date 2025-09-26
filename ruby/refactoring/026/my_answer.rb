# frozen_string_literal: true

class ConfigParamValidator
  def initialize(config)
    @config = config
  end

  def validate
    raise NotImplementedError, "#{self.class} must implement #validate"
  end

  private

  def failure_result(info)
    { success: false, info: }
  end
end

class HostValidator < ConfigParamValidator
  def validate
    return failure_result('database_host is required') unless host_valid?(@config['database_host'])

    { success: true }
  end

  private

  def host_valid?(host)
    !host.nil? && !host.empty?
  end
end

class PortValidator < ConfigParamValidator
  MINIMUM_PORT_NUMBER = 1
  MAXIMUM_PORT_NUMBER = 65_535

  def validate
    return failure_result("database_port must be an integer between #{MINIMUM_PORT_NUMBER} and #{MAXIMUM_PORT_NUMBER}") unless port_valid?(@config['database_port'])

    { success: true }
  end

  private

  def port_valid?(port)
    !port.nil? && port.is_a?(Integer) && port.between?(MINIMUM_PORT_NUMBER, MAXIMUM_PORT_NUMBER)
  end
end

class ApiKeyValidator < ConfigParamValidator
  MINIMUM_API_KEY_LENGTH = 8

  def validate
    return failure_result("api_key must be at least #{MINIMUM_API_KEY_LENGTH} characters") unless api_key_valid?(@config['api_key'])

    { success: true }
  end

  private

  def api_key_valid?(api_key)
    !api_key.nil? && api_key.length >= MINIMUM_API_KEY_LENGTH
  end
end

class LogLevelValidator < ConfigParamValidator
  VALID_LOG_LEVELS = %w[debug info warn error].freeze

  def validate
    return failure_result("log_level must be one of: #{VALID_LOG_LEVELS.join(', ')}") unless log_level_valid?(@config['log_level'])

    { success: true }
  end

  private

  def log_level_valid?(log_level)
    VALID_LOG_LEVELS.include?(log_level)
  end
end

class TimeoutValidator < ConfigParamValidator
  def validate
    return failure_result('timeout must be a positive integer') unless timeout_valid?(@config['timeout'])

    { success: true }
  end

  private

  def timeout_valid?(timeout)
    !timeout.nil? && timeout.is_a?(Integer) && timeout.positive?
  end
end

class ConfigValidator
  def initialize(config)
    @validators = [
      HostValidator.new(config),
      PortValidator.new(config),
      ApiKeyValidator.new(config),
      LogLevelValidator.new(config),
      TimeoutValidator.new(config)
    ]
  end

  def validate
    validation_errors = @validators.each_with_object([]) do |validator, errors|
      result = validator.validate
      errors << result[:info] unless result[:success]
    end

    if validation_errors.empty?
      { success: true }
    else
      { success: false, info: validation_errors }
    end
  end
end

class EnvironmentConfig
  class << self
    def to_h
      {
        'database_host' => self::DATABASE_HOST,
        'database_port' => self::DATABASE_PORT,
        'api_key' => self::API_KEY,
        'cache_enabled' => self::CACHE_ENABLED,
        'log_level' => self::LOG_LEVEL,
        'timeout' => self::TIMEOUT
      }
    end
  end
end

class DevelopmentConfig < EnvironmentConfig
  DATABASE_HOST = 'localhost'
  DATABASE_PORT = 5432
  API_KEY = 'dev_key_123'
  CACHE_ENABLED = false
  LOG_LEVEL = 'debug'
  TIMEOUT = 30
end

class StagingConfig < EnvironmentConfig
  DATABASE_HOST = 'staging.db.com'
  DATABASE_PORT = 5432
  API_KEY = 'staging_key_456'
  CACHE_ENABLED = true
  LOG_LEVEL = 'info'
  TIMEOUT = 60
end

class ProductionConfig < EnvironmentConfig
  DATABASE_HOST = 'prod.db.com'
  DATABASE_PORT = 5432
  API_KEY = 'prod_key_789'
  CACHE_ENABLED = true
  LOG_LEVEL = 'warn'
  TIMEOUT = 120
end

class TestConfig < EnvironmentConfig
  DATABASE_HOST = 'test.db.com'
  DATABASE_PORT = 5433
  API_KEY = 'test_key_000'
  CACHE_ENABLED = false
  LOG_LEVEL = 'debug'
  TIMEOUT = 10
end

class EnvironmentConfigDispatcher
  ENVIRONMENT_CONFIG_MAP = {
    development: DevelopmentConfig,
    staging: StagingConfig,
    production: ProductionConfig,
    test: TestConfig
  }.freeze

  class << self
    def dispatch(environment)
      ENVIRONMENT_CONFIG_MAP[environment.to_sym]
    end
  end
end

class ConfigObserver
  def initialize(&block)
    @callback = block
  end

  def notify(key:, old_value:, new_value:)
    @callback.call(key, old_value, new_value)
  end
end

class DynamicConfig
  CONFIG_PARAMS = %w[database_host database_port api_key cache_enabled log_level timeout].freeze
  ENVIRONMENTS = %w[development staging production test].freeze

  def initialize(data = {})
    @data = data
    @observers = []
    define_config_param_accessors
    define_config_param_setters
    define_environment_config_accessors
  end

  def get_environment_config(env)
    unless ENVIRONMENTS.include?(env)
      puts "Unknown environment: #{env}"
      return {}
    end

    send("get_#{env}_config")
  end

  def validate_config
    result = ConfigValidator.new(@data).validate
    return result[:info] unless result[:success]

    []
  end

  def add_observer(&block)
    @observers << ConfigObserver.new(&block)
  end

  def notify_observers(key:, old_value:, new_value:)
    @observers.each do |observer|
      observer.notify(key: key, old_value:, new_value:)
    end
  end

  def method_missing(method_name, *args)
    puts "Unknown method: #{method_name}" unless self.class.method_defined?(method_name)

    puts "Method is defined"
  end

  private

  def define_config_param_accessors
    CONFIG_PARAMS.each do |param|
      self.class.define_method(param) do
        @data[param]
      end
    end
  end

  def define_config_param_setters
    CONFIG_PARAMS.each do |param|
      self.class.define_method("#{param}=") do |new_value|
        old_value = @data[param]
        @data[param] = new_value
        notify_observers(key: param, old_value:, new_value:)
      end
    end
  end

  def define_environment_config_accessors
    ENVIRONMENTS.each do |env|
      self.class.define_method("get_#{env}_config") do
        EnvironmentConfigDispatcher.dispatch(env).to_h
      end
    end
  end
end
