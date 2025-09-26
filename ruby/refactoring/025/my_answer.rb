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

class Filter
  def apply(document_results)
    raise NotImplementedError, "#{self.class} must implement #apply"
  end
end

class TagsFilter < Filter
  def initialize(tags)
    @tags = tags
  end

  def apply(document_results)
    document_results.select do |result|
      (result[:document].tags & @tags).any?
    end
  end
end

class DateFromFilter < Filter
  def initialize(date_from)
    @date_from = date_from
  end

  def apply(document_results)
    document_results.select do |result|
      result[:document].added_at >= @date_from
    end
  end
end

class DateToFilter < Filter
  def initialize(date_to)
    @date_to = date_to
  end

  def apply(document_results)
    document_results.select do |result|
      result[:document].added_at <= @date_to
    end
  end
end

class FilteringChain
  def initialize(options)
    @filters = build_filters(options)
  end

  def apply_filters(scored_results)
    @filters.reduce(scored_results) { |result, filter| filter.apply(result) }
  end

  private

  def build_filters(options)
    filters = []

    filters << TagsFilter.new(options[:tags]) if options[:tags]
    filters << DateFromFilter.new(options[:date_from]) if options[:date_from]
    filters << DateToFilter.new(options[:date_to]) if options[:date_to]

    filters
  end
end

class Sorter
  def initialize(options)
    @options = options
  end

  def sort(document_results)
    raise NotImplementedError, "#{self.class} must implement #sort"
  end
end

class DateSorter < Sorter
  def sort(document_results)
    sorted_results = document_results.sort_by { |result| result[:document].added_at }
    @options[:order] == 'desc' ? sorted_results.reverse : sorted_results
  end
end

class TitleSorter < Sorter
  def sort(document_results)
    document_results.sort_by { |result| result[:document].title }
  end
end

class ScoreSorter < Sorter
  def sort(document_results)
    document_results.sort_by { |result| -result[:score] }
  end
end

class SorterDispatcher
  SORTER_MAP = {
    date: DateSorter,
    title: TitleSorter,
    score: ScoreSorter
  }.freeze

  DEFAULT_SORT_BY = :score

  class << self
    def dispatch(sort_by)
      return SORTER_MAP[DEFAULT_SORT_BY] unless sort_by

      SORTER_MAP[sort_by.to_sym]
    end
  end
end

class Paginator
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 10

  attr_reader :page, :per_page

  def initialize(results:, page:, per_page:)
    @results = results
    @page = page || DEFAULT_PAGE
    @per_page = per_page || DEFAULT_PER_PAGE
  end

  def paginate
    start_index = (page - 1) * @per_page
    @results[start_index, @per_page] || []
  end
end

class Highlighter
  DEFAULT_HIGHLIGHT_TAG = 'mark'

  def initialize(highlight_tag: DEFAULT_HIGHLIGHT_TAG)
    @highlight_tag = highlight_tag
  end

  def highlight(text:, terms:)
    terms.reduce(text.dup) do |highlighted, term|
      highlighted.gsub(/#{Regexp.escape(term)}/i) { |match| "<#{@highlight_tag}>#{match}</#{@highlight_tag}>" }
    end
  end
end

class SearchResponse
  def initialize(results:, total:, page:, per_page:)
    @results = results
    @total = total
    @page = page
    @per_page = per_page
  end

  def to_h
    {
      results: @results,
      total: @total,
      page: @page,
      per_page: @per_page
    }
  end
end

class Searcher
  def initialize(index_registry)
    @index_registry = index_registry
  end

  def search(query:, document_registry:, options: {})
    return [] if query.terms.empty?

    matching_index_entries = find_matching_index_entries(query)
    scores_by_document_id = calculate_scores_by_doc_id(matching_index_entries)
    scores_by_document = find_documents(scores_by_document_id, document_registry)

    filtered_results = apply_filters(scores_by_document, options)
    sorted_results = apply_sorting(filtered_results, options)

    pagination_results_details = paginate(sorted_results, options)
    highlighted_results = apply_highlighting(pagination_results_details[:paginated_results], query.terms, options)

    SearchResponse.new(
      results: highlighted_results,
      total: sorted_results.length,
      page: pagination_results_details[:page],
      per_page: pagination_results_details[:per_page]
    ).to_h
  end

  private

  def find_matching_index_entries(query)
    query.terms.flat_map do |term|
      @index_registry.find_entries_by(term.downcase) || []
    end
  end

  def calculate_scores_by_doc_id(index_entries)
    index_entries.each_with_object(Hash.new(0)) do |index_entry, scores|
      scores[index_entry.document_id] += index_entry.score
    end
  end

  def find_documents(scores_by_doc_id, document_registry)
    scores_by_doc_id.each_with_object([]) do |(doc_id, score), results|
      document = document_registry.find_by(doc_id)
      results << { document:, score: } if document
    end
  end

  def apply_filters(document_results, options)
    FilteringChain.new(options).apply_filters(document_results)
  end

  def apply_sorting(document_results, options)
    sorter_class = SorterDispatcher.dispatch(options[:sort_by])
    sorter_class.new(options).sort(document_results)
  end

  def paginate(results, options)
    paginator = Paginator.new(results:, page: options[:page], per_page: options[:per_page])

    {
      paginated_results: paginator.paginate,
      page: paginator.page,
      per_page: paginator.per_page
    }
  end

  def apply_highlighting(results, terms, options)
    return results unless options[:highlight]

    highlighter = Highlighter.new

    results.map do |result|
      result.merge(
        highlighted_content: highlighter.highlight(text: result[:document].content, terms: terms)
      )
    end
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
    
    searcher = Searcher.new(@index_registry)
    searcher.search(query:, document_registry: @document_registry, options:)
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
