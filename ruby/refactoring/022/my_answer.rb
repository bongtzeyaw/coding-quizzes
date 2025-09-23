class CacheSystem
  def initialize(max_size = 100, ttl = 3600)
    @cache = {}
    @access_times = {}
    @creation_times = {}
    @max_size = max_size
    @ttl = ttl
    @hit_count = 0
    @miss_count = 0
  end

  def get(key, options = {})
    if @creation_times[key] && (Time.now - @creation_times[key]) > @ttl
      @cache.delete(key)
      @access_times.delete(key)
      @creation_times.delete(key)
    end

    if @cache.has_key?(key)
      @hit_count += 1
      @access_times[key] = Time.now

      puts "[CACHE HIT] Key: #{key}" if options[:debug]

      return @cache[key]
    end

    @miss_count += 1

    # ログ出力
    puts "[CACHE MISS] Key: #{key}" if options[:debug]

    return nil unless block_given?

    value = yield

    if @cache.size >= @max_size
      oldest_key = nil
      oldest_time = Time.now

      @access_times.each do |k, time|
        if time < oldest_time
          oldest_key = k
          oldest_time = time
        end
      end

      if oldest_key
        @cache.delete(oldest_key)
        @access_times.delete(oldest_key)
        @creation_times.delete(oldest_key)

        puts "[CACHE EVICT] Key: #{oldest_key}" if options[:debug]
      end
    end

    @cache[key] = value
    @access_times[key] = Time.now
    @creation_times[key] = Time.now

    value
  end

  def set(key, value, options = {})
    ttl = options[:ttl] || @ttl

    # キャッシュサイズチェック
    if !@cache.has_key?(key) && @cache.size >= @max_size
      oldest_key = nil
      oldest_time = Time.now

      @access_times.each do |k, time|
        if time < oldest_time
          oldest_key = k
          oldest_time = time
        end
      end

      if oldest_key
        @cache.delete(oldest_key)
        @access_times.delete(oldest_key)
        @creation_times.delete(oldest_key)
      end
    end

    @cache[key] = value
    @access_times[key] = Time.now
    @creation_times[key] = Time.now

    nil unless ttl != @ttl
  end

  def delete(key)
    return false unless @cache.has_key?(key)

    @cache.delete(key)
    @access_times.delete(key)
    @creation_times.delete(key)
    true
  end

  def clear
    @cache.clear
    @access_times.clear
    @creation_times.clear
    @hit_count = 0
    @miss_count = 0
  end

  def size
    @cache.size
  end

  def stats
    total_requests = @hit_count + @miss_count
    hit_rate = total_requests > 0 ? (@hit_count.to_f / total_requests * 100).round(2) : 0

    puts 'Cache Statistics:'
    puts "  Size: #{@cache.size}/#{@max_size}"
    puts "  Hits: #{@hit_count}"
    puts "  Misses: #{@miss_count}"
    puts "  Hit Rate: #{hit_rate}%"

    memory_usage = 0
    @cache.each do |k, v|
      memory_usage += k.to_s.length
      memory_usage += v.to_s.length
    end

    puts "  Estimated Memory: #{memory_usage} bytes"
  end

  def get_multiple(keys)
    results = {}

    keys.each do |key|
      results[key] = get(key)
    end

    results
  end

  def set_multiple(entries)
    entries.each do |key, value|
      set(key, value)
    end
  end
end
