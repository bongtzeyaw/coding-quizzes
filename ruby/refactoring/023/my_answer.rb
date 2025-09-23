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
    @mutex = Mutex.new
  end

  def register(topic_name:)
    @messages[topic_name] = []
  end

  def create_entry(topic:, message:)
    @mutex.synchronize do
      @messages[topic.name] << message
      topic.message_count += 1
    end
  end

  def generate_id
    @message_id += 1
  end

  def cleanup_expired(topic_name:, retention_period:)
    @mutex.synchronize do
      @messages[topic_name].delete_if { |message| message.expired?(retention_period) }
    end
  end

  def filter_messages_for_topic(topic_name:, subscriber:, limit:)
    filtered_messages = (@messages[topic_name] || []).select { |message| subscriber.filter_pass_for_message?(message) }
    filtered_messages.sort_by(&:published_at).reverse.take(limit)
  end
end

class Subscriber
  attr_reader :name
  attr_accessor :message_count, :error_count

  def initialize(name:, filter:, handler:)
    @name = name
    @filter = filter
    @handler = handler
    @subscribed_at = Time.now.utc
    @message_count = 0
    @error_count = 0
  end

  def filter_pass_for_message?(message)
    return true unless @filter

    @filter.all? { |key, value| message.attributes[key] == value }
  end

  def handle(message)
    @handler.call(message.content, message.attributes)
  end
end

class SubscriberRegistry
  def initialize
    @subscribers = {}
    @mutex = Mutex.new
  end

  def find(topic_name:, subscriber_name:)
    subscriber = @subscribers[topic_name]&.find { |subscriber| subscriber.name == subscriber_name }
    raise "Subscriber not found: #{subscriber_name} for topic: #{topic_name}" unless subscriber

    subscriber
  end

  def register_topic(topic_name:)
    @subscribers[topic_name] = []
  end

  def register_subscriber_for_topic(topic_name:, subscriber:)
    @mutex.synchronize do
      @subscribers[topic_name] << subscriber
    end
  end

  def subscriber_exist?(topic_name:, subscriber_name:)
    @subscribers[topic_name]&.any? { |subscriber| subscriber.name == subscriber_name } || false
  end

  def filter_subscribers_for_topic(topic_name:, message:)
    (@subscribers[topic_name] || []).select { |subscriber| subscriber.filter_pass_for_message?(message) }
  end

  def delete_subscriber_for_topic(topic_name:, subscriber_name:)
    @mutex.synchronize do
      @subscribers[topic_name].delete_if { |subscriber| subscriber.name == subscriber_name }
    end
  end

  def count_subscribers_for_topic(topic_name:)
    @subscribers[topic_name]&.length || 0
  end
end

class Validator
  private

  def failure_result(info)
    { success: false, info: info }
  end

  def topic_exists_in_topic_registry?(topic_registry, topic_name)
    topic_registry.topic_exist?(topic_name)
  end

  def subscriber_exists_in_subscriber_registry?(subscriber_registry, topic_name, subscriber_name)
    subscriber_registry.subscriber_exist?(topic_name:, subscriber_name:)
  end
end

class TopicCreationValidator < Validator
  def initialize(topic_registry:)
    @topic_registry = topic_registry
  end

  def validate(topic_name)
    return failure_result("Topic already exists: #{topic_name}") if topic_exists_in_topic_registry?(@topic_registry,
                                                                                                    topic_name)

    { success: true }
  end
end

class SubscriptionValidator < Validator
  def initialize(topic_registry:, subscriber_registry:)
    @topic_registry = topic_registry
    @subscriber_registry = subscriber_registry
  end

  def validate(topic_name, subscriber_name)
    return failure_result("Topic not found: #{topic_name}") unless topic_exists_in_topic_registry?(@topic_registry,
                                                                                                   topic_name)

    return failure_result("Subscriber already exists: #{subscriber_name}") if subscriber_exists_in_subscriber_registry?(
      @subscriber_registry, topic_name, subscriber_name
    )

    { success: true }
  end
end

class TopicPublicationValidator < Validator
  def initialize(topic_registry:)
    @topic_registry = topic_registry
  end

  def validate(topic_name)
    return failure_result("Topic not found: #{topic_name}") unless topic_exists_in_topic_registry?(@topic_registry,
                                                                                                   topic_name)

    { success: true }
  end
end

class MessagesObtentionValidator < Validator
  def initialize(topic_registry:, subscriber_registry:)
    @topic_registry = topic_registry
    @subscriber_registry = subscriber_registry
  end

  def validate(topic_name, subscriber_name)
    return failure_result("Topic not found: #{topic_name}") unless topic_exists_in_topic_registry?(@topic_registry,
                                                                                                   topic_name)

    return failure_result("Subscriber not found: #{subscriber_name}") unless subscriber_exists_in_subscriber_registry?(
      @subscriber_registry, topic_name, subscriber_name
    )

    { success: true }
  end
end

class UnsubscriptionValidator < Validator
  def initialize(topic_registry:)
    @topic_registry = topic_registry
  end

  def validate(topic_name)
    return failure_result("Topic not found: #{topic_name}") unless topic_exists_in_topic_registry?(@topic_registry,
                                                                                                   topic_name)

    { success: true }
  end
end

class DeliveryStrategy
  def initialize(message)
    @message = message
  end

  def with_strategy
    raise NotImplementedError, "#{self.class} must implement #with_strategy"
  end
end

class SyncDeliveryStrategy < DeliveryStrategy
  def with_strategy
    yield
  end
end

class AsyncDeliveryStrategy < DeliveryStrategy
  def with_strategy
    Thread.new do
      sleep(delay_factor)
      yield
    end
  end

  private

  def delay_factor
    0.1 * (10 - @message.priority)
  end
