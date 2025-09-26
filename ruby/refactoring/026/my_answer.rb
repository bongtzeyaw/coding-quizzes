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

class DynamicConfig
  CONFIG_PARAMS = %w[database_host database_port api_key cache_enabled log_level timeout].freeze
  ENVIRONMENTS = %w[development staging production test].freeze

  def initialize(data = {})
    @data = data
    @observers = []
    define_config_param_accessors
    define_config_param_setters
  end

  def timeout
    @data['timeout']
  end

  def timeout=(value)
    old_value = @data['timeout']
    @data['timeout'] = value
    notify_observers('timeout', old_value, value)
  end

  def get_environment_config(env)
    unless ENVIRONMENTS.include?(env)
      puts "Unknown environment: #{env}"
      return {}
    end

    send("get_#{env}_config")
  end

  def validate_config
    errors = []

    errors << 'database_host is required' if @data['database_host'].nil? || @data['database_host'].empty?

    port = @data['database_port']
    if port.nil? || !port.is_a?(Integer) || port < 1 || port > 65_535
      errors << 'database_port must be an integer between 1 and 65535'
    end

    errors << 'api_key must be at least 8 characters' if @data['api_key'].nil? || @data['api_key'].length < 8

    valid_levels = %w[debug info warn error]
    errors << "log_level must be one of: #{valid_levels.join(', ')}" unless valid_levels.include?(@data['log_level'])

    timeout = @data['timeout']
    errors << 'timeout must be a positive integer' if timeout.nil? || !timeout.is_a?(Integer) || timeout < 1

    errors
  end

  def add_observer(&block)
    @observers << block
  end

  def notify_observers(key, old_value, new_value)
    @observers.each do |observer|
      observer.call(key, old_value, new_value)
    end
  end

  def method_missing(method_name, *args)
    puts "Unknown method: #{method_name}"
    nil
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
