# frozen_string_literal: true

class CacheRetentionManager
  DEFAULT_TTL = 60 * 60

  def initialize(ttl: DEFAULT_TTL)
    @ttl = ttl
    @access_times = {}
    @creation_times = {}
    @mutex = Mutex.new
  end

  def key_expired?(key)
    @mutex.synchronize do
      @creation_times[key] && (Time.now.utc - @creation_times[key]) > @ttl
    end
  end

  def delete(key)
    @mutex.synchronize do
      @access_times.delete(key)
      @creation_times.delete(key)
    end
  end

  def clear
    @mutex.synchronize do
      @access_times.clear
      @creation_times.clear
    end
  end

  def record_access(key)
    @mutex.synchronize do
      @access_times[key] = Time.now.utc
    end
  end

  def record_creation(key)
    @mutex.synchronize do
      @creation_times[key] = Time.now.utc
      @access_times[key] = Time.now.utc
    end
  end

  def least_recently_used_key
    @mutex.synchronize do
      @access_times.key(@access_times.values.min)
    end
  end

  def equal_current_ttl?(ttl)
    @ttl == ttl
  end
end

class CacheStorage
  DEFAULT_MAX_SIZE = 100

  attr_reader :max_size

  def initialize(max_size: DEFAULT_MAX_SIZE)
    @cache = {}
    @max_size = max_size
    @mutex = Mutex.new
  end

  def find_by(key)
    @mutex.synchronize do
      @cache[key]
    end
  end

  def key_exists?(key)
    @mutex.synchronize do
      @cache.key?(key)
    end
  end

  def set(key, value)
    @mutex.synchronize do
      @cache[key] = value
    end
  end

  def delete(key)
    @mutex.synchronize do
      @cache.delete(key)
    end
  end

  def clear
    @mutex.synchronize do
      @cache.clear
    end
  end

  def size
    @cache.size
  end

  def capacity_reached?
    size >= @max_size
  end

  def memory_usage
    @cache.sum { |key, value| key.to_s.length + value.to_s.length }
  end
end

class CacheHitMissCounter
  attr_reader :hit_count, :miss_count

  def initialize
    @hit_count = 0
    @miss_count = 0
    @mutex = Mutex.new
  end

  def record_hit
    @mutex.synchronize do
      @hit_count += 1
    end
  end

  def record_miss
    @mutex.synchronize do
      @miss_count += 1
    end
  end

  def clear
    @mutex.synchronize do
      @hit_count = 0
      @miss_count = 0
    end
  end

  def hit_rate
    @mutex.synchronize do
      total_requests = @hit_count + @miss_count
      return 0 unless total_requests.positive?

      (@hit_count.to_f / total_requests * 100)
    end
  end
end

class CacheStatistics
  def display_summary(cache_storage:, cache_hit_miss_counter:)
    puts 'Cache Statistics:'
    puts "  Size: #{cache_storage.size}/#{cache_storage.max_size}"
    puts "  Hits: #{cache_hit_miss_counter.hit_count}"
    puts "  Misses: #{cache_hit_miss_counter.miss_count}"
    puts "  Hit Rate: #{cache_hit_miss_counter.hit_rate}%"
    puts "  Estimated Memory: #{cache_storage.memory_usage} bytes"
  end
end

class CacheSystemLogger
  def log_cache_hit(key)
    puts "[CACHE HIT] Key: #{key}"
  end

  def log_cache_miss(key)
    puts "[CACHE MISS] Key: #{key}"
  end

  def log_eviction(key)
    puts "[CACHE EVICT] Key: #{key}"
  end
end

class NullCacheSystemLogger
  def log_cache_hit(key); end

  def log_cache_miss(key); end

  def log_eviction(key); end
end

class CacheSystem
  def initialize(
    cache_storage: CacheStorage.new,
    cache_retention_manager: CacheRetentionManager.new,
    cache_hit_miss_counter: CacheHitMissCounter.new,
    logger: NullCacheSystemLogger.new,
    cache_statistics: CacheStatistics.new
  )
    @cache_storage = cache_storage
    @cache_retention_manager = cache_retention_manager
    @cache_hit_miss_counter = cache_hit_miss_counter
    @logger = logger
    @cache_statistics = cache_statistics
  end

  def get(key)
    delete(key) if @cache_retention_manager.key_expired?(key)

    cache_value = @cache_storage.find_by(key)

    if cache_value
      handle_cache_hit(key)
      return cache_value
    end

    handle_cache_miss(key)

    return nil unless block_given?

    value = yield

    evict_lru_key if @cache_storage.capacity_reached?

    @cache_storage.set(key, value)
    @cache_retention_manager.record_creation(key)

    value
  end

  def set(key, value, options = {})
    evict_lru_key if !@cache_storage.key_exists?(key) && @cache_storage.capacity_reached?

    @cache_storage.set(key, value)
    @cache_retention_manager.record_creation(key)

    nil unless @cache_retention_manager.equal_current_ttl?(options[:ttl])
  end

  def delete(key)
    return false unless @cache_storage.key_exists?(key)

    @cache_storage.delete(key)
    @cache_retention_manager.delete(key)
    true
  end

  def clear
    @cache_storage.clear
    @cache_retention_manager.clear
    @cache_hit_miss_counter.clear
  end

  def size
    @cache_storage.size
  end

  def stats
    @cache_statistics.display_summary(
      cache_storage: @cache_storage,
      cache_hit_miss_counter: @cache_hit_miss_counter
    )
  end

  def get_multiple(keys)
    keys.each_with_object({}) do |key, results|
      results[key] = get(key)
    end
  end

  def set_multiple(entries)
    entries.each do |key, value|
      set(key, value)
    end
  end

  private

  def evict_lru_key
    lru_key = @cache_retention_manager.least_recently_used_key
    return unless lru_key

    delete(lru_key)
    @logger.log_eviction(lru_key)
  end

  def handle_cache_hit(key)
    @cache_hit_miss_counter.record_hit
    @cache_retention_manager.record_access(key)
    @logger.log_cache_hit(key)
  end

  def handle_cache_miss(key)
    @cache_hit_miss_counter.record_miss
    @logger.log_cache_miss(key)
  end
end
