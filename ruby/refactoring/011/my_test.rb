require 'minitest/autorun'
require 'fileutils'
require 'tempfile'
require_relative 'my_answer'

class ImageProcessorTest < Minitest::Test
  TEMP_CACHE_DIR = '/tmp/cache'

  def setup
    @processor = ImageProcessor.new
    FileUtils.mkdir_p(TEMP_CACHE_DIR)
    @test_files = []
  end

  def teardown
    @test_files.each do |file_path|
      FileUtils.rm_r(file_path) if File.exist?(file_path)
    end
    FileUtils.rm_r(TEMP_CACHE_DIR) if Dir.exist?(TEMP_CACHE_DIR)
  end

  def test_get_thumbnail_from_cache_if_not_expired
    cache_path = File.join(TEMP_CACHE_DIR, 'image1_100x100')
    File.write(cache_path, 'cached_data')
    @test_files << cache_path
    File.utime(Time.now - 3000, Time.now - 3000, cache_path)
    assert_equal 'cached_data', @processor.get_thumbnail('image1', 100, 100)
  end

  def test_get_thumbnail_and_cache_if_no_cache_exists
    cache_path = File.join(TEMP_CACHE_DIR, 'image2_200x200')
    @test_files << cache_path
    refute File.exist?(cache_path)
    assert_equal 'resized_image_data_image2_200x200', @processor.get_thumbnail('image2', 200, 200)
    assert File.exist?(cache_path)
    assert_equal 'resized_image_data_image2_200x200', File.read(cache_path)
  end

  def test_get_thumbnail_and_cache_if_cache_expired
    cache_path = File.join(TEMP_CACHE_DIR, 'image3_300x300')
    @test_files << cache_path
    File.write(cache_path, 'old_data')
    File.utime(Time.now - 4000, Time.now - 4000, cache_path)
    assert_equal 'resized_image_data_image3_300x300', @processor.get_thumbnail('image3', 300, 300)
    assert_equal 'resized_image_data_image3_300x300', File.read(cache_path)
  end

  def test_get_thumbnail_without_resizing_if_no_width_or_height
    cache_path = File.join(TEMP_CACHE_DIR, 'image4_x')
    @test_files << cache_path
    assert_equal 'image_data_image4', @processor.get_thumbnail('image4', nil, nil)
    assert_equal 'image_data_image4', File.read(cache_path)
  end

  def test_get_multiple_thumbnails
    image_paths = %w[image1 image2]
    sizes = [{ width: 100, height: 100 }, { width: 200, height: 200 }]
    expected = {
      'image1' => { '100x100' => 'resized_image_data_image1_100x100',
                    '200x200' => 'resized_image_data_image1_200x200' },
      'image2' => { '100x100' => 'resized_image_data_image2_100x100', '200x200' => 'resized_image_data_image2_200x200' }
    }
    results = @processor.get_multiple_thumbnails(image_paths, sizes)
    assert_equal expected, results
    @test_files << File.join(TEMP_CACHE_DIR, 'image1_100x100')
    @test_files << File.join(TEMP_CACHE_DIR, 'image1_200x200')
    @test_files << File.join(TEMP_CACHE_DIR, 'image2_100x100')
    @test_files << File.join(TEMP_CACHE_DIR, 'image2_200x200')
  end

  def test_clean_old_cache
    old_file_path = File.join(TEMP_CACHE_DIR, 'old_file.jpg')
    new_file_path = File.join(TEMP_CACHE_DIR, 'new_file.jpg')
    @test_files << old_file_path
    @test_files << new_file_path
    File.write(old_file_path, 'old_data')
    File.write(new_file_path, 'new_data')
    File.utime(Time.now - 90_000, Time.now - 90_000, old_file_path)
    @processor.clean_old_cache
    refute File.exist?(old_file_path)
    assert File.exist?(new_file_path)
  end

  def test_clean_old_cache_when_directory_does_not_exist
    FileUtils.rm_r(TEMP_CACHE_DIR)
    refute Dir.exist?(TEMP_CACHE_DIR)
    assert_nil @processor.clean_old_cache
  end
end
