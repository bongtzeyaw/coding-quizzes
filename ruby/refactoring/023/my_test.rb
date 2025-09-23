require 'minitest/autorun'
require_relative 'my_answer'

class MessageQueueTest < Minitest::Test
  def setup
    @queue = MessageQueue.new
  end

  def test_create_topic
    assert @queue.create_topic('test-topic')
    assert_equal false, @queue.create_topic('test-topic')

    topic_with_options = @queue.create_topic('options-topic', max_retries: 5, retention_period: 3600)
    assert topic_with_options
  end

  def test_subscribe
    @queue.create_topic('test-topic')

    handler = ->(message, attributes) {}
    assert @queue.subscribe('test-topic', 'subscriber1', &handler)

    assert_equal false, @queue.subscribe('test-topic', 'subscriber1', &handler)
    assert_equal false, @queue.subscribe('non-existent-topic', 'subscriber2', &handler)

    filter = { region: 'us-east' }
    assert @queue.subscribe('test-topic', 'subscriber2', filter, &handler)
  end

  def test_publish
    @queue.create_topic('test-topic')

    messages_received = []
    handler = ->(message, attributes) { messages_received << { message: message, attributes: attributes } }
    @queue.subscribe('test-topic', 'subscriber1', &handler)

    result = @queue.publish('test-topic', 'Hello World')
    assert_equal 1, result[:id]
    assert_equal 1, result[:delivered_to]
    assert_equal 1, messages_received.length
    assert_equal 'Hello World', messages_received[0][:message]

    assert_nil @queue.publish('non-existent-topic', 'Failed message')

    filter = { region: 'us-east' }
    @queue.subscribe('test-topic', 'filtered-sub', filter, &handler)

    result = @queue.publish('test-topic', 'Filtered message', attributes: { region: 'us-west' })
    assert_equal 1, result[:delivered_to]

    result = @queue.publish('test-topic', 'Matching message', attributes: { region: 'us-east' })
    assert_equal 2, result[:delivered_to]

    result = @queue.publish('test-topic', 'Async message', async: true)
    sleep(1.0)
    assert_equal 1, result[:delivered_to]
  end

  def test_get_messages
    @queue.create_topic('test-topic')

    handler = ->(message, attributes) {}
    @queue.subscribe('test-topic', 'subscriber1', &handler)

    assert_equal [], @queue.get_messages('test-topic', 'subscriber1')

    5.times do |i|
      @queue.publish('test-topic', "Message #{i}")
    end

    messages = @queue.get_messages('test-topic', 'subscriber1')
    assert_equal 5, messages.length
    assert_equal 'Message 4', messages[0][:content]

    messages = @queue.get_messages('test-topic', 'subscriber1', 2)
    assert_equal 2, messages.length

    assert_equal [], @queue.get_messages('non-existent-topic', 'subscriber1')
    assert_equal [], @queue.get_messages('test-topic', 'non-existent-subscriber')

    filter = { region: 'us-east' }
    @queue.subscribe('test-topic', 'filtered-sub', filter, &handler)

    @queue.publish('test-topic', 'Filtered message', attributes: { region: 'us-east' })
    @queue.publish('test-topic', 'Non-matching', attributes: { region: 'us-west' })

    messages = @queue.get_messages('test-topic', 'filtered-sub')
    assert_equal 1, messages.length
    assert_equal 'Filtered message', messages[0][:content]
  end

  def test_unsubscribe
    @queue.create_topic('test-topic')

    handler = ->(message, attributes) {}
    @queue.subscribe('test-topic', 'subscriber1', &handler)

    assert @queue.unsubscribe('test-topic', 'subscriber1')
    assert_equal false, @queue.unsubscribe('non-existent-topic', 'subscriber1')

    assert @queue.subscribe('test-topic', 'subscriber1', &handler)
    @queue.unsubscribe('test-topic', 'subscriber1')

    messages_received = []
    @queue.subscribe('test-topic', 'subscriber2') { |msg, _| messages_received << msg }
    @queue.publish('test-topic', 'Test message')

    assert_equal 1, messages_received.length
  end

  def test_get_stats
    @queue.create_topic('topic1')
    @queue.create_topic('topic2')

    stats = @queue.get_stats
    assert_equal 0, stats['topic1'][:message_count]
    assert_equal 0, stats['topic1'][:subscriber_count]
    assert_equal 0, stats['topic1'][:failed_count]

    handler = ->(message, attributes) {}
    @queue.subscribe('topic1', 'sub1', &handler)
    @queue.subscribe('topic1', 'sub2', &handler)
    @queue.subscribe('topic2', 'sub3', &handler)

    stats = @queue.get_stats
    assert_equal 2, stats['topic1'][:subscriber_count]
    assert_equal 1, stats['topic2'][:subscriber_count]

    @queue.publish('topic1', 'Test message 1')
    @queue.publish('topic1', 'Test message 2')
    @queue.publish('topic2', 'Test message 3')

    stats = @queue.get_stats
    assert_equal 2, stats['topic1'][:message_count]
    assert_equal 1, stats['topic2'][:message_count]
  end

  def test_error_handling_and_retries
    @queue.create_topic('test-topic', max_retries: 2)

    error_count = 0
    handler = lambda { |_message, _attributes|
      error_count += 1
      raise 'Simulated failure'
    }

    @queue.subscribe('test-topic', 'failing-subscriber', &handler)

    result = @queue.publish('test-topic', 'Will fail')
    assert_equal 0, result[:delivered_to]

    assert error_count.positive?
  end

  def test_retention_period
    @queue.create_topic('test-topic', retention_period: 60)

    handler = ->(message, attributes) {}
    @queue.subscribe('test-topic', 'subscriber1', &handler)

    @queue.publish('test-topic', 'Message 1')
    @queue.publish('test-topic', 'Message 2')

    messages = @queue.get_messages('test-topic', 'subscriber1')
    assert_equal 2, messages.length
    assert_equal 'Message 2', messages[0][:content]
    assert_equal 'Message 1', messages[1][:content]
  end
end
