# frozen_string_literal: true

class Discount
  def rate
    eligible? ? calculate_rate : 0
  end

  private

  def eligible?
    raise NotImplementedError, "#{self.class} must implement #eligible?"
  end

  def calculate_rate
    raise NotImplementedError, "#{self.class} must implement #rate"
  end
end

class CategoryDiscount < Discount
  DISCOUNT_RULES = {
    'electronics' => { 5 => 0.15, 3 => 0.10 },
    'books' => { 10 => 0.20, 5 => 0.10 },
    'clothing' => { 3 => 0.25 }
  }.freeze

  def initialize(category, quantity)
    super()
    @category = category
    @quantity = quantity
  end

  private

  def eligible?
    DISCOUNT_RULES.key?(@category)
  end

  def calculate_rate
    category_discount_rule = DISCOUNT_RULES[@category]
    applicable_discounts = category_discount_rule.select { |min_qty, _rate| @quantity >= min_qty }

    applicable_discounts[applicable_discounts.keys.max] || 0
  end
end

class CustomerRankDiscount < Discount
  DISCOUNT_RULES = {
    'gold' => 0.10,
    'silver' => 0.05,
    'bronze' => 0.03
  }.freeze

  def initialize(customer)
    super()
    @customer = customer
  end

  private

  def eligible?
    DISCOUNT_RULES.key?(@customer.rank)
  end

  def calculate_rate
    DISCOUNT_RULES[@customer.rank] || 0
  end
end

class SeasonalDiscount < Discount
  DISCOUNT_RULES = [
    { start_date: Time.new(2024, 12, 1), end_date: Time.new(2024, 12, 31), categories: %w[electronics toys],
      rate: 0.20 },
    { start_date: Time.new(2024, 11, 24), end_date: Time.new(2024, 11, 27), categories: nil, rate: 0.30 }
  ].freeze

  def initialize(product, now: Time.now)
    super()
    @product = product
    @now = now
  end

  private

  def eligible?
    !!matching_rule
  end

  def calculate_rate
    matching_rule[:rate]
  end

  def matching_rule
    DISCOUNT_RULES.find do |rule|
      @now.between?(rule[:start_date], rule[:end_date]) &&
        (rule[:categories].nil? || rule[:categories].include?(@product.category))
    end
  end
end

class CategoryBulkDiscount < Discount
  DISCOUNT_RULES = {
    3 => 0.10
  }.freeze

  def initialize(product, customer)
    super()
    @product = product
    @customer = customer
  end

  private

  def eligible?
    @customer.cart&.length&.positive?
  end

  def calculate_rate
    category_count = @customer.cart.count { |item| item.category == @product.category }
    applicable_discounts = DISCOUNT_RULES.select { |min_qty, _rate| category_count >= min_qty }

    applicable_discounts[applicable_discounts.keys.max] || 0
  end
end

class PricingCalculator
  def calculate_price(product, quantity, customer)
    base_price = product.price * quantity

    discount = CategoryDiscount.new(product.category, quantity).rate

    price_after_category_discount = base_price * (1 - discount)

    customer_discount = CustomerRankDiscount.new(customer).rate

    price_after_customer_discount = price_after_category_discount * (1 - customer_discount)

    seasonal_discount = SeasonalDiscount.new(product).rate

    price_after_customer_discount *= (1 - seasonal_discount)

    category_bulk_discount = CategoryBulkDiscount.new(product, customer).rate
    price_after_customer_discount *= (1 - category_bulk_discount)

    min_price = product.cost * 1.1
    price_after_customer_discount = min_price if price_after_customer_discount < min_price

    (price_after_customer_discount * 100).round / 100.0
  end
end
