# frozen_string_literal: true

require 'yaml'
require 'erb'

class Environment
  VALID_RAILS_ENVS = %w[production staging test development].freeze

  class << self
    def current_rails_env
      env = ENV.fetch('RAILS_ENV', 'development')
      raise 'Invalid environment' unless valid_rails_env?(env)

      env
    end

    private

    def valid_rails_env?(env)
      VALID_RAILS_ENVS.include?(env)
    end
  end
end

class ConfigLoader
  CONFIG_PATH = 'config/app_config.yml'

  def initialize(env)
    @env = env
  end

  def config
    deep_symbolize_keys(load_config[@env])
  end

  private

  def load_config
    erb_result = ERB.new(File.read(CONFIG_PATH)).result
    YAML.load(erb_result)
  rescue Errno::ENOENT => e
    puts "Warning: Unable to load config file: #{e.message}"
    {}
  end

  def deep_symbolize_keys(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize_keys(v) }
    when Array
      obj.map { |v| deep_symbolize_keys(v) }
    else
      obj
    end
  end
end

class AppConfig
  class << self
    def get_database_config
      config[:database]
    end

    def get_redis_config
      config[:redis]
    end

    def get_api_endpoints
      config[:api]
    end

    private

    def env
      Environment.current_rails_env
    end

    def config
      ConfigLoader.new(env).config
    end
  end
end
