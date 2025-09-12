require 'minitest/autorun'
require_relative 'my_answer'

# Define stubbed service classes so tests don't raise NameError
module StockManager
  def self.check_stock(_id); end
  def self.reduce_stock(_id, _qty); end
end

module EmailService
  def self.send(**_args); end
end

module SlackNotifier
  def self.notify(_channel, _message); end
end

module CustomerService
  def self.add_points(_customer_id, _points); end
end

module Analytics
  def self.track(_event, _data); end
end

module ShippingService
  def self.create_shipment(_data); end
end

class OrderProcessorTest < Minitest::Test
  class FakeOrder
    attr_accessor :status, :confirmed_at
    attr_reader :items, :id, :customer_name, :customer_email,
                :total_amount, :shipping_address, :customer_id

    def initialize
      @items = [{ product_id: 1, product_name: 'Widget', quantity: 2, price: 10 }]
      @id = 123
      @customer_name = 'Alice'
      @customer_email = 'alice@example.com'
      @total_amount = 20
      @shipping_address = '123 Main St'
      @customer_id = 42
      @saved = false
    end

    def save
      @saved = true
    end

    def saved?
      @saved
    end
  end

  def setup
    @order = FakeOrder.new
    @processor = OrderProcessor.new
  end

  def test_process_order_success
    StockManager.stub :check_stock, 5 do
      StockManager.stub :reduce_stock, true do
        EmailService.stub :send, true do
          SlackNotifier.stub :notify, true do
            CustomerService.stub :add_points, true do
              Analytics.stub :track, true do
                ShippingService.stub :create_shipment, true do
                  result = @processor.process_order(@order)

                  assert result[:success]
                  assert_equal 123, result[:order_id]
                  assert_equal 'confirmed', @order.status
                  assert @order.saved?
                end
              end
            end
          end
        end
      end
    end
  end

  def test_process_order_insufficient_stock
    StockManager.stub :check_stock, 1 do
      result = @processor.process_order(@order)

      refute result[:success]
      assert_match(/Insufficient stock/, result[:error])
    end
  end

  def test_process_order_guest_customer_skips_points
    guest_order = FakeOrder.new
    guest_order.instance_variable_set(:@customer_id, nil)

    StockManager.stub :check_stock, 5 do
      StockManager.stub :reduce_stock, true do
        CustomerService.stub :add_points, ->(*_args) { flunk 'Should not be called' } do
          EmailService.stub :send, true do
            SlackNotifier.stub :notify, true do
              Analytics.stub :track, true do
                ShippingService.stub :create_shipment, true do
                  result = @processor.process_order(guest_order)

                  assert result[:success]
                  assert_equal 123, result[:order_id]
                end
              end
            end
          end
        end
      end
    end
  end
end
