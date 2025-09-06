require 'minitest/autorun'
require_relative 'my_answer'

class NotificationServiceTest < Minitest::Test
  class FakeUser
    attr_accessor :id, :email, :phone, :device_token,
                  :email_enabled, :sms_enabled, :push_enabled

    def initialize(id:, email_enabled: false, sms_enabled: false, push_enabled: false)
      @id = id
      @phone = '1234567890'
      @device_token = 'device_token_123'
      @email = 'user@example.com'
      @email_enabled = email_enabled
      @sms_enabled = sms_enabled
      @push_enabled = push_enabled
    end
  end

  class FakeNotificationLog
    @@logs = []
    attr_accessor :user_id, :type, :event, :sent_at

    def save
      @@logs << self
    end

    def self.logs
      @@logs
    end

    def self.reset
      @@logs = []
    end
  end

  def setup
    @service = NotificationService.new
    FakeNotificationLog.reset
    Object.const_set(:NotificationLog, FakeNotificationLog)
    Object.const_set(:User, Class.new)
    Object.const_set(:EmailSender, Class.new)
    Object.const_set(:SmsSender, Class.new)
    Object.const_set(:PushNotifier, Class.new)
  end

  def teardown
    Object.send(:remove_const, :NotificationLog)
    Object.send(:remove_const, :User)
    Object.send(:remove_const, :EmailSender)
    Object.send(:remove_const, :SmsSender)
    Object.send(:remove_const, :PushNotifier)
  end

  def test_send_email_notification_order_completed
    user = FakeUser.new(id: 1, email_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    EmailSender.define_singleton_method(:send) do |email, subject, body|
      @sent_args = [email, subject, body]
    end

    @service.send_notification(user_id: 1, type: 'email', data: { event: 'order_completed', order_id: 42 })

    assert_equal ['user@example.com', 'Order Completed!', 'Your order #42 has been completed.'],
                 EmailSender.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'email', log.type
    assert_equal 'order_completed', log.event
  end

  def test_send_email_notification_payment_received
    user = FakeUser.new(id: 1, email_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    EmailSender.define_singleton_method(:send) do |email, subject, body|
      @sent_args = [email, subject, body]
    end

    @service.send_notification(user_id: 1, type: 'email', data: { event: 'payment_received', amount: 100 })

    assert_equal ['user@example.com', 'Payment Received', "We've received your payment of $100."],
                 EmailSender.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'email', log.type
    assert_equal 'payment_received', log.event
  end

  def test_send_email_notification_shipment_sent
    user = FakeUser.new(id: 1, email_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    EmailSender.define_singleton_method(:send) do |email, subject, body|
      @sent_args = [email, subject, body]
    end

    @service.send_notification(user_id: 1, type: 'email', data: { event: 'shipment_sent', order_id: 55 })

    assert_equal ['user@example.com', 'Your Order Has Shipped!', 'Your order #55 is on its way.'],
                 EmailSender.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'email', log.type
    assert_equal 'shipment_sent', log.event
  end

  def test_send_sms_notification_order_completed
    user = FakeUser.new(id: 2, sms_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    SmsSender.define_singleton_method(:send) do |phone, message|
      @sent_args = [phone, message]
    end

    @service.send_notification(user_id: 2, type: 'sms', data: { event: 'order_completed', order_id: 42 })

    assert_equal ['1234567890', 'Order #42 completed!'], SmsSender.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'sms', log.type
    assert_equal 'order_completed', log.event
  end

  def test_send_sms_notification_payment_received
    user = FakeUser.new(id: 2, sms_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    SmsSender.define_singleton_method(:send) do |phone, message|
      @sent_args = [phone, message]
    end

    @service.send_notification(user_id: 2, type: 'sms', data: { event: 'payment_received', amount: 100 })

    assert_equal ['1234567890', 'Payment of $100 received.'], SmsSender.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'sms', log.type
    assert_equal 'payment_received', log.event
  end

  def test_send_sms_notification_shipment_sent
    user = FakeUser.new(id: 2, sms_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    SmsSender.define_singleton_method(:send) do |phone, message|
      @sent_args = [phone, message]
    end

    @service.send_notification(user_id: 2, type: 'sms', data: { event: 'shipment_sent', order_id: 55 })

    assert_equal ['1234567890', 'Order #55 shipped!'], SmsSender.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'sms', log.type
    assert_equal 'shipment_sent', log.event
  end

  def test_send_push_notification_order_completed
    user = FakeUser.new(id: 3, push_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    PushNotifier.define_singleton_method(:send) do |token, title, message|
      @sent_args = [token, title, message]
    end

    @service.send_notification(user_id: 3, type: 'push', data: { event: 'order_completed', order_id: 42 })

    assert_equal ['device_token_123', 'Order Completed', 'Your order #42 is complete!'],
                 PushNotifier.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'push', log.type
    assert_equal 'order_completed', log.event
  end

  def test_send_push_notification_payment_received
    user = FakeUser.new(id: 3, push_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    PushNotifier.define_singleton_method(:send) do |token, title, message|
      @sent_args = [token, title, message]
    end

    @service.send_notification(user_id: 3, type: 'push', data: { event: 'payment_received', amount: 100 })

    assert_equal ['device_token_123', 'Payment Received', '$100 payment confirmed'],
                 PushNotifier.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'push', log.type
    assert_equal 'payment_received', log.event
  end

  def test_send_push_notification_shipment_sent
    user = FakeUser.new(id: 3, push_enabled: true)
    User.define_singleton_method(:find) { |_id| user }
    PushNotifier.define_singleton_method(:send) do |token, title, message|
      @sent_args = [token, title, message]
    end

    @service.send_notification(user_id: 3, type: 'push', data: { event: 'shipment_sent', order_id: 55 })

    assert_equal ['device_token_123', 'Order Shipped', 'Order #55 is on the way!'],
                 PushNotifier.instance_variable_get(:@sent_args)
    assert_equal 1, NotificationLog.logs.size
    log = NotificationLog.logs.first
    assert_equal 'push', log.type
    assert_equal 'shipment_sent', log.event
  end

  def test_send_bulk_notifications
    user1 = FakeUser.new(id: 10, email_enabled: true)
    user2 = FakeUser.new(id: 11, email_enabled: true)
    users = { 10 => user1, 11 => user2 }
    User.define_singleton_method(:find) { |id| users[id] }
    EmailSender.define_singleton_method(:send) { |*args| (@calls ||= []) << args }

    @service.send_bulk_notifications(user_ids: [10, 11], type: 'email',
                                     data: { event: 'order_completed', order_id: 99 })

    assert_equal 2, NotificationLog.logs.size
    assert_equal 2, EmailSender.instance_variable_get(:@calls).size
    assert_equal ['user@example.com', 'Order Completed!', 'Your order #99 has been completed.'],
                 EmailSender.instance_variable_get(:@calls)[0]
    assert_equal ['user@example.com', 'Order Completed!', 'Your order #99 has been completed.'],
                 EmailSender.instance_variable_get(:@calls)[1]
  end
end
