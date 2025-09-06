# frozen_string_literal: true

class MessageTemplate
  def build(data)
    template = self.class::TEMPLATES[data[:event].to_sym]

    raise ArgumentError, 'No template found for event' unless template
    raise ArgumentError, 'Missing required data keys' unless required_data_keys_present?(template, data)

    interpolate(template, data)
  end

  private

  def required_data_keys_present?(template, data)
    template.all? do |_field, text_detail|
      keys = text_detail[:required_data_keys]
      keys.nil? || (keys - data.keys).empty?
    end
  end

  def interpolate(template, data)
    template.transform_values do |text_detail|
      if text_detail[:required_data_keys]
        format(text_detail[:text], data.slice(*text_detail[:required_data_keys]))
      else
        text_detail[:text]
      end
    end
  end
end

class EmailMessageTemplate < MessageTemplate
  TEMPLATES = {
    order_completed: {
      subject: {
        text: 'Order Completed!'
      },
      body: {
        text: 'Your order #%<order_id>s has been completed.',
        required_data_keys: [:order_id]
      }
    },
    payment_received: {
      subject: {
        text: 'Payment Received'
      },
      body: {
        text: "We've received your payment of $%<amount>s.",
        required_data_keys: [:amount]
      }
    },
    shipment_sent: {
      subject: {
        text: 'Your Order Has Shipped!'
      },
      body: {
        text: 'Your order #%<order_id>s is on its way.',
        required_data_keys: [:order_id]
      }
    }
  }.freeze
end

class SmsMessageTemplate < MessageTemplate
  TEMPLATES = {
    order_completed: {
      message: {
        text: 'Order #%<order_id>s completed!',
        required_data_keys: [:order_id]
      }
    },
    payment_received: {
      message: {
        text: 'Payment of $%<amount>s received.',
        required_data_keys: [:amount]
      }
    },
    shipment_sent: {
      message: {
        text: 'Order #%<order_id>s shipped!',
        required_data_keys: [:order_id]
      }
    }
  }.freeze
end

class PushMessageTemplate < MessageTemplate
  TEMPLATES = {
    order_completed: {
      title: {
        text: 'Order Completed'
      },
      message: {
        text: 'Your order #%<order_id>s is complete!',
        required_data_keys: [:order_id]
      }
    },
    payment_received: {
      title: {
        text: 'Payment Received'
      },
      message: {
        text: '$%<amount>s payment confirmed',
        required_data_keys: [:amount]
      }
    },
    shipment_sent: {
      title: {
        text: 'Order Shipped'
      },
      message: {
        text: 'Order #%<order_id>s is on the way!',
        required_data_keys: [:order_id]
      }
    }
  }.freeze
end

class MessageTemplateDispatcher
  TEMPLATES_BY_CHANNEL = {
    email: EmailMessageTemplate,
    sms: SmsMessageTemplate,
    push: PushMessageTemplate
  }.freeze

  def self.dispatch(channel_type:)
    template_class = TEMPLATES_BY_CHANNEL[channel_type.to_sym]
    raise ArgumentError, 'No template found for channel type' unless template_class

    template_class.new
  end
end

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

  def message_template
    MessageTemplateDispatcher.dispatch(channel_type: self.class::TYPE)
  end

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

    template = message_template.build(data)

    deliver(email: user.email, subject: template[:subject], body: template[:body])
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

    template = message_template.build(data)

    deliver(phone: user.phone, message: template[:message])
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

    template = message_template.build(data)

    deliver(device_token: user.device_token, title: template[:title], message: template[:message])
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
