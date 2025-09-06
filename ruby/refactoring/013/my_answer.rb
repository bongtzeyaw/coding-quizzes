class NotificationService
  def send_notification(user_id, type, data)
    user = User.find(user_id)

    if type == 'email'
      if user.email_enabled
        subject = ''
        body = ''

        if data[:event] == 'order_completed'
          subject = 'Order Completed!'
          body = "Your order ##{data[:order_id]} has been completed."
        elsif data[:event] == 'payment_received'
          subject = 'Payment Received'
          body = "We've received your payment of $#{data[:amount]}."
        elsif data[:event] == 'shipment_sent'
          subject = 'Your Order Has Shipped!'
          body = "Your order ##{data[:order_id]} is on its way."
        end

        EmailSender.send(user.email, subject, body)

        log = NotificationLog.new
        log.user_id = user_id
        log.type = 'email'
        log.event = data[:event]
        log.sent_at = Time.now
        log.save
      end
    elsif type == 'sms'
      if user.sms_enabled && user.phone
        message = ''

        if data[:event] == 'order_completed'
          message = "Order ##{data[:order_id]} completed!"
        elsif data[:event] == 'payment_received'
          message = "Payment of $#{data[:amount]} received."
        elsif data[:event] == 'shipment_sent'
          message = "Order ##{data[:order_id]} shipped!"
        end

        SmsSender.send(user.phone, message)

        log = NotificationLog.new
        log.user_id = user_id
        log.type = 'sms'
        log.event = data[:event]
        log.sent_at = Time.now
        log.save
      end
    elsif type == 'push'
      if user.push_enabled && user.device_token
        title = ''
        message = ''

        if data[:event] == 'order_completed'
          title = 'Order Completed'
          message = "Your order ##{data[:order_id]} is complete!"
        elsif data[:event] == 'payment_received'
          title = 'Payment Received'
          message = "$#{data[:amount]} payment confirmed"
        elsif data[:event] == 'shipment_sent'
          title = 'Order Shipped'
          message = "Order ##{data[:order_id]} is on the way!"
        end

        PushNotifier.send(user.device_token, title, message)

        log = NotificationLog.new
        log.user_id = user_id
        log.type = 'push'
        log.event = data[:event]
        log.sent_at = Time.now
        log.save
      end
    end
  end

  def send_bulk_notifications(user_ids, type, data)
    for i in 0..user_ids.length - 1
      send_notification(user_ids[i], type, data)
    end
  end
end
