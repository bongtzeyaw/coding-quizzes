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
    raise NotImplementedError, "#{self.class} must implement #calculate_rate"
  end
end

class CategoryDiscount < Discount
  DISCOUNT_RULES = {
    'electronics' => { 5 => 0.15, 3 => 0.10 },
    'books' => { 10 => 0.20, 5 => 0.10 },
    'clothing' => { 3 => 0.25 }
  }.freeze

  def initialize(category, quantity)
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
    { start_date: Time.new(2024, 12, 1).utc, end_date: Time.new(2024, 12, 31).utc, categories: %w[electronics toys],
      rate: 0.20 },
    { start_date: Time.new(2024, 11, 24).utc, end_date: Time.new(2024, 11, 27).utc, categories: nil, rate: 0.30 }
  ].freeze

  def initialize(product)
    @product = product
    @now = Time.now.utc
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
    @product = product
    @customer = customer
  end

  private

  def eligible?
    @customer.cart&.length.positive?
  end

  def calculate_rate
    category_count = @customer.cart.count { |item| item.category == @product.category }
    applicable_discounts = DISCOUNT_RULES.select { |min_qty, _rate| category_count >= min_qty }

    applicable_discounts[applicable_discounts.keys.max] || 0
  end
end

class PricingStrategy
  MINIMUM_MARGIN_RATE = 1.1

  def initialize(product, quantity, customer)
    @product = product
    @quantity = quantity
    @customer = customer
  end

  def calculate_price
    discounted_price = apply_discounts(base_price)
    adjusted_discounted_price = ensure_min_price(discounted_price)
    round_price(adjusted_discounted_price)
  end

  private

  def base_price
    @product.price * @quantity
  end

  def discounts
    [
      CategoryDiscount.new(@product.category, @quantity),
      CustomerRankDiscount.new(@customer),
      SeasonalDiscount.new(@product),
      CategoryBulkDiscount.new(@product, @customer)
    ]
  end

  def apply_discounts(price)
    discounts.reduce(price) do |current_price, discount|
      current_price * (1 - discount.rate)
    end
  end

  def ensure_min_price(price)
    min_price = @product.cost * MINIMUM_MARGIN_RATE
    [price, min_price].max
  end

  def round_price(price)
    (price * 100).round / 100.0
  end
end

class PricingCalculator
  def calculate_price(product, quantity, customer)
    return if product.nil? || quantity <= 0 || customer.nil?

    pricing_strategy = PricingStrategy.new(product, quantity, customer)
    pricing_strategy.calculate_price
  end
end
