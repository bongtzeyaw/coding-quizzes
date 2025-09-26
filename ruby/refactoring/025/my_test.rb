require 'minitest/autorun'
require_relative 'my_answer'

class SearchEngineTest < Minitest::Test
  def setup
    @engine = SearchEngine.new
  end

  def test_add_document
    result = @engine.add_document(id: 1, title: 'Doc One', content: 'Hello world', tags: ['tag1'])
    assert result
    refute @engine.add_document(id: 1, title: 'Duplicate', content: 'Another')
  end

  def test_search_basic
    @engine.add_document(id: 1, title: 'Doc One', content: 'Hello world', tags: ['tag1'])
    res = @engine.search(query_string: 'Hello')
    assert_equal 1, res[:results].size
    assert_equal 'Doc One', res[:results].first[:document].title
  end

  def test_search_with_tag_filter
    @engine.add_document(id: 1, title: 'Doc A', content: 'Alpha content', tags: ['tag1'])
    @engine.add_document(id: 2, title: 'Doc B', content: 'Beta content', tags: ['tag2'])
    res = @engine.search(query_string: 'content', options: { tags: ['tag2'] })
    assert_equal 1, res[:results].size
    assert_equal 'Doc B', res[:results].first[:document].title
  end

  def test_search_with_date_filter
    @engine.add_document(id: 1, title: 'Doc Old', content: 'Old data', tags: ['tag1'])
    old_time = Time.now - 3600
    res = @engine.search(query_string: 'Old', options: { date_from: old_time })
    assert_equal 1, res[:results].size
    res2 = @engine.search(query_string: 'Old', options: { date_from: Time.now + 3600 })
    assert_equal 0, res2[:results].size
  end

  def test_search_sorting
    @engine.add_document(id: 1, title: 'B Doc', content: 'Bravo', tags: ['tag1'])
    @engine.add_document(id: 2, title: 'A Doc', content: 'Alpha', tags: ['tag2'])
    res = @engine.search(query_string: 'Doc', options: { sort_by: 'title' })
    assert_equal(['A Doc', 'B Doc'], res[:results].map { |r| r[:document].title })
  end

  def test_search_pagination
    @engine.add_document(id: 1, title: 'Doc One', content: 'First text', tags: ['tag1'])
    @engine.add_document(id: 2, title: 'Doc Two', content: 'Second text', tags: ['tag2'])
    res = @engine.search(query_string: 'Doc', options: { per_page: 1, page: 2 })
    assert_equal 1, res[:results].size
    assert_equal 'Doc Two', res[:results].first[:document].title
  end

  def test_search_highlighting
    @engine.add_document(id: 1, title: 'Doc Highlight', content: 'Highlight me', tags: ['tag1'])
    res = @engine.search(query_string: 'Highlight', options: { highlight: true })
    assert_includes res[:results].first[:highlighted_content], '<mark>Highlight</mark>'
  end

  def test_suggest
    @engine.add_document(id: 1, title: 'Ruby Doc', content: 'Ruby text', tags: ['tag1'])
    suggestions = @engine.suggest(prefix: 'Ru')
    assert_includes suggestions, 'ruby'
  end

  def test_reindex
    @engine.add_document(id: 1, title: 'Doc Re', content: 'Reindex test', tags: ['tag1'])
    @engine.reindex
    res = @engine.search(query_string: 'Reindex')
    assert_equal 1, res[:results].size
  end

  def test_get_stats_output
    @engine.add_document(id: 1, title: 'Doc Stats', content: 'Stats text', tags: ['tag1'])
    @engine.search(query_string: 'Stats')
    out, = capture_io { @engine.get_stats }
    assert_includes out, 'Search Engine Statistics:'
    assert_includes out, 'Documents: 1'
    assert_includes out, 'Top queries:'
    assert_includes out, 'Stats: 1 times'
  end

  def test_search_with_empty_query
    @engine.add_document(id: 1, title: 'Doc One', content: 'Hello world', tags: ['tag1'])
    res = @engine.search(query_string: '')
    assert res.is_a?(Array) || (res.is_a?(Hash) && res[:results].empty?)
  end

  def test_search_with_quoted_phrases
    @engine.add_document(id: 1, title: 'Doc One', content: 'Hello beautiful world', tags: ['tag1'])
    res = @engine.search(query_string: 'Hello beautiful')
    assert_equal 1, res[:results].size
    assert_equal 'Doc One', res[:results].first[:document].title
  end

  def test_search_with_stop_words
    @engine.add_document(id: 1, title: 'Doc Stop Words', content: 'The quick brown fox jumps over the lazy dog',
                         tags: ['tag1'])
    res = @engine.search(query_string: 'the a an')
    assert_empty res[:results]

    res = @engine.search(query_string: 'the quick fox')
    assert_equal 1, res[:results].size
    assert_equal 'Doc Stop Words', res[:results].first[:document].title
  end

  def test_search_with_date_to_filter
    now = Time.now
    @engine.add_document(id: 1, title: 'Doc Recent', content: 'Recent document', tags: ['tag1'])
    sleep(0.1)
    future_time = now + 3600

    res = @engine.search(query_string: 'Recent', options: { date_to: future_time })
    assert_equal 1, res[:results].size

    past_time = now - 3600
    res2 = @engine.search(query_string: 'Recent', options: { date_to: past_time })
    assert_equal 0, res2[:results].size
  end

  def test_search_score_ordering
    @engine.add_document(id: 1, title: 'Ruby Programming', content: 'Learn to code', tags: ['tag1'])
    @engine.add_document(id: 2, title: 'Learn Python', content: 'Ruby is great too', tags: ['tag2'])

    res = @engine.search(query_string: 'Ruby')
    assert_equal 2, res[:results].size

    assert_equal 'Ruby Programming', res[:results][0][:document].title
    assert_equal 'Learn Python', res[:results][1][:document].title

    assert res[:results][0][:score] > res[:results][1][:score]
  end

  def test_date_sorting_with_order_option
    @engine.add_document(id: 1, title: 'Doc One', content: 'First document', tags: ['tag1'])
    sleep(0.1)
    @engine.add_document(id: 2, title: 'Doc Two', content: 'Second document', tags: ['tag1'])

    res = @engine.search(query_string: 'document', options: { sort_by: 'date', order: 'asc' })
    assert_equal 2, res[:results].size
    assert_equal 'Doc One', res[:results][0][:document].title
    assert_equal 'Doc Two', res[:results][1][:document].title

    res = @engine.search(query_string: 'document', options: { sort_by: 'date', order: 'desc' })
    assert_equal 2, res[:results].size
    assert_equal 'Doc Two', res[:results][0][:document].title
    assert_equal 'Doc One', res[:results][1][:document].title
  end

  def test_suggest_with_limit_parameter
    @engine.add_document(id: 1, title: 'Programming', content: 'Program in Ruby', tags: ['tag1'])
    @engine.add_document(id: 2, title: 'Progress', content: 'Making progress', tags: ['tag2'])
    @engine.add_document(id: 3, title: 'Project', content: 'New project', tags: ['tag3'])
    @engine.add_document(id: 4, title: 'Problem', content: 'Solving problems', tags: ['tag4'])
    @engine.add_document(id: 5, title: 'Process', content: 'Process management', tags: ['tag5'])

    suggestions = @engine.suggest(prefix: 'pro')
    assert_operator suggestions.size, :>=, 5

    limited_suggestions = @engine.suggest(prefix: 'pro', limit: 2)
    assert_equal 2, limited_suggestions.size

    larger_suggestions = @engine.suggest(prefix: 'pro', limit: 20)
    assert_operator larger_suggestions.size, :>=, 5

    no_suggestions = @engine.suggest(prefix: 'xyz')
    assert_empty no_suggestions
  end

  def test_search_with_special_characters
    @engine.add_document(id: 1, title: 'C++ Programming', content: 'Learn C++ language', tags: ['tag1'])
    @engine.add_document(id: 2, title: 'Regular Expressions', content: 'Learn about (.*) and [a-z]+', tags: ['tag2'])
    @engine.add_document(id: 3, title: 'SQL Queries', content: 'WHERE column = "value"', tags: ['tag3'])

    res_cpp = @engine.search(query_string: 'Programming')
    assert_equal 1, res_cpp[:results].size
    assert_equal 'C++ Programming', res_cpp[:results].first[:document].title

    res_regex = @engine.search(query_string: 'about')
    assert_equal 1, res_regex[:results].size
    assert_equal 'Regular Expressions', res_regex[:results].first[:document].title

    res_quotes = @engine.search(query_string: 'column')
    assert_equal 1, res_quotes[:results].size
    assert_equal 'SQL Queries', res_quotes[:results].first[:document].title

    res_highlight = @engine.search(query_string: 'language', options: { highlight: true })
    assert_includes res_highlight[:results].first[:highlighted_content], '<mark>language</mark>'
  end

  def test_document_with_empty_fields
    @engine.add_document(id: 1, title: '', content: 'Content with no title', tags: ['tag1'])
    @engine.add_document(id: 2, title: 'Title with no content', content: '', tags: ['tag2'])
    @engine.add_document(id: 3, title: 'Title with no tags', content: 'Content with no tags', tags: [])

    res_no_title = @engine.search(query_string: 'Content')
    assert_operator res_no_title[:results].size, :>=, 1
    assert(res_no_title[:results].any? { |r| r[:document].title == '' })

    res_no_content = @engine.search(query_string: 'Title')
    assert_operator res_no_content[:results].size, :>=, 1
    assert(res_no_content[:results].any? { |r| r[:document].title == 'Title with no content' })

    res_no_tags = @engine.search(query_string: 'tags')
    assert_operator res_no_tags[:results].size, :>=, 1
    assert(res_no_tags[:results].any? { |r| r[:document].tags.empty? })
  end

  def test_search_with_multiple_terms
    @engine.add_document(id: 1, title: 'Ruby Programming', content: 'Learn Ruby programming language',
                         tags: %w[ruby programming])
    @engine.add_document(id: 2, title: 'Python Basics', content: 'Introduction to Python programming', tags: ['python'])
    @engine.add_document(id: 3, title: 'Java Tutorial', content: 'Java programming examples', tags: ['java'])
    @engine.add_document(id: 4, title: 'Programming Books', content: 'Best books on coding and algorithms',
                         tags: ['books'])

    res = @engine.search(query_string: 'programming')
    assert_operator res[:results].size, :>=, 1

    res_ruby = @engine.search(query_string: 'ruby')
    assert_operator res_ruby[:results].size, :>=, 1

    res_python = @engine.search(query_string: 'python')
    assert_operator res_python[:results].size, :>=, 1

    res_books = @engine.search(query_string: 'books')
    assert_operator res_books[:results].size, :>=, 1

    all_titles = res[:results].map { |r| r[:document].title }
    assert(all_titles.any? { |title| title.include?('Ruby') || title.include?('Programming') })
  end
end
