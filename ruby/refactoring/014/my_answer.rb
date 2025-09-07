class PricingCalculator
  def calculate_price(product, quantity, customer)
    base_price = product.price * quantity

    discount = 0
    if product.category == 'electronics'
      if quantity >= 5
        discount = 0.15
      elsif quantity >= 3
        discount = 0.10
      end
    elsif product.category == 'books'
      if quantity >= 10
        discount = 0.20
      elsif quantity >= 5
        discount = 0.10
      end
    elsif product.category == 'clothing'
      discount = 0.25 if quantity >= 3
    end

    price_after_category_discount = base_price * (1 - discount)

    customer_discount = 0
    if customer.rank == 'gold'
      customer_discount = 0.10
    elsif customer.rank == 'silver'
      customer_discount = 0.05
    elsif customer.rank == 'bronze'
      customer_discount = 0.03
    end

    price_after_customer_discount = price_after_category_discount * (1 - customer_discount)

    if Time.now >= Time.new(2024, 12, 1) && Time.now <= Time.new(2024, 12, 31)
      price_after_customer_discount *= 0.80 if %w[electronics toys].include?(product.category)
    elsif Time.now >= Time.new(2024, 11, 24) && Time.now <= Time.new(2024, 11, 27)
      price_after_customer_discount *= 0.70
    end

    if customer.cart && customer.cart.length > 0
      category_count = 0
      for i in 0..customer.cart.length - 1
        category_count += 1 if customer.cart[i].category == product.category
      end

      price_after_customer_discount *= 0.90 if category_count >= 3
    end

    min_price = product.cost * 1.1
    price_after_customer_discount = min_price if price_after_customer_discount < min_price

    (price_after_customer_discount * 100).round / 100.0
  end
end
