# frozen_string_literal: true

class EvictionStrategy
  def select_victim_key
    raise NotImplementedError, "#{self.class} must implement #select_victim_key"
  end
end

class LRUEvictionStrategy < EvictionStrategy
  def select_victim_key(access_times)
    access_times.key(access_times.values.min)
  end
end

class CacheRetentionManager
  DEFAULT_TTL = 60 * 60

  def initialize(ttl: DEFAULT_TTL, eviction_strategy: LRUEvictionStrategy.new)
    @ttl = ttl
    @eviction_strategy = eviction_strategy
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

  def delete_multiple(keys)
    @mutex.synchronize do
      keys.each do |key|
        @access_times.delete(key)
        @creation_times.delete(key)
      end
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

  def record_accesses(keys)
    @mutex.synchronize do
      keys.each do |key|
        @access_times[key] = Time.now.utc
      end
    end
  end

  def record_creation(key)
    @mutex.synchronize do
      @creation_times[key] = Time.now.utc
      @access_times[key] = Time.now.utc
    end
  end

  def record_creations(keys)
    @mutex.synchronize do
      keys.each do |key|
        @creation_times[key] = Time.now.utc
        @access_times[key] = Time.now.utc
      end
    end
  end

  def eviction_victim_key
    @mutex.synchronize do
      @eviction_strategy.select_victim_key(@access_times)
    end
  end

  def equal_current_ttl?(ttl)
    @ttl == ttl
  end
end

class CacheValue
  attr_reader :value

  def initialize(value)
    @value = value
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
      @cache[key]&.value
    end
  end

  def find_multiple_by(keys)
    @mutex.synchronize do
      keys.map { |key| [key, @cache[key]&.value] }.to_h
    end
  end

  def key_exists?(key)
    @mutex.synchronize do
      @cache.key?(key)
    end
  end

  def set(key, value)
    @mutex.synchronize do
      @cache[key] = CacheValue.new(value)
    end
  end

  def set_multiple(entries)
    @mutex.synchronize do
      entries.each do |key, value|
        @cache[key] = CacheValue.new(value)
      end
    end
  end

  def delete(key)
    @mutex.synchronize do
      @cache.delete(key)
    end
  end

  def delete_multiple(keys)
    @mutex.synchronize do
      keys.each { |key| @cache.delete(key) }
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
    @cache.sum { |key, cache_value| key.to_s.size + cache_value.value.to_s.size }
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

  def record_hits(count)
    @mutex.synchronize do
      @hit_count += count
    end
  end

  def record_miss
    @mutex.synchronize do
      @miss_count += 1
    end
  end

  def record_misses(count)
    @mutex.synchronize do
      @miss_count += count
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

class CacheStatisticsSummary
  attr_reader :storage_size, :storage_max_size, :hits, :misses, :hit_rate, :estimated_memory

  def initialize(storage_size:, storage_max_size:, hits:, misses:, hit_rate:, estimated_memory:)
    @storage_size = storage_size
    @storage_max_size = storage_max_size
    @hits = hits
    @misses = misses
    @hit_rate = hit_rate
    @estimated_memory = estimated_memory
  end
end

class CacheStatistics
  def display_summary(cache_storage:, cache_hit_miss_counter:)
    summary = build_summary(cache_storage, cache_hit_miss_counter)

    puts 'Cache Statistics:'
    puts "  Size: #{summary.storage_size}/#{summary.storage_max_size}"
    puts "  Hits: #{summary.hits}"
    puts "  Misses: #{summary.misses}"
    puts "  Hit Rate: #{summary.hit_rate}%"
    puts "  Estimated Memory: #{summary.estimated_memory} bytes"
  end

  private

  def build_summary(cache_storage, cache_hit_miss_counter)
    CacheStatisticsSummary.new(
      storage_size: cache_storage.size,
      storage_max_size: cache_storage.max_size,
      hits: cache_hit_miss_counter.hit_count,
      misses: cache_hit_miss_counter.miss_count,
      hit_rate: cache_hit_miss_counter.hit_rate,
      estimated_memory: cache_storage.memory_usage
    )
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

    evict_key if @cache_storage.capacity_reached?

    @cache_storage.set(key, value)
    @cache_retention_manager.record_creation(key)

    value
  end

  def set(key, value, options = {})
    evict_key if !@cache_storage.key_exists?(key) && @cache_storage.capacity_reached?

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
    expired_existing_keys = keys.select do |key|
      @cache_retention_manager.key_expired?(key) && @cache_storage.key_exists?(key)
    end

    @cache_storage.delete_multiple(expired_existing_keys)
    @cache_retention_manager.delete_multiple(expired_existing_keys)

    existing_keys = keys.select { |key| @cache_storage.key_exists?(key) }
    handle_cache_hits(existing_keys)
    cache_hits_result = @cache_storage.find_multiple_by(existing_keys)

    non_existing_keys = keys - existing_keys
    handle_cache_misses(non_existing_keys)

    if block_given?
      new_entries = yield
      cache_misses_result = non_existing_keys.map { |key| [key, new_entries[key]] }.to_h

      set_multiple(cache_misses_result)
    else
      value = nil
      cache_misses_result = non_existing_keys.map { |key| [key, value] }.to_h
    end

    cache_hits_result.merge(cache_misses_result)
  end

  def set_multiple(entries)
    non_existing_keys = entries.keys.reject { |key| @cache_storage.key_exists?(key) }

    remaining_capacity = @cache_storage.max_size - @cache_storage.size
    delta_cache_storage_size = non_existing_keys.size - remaining_capacity
    evict_keys(delta_cache_storage_size) if delta_cache_storage_size.positive?

    @cache_storage.set_multiple(entries.slice(*non_existing_keys))
    @cache_retention_manager.record_creations(non_existing_keys)
  end

  private

  def evict_key
    victim_key = @cache_retention_manager.eviction_victim_key
    return unless victim_key

    delete(victim_key)
    @logger.log_eviction(victim_key)
  end

  def evict_keys(count)
    count.times do
      evict_key
    end
  end

  def handle_cache_hit(key)
    @cache_hit_miss_counter.record_hit
    @cache_retention_manager.record_access(key)
    @logger.log_cache_hit(key)
  end

  def handle_cache_hits(keys)
    @cache_hit_miss_counter.record_hits(keys.size)
    @cache_retention_manager.record_accesses(keys)

    keys.each do |key|
      @logger.log_cache_hit(key)
    end
  end

  def handle_cache_miss(key)
    @cache_hit_miss_counter.record_miss
    @logger.log_cache_miss(key)
  end

  def handle_cache_misses(keys)
    @cache_hit_miss_counter.record_misses(keys.size)

    keys.each do |key|
      @logger.log_cache_miss(key)
    end
  end
end
