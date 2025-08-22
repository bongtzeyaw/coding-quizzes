require 'minitest/autorun'
require_relative 'my_answer'

class ShoppingCartTest < Minitest::Test
  DEFAULT_TAX_RATE = 0.08
  DEFAULT_SHIPPING_FEE = 500
  FREE_SHIPPING_THRESHOLD = 3000
  MEMBER_DISCOUNT_RATE = 0.05

  def setup
    @cart = ShoppingCart.new
  end

  def test_initialize
    assert_equal [], @cart.get_items
    assert_equal 0, @cart.get_total
  end

  def test_add_item_new
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    assert @cart.add_item(item1)
    assert_equal 1, @cart.get_items.length
    assert_equal (1000 * 1 * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_add_item_existing
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    item2 = {id: 1, name: 'Laptop', price: 1000, quantity: 2}
    assert @cart.add_item(item2)
    assert_equal 1, @cart.get_items.length
    assert_equal 3, @cart.get_items[0][:quantity]
    # Total price (3000) hits free shipping threshold
    assert_equal (1000 * 3 * (1 + DEFAULT_TAX_RATE)), @cart.get_total
  end

  def test_add_item_invalid_quantity
    item = {id: 1, name: 'Laptop', price: 1000, quantity: 0}
    refute @cart.add_item(item)
    assert_equal 0, @cart.get_items.length
  end

  def test_remove_item_existing
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    item2 = {id: 2, name: 'Mouse', price: 20, quantity: 2}
    @cart.add_item(item1)
    @cart.add_item(item2)
    assert @cart.remove_item(1)
    assert_equal 1, @cart.get_items.length
    assert_equal (20 * 2 * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_remove_item_non_existent
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    refute @cart.remove_item(99)
    assert_equal 1, @cart.get_items.length
  end

  def test_apply_coupon_save10
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    assert @cart.apply_coupon('SAVE10')
    assert_equal (1000 * 1 * (1 - 0.1) * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_apply_coupon_save20
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    assert @cart.apply_coupon('SAVE20')
    assert_equal (1000 * 1 * (1 - 0.2) * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_apply_coupon_freeship
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    assert @cart.apply_coupon('FREESHIP')
    assert_equal (1000 * 1 * (1 + DEFAULT_TAX_RATE)), @cart.get_total
  end

  def test_apply_coupon_invalid
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    refute @cart.apply_coupon('INVALID')
    assert_equal (1000 * 1 * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_set_member_true
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    @cart.set_member(true)
    assert_equal (1000 * 1 * (1 - MEMBER_DISCOUNT_RATE) * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_set_member_false
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    @cart.add_item(item1)
    @cart.set_member(false)
    assert_equal (1000 * 1 * (1 + MEMBER_DISCOUNT_RATE) * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_calculate_total_with_shipping_fee
    item1 = {id: 1, name: 'Keyboard', price: 50, quantity: 1}
    @cart.add_item(item1)
    assert_equal (50 * 1 * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_calculate_total_without_shipping_fee
    item1 = {id: 1, name: 'TV', price: 3000, quantity: 1}
    @cart.add_item(item1)
    assert_equal (3000 * 1 * (1 + DEFAULT_TAX_RATE)), @cart.get_total
  end

  def test_calculate_total_with_multiple_discounts
    item1 = {id: 1, name: 'Monitor', price: 2000, quantity: 1}
    @cart.add_item(item1)
    @cart.apply_coupon('SAVE10')
    @cart.set_member(true)
    assert_equal (2000 * 1 * (1 - 0.1 - MEMBER_DISCOUNT_RATE) * (1 + DEFAULT_TAX_RATE)) + DEFAULT_SHIPPING_FEE, @cart.get_total
  end

  def test_get_items_after_operations
    item1 = {id: 1, name: 'Laptop', price: 1000, quantity: 1}
    item2 = {id: 2, name: 'Mouse', price: 20, quantity: 2}
    @cart.add_item(item1)
    @cart.add_item(item2)
    expected_items = [
      {id: 1, name: 'Laptop', price: 1000, quantity: 1},
      {id: 2, name: 'Mouse', price: 20, quantity: 2}
    ]
    assert_equal expected_items, @cart.get_items
  end
end
