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

  def calculate_subtotal
    @items.sum { |item| item[:price] * item[:quantity] }
  end

  private

  def find(item_id)
    @items.find { |item| item[:id] == item_id }
  end
end

class ShoppingCart
  DEFAULT_TAX_RATE = 0.08
  DEFAULT_SHIPPING_FEE = 500
  FREE_SHIPPING_THRESHOLD = 3000
  MEMBER_DISCOUNT_RATE = 0.05

  def initialize
    @items_collection = ItemCollection.new([])
    @discount = 0
    @tax_rate = DEFAULT_TAX_RATE
    @shipping_fee = 0
    @is_member = false
    @coupon_code = nil
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
    if code == 'SAVE10'
      @coupon_code = code
      @discount = 0.1
    elsif code == 'SAVE20'
      @coupon_code = code
      @discount = 0.2
    elsif code == 'FREESHIP'
      @coupon_code = code
      @shipping_fee = 0
    else
      return false
    end
    true
  end

  def set_member(is_member)
    @is_member = is_member
    @discount = if @is_member
                  @discount + MEMBER_DISCOUNT_RATE
                else
                  @discount - MEMBER_DISCOUNT_RATE
                end
    calculate_total
  end

  def calculate_total
    subtotal = 0
    items = get_items
    for i in 0..items.length - 1
      subtotal += (items[i][:price] * items[i][:quantity])
    end

    discount_amount = subtotal * @discount
    after_discount = subtotal - discount_amount

    tax = after_discount * @tax_rate

    if @coupon_code != 'FREESHIP'
      @shipping_fee = if subtotal < FREE_SHIPPING_THRESHOLD
                        DEFAULT_SHIPPING_FEE
                      else
                        0
                      end
    end

    after_discount + tax + @shipping_fee
  end

  def get_total
    calculate_total
  end

  def get_items
    @items_collection.items
  end
end
