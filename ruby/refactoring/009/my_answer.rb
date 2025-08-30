# frozen_string_literal: true

class StockManagerClient
  class << self
    def check_stock_availability(order)
      order.items.each do |item|
        stock = StockManager.check_stock(item[:product_id])

        unless item_available?(item[:quantity], stock)
          return {
            success: false,
            error: "Insufficient stock for #{item[:product_name]}"
          }
        end
      end

      { success: true }
    end

    def reduce_stock(order)
      order.items.each do |item|
        StockManager.reduce_stock(item[:product_id], item[:quantity])
      end
    end

    private

    def item_available?(requested_quantity, stock)
      requested_quantity <= stock
    end
  end
end

class EmailServiceClient
  class << self
    def send_order_confirmation_email(order)
      EmailService.send(
        to: order.customer_email,
        subject: "Order Confirmation ##{order.id}",
        body: build_order_confirmation_email(order)
      )
    end

    def send_points_obtention_notification_email(order, points)
      EmailService.send(
        to: order.customer_email,
        subject: 'Points Earned!',
        body: build_points_obtention_notification_email(points)
      )
    end

    private

    def order_details_text(order)
      order.items.map do |item|
        "- #{item[:product_name]} x#{item[:quantity]} = $#{item[:price] * item[:quantity]}\n"
      end.join
    end

    def build_order_confirmation_email(order)
      <<~BODY
        Dear #{order.customer_name},

        Your order ##{order.id} has been confirmed.

        Order details:
        #{order_details_text(order)}

        Total: $#{order.total_amount}

        Thank you for your purchase!
      BODY
    end

    def build_points_obtention_notification_email(points)
      "You've earned #{points} points from your recent purchase!"
    end
  end
end

class SlackNotifierClient
  class << self
    def notify_order_confirmation(order)
      SlackNotifier.notify('#sales', build_order_confirmation_slack_message(order))
    end

    private

    def build_order_confirmation_slack_message(order)
      "New order ##{order.id} from #{order.customer_name} - Total: $#{order.total_amount}"
    end
  end
end

class CustomerServiceClient
  def self.add_points(order, points)
    CustomerService.add_points(order.customer_id, points)
  end
end

class AnalyticsClient
  def self.track(order)
    Analytics.track('order_completed', {
                      order_id: order.id,
                      customer_id: order.customer_id,
                      total: order.total_amount,
                      items_count: order.items.count
                    })
  end
end

class ShippingServiceClient
  def self.create_shipment(order)
    ShippingService.create_shipment({
                                      order_id: order.id,
                                      address: order.shipping_address,
                                      items: order.items
                                    })
  end
end

class OrderProcessor
  def process_order(order)
    stock_availability_result = StockManagerClient.check_stock_availability(order)
    return stock_availability_result unless stock_availability_result[:success]

    StockManagerClient.reduce_stock(order)
    confirm_order!(order)

    EmailServiceClient.send_order_confirmation_email(order)

    SlackNotifierClient.notify_order_confirmation(order)

    if order_from_customer?(order)
      points = calculate_points(order)

      CustomerServiceClient.add_points(order, points)
      EmailServiceClient.send_points_obtention_notification_email(order, points)
    end

    AnalyticsClient.track(order)
    ShippingServiceClient.create_shipment(order)

    { success: true, order_id: order.id }
  end

  private

  def confirm_order!(order)
    order.status = 'confirmed'
    order.confirmed_at = Time.now
    order.save
  end

  def order_from_customer?(order)
    order.customer_id
  end

  def calculate_points(order)
    (order.total_amount * 0.01).to_i
  end
end
