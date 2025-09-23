# frozen_string_literal: true

class Topic
  DEFAULT_MAX_RETRIES = 3
  DEFAULT_RETENTION_PERIOD = 24 * 60 * 60

  attr_reader :name, :max_retries, :retention_period
  attr_accessor :message_count

  def initialize(name:, max_retries:, retention_period:)
    @name = name
    @created_at = Time.now.utc
    @max_retries = max_retries || DEFAULT_MAX_RETRIES
    @retention_period = retention_period || DEFAULT_RETENTION_PERIOD
    @message_count = 0
  end
end

class TopicRegistry
  def initialize
    @topics = {}
  end

  def find(name)
    topic = @topics[name]
    raise "Topic not found: #{name}" unless topic

    topic
  end

  def all
    @topics.values
  end

  def topic_exist?(name)
    @topics.key?(name)
  end

  def register(topic)
    @topics[topic.name] = topic
  end
end

class Message
  DEFAULT_PRIORITY = 5

  attr_reader :id, :content, :priority, :attributes, :published_at, :topic
  attr_writer :last_error
  attr_accessor :retry_count

  def initialize(id:, topic:, content:, priority:, attributes:)
    @id = id
    @topic = topic
    @content = content
    @priority = priority || DEFAULT_PRIORITY
    @published_at = Time.now.utc
    @attributes = attributes || {}
    @retry_count = 0
  end

  def expired?(retention_period)
    (Time.now.utc - @published_at) > retention_period
  end

  def under_retry_limit?
    @retry_count < @topic.max_retries
  end
end

class MessageRegistry
  def initialize
    @messages = {}
    @message_id = 0
  end

  def register(topic_name:)
    @messages[topic_name] = []
  end

  def create_entry(topic:, message:)
    @messages[topic.name] << message
    topic.message_count += 1
  end

  def generate_id
    @message_id += 1
  end

  def cleanup_expired(topic_name:, retention_period:)
    @messages[topic_name].delete_if { |message| message.expired?(retention_period) }
  end

  def filter_messages_for_topic(topic_name:, subscriber:, limit:)
    filtered_messages = (@messages[topic_name] || []).select { |message| subscriber.filter_pass_for_message?(message) }
    filtered_messages.sort_by(&:published_at).reverse.take(limit)
  end
end

class MessageQueue
  def initialize
    @topic_registry = TopicRegistry.new
    @message_registry = MessageRegistry.new
    @subscribers = {}
    @failed_messages = []
    @message_id = 0
  end

  def create_topic(topic_name, options = {})
    if @topic_registry.topic_exist?(topic_name)
      puts "Topic already exists: #{topic_name}"
      return false
    end

    topic = Topic.new(
      name: topic_name,
      max_retries: options[:max_retries],
      retention_period: options[:retention_period]
    )

    @topic_registry.register(topic)
    @message_registry.register(topic_name:)
    @subscribers[topic_name] = []

    true
  end

  def subscribe(topic_name, subscriber_name, filter = nil, &handler)
    unless @topic_registry.topic_exist?(topic_name)
      puts "Topic not found: #{topic_name}"
      return false
    end

    existing = @subscribers[topic_name].find { |s| s[:name] == subscriber_name }
    if existing
      puts "Subscriber already exists: #{subscriber_name}"
      return false
    end

    @subscribers[topic_name] << {
      name: subscriber_name,
      filter: filter,
      handler: handler,
      subscribed_at: Time.now,
      message_count: 0,
      error_count: 0
    }

    true
  end

  def publish(topic_name, message, options = {})
    unless @topic_registry.topic_exist?(topic_name)
      puts "Topic not found: #{topic_name}"
      return nil
    end

    message_id = @message_registry.generate_id
    topic = @topic_registry.find(topic_name)

    message = Message.new(
      id: message_id,
      topic: topic,
      content: message,
      priority: options[:priority],
      attributes: options[:attributes]
    )

    @message_registry.create_entry(topic:, message:)
    @message_registry.cleanup_expired(topic_name:, retention_period: topic.retention_period)

    delivered_count = 0
    @subscribers[topic_name].each do |subscriber|
      if subscriber[:filter]
        matched = true
        subscriber[:filter].each do |key, value|
          if message_data[:attributes][key] != value
            matched = false
            break
          end
        end
        next unless matched
      end

      begin
        if options[:async]
          Thread.new do
            sleep(0.1 * (10 - message.priority))
            subscriber[:handler].call(message.content, message.attributes)
          end
        else
          subscriber[:handler].call(message.content, message.attributes)
        end

        subscriber[:message_count] += 1
        delivered_count += 1
      rescue StandardError => e
        subscriber[:error_count] += 1

        if message.retry_count < topic.max_retries
          message.retry_count += 1
          message.last_error = e.message

          Thread.new do
            sleep(message.retry_count * 2)
            publish(topic_name, message, options)
          end
        else
          @failed_messages << {
            message:,
            subscriber: subscriber[:name],
            error: e.message,
            failed_at: Time.now
          }
        end

        puts "Error delivering to #{subscriber[:name]}: #{e.message}"
      end
    end

    { id: @message_id, delivered_to: delivered_count }
  end

  def get_messages(topic_name, subscriber_name, limit = 10)
    return [] unless @topic_registry.topic_exist?(topic_name)

    subscriber = @subscribers[topic_name].find { |s| s[:name] == subscriber_name }
    return [] unless subscriber

    @message_registry.filter_messages_for_topic(topic_name:, subscriber: target_subscriber, limit:)
  end

  def unsubscribe(topic_name, subscriber_name)
    return false unless @topic_registry.topic_exist?(topic_name)

    @subscribers[topic_name].delete_if { |s| s[:name] == subscriber_name }
    true
  end

  def get_stats
    stats = {}

    @topic_registry.all.each do |topic_name, topic_info|
      stats[topic_name] = {
        message_count: topic_info[:message_count],
        subscriber_count: @subscribers[topic_name].length,
        failed_count: @failed_messages.count { |f| f[:message][:topic] == topic_name }
      }
    end

    stats
  end
end
