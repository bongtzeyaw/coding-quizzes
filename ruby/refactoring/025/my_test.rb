require 'minitest/autorun'
require_relative 'my_answer'

class SearchEngineTest < Minitest::Test
  def setup
    @engine = SearchEngine.new
  end

  def test_add_document
    result = @engine.add_document(1, 'Doc One', 'Hello world', ['tag1'])
    assert result
    refute @engine.add_document(1, 'Duplicate', 'Another')
  end

  def test_search_basic
    @engine.add_document(1, 'Doc One', 'Hello world', ['tag1'])
    res = @engine.search('Hello')
    assert_equal 1, res[:results].size
    assert_equal 'Doc One', res[:results].first[:document][:title]
  end

  def test_search_with_tag_filter
    @engine.add_document(1, 'Doc A', 'Alpha content', ['tag1'])
    @engine.add_document(2, 'Doc B', 'Beta content', ['tag2'])
    res = @engine.search('content', tags: ['tag2'])
    assert_equal 1, res[:results].size
    assert_equal 'Doc B', res[:results].first[:document][:title]
  end

  def test_search_with_date_filter
    @engine.add_document(1, 'Doc Old', 'Old data', ['tag1'])
    old_time = Time.now - 3600
    res = @engine.search('Old', date_from: old_time)
    assert_equal 1, res[:results].size
    res2 = @engine.search('Old', date_from: Time.now + 3600)
    assert_equal 0, res2[:results].size
  end

  def test_search_sorting
    @engine.add_document(1, 'B Doc', 'Bravo', ['tag1'])
    @engine.add_document(2, 'A Doc', 'Alpha', ['tag2'])
    res = @engine.search('Doc', sort_by: 'title')
    assert_equal(['A Doc', 'B Doc'], res[:results].map { |r| r[:document][:title] })
  end

  def test_search_pagination
    @engine.add_document(1, 'Doc One', 'First text', ['tag1'])
    @engine.add_document(2, 'Doc Two', 'Second text', ['tag2'])
    res = @engine.search('Doc', per_page: 1, page: 2)
    assert_equal 1, res[:results].size
    assert_equal 'Doc Two', res[:results].first[:document][:title]
  end

  def test_search_highlighting
    @engine.add_document(1, 'Doc Highlight', 'Highlight me', ['tag1'])
    res = @engine.search('Highlight', highlight: true)
    assert_includes res[:results].first[:highlighted_content], '<mark>Highlight</mark>'
  end

  def test_suggest
    @engine.add_document(1, 'Ruby Doc', 'Ruby text', ['tag1'])
    suggestions = @engine.suggest('Ru')
    assert_includes suggestions, 'ruby'
  end

  def test_reindex
    @engine.add_document(1, 'Doc Re', 'Reindex test', ['tag1'])
    @engine.reindex
    res = @engine.search('Reindex')
    assert_equal 1, res[:results].size
  end

  def test_get_stats_output
    @engine.add_document(1, 'Doc Stats', 'Stats text', ['tag1'])
    @engine.search('Stats')
    out, = capture_io { @engine.get_stats }
    assert_includes out, 'Search Engine Statistics:'
    assert_includes out, 'Documents: 1'
    assert_includes out, 'Top queries:'
    assert_includes out, 'Stats: 1 times'
  end
end