end

class DeliveryStrategyDispatcher
  def self.dispatch(options_async)
    options_async ? AsyncDeliveryStrategy : SyncDeliveryStrategy
  end
end

class DeliveryExecutor
  def initialize(strategy:, subscribers:, message:)
    @strategy = strategy
    @subscribers = subscribers
    @message = message
    @delivered_count = 0
  end

  def execute
    @subscribers.each do |subscriber|
      with_retry_attempt(subscriber) do
        @strategy.with_strategy do
          subscriber.handle(@message)
        end

        subscriber.message_count += 1
        @delivered_count += 1
      end
    end

    { success: true, delivered_count: @delivered_count }
  end

  private

  def retriable?
    @message.under_retry_limit?
  end

  def handle_failure(error, subscriber)
    failed_message = {
      message: @message,
      subscriber: subscriber.name,
      error: error.message,
      failed_at: Time.now.utc
    }

    { success: false, failed_message: }
  end

  def retry_delivery(error)
    @message.retry_count += 1
    @message.last_error = error.message

    Thread.new do
      sleep(@message.retry_count * 2)
      execute
    end
  end

  def with_retry_attempt(subscriber)
    yield
  rescue StandardError => e
    subscriber.error_count += 1

    handle_failure(e, subscriber) unless retriable?

    retry_delivery(e)

    puts "Error delivering to #{subscriber.name}: #{e.message}"

    { success: false }
  end
end

class DeliveryService
  def initialize
    @failed_messages = []
    @mutex = Mutex.new
  end

  def deliver(message:, subscribers:, options: {})
    strategy_class = DeliveryStrategyDispatcher.dispatch(options[:async])
    strategy = strategy_class.new(message)

    executor = DeliveryExecutor.new(strategy:, subscribers:, message:)
    result = executor.execute

    handle_failure(result) unless result[:success]

    result
  end

  def count_failed_messages_for_topic(topic_name:)
    @failed_messages.count { |m| m[:message].topic.name == topic_name }
  end

  private

  def handle_failure(result)
    @mutex.synchronize do
      @failed_messages << result[:failed_message]
    end
  end
end

class StatisticsCollector
  def initialize(topic_registry:, subscriber_registry:, delivery_service:)
    @topic_registry = topic_registry
    @subscriber_registry = subscriber_registry
    @delivery_service = delivery_service
  end

  def collect
    @topic_registry.all.each_with_object({}) do |topic, stats|
      stats[topic.name] = {
        message_count: topic.message_count,
        subscriber_count: @subscriber_registry.count_subscribers_for_topic(topic_name: topic.name),
        failed_count: @delivery_service.count_failed_messages_for_topic(topic_name: topic.name)
      }
    end
  end
end

class MessageQueue
  def initialize
    @topic_registry = TopicRegistry.new
    @message_registry = MessageRegistry.new
    @subscriber_registry = SubscriberRegistry.new
    @delivery_service = DeliveryService.new
  end

  def create_topic(topic_name, options = {})
    validator = TopicCreationValidator.new(topic_registry: @topic_registry)
    validation_result = validator.validate(topic_name)

    unless validation_result[:success]
      puts validation_result[:info]
      return false
    end

    topic = Topic.new(
      name: topic_name,
      max_retries: options[:max_retries],
      retention_period: options[:retention_period]
    )

    @topic_registry.register(topic)

    @message_registry.register(topic_name:)
    @subscriber_registry.register_topic(topic_name:)

    true
  end

  def subscribe(topic_name, subscriber_name, filter = nil, &handler)
    validator = SubscriptionValidator.new(topic_registry: @topic_registry, subscriber_registry: @subscriber_registry)
    validation_result = validator.validate(topic_name, subscriber_name)

    unless validation_result[:success]
      puts validation_result[:info]
      return false
    end

    subscriber = Subscriber.new(
      name: subscriber_name,
      filter: filter,
      handler: handler
    )

    @subscriber_registry.register_subscriber_for_topic(topic_name:, subscriber:)

    true
  end

  def publish(topic_name, message, options = {})
    validator = TopicPublicationValidator.new(topic_registry: @topic_registry)
    validation_result = validator.validate(topic_name)

    unless validation_result[:success]
      puts validation_result[:info]
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

    target_subscribers = @subscriber_registry.filter_subscribers_for_topic(topic_name:, message:)
    result = @delivery_service.deliver(message:, subscribers: target_subscribers, options:)

    return nil unless result[:success]

    { id: message_id, delivered_to: result[:delivered_count] }
  end

  def get_messages(topic_name, subscriber_name, limit = 10)
    validator = MessagesObtentionValidator.new(topic_registry: @topic_registry,
                                               subscriber_registry: @subscriber_registry)
    validation_result = validator.validate(topic_name, subscriber_name)

    return [] unless validation_result[:success]

    target_subscriber = @subscriber_registry.find(topic_name:, subscriber_name:)
    @message_registry.filter_messages_for_topic(topic_name:, subscriber: target_subscriber, limit:)
  end

  def unsubscribe(topic_name, subscriber_name)
    validator = UnsubscriptionValidator.new(topic_registry: @topic_registry)
    validation_result = validator.validate(topic_name)

    return false unless validation_result[:success]

    @subscriber_registry.delete_subscriber_for_topic(topic_name:, subscriber_name:)
    true
  end

  def get_stats
    StatisticsCollector.new(
      topic_registry: @topic_registry,
      subscriber_registry: @subscriber_registry,
      delivery_service: @delivery_service
    ).collect
  end
end
