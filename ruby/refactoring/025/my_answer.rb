class Document
  attr_reader :id, :title, :content, :tags, :added_at

  def initialize(id:, title:, content:, tags:)
    @id = id
    @title = title
    @content = content
    @tags = tags
    @added_at = Time.now.utc
  end
end

class DocumentRegistry
  def initialize
    @documents = {}
  end

  def document_exists?(id)
    @documents.key?(id)
  end

  def add(document)
    @documents[document.id] = document
  end

  def find_by(id)
    @documents[id]
  end

  def count
    @documents.length
  end

  def all
    @documents.values
  end
end

class IndexScoreStrategy
  SCORES = {
    title: 10,
    content: 1,
    tag: 5
  }.freeze

  class << self
    def score(field_type)
      score = SCORES[field_type]
      raise "Score not defined for field type: #{field_type}" unless score

      score
    end
  end
end

class IndexabilityAnalyzer
  STOP_WORDS = %w[the a an and or but in on at to for].freeze

  def analyze(text)
    words = text.downcase
                .split(/\W+/)

    words.filter { |word| indexable?(word) }
  end

  private

  def indexable?(word)
    !word.empty? && !STOP_WORDS.include?(word)
  end
end

class IndexEntry
  attr_reader :document_id, :score

  def initialize(document_id:, field:, score:)
    @document_id = document_id
    @field = field
    @score = score
  end
end

class Indexer
  def initialize(index_registry)
    @index_registry = index_registry
    @analyzer = IndexabilityAnalyzer.new
  end

  def index_document(document)
    index_field(document.id, :title, document.title)
    index_field(document.id, :content, document.content)
    index_tags(document.id, document.tags)
  end

  private

  def find_score(field_type)
    IndexScoreStrategy.score(field_type)
  end

  def index_field(document_id, field_type, text)
    score = find_score(field_type)
    indexable_words = @analyzer.analyze(text)

    indexable_words.each do |word|
      index_entry = IndexEntry.new(
        document_id: document_id,
        field: field_type.to_s,
        score:
      )

      @index_registry.add_entry(word:, index_entry:)
    end
  end

  def index_tags(document_id, tags)
    field_type = :tag
    score = find_score(field_type)

    tags.each do |tag|
      tag_key = "tag:#{tag.downcase}"

      index_entry = IndexEntry.new(
        document_id: document_id,
        field: field_type.to_s,
        score:
      )

      @index_registry.add_entry(word: tag_key, index_entry:)
    end
  end
end

class IndexRegistry
  def initialize
    @index = {}
  end

  def add_entry(word:, index_entry:)
    @index[word] ||= []
    @index[word] << index_entry
  end

  def find_entries_by(word)
    @index[word]
  end

  def clear
    @index.clear
  end

  def keys
    @index.keys
  end

  def word_frequency(word)
    entries = find_entries_by(word)
    entries ? entries.length : 0
  end
end

class Token
  attr_reader :value, :type

  def initialize(value)
    @value = value
    @type = self.class::TYPE
  end
end

class QueryTermToken < Token
  TYPE = :term
end

class QueryOperatorToken < Token
  TYPE = :operator
end

class QueryTokenizer
  QUERY_OPERATOR_INDICATORS = %w[AND OR NOT].freeze

  attr_reader :tokens

  def initialize(query_string)
    @query_string = query_string
    @tokens = []
  end

  def tokenize
    current_token = ''
    state = :normal

    @query_string.each_char do |char|
      case state
      when :normal
        case char
        when '"'
          state = :quoted
        when ' '
          add_token(current_token)
          current_token = ''
        else
          current_token += char
        end
      when :quoted
        if char == '"'
          state = :normal
        else
          current_token += char
        end
      end
    end

    add_token(current_token)
  end

  private

  def add_token(token)
    return if token.empty?

    @tokens << if QUERY_OPERATOR_INDICATORS.include?(token)
                 QueryOperatorToken.new(token)
               else
                 QueryTermToken.new(token)
               end
  end
end

class Query
  attr_reader :terms, :operators

  def initialize(terms:, operators:)
    @terms = terms
    @operators = operators
  end
end

