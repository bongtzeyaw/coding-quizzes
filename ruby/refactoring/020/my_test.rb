require 'minitest/autorun'
require_relative 'my_answer'

class TestInventoryManager < Minitest::Test
  def setup
    @manager = InventoryManager.new
    @manager.add_product(1, 'Apple', 2, 'W1', 50)
  end

  def test_add_product_success_new_product_new_warehouse
    expected_result = true
    result = @manager.add_product(2, 'Banana', 1, 'W2', 30)
    assert_equal expected_result, result
  end

  def test_add_product_success_existing_warehouse_new_product
    expected_result = true
    result = @manager.add_product(3, 'Mango', 3, 'W1', 10)
    assert_equal expected_result, result
  end

  def test_add_product_failure_existing_product
    expected_result = false
    result = @manager.add_product(1, 'Apple', 2, 'W1', 10)
    assert_equal expected_result, result
  end

  def test_transfer_stock_success_new_warehouse
    expected_result = true
    result = @manager.transfer_stock(1, 'W1', 'W2', 20)
    assert_equal expected_result, result
  end

  def test_transfer_stock_success_existing_warehouse_with_same_product
    @manager.add_product(2, 'Banana', 1, 'W2', 10)
    @manager.transfer_stock(1, 'W1', 'W2', 5)
    expected_quantity = 5
    result = @manager.instance_variable_get(:@warehouses)['W2'][1]
    assert_equal expected_quantity, result
  end

  def test_transfer_stock_failure_product_not_found
    expected_result = false
    result = @manager.transfer_stock(99, 'W1', 'W2', 10)
    assert_equal expected_result, result
  end

  def test_transfer_stock_failure_no_source_warehouse
    expected_result = false
    result = @manager.transfer_stock(1, 'W99', 'W2', 10)
    assert_equal expected_result, result
  end

  def test_transfer_stock_failure_insufficient_stock
    expected_result = false
    result = @manager.transfer_stock(1, 'W1', 'W2', 999)
    assert_equal expected_result, result
  end

  def test_sell_product_success
    expected_result = {
      product: 'Apple',
      quantity: 10,
      total_price: 20
    }
    result = @manager.sell_product(1, 'W1', 10, 'John')
    assert_equal expected_result, result
  end

  def test_sell_product_failure_product_not_exists
    expected_result = nil
    result = @manager.sell_product(99, 'W1', 10, 'John')
    assert_equal expected_result, result
  end

  def test_sell_product_failure_product_not_in_warehouse
    @manager.add_product(2, 'Banana', 1, 'W2', 5)
    expected_result = nil
    result = @manager.sell_product(2, 'W1', 1, 'John')
    assert_equal expected_result, result
  end

  def test_sell_product_failure_insufficient_stock
    expected_result = nil
    result = @manager.sell_product(1, 'W1', 999, 'John')
    assert_equal expected_result, result
  end

  def test_get_inventory_report_single_product
    report = @manager.get_inventory_report
    expected_report = <<~HEREDOC
      INVENTORY REPORT
      ================

      Product: Apple
        Total Quantity: 50
        Price: $2
        Total Value: $100
        Locations:
          W1: 50 units

      WAREHOUSE SUMMARY
      =================

      Warehouse: W1
        Total Items: 50
        Total Value: $100

    HEREDOC
    assert_equal expected_report, report
  end

  def test_get_inventory_report_multiple_products
    @manager.add_product(2, 'Banana', 1, 'W1', 10)
    report = @manager.get_inventory_report
    expected_report = <<~HEREDOC
      INVENTORY REPORT
      ================

      Product: Apple
        Total Quantity: 50
        Price: $2
        Total Value: $100
        Locations:
          W1: 50 units

      Product: Banana
        Total Quantity: 10
        Price: $1
        Total Value: $10
        Locations:
          W1: 10 units

      WAREHOUSE SUMMARY
      =================

      Warehouse: W1
        Total Items: 60
        Total Value: $110

    HEREDOC
    assert_equal expected_report, report
  end

  def test_get_low_stock_alert_triggered
    @manager.add_product(3, 'Orange', 1, 'W1', 5)
    alerts = @manager.get_low_stock_alert(10)
    expected_alerts = ['LOW STOCK: Orange - Only 5 units remaining']
    assert_equal expected_alerts, alerts
  end

  def test_get_low_stock_alert_none
    result = @manager.get_low_stock_alert(1)
    expected_result = []
    assert_equal expected_result, result
  end

  def test_get_low_stock_alert_multiple
    manager = InventoryManager.new
    manager.add_product(1, 'Kiwi', 2, 'W1', 3)
    manager.add_product(2, 'Lemon', 1, 'W1', 2)
    alerts = manager.get_low_stock_alert(5)
    expected_alerts = [
      'LOW STOCK: Kiwi - Only 3 units remaining',
      'LOW STOCK: Lemon - Only 2 units remaining'
    ]
    assert_equal expected_alerts, alerts
  end
end
