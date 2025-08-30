class OrderProcessor
  def process_order(order)
    order.items.each do |item|
      stock = StockManager.check_stock(item[:product_id])
      return { success: false, error: "Insufficient stock for #{item[:product_name]}" } if stock < item[:quantity]
    end

    order.items.each do |item|
      StockManager.reduce_stock(item[:product_id], item[:quantity])
    end

    order.status = 'confirmed'
    order.confirmed_at = Time.now
    order.save

    email_body = "Dear #{order.customer_name},\n\nYour order ##{order.id} has been confirmed.\n\nOrder details:\n"
    order.items.each do |item|
      email_body += "- #{item[:product_name]} x#{item[:quantity]} = $#{item[:price] * item[:quantity]}\n"
    end
    email_body += "\nTotal: $#{order.total_amount}\n\nThank you for your purchase!"

    EmailService.send(
      to: order.customer_email,
      subject: "Order Confirmation ##{order.id}",
      body: email_body
    )

    slack_message = "New order ##{order.id} from #{order.customer_name} - Total: $#{order.total_amount}"
    SlackNotifier.notify('#sales', slack_message)

    if order.customer_id
      points = (order.total_amount * 0.01).to_i
      CustomerService.add_points(order.customer_id, points)

      EmailService.send(
        to: order.customer_email,
        subject: 'Points Earned!',
        body: "You've earned #{points} points from your recent purchase!"
      )
    end

    Analytics.track('order_completed', {
                      order_id: order.id,
                      customer_id: order.customer_id,
                      total: order.total_amount,
                      items_count: order.items.count
                    })

    ShippingService.create_shipment({
                                      order_id: order.id,
                                      address: order.shipping_address,
                                      items: order.items
                                    })

    { success: true, order_id: order.id }
  end
end
