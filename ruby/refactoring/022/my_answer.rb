# frozen_string_literal: true

class CacheRetentionManager
  DEFAULT_TTL = 60 * 60

  def initialize(ttl: DEFAULT_TTL)
    @ttl = ttl
    @access_times = {}
    @creation_times = {}
  end

  def key_expired?(key)
    @creation_times[key] && (Time.now.utc - @creation_times[key]) > @ttl
  end

  def delete(key)
    @access_times.delete(key)
    @creation_times.delete(key)
  end

  def clear
    @access_times.clear
    @creation_times.clear
  end

  def record_access(key)
    @access_times[key] = Time.now.utc
  end

  def record_creation(key)
    @creation_times[key] = Time.now.utc
    record_access(key)
  end

  def least_recently_used_key
    @access_times.key(@access_times.values.min)
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
  end

  def find_by(key)
    @cache[key]
  end

  def key_exists?(key)
    @cache.key?(key)
  end

  def set(key, value)
    @cache[key] = value
  end

  def delete(key)
    @cache.delete(key)
  end

  def clear
    @cache.clear
  end

  def capacity_reached?
    @cache.size >= @max_size
  end

  def size
    @cache.size
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
  end

  def record_hit
    @hit_count += 1
  end

  def record_miss
    @miss_count += 1
  end

  def clear
    @hit_count = 0
    @miss_count = 0
  end

  def hit_rate
    total_requests = @hit_count + @miss_count
    return 0 unless total_requests.positive?

    (@hit_count.to_f / total_requests * 100)
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

class CacheSystem
  def initialize(max_size = 100, ttl = 3600)
    @cache_storage = CacheStorage.new
    @cache_retention_manager = CacheRetentionManager.new
    @cache_hit_miss_counter = CacheHitMissCounter.new
  end

  def get(key, options = {})
    delete(key) if @cache_retention_manager.key_expired?(key)

    cache_value = @cache_storage.find_by(key)

    if cache_value
      handle_cache_hit(key:, logging: options[:debug])
      return cache_value
    end

    handle_cache_miss(key:, logging: options[:debug])

    return nil unless block_given?

    value = yield

    evict_lru_key(logging: options[:debug]) if @cache_storage.capacity_reached?

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
    @miss_count = 0
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

  def evict_lru_key(logging: false)
    lru_key = @cache_retention_manager.least_recently_used_key
    return unless lru_key

    delete(lru_key)
    @logger.log_eviction(lru_key) if logging
  end

  def handle_cache_hit(key:, logging: false)
    @cache_retention_manager.record_access(key)
    @cache_hit_miss_counter.record_hit
    puts "[CACHE HIT] Key: #{key}" if logging
  end

  def handle_cache_miss(key:, logging: false)
    @cache_hit_miss_counter.record_miss
    puts "[CACHE MISS] Key: #{key}" if logging
  end
end
