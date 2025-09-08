class AppConfig
  def self.get_database_config
    if ENV['RAILS_ENV'] == 'production'
      {
        host: ENV['DB_HOST'] || 'prod-db.example.com',
        port: ENV['DB_PORT'] ? ENV['DB_PORT'].to_i : 5432,
        database: ENV['DB_NAME'] || 'myapp_production',
        username: ENV['DB_USER'] || 'app_user',
        password: ENV['DB_PASSWORD'],
        pool: ENV['DB_POOL'] ? ENV['DB_POOL'].to_i : 20,
        timeout: 5000
      }
    elsif ENV['RAILS_ENV'] == 'staging'
      {
        host: ENV['DB_HOST'] || 'staging-db.example.com',
        port: ENV['DB_PORT'] ? ENV['DB_PORT'].to_i : 5432,
        database: ENV['DB_NAME'] || 'myapp_staging',
        username: ENV['DB_USER'] || 'app_user',
        password: ENV['DB_PASSWORD'],
        pool: ENV['DB_POOL'] ? ENV['DB_POOL'].to_i : 10,
        timeout: 5000
      }
    elsif ENV['RAILS_ENV'] == 'test'
      {
        host: 'localhost',
        port: 5432,
        database: 'myapp_test',
        username: 'test_user',
        password: 'test_password',
        pool: 5,
        timeout: 1000
      }
    else # development
      {
        host: ENV['DB_HOST'] || 'localhost',
        port: ENV['DB_PORT'] ? ENV['DB_PORT'].to_i : 5432,
        database: ENV['DB_NAME'] || 'myapp_development',
        username: ENV['DB_USER'] || 'dev_user',
        password: ENV['DB_PASSWORD'] || 'dev_password',
        pool: ENV['DB_POOL'] ? ENV['DB_POOL'].to_i : 5,
        timeout: 5000
      }
    end
  end

  def self.get_redis_config
    if ENV['RAILS_ENV'] == 'production'
      {
        host: ENV['REDIS_HOST'] || 'prod-redis.example.com',
        port: ENV['REDIS_PORT'] ? ENV['REDIS_PORT'].to_i : 6379,
        db: 0,
        password: ENV['REDIS_PASSWORD']
      }
    elsif ENV['RAILS_ENV'] == 'staging'
      {
        host: ENV['REDIS_HOST'] || 'staging-redis.example.com',
        port: ENV['REDIS_PORT'] ? ENV['REDIS_PORT'].to_i : 6379,
        db: 1,
        password: ENV['REDIS_PASSWORD']
      }
    else
      {
        host: ENV['REDIS_HOST'] || 'localhost',
        port: ENV['REDIS_PORT'] ? ENV['REDIS_PORT'].to_i : 6379,
        db: 2,
        password: nil
      }
    end
  end

  def self.get_api_endpoints
    if ENV['RAILS_ENV'] == 'production'
      {
        payment_api: 'https://api.payment.com/v1',
        shipping_api: 'https://api.shipping.com/v2',
        notification_api: 'https://api.notification.com/v1'
      }
    elsif ENV['RAILS_ENV'] == 'staging'
      {
        payment_api: 'https://staging-api.payment.com/v1',
        shipping_api: 'https://staging-api.shipping.com/v2',
        notification_api: 'https://staging-api.notification.com/v1'
      }
    else
      {
        payment_api: ENV['PAYMENT_API_URL'] || 'http://localhost:3001',
        shipping_api: ENV['SHIPPING_API_URL'] || 'http://localhost:3002',
        notification_api: ENV['NOTIFICATION_API_URL'] || 'http://localhost:3003'
      }
    end
  end
end
