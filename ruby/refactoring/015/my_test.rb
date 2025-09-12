require 'minitest/autorun'
require_relative 'my_answer'

class AppConfigTest < Minitest::Test
  def setup
    @original_env = ENV.to_hash
  end

  def teardown
    ENV.replace(@original_env)
  end

  def test_get_database_config_in_production
    ENV['RAILS_ENV'] = 'production'
    ENV['DB_HOST'] = nil
    ENV['DB_PORT'] = nil
    ENV['DB_NAME'] = nil
    ENV['DB_USER'] = nil
    ENV['DB_PASSWORD'] = 'prod_secret'
    ENV['DB_POOL'] = nil
    config = AppConfig.get_database_config
    assert_equal 'prod-db.example.com', config[:host]
    assert_equal 5432, config[:port]
    assert_equal 'myapp_production', config[:database]
    assert_equal 'app_user', config[:username]
    assert_equal 'prod_secret', config[:password]
    assert_equal 20, config[:pool]
    assert_equal 5000, config[:timeout]
  end

  def test_get_database_config_in_production_with_env_vars
    ENV['RAILS_ENV'] = 'production'
    ENV['DB_HOST'] = 'custom-prod-db'
    ENV['DB_PORT'] = '1234'
    ENV['DB_NAME'] = 'custom_prod_db'
    ENV['DB_USER'] = 'custom_user'
    ENV['DB_PASSWORD'] = 'custom_secret'
    ENV['DB_POOL'] = '25'
    config = AppConfig.get_database_config
    assert_equal 'custom-prod-db', config[:host]
    assert_equal 1234, config[:port]
    assert_equal 'custom_prod_db', config[:database]
    assert_equal 'custom_user', config[:username]
    assert_equal 'custom_secret', config[:password]
    assert_equal 25, config[:pool]
  end

  def test_get_database_config_in_staging
    ENV['RAILS_ENV'] = 'staging'
    ENV['DB_HOST'] = nil
    ENV['DB_PORT'] = nil
    ENV['DB_NAME'] = nil
    ENV['DB_USER'] = nil
    ENV['DB_PASSWORD'] = 'staging_secret'
    ENV['DB_POOL'] = nil
    config = AppConfig.get_database_config
    assert_equal 'staging-db.example.com', config[:host]
    assert_equal 5432, config[:port]
    assert_equal 'myapp_staging', config[:database]
    assert_equal 'app_user', config[:username]
    assert_equal 'staging_secret', config[:password]
    assert_equal 10, config[:pool]
    assert_equal 5000, config[:timeout]
  end

  def test_get_database_config_in_staging_with_env_vars
    ENV['RAILS_ENV'] = 'staging'
    ENV['DB_HOST'] = 'custom-staging-db'
    ENV['DB_PORT'] = '4321'
    ENV['DB_NAME'] = 'custom_staging_db'
    ENV['DB_USER'] = 'custom_staging_user'
    ENV['DB_PASSWORD'] = 'custom_staging_secret'
    ENV['DB_POOL'] = '15'
    config = AppConfig.get_database_config
    assert_equal 'custom-staging-db', config[:host]
    assert_equal 4321, config[:port]
    assert_equal 'custom_staging_db', config[:database]
    assert_equal 'custom_staging_user', config[:username]
    assert_equal 'custom_staging_secret', config[:password]
    assert_equal 15, config[:pool]
  end

  def test_get_database_config_in_test
    ENV['RAILS_ENV'] = 'test'
    config = AppConfig.get_database_config
    assert_equal 'localhost', config[:host]
    assert_equal 5432, config[:port]
    assert_equal 'myapp_test', config[:database]
    assert_equal 'test_user', config[:username]
    assert_equal 'test_password', config[:password]
    assert_equal 5, config[:pool]
    assert_equal 1000, config[:timeout]
  end

  def test_get_database_config_in_development
    ENV['RAILS_ENV'] = 'development'
    ENV['DB_HOST'] = nil
    ENV['DB_PORT'] = nil
    ENV['DB_NAME'] = nil
    ENV['DB_USER'] = nil
    ENV['DB_PASSWORD'] = nil
    ENV['DB_POOL'] = nil
    config = AppConfig.get_database_config
    assert_equal 'localhost', config[:host]
    assert_equal 5432, config[:port]
    assert_equal 'myapp_development', config[:database]
    assert_equal 'dev_user', config[:username]
    assert_equal 'dev_password', config[:password]
    assert_equal 5, config[:pool]
    assert_equal 5000, config[:timeout]
  end

  def test_get_database_config_in_development_with_env_vars
    ENV['RAILS_ENV'] = 'development'
    ENV['DB_HOST'] = 'custom-dev-db'
    ENV['DB_PORT'] = '5433'
    ENV['DB_NAME'] = 'custom_dev_db'
    ENV['DB_USER'] = 'custom_dev_user'
    ENV['DB_PASSWORD'] = 'custom_dev_password'
    ENV['DB_POOL'] = '10'
    config = AppConfig.get_database_config
    assert_equal 'custom-dev-db', config[:host]
    assert_equal 5433, config[:port]
    assert_equal 'custom_dev_db', config[:database]
    assert_equal 'custom_dev_user', config[:username]
    assert_equal 'custom_dev_password', config[:password]
    assert_equal 10, config[:pool]
  end

  def test_get_redis_config_in_production
    ENV['RAILS_ENV'] = 'production'
    ENV['REDIS_HOST'] = nil
    ENV['REDIS_PORT'] = nil
    ENV['REDIS_PASSWORD'] = 'redis_prod_secret'
    config = AppConfig.get_redis_config
    assert_equal 'prod-redis.example.com', config[:host]
    assert_equal 6379, config[:port]
    assert_equal 0, config[:db]
    assert_equal 'redis_prod_secret', config[:password]
  end

  def test_get_redis_config_in_staging
    ENV['RAILS_ENV'] = 'staging'
    ENV['REDIS_HOST'] = nil
    ENV['REDIS_PORT'] = nil
    ENV['REDIS_PASSWORD'] = 'redis_staging_secret'
    config = AppConfig.get_redis_config
    assert_equal 'staging-redis.example.com', config[:host]
    assert_equal 6379, config[:port]
    assert_equal 1, config[:db]
    assert_equal 'redis_staging_secret', config[:password]
  end

  def test_get_redis_config_in_development
    ENV['RAILS_ENV'] = 'development'
    ENV['REDIS_HOST'] = nil
    ENV['REDIS_PORT'] = nil
    config = AppConfig.get_redis_config
    assert_equal 'localhost', config[:host]
    assert_equal 6379, config[:port]
    assert_equal 2, config[:db]
    assert_nil config[:password]
  end

  def test_get_api_endpoints_in_production
    ENV['RAILS_ENV'] = 'production'
    config = AppConfig.get_api_endpoints
    assert_equal 'https://api.payment.com/v1', config[:payment_api]
    assert_equal 'https://api.shipping.com/v2', config[:shipping_api]
    assert_equal 'https://api.notification.com/v1', config[:notification_api]
  end

  def test_get_api_endpoints_in_staging
    ENV['RAILS_ENV'] = 'staging'
    config = AppConfig.get_api_endpoints
    assert_equal 'https://staging-api.payment.com/v1', config[:payment_api]
    assert_equal 'https://staging-api.shipping.com/v2', config[:shipping_api]
    assert_equal 'https://staging-api.notification.com/v1', config[:notification_api]
  end

  def test_get_api_endpoints_in_development
    ENV['RAILS_ENV'] = 'development'
    ENV['PAYMENT_API_URL'] = nil
    ENV['SHIPPING_API_URL'] = nil
    ENV['NOTIFICATION_API_URL'] = nil
    config = AppConfig.get_api_endpoints
    assert_equal 'http://localhost:3001', config[:payment_api]
    assert_equal 'http://localhost:3002', config[:shipping_api]
    assert_equal 'http://localhost:3003', config[:notification_api]
  end

  def test_get_api_endpoints_in_development_with_env_vars
    ENV['RAILS_ENV'] = 'development'
    ENV['PAYMENT_API_URL'] = 'http://custom-payment:5000'
    ENV['SHIPPING_API_URL'] = 'http://custom-shipping:5001'
    ENV['NOTIFICATION_API_URL'] = 'http://custom-notification:5002'
    config = AppConfig.get_api_endpoints
    assert_equal 'http://custom-payment:5000', config[:payment_api]
    assert_equal 'http://custom-shipping:5001', config[:shipping_api]
    assert_equal 'http://custom-notification:5002', config[:notification_api]
  end
end
