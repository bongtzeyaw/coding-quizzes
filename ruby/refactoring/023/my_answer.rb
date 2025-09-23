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

class MessageQueue
  def initialize
    @topic_registry = TopicRegistry.new
    @subscribers = {}
    @messages = {}
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

    @messages[topic_name] = []
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

    @message_id += 1

    message_data = {
      id: @message_id,
      topic: topic_name,
      content: message,
      priority: options[:priority] || 5,
      published_at: Time.now,
      attributes: options[:attributes] || {},
      retry_count: 0
    }

    @messages[topic_name] << message_data
    @topic_registry.find(topic_name).message_count += 1

    retention = @topic_registry.find(topic_name).retention_period
    @messages[topic_name].delete_if do |msg|
      (Time.now - msg[:published_at]) > retention
    end

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
            sleep(0.1 * (10 - message_data[:priority]))
            subscriber[:handler].call(message_data[:content], message_data[:attributes])
          end
        else
          subscriber[:handler].call(message_data[:content], message_data[:attributes])
        end

        subscriber[:message_count] += 1
        delivered_count += 1
      rescue StandardError => e
        subscriber[:error_count] += 1

        if message_data[:retry_count] < @topics[topic_name][:max_retries]
          message_data[:retry_count] += 1
          message_data[:last_error] = e.message

          Thread.new do
            sleep(message_data[:retry_count] * 2)
            publish(topic_name, message, options)
          end
        else
          @failed_messages << {
            message: message_data,
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

    filtered_messages = []
    @messages[topic_name].each do |msg|
      if subscriber[:filter]
        matched = true
        subscriber[:filter].each do |key, value|
          if msg[:attributes][key] != value
            matched = false
            break
          end
        end
        next unless matched
      end

      filtered_messages << msg
    end

    filtered_messages.sort_by { |m| m[:published_at] }.reverse.take(limit)
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