class QueryParser
  def parse(query_string)
    parser = QueryTokenizer.new(query_string)
    parser.tokenize
    tokens = parser.tokens

    terms = filter_tokens_by_type(tokens, :term).map(&:value)
    operators = filter_tokens_by_type(tokens, :operator).map(&:value)

    Query.new(terms:, operators:)
  end

  private

  def filter_tokens_by_type(tokens, type)
    tokens.select { |token| token.type == type }
  end
end

class SearchEngine
  def initialize
    @document_registry = DocumentRegistry.new
    @index_registry = IndexRegistry.new
    @search_history = []
    @stop_words = %w[the a an and or but in on at to for]
  end

  def add_document(id, title, content, tags = [])
    existing = @documents.find { |d| d[:id] == id }
    if existing
      puts "Document already exists: #{id}"
      return false
    end

    document = Document.new(
      id:,
      title:,
      content:,
      tags:
    )

    @document_registry.add(document)

    indexer = Indexer.new(@index_registry)
    indexer.index_document(document)

    true
  end

  def search(query, options = {})
    @search_history << { query: query, timestamp: Time.now }

    query = @query_parser.parse(query_string)
    
    terms = query.terms
    operators = query.operators

    results = []

    return [] if terms.empty?

    term_results = []
    terms.each do |term|
      term_lower = term.downcase

      next unless @index[term_lower]

      @index[term_lower].each do |entry|
        term_results << entry
      end
    end

    doc_scores = {}
    term_results.each do |entry|
      doc_scores[entry[:doc_id]] ||= 0
      doc_scores[entry[:doc_id]] += entry[:score]
    end

    doc_scores.each do |doc_id, score|
      doc = @documents.find { |d| d[:id] == doc_id }
      next unless doc

      results << {
        document: doc,
        score: score
      }
    end

    if options[:tags]
      results = results.select do |result|
        (result[:document][:tags] & options[:tags]).any?
      end
    end

    if options[:date_from]
      results = results.select do |result|
        result[:document][:added_at] >= options[:date_from]
      end
    end

    if options[:date_to]
      results = results.select do |result|
        result[:document][:added_at] <= options[:date_to]
      end
    end

    case options[:sort_by]
    when 'date'
      results.sort_by! { |r| r[:document][:added_at] }
      results.reverse! if options[:order] == 'desc'
    when 'title'
      results.sort_by! { |r| r[:document][:title] }
    else
      results.sort_by! { |r| -r[:score] }
    end

    page = options[:page] || 1
    per_page = options[:per_page] || 10
    start_index = (page - 1) * per_page

    paged_results = results[start_index, per_page] || []

    if options[:highlight]
      paged_results.each do |result|
        highlighted_content = result[:document][:content].dup
        terms.each do |term|
          highlighted_content.gsub!(/#{term}/i, "<mark>#{term}</mark>")
        end
        result[:highlighted_content] = highlighted_content
      end
    end

    {
      results: paged_results,
      total: results.length,
      page: page,
      per_page: per_page
    }
  end

  def suggest(prefix, limit = 5)
    suggestions = []

    @index.keys.each do |word|
      suggestions << word if word.start_with?(prefix.downcase) && !word.start_with?('tag:')
    end

    suggestions.sort_by! { |word| -@index[word].length }

    suggestions.take(limit)
  end

  def get_stats
    puts 'Search Engine Statistics:'
    puts "  Documents: #{@documents.length}"
    puts "  Indexed words: #{@index.keys.reject { |k| k.start_with?('tag:') }.length}"
    puts "  Tags: #{@index.keys.select { |k| k.start_with?('tag:') }.length}"
    puts "  Search history: #{@search_history.length} queries"

    query_counts = {}
    @search_history.each do |entry|
      query_counts[entry[:query]] ||= 0
      query_counts[entry[:query]] += 1
    end

    top_queries = query_counts.sort_by { |_, count| -count }.take(5)
    puts '  Top queries:'
    top_queries.each do |query, count|
      puts "    #{query}: #{count} times"
    end
  end

  def reindex
    @index.clear

    @documents.each do |doc|
      add_document(doc[:id], doc[:title], doc[:content], doc[:tags])
    end
  end
end
