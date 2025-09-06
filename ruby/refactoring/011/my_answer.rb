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
    rescue Errno::ENOENT, Errno::EACCES => e
      puts "Warning: Failed to check cache validity: #{e.message}"
      false
    end

    def cache_expired?(file_path)
      Time.now - File.mtime(file_path) > CACHE_EXPIRATION_PERIOD
    rescue Errno::ENOENT, Errno::EACCES => e
      puts "Warning: Failed to check cache expiration: #{e.message}"
      false
    end

    def find_by_cache_key(key)
      file_path = cache_file_path(key)

      return nil unless File.exist?(file_path)
      return nil unless cache_valid?(file_path)

      File.read(file_path)
    rescue Errno::ENOENT, Errno::EACCES, IOError, ArgumentError => e
      puts "Warning: Failed to read from cache file: #{e.message}"
    end

    def create_cache_entry(key, value)
      file_path = cache_file_path(key)

      Dir.mkdir(CACHE_DIR) unless Dir.exist?(CACHE_DIR)
      File.write(file_path, value)
    rescue Errno::EACCES, IOError => e
      puts "Warning: Failed to write to cache file: #{e.message}"
    end

    def expired_file_paths
      Dir.glob(File.join(CACHE_DIR, '*')).filter do |file_path|
        File.file?(file_path) && cache_expired?(file_path)
      end
    rescue Errno::ENOENT, Errno::EACCES => e
      puts "Warning: Failed to list expired cache files: #{e.message}"
      []
    end

    def delete_file(file_path)
      File.delete(file_path)
    rescue Errno::EACCES, IOError => e
      puts "Warning: Failed to delete file: #{e.message}"
    end
  end
end

class ThumbnailGenerator
  class << self
    def generate_thumbnail(image_path:, width:, height:)
      original = load_image(image_path)
      resize_applicable?(width, height) ? resize_image(original, width, height) : original
    end

    private

    def load_image(path)
      "image_data_#{path}"
    end

    def resize_applicable?(width, height)
      width && height
    end

    def resize_image(image, width, height)
      "resized_#{image}_#{width}x#{height}"
    end
  end
end

class ImageProcessor
  def get_thumbnail(image_path, width, height)
    cache_key = CacheManager.build_image_cache_key(image_path:, width:, height:)

    CacheManager.with_caching(cache_key) do
      ThumbnailGenerator.generate_thumbnail(image_path:, width:, height:)
    end
  end

  def get_multiple_thumbnails(image_paths, sizes)
    image_paths.map do |image_path|
      [
        image_path,
        sizes.map do |size|
          width = size[:width]
          height = size[:height]

          [
            "#{width}x#{height}",
            get_thumbnail(image_path, width, height)
          ]
        end.to_h
      ]
    end.to_h
  end

  def clean_old_cache
    CacheManager.clean_expired_cache
  end
end
