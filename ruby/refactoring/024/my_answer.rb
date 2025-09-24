# frozen_string_literal: true

class ConfigValidator
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

  def valid_integer?(value)
    value.is_a?(Integer) && value >= 0
  end

  def valid_string?(value)
    value.is_a?(String) && !value.empty?
  end

  def valid_boolean?(value)
    [true, false].include?(value)
  end
end

class RequiredFieldValidator < ConfigValidator
  REQUIRED_FIELD_KEYWORD_SUFFIX = '_required'

  def validate
    required_config = @config.filter { |key, _| key.end_with?(REQUIRED_FIELD_KEYWORD_SUFFIX) }
    key_with_missing_value, = required_config.find { |_, value| value.nil? }

    return failure_result("Required config missing: #{key_with_missing_value}") if key_with_missing_value

    { success: true }
  end
end

class PortValidator < ConfigValidator
  PORT_FIELD_KEYWORD = 'port'

  def validate
    port_config = @config.filter { |key, _| key.include?(PORT_FIELD_KEYWORD) }
    invalid_key, invalid_value = port_config.find { |_key, value| !valid_integer?(value) }

    return failure_result("Invalid number for #{invalid_key}: #{invalid_value}") if invalid_key

    { success: true }
  end
end

class TimeoutValidator < ConfigValidator
  TIMEOUT_FIELD_KEYWORD = 'timeout'

  def validate
    timeout_config = @config.filter { |key, _| key.include?(TIMEOUT_FIELD_KEYWORD) }
    invalid_key, invalid_value = timeout_config.find { |_key, value| !valid_integer?(value) }

    return failure_result("Invalid number for #{invalid_key}: #{invalid_value}") if invalid_key

    { success: true }
  end
end

class UrlValidator < ConfigValidator
  URL_FIELD_KEYWORD = 'url'

  def validate
    url_config = @config.filter { |key, _| key.include?(URL_FIELD_KEYWORD) }
    invalid_key, invalid_value = url_config.find { |_key, value| !valid_string?(value) }

    return failure_result("Invalid string for #{invalid_key}: #{invalid_value}") if invalid_key

    { success: true }
  end
end

class HostValidator < ConfigValidator
  HOST_FIELD_KEYWORD = 'host'

  def validate
    host_config = @config.filter { |key, _| key.include?(HOST_FIELD_KEYWORD) }
    invalid_key, invalid_value = host_config.find { |_key, value| !valid_string?(value) }

    return failure_result("Invalid string for #{invalid_key}: #{invalid_value}") if invalid_key

    { success: true }
  end
end

class EnabledValidator < ConfigValidator
  ENABLED_FIELD_KEYWORD = 'enabled'

  def validate
    enabled_config = @config.filter { |key, _| key.include?(ENABLED_FIELD_KEYWORD) }
    invalid_key, invalid_value = enabled_config.find { |_key, value| !valid_boolean?(value) }

    return failure_result("Invalid boolean for #{invalid_key}: #{invalid_value}") if invalid_key

    { success: true }
  end
end

class DebugValidator < ConfigValidator
  DEBUG_FIELD_KEYWORD = 'debug'

  def validate
    debug_config = @config.filter { |key, _| key.include?(DEBUG_FIELD_KEYWORD) }
    invalid_key, invalid_value = debug_config.find { |_key, value| !valid_boolean?(value) }

    return failure_result("Invalid boolean for #{invalid_key}: #{invalid_value}") if invalid_key

    { success: true }
  end
end

class CircularReferenceValidator < ConfigValidator
  def validate
    errors = []

    @config.each do |key, value|
      errors << "Circular reference detected: #{key}" if circular_reference?(key, value)
    end

    if errors.empty?
      { success: true }
    else
      failure_result(errors.join("\n"))
    end
  end

  private

  def circular_reference?(key, value)
    value.is_a?(String) && value.include?("${#{key}}")
  end
end

class UndefinedReferenceValidator < ConfigValidator
  def validate
    errors = []

    @config.each do |key, value|
      next unless value.is_a?(String) && value.include?('${')

      value.scan(/\${([^}]+)}/).each do |(var_name)|
        errors << "Undefined reference: ${#{var_name}} in #{key}" unless reference_defined?(var_name)
      end
    end

    if errors.empty?
      { success: true }
    else
      failure_result(errors.join("\n"))
    end
  end

  private

  def reference_defined?(var_name)
    @config.key?(var_name)
  end
end

