# frozen_string_literal: true

require 'yaml'
require 'erb'

class AppConfig
  CONFIG_PATH = 'config/app_config.yml'

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
      ENV.fetch('RAILS_ENV', 'development')
    end

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

    def config
      deep_symbolize_keys(load_config[env])
    end
  end
end
