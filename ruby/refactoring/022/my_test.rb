require 'minitest/autorun'
require 'time'
require 'stringio'
require_relative 'my_answer'

class TestCacheRetentionManager < Minitest::Test
  def setup
    @retention_manager = CacheRetentionManager.new(ttl: 60)
  end

  def test_key_expired
    @retention_manager.record_creation('key1')

    refute @retention_manager.key_expired?('key1')

    @retention_manager.instance_variable_set(:@creation_times, { 'key1' => Time.now - 120 })

    assert @retention_manager.key_expired?('key1')
  end

  def test_delete
    @retention_manager.record_creation('key1')
    @retention_manager.delete('key1')

    refute @retention_manager.instance_variable_get(:@access_times).key?('key1')
    refute @retention_manager.instance_variable_get(:@creation_times).key?('key1')
  end

  def test_clear
    @retention_manager.record_creation('key1')
    @retention_manager.record_creation('key2')

    @retention_manager.clear

    assert_equal 0, @retention_manager.instance_variable_get(:@access_times).size
    assert_equal 0, @retention_manager.instance_variable_get(:@creation_times).size
  end

  def test_record_access
    @retention_manager.record_access('key1')

    assert @retention_manager.instance_variable_get(:@access_times).key?('key1')
  end

  def test_record_creation
    @retention_manager.record_creation('key1')

    assert @retention_manager.instance_variable_get(:@access_times).key?('key1')
    assert @retention_manager.instance_variable_get(:@creation_times).key?('key1')
  end

  def test_eviction_victim_key_with_default_lru_eviction_strategy
    @retention_manager.record_creation('key1')
    @retention_manager.record_creation('key2')

    @retention_manager.instance_variable_get(:@access_times)['key1'] = Time.now - 10

    assert_equal 'key1', @retention_manager.eviction_victim_key
  end

  def test_equal_current_ttl
    assert @retention_manager.equal_current_ttl?(60)
    refute @retention_manager.equal_current_ttl?(30)
  end
end

class TestCacheStorage < Minitest::Test
  def setup
    @storage = CacheStorage.new(max_size: 3)
  end

  def test_find_by
    @storage.set('key1', 'value1')

    assert_equal 'value1', @storage.find_by('key1')
    assert_nil @storage.find_by('nonexistent')
  end

  def test_key_exists
    @storage.set('key1', 'value1')

    assert @storage.key_exists?('key1')
    refute @storage.key_exists?('nonexistent')
  end

  def test_set_and_delete
    @storage.set('key1', 'value1')
    assert_equal 1, @storage.size

    @storage.delete('key1')
    assert_equal 0, @storage.size
  end

  def test_clear
    @storage.set('key1', 'value1')
    @storage.set('key2', 'value2')

    @storage.clear

    assert_equal 0, @storage.size
  end

  def test_capacity_reached
    refute @storage.capacity_reached?

    @storage.set('key1', 'value1')
    @storage.set('key2', 'value2')
    @storage.set('key3', 'value3')

    assert @storage.capacity_reached?
  end

  def test_memory_usage
    @storage.set('key1', 'value1')
    @storage.set('key2', 'value2')

    expected_memory = 'key1'.length + 'value1'.length + 'key2'.length + 'value2'.length
    assert_equal expected_memory, @storage.memory_usage
  end
end

class TestCacheHitMissCounter < Minitest::Test
  def setup
    @counter = CacheHitMissCounter.new
  end

  def test_record_hit
    @counter.record_hit
    assert_equal 1, @counter.hit_count
  end

  def test_record_miss
    @counter.record_miss
    assert_equal 1, @counter.miss_count
  end

  def test_clear
    @counter.record_hit
    @counter.record_miss

    @counter.clear

    assert_equal 0, @counter.hit_count
    assert_equal 0, @counter.miss_count
  end

  def test_hit_rate
    assert_equal 0, @counter.hit_rate

    @counter.record_hit
    @counter.record_hit
    @counter.record_miss

    assert_equal 66.67, @counter.hit_rate.round(2)
  end
end

class TestLogger < Minitest::Test
  def setup
    @logger = CacheSystemLogger.new
  end

  def test_log_cache_hit
    output = capture_io { @logger.log_cache_hit('test_key') }
    assert_equal "[CACHE HIT] Key: test_key\n", output.join
  end

  def test_log_cache_miss
    output = capture_io { @logger.log_cache_miss('test_key') }
    assert_equal "[CACHE MISS] Key: test_key\n", output.join
  end

  def test_log_eviction
    output = capture_io { @logger.log_eviction('test_key') }
    assert_equal "[CACHE EVICT] Key: test_key\n", output.join
  end
end

class TestCacheSystem < Minitest::Test
  def setup
    @cache = CacheSystem.new
  end

  def test_set_and_get
    @cache.set('key1', 'value1')
    assert_equal 'value1', @cache.get('key1')
  end

  def test_get_returns_nil_when_missing
    assert_nil @cache.get('missing_key')
  end

  def test_get_with_block_sets_value_on_miss
    value = @cache.get('new_key') { 'computed_value' }
    assert_equal 'computed_value', value
    assert_equal 'computed_value', @cache.get('new_key')
  end

  def test_delete_existing_key
    @cache.set('key1', 'value1')
    assert @cache.delete('key1')
    refute @cache.delete('key1')
  end

  def test_clear
    @cache.set('key1', 'value1')
    @cache.set('key2', 'value2')
    @cache.clear
    assert_equal 0, @cache.size
  end

  def test_size
    @cache.set('key1', 'value1')
    @cache.set('key2', 'value2')
    assert_equal 2, @cache.size
  end

  def test_ttl_expiration
    cache = CacheSystem.new
    cache.set('temp_key', 'temp_value')

    retention = cache.instance_variable_get(:@cache_retention_manager)
    retention.instance_variable_get(:@creation_times)['temp_key'] = Time.now.utc - 4000

    assert_nil cache.get('temp_key')
  end

  def test_eviction_lru
    cache = CacheSystem.new
    storage = cache.instance_variable_get(:@cache_storage)

    (1..CacheStorage::DEFAULT_MAX_SIZE).each do |i|
      cache.set("key#{i}", "value#{i}")
    end

    cache.get('key1')
    cache.set('new_key', 'new_value')
    assert_nil storage.find_by('key2')
    assert_equal 'new_value', cache.get('new_key')
  end

  def test_get_multiple
    @cache.set('k1', 'v1')
    @cache.set('k2', 'v2')
    result = @cache.get_multiple(%w[k1 k2 k3])
    assert_equal({ 'k1' => 'v1', 'k2' => 'v2', 'k3' => nil }, result)
  end

  def test_set_multiple
    entries = { 'a' => '1', 'b' => '2' }
    @cache.set_multiple(entries)
    assert_equal '1', @cache.get('a')
    assert_equal '2', @cache.get('b')
  end

  def test_logging_on_hit_and_miss
    @cache_with_logger = CacheSystem.new(logger: CacheSystemLogger.new)

    output = capture_io do
      @cache_with_logger.get('missing')
      @cache_with_logger.set('hit_key', 'hit_val')
      @cache_with_logger.get('hit_key')
    end
    assert_includes output.join, '[CACHE MISS] Key: missing'
    assert_includes output.join, '[CACHE HIT] Key: hit_key'
  end
end