class ConfigLoadValidator
  def initialize(config)
    @validators = [
      RequiredFieldValidator.new(config),
      PortValidator.new(config),
      TimeoutValidator.new(config),
      UrlValidator.new(config),
      HostValidator.new(config),
      EnabledValidator.new(config),
      DebugValidator.new(config)
    ]
  end

  def validate
    @validators.each do |validator|
      result = validator.validate
      return result unless result[:success]
    end

    { success: true }
  end
end

class ConfigManagerValidator
  private

  def failure_result(info)
    { success: false, info: }
  end
end

class LoadValidator < ConfigManagerValidator
  def validate(file_path)
    return failure_result("Config file not found: #{file_path}") unless !file_path.nil? && file_exists?(file_path)

    { success: true }
  end

  private

  def file_exists?(file_path)
    File.exist?(File.expand_path(file_path, __dir__))
  end
end

class ExportValidator < ConfigManagerValidator
  def validate(config_registry:, environment:, format:)
    return failure_result("No config for environment: #{environment}") unless config_registry.environment_exist?(environment)
    return failure_result("Unknown format: #{format}") unless ConfigFormatterDispatcher.format_exists?(format)

    { success: true }
  end
end

class AllConfigValidator < ConfigManagerValidator
  def initialize
    @config_validator_classes = [
      CircularReferenceValidator,
      UndefinedReferenceValidator
    ]
  end

  def validate(config_registry)
    errors = []

    config_registry.all.each do |environment, config|
      puts "Validating #{environment}..."

      @config_validator_classes.each do |config_validator_class|
        validator = config_validator_class.new(config)
        result = validator.validate

        errors << result[:info] unless result[:success]
      end
    end

    if errors.empty?
      { success: true }
    else
      failure_result(errors.join("\n"))
    end
  end
end

class ConfigFormatter
  class << self
    def format(config)
      raise NotImplementedError, "#{self.class} must implement .format"
    end
  end
end

class YamlFormatter < ConfigFormatter
  class << self
    def format(config)
      config.to_yaml
    end
  end
end

class JsonFormatter < ConfigFormatter
  class << self
    def format(config)
      JSON.pretty_generate(config)
    end
  end
end

class EnvFormatter < ConfigFormatter
  ENV_FORMAT_PREFIX = 'APP'

  class << self
    def format(config)
      config.map do |key, value|
        "#{ENV_FORMAT_PREFIX}_#{key.upcase}=#{value}"
      end.join("\n")
    end
  end
end

class ConfigFormatterDispatcher
  FORMATTER_MAP = {
    yaml: YamlFormatter,
    json: JsonFormatter,
    env: EnvFormatter
  }.freeze

  class << self
    def dispatch(format)
      FORMATTER_MAP[format.to_sym]
    end

    def format_exists?(format)
      FORMATTER_MAP.key?(format.to_sym)
    end
  end
end

class EnvConfigLoader
  def load(data:, environment:)
    env_config = {}

    data['default']&.each do |key, value|
      env_config[key] = value
    end

    data[environment]&.each do |key, value|
      env_config[key] = value
    end

    env_config
  end
end

class EnvVariableOverrider
  ENV_KEY_PREFIX = 'APP'

  def override(env_config)
    env_config.each_with_object({}) do |(original_key, original_value), result|
      env_key = "#{ENV_KEY_PREFIX}_#{original_key.upcase}"

      result[original_key] =
        if ENV[env_key]
          convert_env_value(ENV[env_key], original_value)
        else
          original_value
        end
    end
  end

  private

  def convert_env_value(env_value, original_value)
    case original_value
    when Integer then env_value.to_i
    when TrueClass, FalseClass then env_value.downcase == 'true'
    else env_value
    end
  end
end

class VariableInterpolator
  def interpolate(config)
    interpolated_config = config.dup

    interpolated_config.each do |key, value|
      next unless interpolatable?(value)

      resolved = value.gsub(/\${([^}]+)}/) do
        var_name = Regexp.last_match(1)
        if interpolated_config[var_name]
          interpolated_config[var_name].to_s
        else
          return {
            success: false,
            info: "Undefined variable: ${#{var_name}}"
          }
        end
      end

      interpolated_config[key] = resolved
    end

    {
      success: true,
      config: interpolated_config
    }
  end

  private

  def interpolatable?(value)
    value.is_a?(String) && value.include?('${')
  end
end

