# frozen_string_literal: true

class CacheManager
  CACHE_VALIDITY_PERIOD = 1 * 60 * 60
  CACHE_EXPIRATION_PERIOD = 24 * 60 * 60
  CACHE_DIR = '/tmp/cache'

  class << self
    def build_image_cache_key(image_path:, width:, height:)
      "#{image_path}_#{width}x#{height}"
    end

    def with_caching(key)
      cached_value = find_by_cache_key(key)
      return cached_value if cached_value

      value = yield
      create_cache_entry(key, value)
      value
    end

    def clean_expired_cache
      return unless Dir.exist?(CACHE_DIR)

      expired_file_paths.each { |file_path| delete_file(file_path) }
    end

    private

    def cache_file_path(key)
      File.join(CACHE_DIR, key)
    end

    def cache_valid?(file_path)
      Time.now - File.mtime(file_path) < CACHE_VALIDITY_PERIOD
    end

    def cache_expired?(file_path)
      Time.now - File.mtime(file_path) > CACHE_EXPIRATION_PERIOD
    end

    def find_by_cache_key(key)
      file_path = cache_file_path(key)

      return nil unless File.exist?(file_path)
      return nil unless cache_valid?(file_path)

      File.read(file_path)
    end

    def create_cache_entry(key, value)
      file_path = cache_file_path(key)

      Dir.mkdir(CACHE_DIR) unless Dir.exist?(CACHE_DIR)
      File.write(file_path, value)
    end

    def expired_file_paths
      Dir.glob(File.join(CACHE_DIR, '*')).filter do |file_path|
        File.file?(file_path) && cache_expired?(file_path)
      end
    end

    def delete_file(file_path)
      File.delete(file_path)
    end
  end
end

class ImageProcessor
  def get_thumbnail(image_path, width, height)
    cache_key = CacheManager.build_image_cache_key(image_path:, width:, height:)

    CacheManager.with_caching(cache_key) do
      original = load_image(image_path)

      resized = if width && height
                  resize_image(original, width, height)
                else
                  original
                end

      resized
    end
  end

  def get_multiple_thumbnails(image_paths, sizes)
    results = {}

    for i in 0..image_paths.length - 1
      image_path = image_paths[i]
      results[image_path] = {}

      for j in 0..sizes.length - 1
        size = sizes[j]
        width = size[:width]
        height = size[:height]

        thumbnail = get_thumbnail(image_path, width, height)
        results[image_path]["#{width}x#{height}"] = thumbnail
      end
    end

    results
  end

  def clean_old_cache
    CacheManager.clean_expired_cache
  end

  private

  def load_image(path)
    "image_data_#{path}"
  end

  def resize_image(image, width, height)
    "resized_#{image}_#{width}x#{height}"
  end
end
