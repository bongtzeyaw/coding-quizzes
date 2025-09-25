class SearchEngine
  def initialize
    @documents = []
    @index = {}
    @search_history = []
    @stop_words = %w[the a an and or but in on at to for]
  end

  def add_document(id, title, content, tags = [])
    doc = {
      id: id,
      title: title,
      content: content,
      tags: tags,
      added_at: Time.now
    }

    existing = @documents.find { |d| d[:id] == id }
    if existing
      puts "Document already exists: #{id}"
      return false
    end

    @documents << doc

    words = title.downcase.split(/\W+/)
    words.each do |word|
      next if word.empty? || @stop_words.include?(word)

      @index[word] ||= []
      @index[word] << { doc_id: id, field: 'title', score: 10 }
    end

    words = content.downcase.split(/\W+/)
    words.each do |word|
      next if word.empty? || @stop_words.include?(word)

      @index[word] ||= []
      @index[word] << { doc_id: id, field: 'content', score: 1 }
    end

    tags.each do |tag|
      tag_key = "tag:#{tag.downcase}"
      @index[tag_key] ||= []
      @index[tag_key] << { doc_id: id, field: 'tag', score: 5 }
    end

    true
  end

  def search(query, options = {})
    @search_history << { query: query, timestamp: Time.now }

    terms = []
    operators = []
    current_term = ''
    in_quotes = false

    query.chars.each_with_index do |char, i|
      if char == '"'
        in_quotes = !in_quotes
      elsif char == ' ' && !in_quotes
        if %w[AND OR NOT].include?(current_term)
          operators << current_term
        elsif !current_term.empty?
          terms << current_term
        end
        current_term = ''
      else
        current_term += char
      end

      terms << current_term if i == query.length - 1 && !current_term.empty?
    end

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
