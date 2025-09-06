# frozen_string_literal: true

class NotificationLogger
  def self.log(user_id:, channel_type:, event:)
    log = NotificationLog.new
    log.user_id = user_id
    log.type = channel_type
    log.event = event
    log.sent_at = Time.now
    log.save
  end
end

class NotificationChannel
  protected

  def log_notification(user:, data:)
    NotificationLogger.log(
      user_id: user.id,
      channel_type: self.class::TYPE.to_s,
      event: data[:event]
    )
  end
end

class EmailChannel < NotificationChannel
  TYPE = :email

  def notify(user:, data:)
    return unless user_notifiable?(user)

    subject, body =
      case data[:event]
      when 'order_completed'
        ['Order Completed!', "Your order ##{data[:order_id]} has been completed."]
      when 'payment_received'
        ['Payment Received', "We've received your payment of $#{data[:amount]}."]
      when 'shipment_sent'
        ['Your Order Has Shipped!', "Your order ##{data[:order_id]} is on its way."]
      end

    deliver(email: user.email, subject:, body:)
    log_notification(user:, data:)
  end

  private

  def user_notifiable?(user)
    user.email_enabled
  end

  def deliver(email:, subject:, body:)
    EmailSender.send(
      email,
      subject,
      body
    )
  end
end

class SmsChannel < NotificationChannel
  TYPE = :sms

  def notify(user:, data:)
    return unless user_notifiable?(user)

    message =
      case data[:event]
      when 'order_completed'
        "Order ##{data[:order_id]} completed!"
      when 'payment_received'
        "Payment of $#{data[:amount]} received."
      when 'shipment_sent'
        "Order ##{data[:order_id]} shipped!"
      end

    deliver(phone: user.phone, message:)
    log_notification(user:, data:)
  end

  private

  def user_notifiable?(user)
    user.sms_enabled && user.phone
  end

  def deliver(phone:, message:)
    SmsSender.send(
      phone,
      message
    )
  end
end

class PushChannel < NotificationChannel
  TYPE = :push

  def notify(user:, data:)
    return unless user_notifiable?(user)

    title, message =
      case data[:event]
      when 'order_completed'
        ['Order Completed', "Your order ##{data[:order_id]} is complete!"]
      when 'payment_received'
        ['Payment Received', "$#{data[:amount]} payment confirmed"]
      when 'shipment_sent'
        ['Order Shipped', "Order ##{data[:order_id]} is on the way!"]
      end

    deliver(device_token: user.device_token, title:, message:)
    log_notification(user:, data:)
  end

  private

  def user_notifiable?(user)
    user.push_enabled && user.device_token
  end

  def deliver(device_token:, title:, message:)
    PushNotifier.send(
      device_token,
      title,
      message
    )
  end
end

class NotificationChannelDispatcher
  CHANNELS = {
    email: EmailChannel,
    sms: SmsChannel,
    push: PushChannel
  }.freeze

  def self.dispatch(type)
    channel_class = CHANNELS[type.to_sym]
    raise ArgumentError, 'Unknown channel type' unless channel_class

    channel_class.new
  end
end

class NotificationService
  def send_notification(user_id, type, data)
    user = User.find(user_id)

    channel = NotificationChannelDispatcher.dispatch(type)
    return unless channel

    channel.notify(user:, data:)
  end

  def send_bulk_notifications(user_ids, type, data)
    for i in 0..user_ids.length - 1
      send_notification(user_ids[i], type, data)
    end
  end
end
