require 'minitest/autorun'
require 'time'
require_relative 'my_answer'

class TestCacheSystem < Minitest::Test
  def setup
    @cache = CacheSystem.new(3, 1)
  end

  def test_initialization
    assert_equal 0, @cache.size
  end

  def test_set_and_get
    @cache.set('key1', 'value1')
    assert_equal 'value1', @cache.get('key1')
    assert_equal 1, @cache.size
  end

  def test_block_value
    result = @cache.get('key2') { 'value2' }
    assert_equal 'value2', result
    assert_equal 'value2', @cache.get('key2')
  end

  def test_get_nonexistent_key
    assert_nil @cache.get('nonexistent')
  end

  def test_delete
    @cache.set('key1', 'value1')
    assert @cache.delete('key1')
    assert_nil @cache.get('key1')
    assert_equal 0, @cache.size
  end

  def test_delete_nonexistent
    assert_equal false, @cache.delete('nonexistent')
  end

  def test_clear
    @cache.set('key1', 'value1')
    @cache.set('key2', 'value2')
    @cache.clear
    assert_equal 0, @cache.size
    assert_nil @cache.get('key1')
    assert_nil @cache.get('key2')
  end

  def test_hit_miss_count
    @cache.set('key1', 'value1')

    @cache.get('key1')
    @cache.get('nonexistent')

    output = capture_io { @cache.stats }
    assert_match(/Hits: 1/, output.join)
    assert_match(/Misses: 1/, output.join)
  end

  def test_eviction_lru
    @cache.set('key1', 'value1')
    @cache.set('key2', 'value2')
    @cache.set('key3', 'value3')

    @cache.get('key1')
    @cache.set('key4', 'value4')

    assert_nil @cache.get('key2')
    assert_equal 'value1', @cache.get('key1')
    assert_equal 'value3', @cache.get('key3')
    assert_equal 'value4', @cache.get('key4')
  end

  def test_ttl_expiration
    @cache.set('key1', 'value1')
    assert_equal 'value1', @cache.get('key1')

    sleep 1.1

    assert_nil @cache.get('key1')
  end

  def test_get_multiple
    @cache.set('key1', 'value1')
    @cache.set('key2', 'value2')

    results = @cache.get_multiple(['key1', 'key2', 'key3'])

    assert_equal 'value1', results['key1']
    assert_equal 'value2', results['key2']
    assert_nil results['key3']
  end

  def test_set_multiple
    @cache.set_multiple({'key1' => 'value1', 'key2' => 'value2'})

    assert_equal 'value1', @cache.get('key1')
    assert_equal 'value2', @cache.get('key2')
  end

  def test_debug_output
    output = capture_io do
      @cache.get('key1', debug: true)
      @cache.set('key1', 'value1')
      @cache.get('key1', debug: true)
    end

    assert_match(/\[CACHE MISS\] Key: key1/, output.join)
    assert_match(/\[CACHE HIT\] Key: key1/, output.join)
  end
end
