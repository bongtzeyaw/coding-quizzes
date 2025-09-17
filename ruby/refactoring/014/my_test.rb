require 'minitest/autorun'
require_relative 'my_answer'

class Product
  attr_accessor :price, :category, :cost

  def initialize(price:, category:, cost:)
    @price = price
    @category = category
    @cost = cost
  end
end

class Customer
  attr_accessor :rank, :cart

  def initialize(rank:, cart: [])
    @rank = rank
    @cart = cart
  end
end

class PricingCalculatorTest < Minitest::Test
  def setup
    @calculator = PricingCalculator.new
  end

  def test_electronics_discount_tier1
    product = Product.new(price: 100, category: 'electronics', cost: 50)
    customer = Customer.new(rank: 'none')
    price = @calculator.calculate_price(product, 3, customer)
    expected = 100 * 3 * (1 - 0.10)
    assert_in_delta expected, price, 0.01
  end

  def test_electronics_discount_tier2
    product = Product.new(price: 100, category: 'electronics', cost: 50)
    customer = Customer.new(rank: 'silver')
    price = @calculator.calculate_price(product, 5, customer)
    expected = 100 * 5 * (1 - 0.15) * (1 - 0.05)
    assert_in_delta expected, price, 0.01
  end

  def test_books_discount_tier1
    product = Product.new(price: 20, category: 'books', cost: 10)
    customer = Customer.new(rank: 'none')
    price = @calculator.calculate_price(product, 5, customer)
    expected = 20 * 5 * (1 - 0.10)
    assert_in_delta expected, price, 0.01
  end

  def test_books_discount_tier2
    product = Product.new(price: 20, category: 'books', cost: 10)
    customer = Customer.new(rank: 'gold')
    price = @calculator.calculate_price(product, 10, customer)
    expected = 20 * 10 * (1 - 0.20) * (1 - 0.10)
    assert_in_delta expected, price, 0.01
  end

  def test_clothing_discount
    product = Product.new(price: 50, category: 'clothing', cost: 30)
    customer = Customer.new(rank: 'bronze')
    price = @calculator.calculate_price(product, 3, customer)
    expected = 50 * 3 * (1 - 0.25) * (1 - 0.03)
    assert_in_delta expected, price, 0.01
  end

  def test_no_category_discount
    product = Product.new(price: 40, category: 'toys', cost: 20)
    customer = Customer.new(rank: 'none')
    price = @calculator.calculate_price(product, 2, customer)
    expected = 40 * 2
    assert_in_delta expected, price, 0.01
  end

  def test_customer_discount_gold
    product = Product.new(price: 100, category: 'toys', cost: 50)
    customer = Customer.new(rank: 'gold')
    price = @calculator.calculate_price(product, 1, customer)
    expected = 100 * (1 - 0.10)
    assert_in_delta expected, price, 0.01
  end

  def test_customer_discount_silver
    product = Product.new(price: 100, category: 'toys', cost: 50)
    customer = Customer.new(rank: 'silver')
    price = @calculator.calculate_price(product, 1, customer)
    expected = 100 * (1 - 0.05)
    assert_in_delta expected, price, 0.01
  end

  def test_customer_discount_bronze
    product = Product.new(price: 100, category: 'toys', cost: 50)
    customer = Customer.new(rank: 'bronze')
    price = @calculator.calculate_price(product, 1, customer)
    expected = 100 * (1 - 0.03)
    assert_in_delta expected, price, 0.01
  end

  def test_cart_bulk_discount
    product = Product.new(price: 100, category: 'electronics', cost: 70)
    cart = [product, product, product]
    customer = Customer.new(rank: 'gold', cart: cart)
    price = @calculator.calculate_price(product, 1, customer)
    expected = 100 * (1 - 0.10) * 0.90
    assert_in_delta expected, price, 0.01
  end

  def test_minimum_price_enforced
    product = Product.new(price: 1, category: 'books', cost: 10)
    customer = Customer.new(rank: 'gold')
    price = @calculator.calculate_price(product, 1, customer)
    expected = product.cost * 1.1
    assert_equal expected, price
  end

  def test_seasonal_discount_december_for_electronics
    product = Product.new(price: 100, category: 'electronics', cost: 50)
    customer = Customer.new(rank: 'none')
    Time.stub :now, Time.new(2024, 12, 10) do
      price = @calculator.calculate_price(product, 1, customer)
      expected = 100 * 0.80
      assert_in_delta expected, price, 0.01
    end
  end

  def test_seasonal_discount_december_for_toys
    product = Product.new(price: 100, category: 'toys', cost: 50)
    customer = Customer.new(rank: 'none')
    Time.stub :now, Time.new(2024, 12, 20) do
      price = @calculator.calculate_price(product, 1, customer)
      expected = 100 * 0.80
      assert_in_delta expected, price, 0.01
    end
  end

  def test_seasonal_discount_black_friday
    product = Product.new(price: 200, category: 'books', cost: 50)
    customer = Customer.new(rank: 'none')
    Time.stub :now, Time.new(2024, 11, 25) do
      price = @calculator.calculate_price(product, 1, customer)
      expected = 200 * 0.70
      assert_in_delta expected, price, 0.01
    end
  end
end
