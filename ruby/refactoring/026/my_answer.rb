class DynamicConfig
  def initialize(data = {})
    @data = data
    @observers = []
  end

  def database_host
    @data['database_host']
  end

  def database_host=(value)
    old_value = @data['database_host']
    @data['database_host'] = value
    notify_observers('database_host', old_value, value)
  end

  def database_port
    @data['database_port']
  end

  def database_port=(value)
    old_value = @data['database_port']
    @data['database_port'] = value
    notify_observers('database_port', old_value, value)
  end

  def api_key
    @data['api_key']
  end

  def api_key=(value)
    old_value = @data['api_key']
    @data['api_key'] = value
    notify_observers('api_key', old_value, value)
  end

  def cache_enabled
    @data['cache_enabled']
  end

  def cache_enabled=(value)
    old_value = @data['cache_enabled']
    @data['cache_enabled'] = value
    notify_observers('cache_enabled', old_value, value)
  end

  def log_level
    @data['log_level']
  end

  def log_level=(value)
    old_value = @data['log_level']
    @data['log_level'] = value
    notify_observers('log_level', old_value, value)
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
    case env
    when 'development'
      get_development_config
    when 'staging'
      get_staging_config
    when 'production'
      get_production_config
    when 'test'
      get_test_config
    else
      puts "Unknown environment: #{env}"
      {}
    end
  end

  def get_development_config
    {
      'database_host' => 'localhost',
      'database_port' => 5432,
      'api_key' => 'dev_key_123',
      'cache_enabled' => false,
      'log_level' => 'debug',
      'timeout' => 30
    }
  end

  def get_staging_config
    {
      'database_host' => 'staging.db.com',
      'database_port' => 5432,
      'api_key' => 'staging_key_456',
      'cache_enabled' => true,
      'log_level' => 'info',
      'timeout' => 60
    }
  end

  def get_production_config
    {
      'database_host' => 'prod.db.com',
      'database_port' => 5432,
      'api_key' => 'prod_key_789',
      'cache_enabled' => true,
      'log_level' => 'warn',
      'timeout' => 120
    }
  end

  def get_test_config
    {
      'database_host' => 'test.db.com',
      'database_port' => 5433,
      'api_key' => 'test_key_000',
      'cache_enabled' => false,
      'log_level' => 'debug',
      'timeout' => 10
    }
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
end
