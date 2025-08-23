# frozen_string_literal: true

class Coupon
  attr_reader :discount_rate, :free_shipping

  def initialize(code:, discount_rate:, free_shipping:)
    @code = code
    @discount_rate = discount_rate
    @free_shipping = free_shipping
  end
end

class CouponRegistry
  COUPONS = {
    'SAVE10' => Coupon.new(
      code: 'SAVE10',
      discount_rate: 0.1,
      free_shipping: false
    ),
    'SAVE20' => Coupon.new(
      code: 'SAVE20',
      discount_rate: 0.2,
      free_shipping: false
    ),
    'FREESHIP' => Coupon.new(
      code: 'FREESHIP',
      discount_rate: 0,
      free_shipping: true
    )
  }.freeze

  def self.find_by(code:)
    COUPONS[code]
  end
end

class ItemCollection
  attr_reader :items

  def initialize(items)
    @items = items
  end

  def can_add_item?(item)
    item[:quantity].positive?
  end

  def add_item!(item)
    existing_item = find(item[:id])

    if existing_item
      existing_item[:quantity] += item[:quantity]
    else
      @items << item
    end

    @items
  end

  def can_remove_item?(item_id)
    !find(item_id).nil?
  end

  def remove_item!(item_id)
    @items.reject! { |item| item[:id] == item_id }
  end

  private

  def find(item_id)
    @items.find { |item| item[:id] == item_id }
  end
end

class CheckoutTotalCalculator
  attr_writer :is_member, :coupon

  MEMBER_DISCOUNT_RATE = 0.05
  DEFAULT_TAX_RATE = 0.08
  DEFAULT_SHIPPING_FEE = 500
  FREE_SHIPPING_THRESHOLD = 3000

  def initialize(is_member:, coupon:)
    @is_member = is_member
    @coupon = coupon
  end

  def calculate(items_collection:)
    return 0 if items_collection.items.empty?

    subtotal = calculate_subtotal(items_collection)
    subtotal * discount_multiplier * tax_multiplier + shipping_fee(subtotal)
  end

  private

  def calculate_subtotal(items_collection)
    items_collection.items.sum { |item| item[:price] * item[:quantity] }
  end

  def discount_multiplier
    coupon_discount_rate = @coupon ? @coupon.discount_rate : 0

    member_discount_rate =
      case @is_member
      when true
        MEMBER_DISCOUNT_RATE
      when false
        -MEMBER_DISCOUNT_RATE
      else
        0
      end

    1 - (coupon_discount_rate + member_discount_rate)
  end

  def tax_multiplier
    1 + DEFAULT_TAX_RATE
  end

  def shipping_fee(subtotal)
    return 0 if @coupon&.free_shipping

    subtotal >= FREE_SHIPPING_THRESHOLD ? 0 : DEFAULT_SHIPPING_FEE
  end
end

class ShoppingCart
  def initialize
    @items_collection = ItemCollection.new([])
    @checkout_total_calculator = CheckoutTotalCalculator.new(
      is_member: nil,
      coupon: nil
    )
  end

  def add_item(item)
    return false unless @items_collection.can_add_item?(item)

    @items_collection.add_item!(item)
    true
  end

  def remove_item(item_id)
    return false unless @items_collection.can_remove_item?(item_id)

    @items_collection.remove_item!(item_id)
    true
  end

  def apply_coupon(code)
    coupon = CouponRegistry.find_by(code:)

    return false unless coupon

    @checkout_total_calculator.coupon = coupon
    true
  end

  def set_member(is_member)
    @checkout_total_calculator.is_member = is_member
  end

  def calculate_total
    @checkout_total_calculator.calculate(items_collection: @items_collection)
  end

  def get_total
    calculate_total
  end

  def get_items
    @items_collection.items
  end
end
