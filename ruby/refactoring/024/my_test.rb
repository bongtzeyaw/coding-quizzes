require 'minitest/autorun'
require 'json'
require 'tempfile'
require_relative 'my_answer'

class ConfigManagerTest < Minitest::Test
  def setup
    @config_manager = ConfigManager.new

    @test_config = create_tempfile('test_config.yml', {
      'default' => {
        'host' => 'localhost',
        'port' => 8080,
        'debug' => false,
        'timeout' => 30
      },
      'development' => {
        'host' => 'dev.example.com',
        'debug' => true,
        'api_key' => 'dev_key'
      },
      'production' => {
        'host' => 'prod.example.com',
        'port' => 443,
        'debug' => false,
        'api_key' => 'prod_key'
      },
      'staging' => {
        'host' => 'stage.example.com',
        'port' => 8443
      }
    }.to_yaml)

    @invalid_yaml = create_tempfile('invalid_yaml.yml', "host: 'dev.example.com\nport: 8080")
    @nested_config = create_tempfile('nested_config.yml', {
      'default' => {
        'database' => {
          'host' => 'db.example.com',
          'port' => 5432
        }
      },
      'development' => {
        'database' => {
          'user' => 'dev_user'
        }
      }
    }.to_yaml)
    @variable_config = create_tempfile('variable_config.yml', {
      'default' => {
        'host' => 'api.example.com',
        'base_url' => 'https://${host}/v1'
      },
      'development' => {
        'host' => 'dev-api.example.com',
        'api_url' => '${base_url}/api'
      }
    }.to_yaml)
    @circular_config = create_tempfile('circular_config.yml', {
      'development' => {
        'a' => '${b}',
        'b' => '${a}'
      }
    }.to_yaml)
    @undefined_var_config = create_tempfile('undefined_var_config.yml', {
      'development' => {
        'url' => 'https://${host}/api'
      }
    }.to_yaml)
    @required_config = create_tempfile('required_config.yml', {
      'development' => {
        'api_key_required' => nil
      }
    }.to_yaml)
    @invalid_values_config = create_tempfile('invalid_values_config.yml', {
      'development' => {
        'port' => -1,
        'timeout' => 'invalid',
        'url' => '',
        'debug' => 'not_boolean'
      }
    }.to_yaml)
  end

  def create_tempfile(name, content)
    tempfile = Tempfile.new([File.basename(name, '.*'), File.extname(name)])
    tempfile.write(content)
    tempfile.flush
    tempfile
  end

  def teardown
    [@test_config, @invalid_yaml, @nested_config,
     @variable_config, @circular_config, @undefined_var_config,
     @required_config, @invalid_values_config].each do |tempfile|
      tempfile.close
      tempfile.unlink
    end
  end

  def test_initialize
    assert_equal({}, @config_manager.instance_variable_get(:@config_registry).instance_variable_get(:@configs))
    assert_equal(%w[development staging production], @config_manager.instance_variable_get(:@environments))
    default_manager = @config_manager.instance_variable_get(:@default_value_manager)
    assert_equal({}, default_manager.instance_variable_get(:@default_values))
  end

  def test_load_config_file_not_found
    result = @config_manager.load_config('non_existent_file.yml')
    assert_equal(false, result)
  end

  def test_load_config_invalid_yaml
    result = @config_manager.load_config(@invalid_yaml.path)
    assert_equal(false, result)
  end

  def test_load_config_success
    result = @config_manager.load_config(@test_config.path)
    assert_equal(true, result)

    registry = @config_manager.instance_variable_get(:@config_registry)
    dev_config = registry.find('development')

    assert_equal('dev.example.com', dev_config['host'])
    assert_equal(8080, dev_config['port'])
    assert_equal(true, dev_config['debug'])
    assert_equal(30, dev_config['timeout'])
    assert_equal('dev_key', dev_config['api_key'])

    default_manager = @config_manager.instance_variable_get(:@default_value_manager)
    default_values = default_manager.instance_variable_get(:@default_values)
    assert_equal('localhost', default_values['host'])
    assert_equal(8080, default_values['port'])
    assert_equal(false, default_values['debug'])
    assert_equal(30, default_values['timeout'])
  end

  def test_load_config_with_environment
    @config_manager.load_config(@test_config.path, 'production')

    registry = @config_manager.instance_variable_get(:@config_registry)
    prod_config = registry.find('production')

    assert_equal('prod.example.com', prod_config['host'])
    assert_equal(443, prod_config['port'])
    assert_equal(false, prod_config['debug'])
    assert_equal('prod_key', prod_config['api_key'])
    assert_equal(30, prod_config['timeout'])
  end

  def test_load_config_with_required_nil_value
    result = @config_manager.load_config(@required_config.path)
    assert_equal(false, result)
  end

  def test_load_config_with_invalid_values
    result = @config_manager.load_config(@invalid_values_config.path)
    assert_equal(false, result)
  end

  def test_load_config_with_environment_variables
    ENV['APP_HOST'] = 'env.example.com'
    ENV['APP_PORT'] = '9000'
    ENV['APP_DEBUG'] = 'true'

    @config_manager.load_config(@test_config.path)

    registry = @config_manager.instance_variable_get(:@config_registry)
    dev_config = registry.find('development')

    assert_equal('env.example.com', dev_config['host'])
    assert_equal(9000, dev_config['port'])
    assert_equal(true, dev_config['debug'])

    ENV.delete('APP_HOST')
    ENV.delete('APP_PORT')
    ENV.delete('APP_DEBUG')
  end

  def test_load_config_with_variables
    @config_manager.load_config(@variable_config.path)

    registry = @config_manager.instance_variable_get(:@config_registry)
    dev_config = registry.find('development')

    assert_equal('dev-api.example.com', dev_config['host'])
    assert_equal('https://dev-api.example.com/v1', dev_config['base_url'])
    assert_equal('https://dev-api.example.com/v1/api', dev_config['api_url'])
  end

  def test_load_config_with_undefined_variable
    result = @config_manager.load_config(@undefined_var_config.path)
    assert_equal(false, result)
  end

  def test_get_default_value
    @config_manager.load_config(@test_config.path)
    assert_equal(30, @config_manager.get('timeout'))
  end

  def test_get_environment_value
    @config_manager.load_config(@test_config.path)
    assert_equal('dev.example.com', @config_manager.get('host'))
    assert_equal('dev_key', @config_manager.get('api_key'))
  end

  def test_get_nested_value
    @config_manager.load_config(@nested_config.path)
    @config_manager.set('database.host', 'dev-db.example.com')

    assert_equal('dev-db.example.com', @config_manager.get('database.host'))
    assert_equal('dev_user', @config_manager.get('database.user'))
  end

  def test_get_from_specific_environment
    @config_manager.load_config(@test_config.path)
    @config_manager.load_config(@test_config.path, 'production')

    assert_equal('dev.example.com', @config_manager.get('host', 'development'))
    assert_equal('prod.example.com', @config_manager.get('host', 'production'))
  end

  def test_get_non_existent_key
    @config_manager.load_config(@test_config.path)
    assert_nil(@config_manager.get('non_existent_key'))
  end

  def test_get_non_existent_nested_key
    @config_manager.load_config(@nested_config.path)
    assert_nil(@config_manager.get('database.non_existent_key'))
    assert_nil(@config_manager.get('non_existent.key'))
  end

  def test_set_simple_value
    @config_manager.set('new_key', 'new_value')
    assert_equal('new_value', @config_manager.get('new_key'))
  end

  def test_set_override_value
    @config_manager.load_config(@test_config.path)
    @config_manager.set('host', 'new.example.com')
    assert_equal('new.example.com', @config_manager.get('host'))
  end

  def test_set_nested_value
    @config_manager.set('database.host', 'db.example.com')
    @config_manager.set('database.port', 5432)

    assert_equal('db.example.com', @config_manager.get('database.host'))
    assert_equal(5432, @config_manager.get('database.port'))
  end

  def test_set_for_specific_environment
    @config_manager.set('key', 'dev_value')
    @config_manager.set('key', 'prod_value', 'production')

    assert_equal('dev_value', @config_manager.get('key'))
    assert_equal('prod_value', @config_manager.get('key', 'production'))
  end

  def test_reload
    @config_manager.load_config(@test_config.path)
    @config_manager.load_config(@test_config.path, 'production')

    output = capture_io { @config_manager.reload }.first
    assert_match(/Cannot reload development config/, output)
    assert_match(/Cannot reload production config/, output)
  end

  def test_export_yaml
    @config_manager.load_config(@test_config.path)
    yaml_output = @config_manager.export

    exported_config = YAML.load(yaml_output)
    assert_equal('dev.example.com', exported_config['host'])
    assert_equal(true, exported_config['debug'])
  end

  def test_export_json
    @config_manager.load_config(@test_config.path)
    json_output = @config_manager.export('development', 'json')

    exported_config = JSON.parse(json_output)
    assert_equal('dev.example.com', exported_config['host'])
    assert_equal(true, exported_config['debug'])
  end

  def test_export_env
    @config_manager.load_config(@test_config.path)
    env_output = @config_manager.export('development', 'env')

    assert_match(/APP_HOST=dev\.example\.com/, env_output)
    assert_match(/APP_DEBUG=true/, env_output)
  end

  def test_export_unknown_format
    @config_manager.load_config(@test_config.path)
    output = capture_io { @config_manager.export('development', 'unknown') }.first

    assert_match(/Unknown format: unknown/, output)
  end

  def test_export_non_existent_environment
    output = capture_io { @config_manager.export('non_existent') }.first
    assert_match(/No config for environment: non_existent/, output)
  end

  def test_validate_all_valid
    @config_manager.load_config(@test_config.path)
    @config_manager.load_config(@variable_config.path, 'production')

    assert_equal(true, @config_manager.validate_all)
  end

  def test_validate_all_circular_reference
    @config_manager.load_config(@circular_config.path)

    output = capture_io { @config_manager.validate_all }.first
    assert_match(/Circular reference detected/, output)
  end

  def test_validate_all_undefined_reference
    @config_manager.load_config(@test_config.path)
    @config_manager.set('api_url', '${api_host}/endpoint', 'development')

    output = capture_io { @config_manager.validate_all }.first
    assert_match(/Undefined reference: \$\{api_host\} in api_url/, output)
  end
end