class ConfigAccessor
  def initialize(config:, default_values_manager:)
    @config = config
    @default_values_manager = default_values_manager
  end

  def get(key)
    if nested?(key)
      get_nested(key)
    else
      @config[key]
    end
  end

  def set(key, value)
    if nested?(key)
      set_nested(key, value)
    else
      @config[key] = value
    end
  end

  private

  def nested?(key)
    key.include?('.')
  end

  def get_nested(key)
    @config.dig(*key.split('.'))
  rescue StandardError
    @default_values_manager.find_by(key)
  end

  def set_nested(key, value)
    *prefix, last = key.split('.')
    current = prefix.reduce(@config) { |hash, part| hash[part] ||= {} }
    current[last] = value
  end
end

class ConfigLoader
  def initialize
    @env_config_loader = EnvConfigLoader.new
    @env_var_overrider = EnvVariableOverrider.new
    @variable_interpolator = VariableInterpolator.new
  end

  def load(data:, environment:)
    env_config = @env_config_loader.load(data:, environment:)

    config_validator = ConfigLoadValidator.new(env_config)
    validation_result = config_validator.validate

    return validation_result unless validation_result[:success]

    env_config = @env_var_overrider.override(env_config)
    @variable_interpolator.interpolate(env_config)
  end
end

class ConfigRegistry
  def initialize
    @configs = {}
  end

  def store(environment:, config:)
    @configs[environment] = config
  end

  def find(environment)
    config = @configs[environment]
    raise "No config for environment: #{environment}" unless config

    config
  end

  def all
    @configs
  end

  def environment_exist?(environment)
    @configs.key?(environment)
  end
end

class DefaultValuesManager
  def initialize
    @default_values = {}
  end

  def find_by(key)
    @default_values[key]
  end

  def store_defaults(data)
    return unless data.is_a?(Hash)

    return unless data['default']

    data['default'].each do |key, value|
      @default_values[key] = value
    end
  end
end

class FileReader
  class << self
    def read(file_path)
      File.read(File.expand_path(file_path, __dir__))
    end
  end
end

class YamlParser
  class << self
    def parse(content)
      data = YAML.load(content)

      { success: true, data: }
    rescue StandardError => e
      {
        success: false,
        info: "Failed to parse YAML: #{e.message}"
      }
    end
  end
end

class ConfigManager
  DEFAULT_ENVIRONMENT = 'development'
  DEFAULT_EXPORT_FORMAT = 'yaml'

  def initialize
    @config_loader = ConfigLoader.new
    @config_registry = ConfigRegistry.new
    @default_value_manager = DefaultValuesManager.new
    @environments = %w[development staging production].freeze
  end

  def load_config(file_path, environment = DEFAULT_ENVIRONMENT)
    validator = LoadValidator.new
    validation_result = validator.validate(file_path)

    unless validation_result[:success]
      puts validation_result[:info]
      return false
    end

    content = FileReader.read(file_path)
    parse_result = YamlParser.parse(content)

    unless parse_result[:success]
      puts parse_result[:info]
      return false
    end

    data = parse_result[:data]
    @default_value_manager.store_defaults(data)
    load_result = @config_loader.load(data:, environment:)

    unless load_result[:success]
      puts load_result[:info]
      return false
    end

    config = load_result[:config]
    @config_registry.store(environment:, config:)
    true
  end

  def get(key, environment = DEFAULT_ENVIRONMENT)
    return @default_value_manager.find_by(key) unless @config_registry.environment_exist?(environment)

    config = @config_registry.find(environment)
    config_accessor = ConfigAccessor.new(config:, default_values_manager: @default_value_manager)
    config_accessor.get(key)
  end

  def set(key, value, environment = DEFAULT_ENVIRONMENT)
    @config_registry.store(environment:, config: {}) unless @config_registry.environment_exist?(environment)

    config = @config_registry.find(environment)
    config_accessor = ConfigAccessor.new(config:, default_values_manager: @default_value_manager)

    config_accessor.set(key, value)
  end

  def reload
    @environments.each do |environment|
      puts "Cannot reload #{environment} config" if @config_registry.environment_exist?(environment)
    end
  end

  def export(environment = DEFAULT_ENVIRONMENT, format = DEFAULT_EXPORT_FORMAT)
    validator = ExportValidator.new
    validation_result = validator.validate(config_registry: @config_registry, environment:, format:)

    unless validation_result[:success]
      puts validation_result[:info]
      return nil
    end

    config = @config_registry.find(environment)
    formatter_class = ConfigFormatterDispatcher.dispatch(format)

    formatter_class.format(config)
  end

  def validate_all
    validator = AllConfigValidator.new
    validation_result = validator.validate(@config_registry)

    unless validation_result[:success]
      puts validation_result[:info]
      return false
    end

    true
  end
end
