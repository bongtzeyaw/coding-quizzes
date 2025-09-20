require 'minitest/autorun'
require_relative 'my_answer'

class TestInventoryManager < Minitest::Test
  def setup
    @manager = InventoryManager.new
  end

  def test_add_product_success_new_product_new_warehouse
    result = @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    assert result

    warehouse_repository = @manager.instance_variable_get(:@warehouse_repository)
    warehouse1 = warehouse_repository.find(1)
    product1_stock_count = warehouse1.stock(1)

    assert_equal 10, product1_stock_count
  end

  def test_add_product_success_existing_warehouse_new_product
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.add_product(id: 2, name: 'Product 2', price: 2, warehouse_id: 1, quantity: 20)
    assert result

    warehouse_repository = @manager.instance_variable_get(:@warehouse_repository)
    warehouse1 = warehouse_repository.find(1)
    product1_stock_count = warehouse1.stock(1)
    product2_stock_count = warehouse1.stock(2)

    assert_equal 10, product1_stock_count
    assert_equal 20, product2_stock_count
  end

  def test_add_product_failure_existing_product
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    refute result
  end

  def test_transfer_stock_success_new_warehouse
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.transfer_stock(product_id: 1, from_warehouse_id: 1, to_warehouse_id: 2, quantity: 3)
    assert result

    warehouse_repository = @manager.instance_variable_get(:@warehouse_repository)
    warehouse1 = warehouse_repository.find(1)
    warehouse2 = warehouse_repository.find(2)
    warehouse1_product1_stock_count = warehouse1.stock(1)
    warehouse2_product1_stock_count = warehouse2.stock(1)

    assert_equal (10 - 3), warehouse1_product1_stock_count
    assert_equal 3, warehouse2_product1_stock_count
  end

  def test_transfer_stock_success_existing_warehouse
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    @manager.add_product(id: 2, name: 'Product 2', price: 1, warehouse_id: 2, quantity: 20)
    result = @manager.transfer_stock(product_id: 1, from_warehouse_id: 1, to_warehouse_id: 2, quantity: 3)
    assert result

    warehouse_repository = @manager.instance_variable_get(:@warehouse_repository)
    warehouse1 = warehouse_repository.find(1)
    warehouse2 = warehouse_repository.find(2)
    warehouse1_product1_stock_count = warehouse1.stock(1)
    warehouse2_product1_stock_count = warehouse2.stock(1)

    assert_equal (10 - 3), warehouse1_product1_stock_count
    assert_equal 3, warehouse2_product1_stock_count
  end

  def test_transfer_stock_failure_product_not_found
    original_stdout = $stdout
    $stdout = StringIO.new

    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.transfer_stock(product_id: -1, from_warehouse_id: 1, to_warehouse_id: 2, quantity: 3)
    refute result

    assert_includes $stdout.string, 'Product not found in source warehouse'
  end

  def test_transfer_stock_failure_no_source_warehouse
    original_stdout = $stdout
    $stdout = StringIO.new

    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.transfer_stock(product_id: 1, from_warehouse_id: -1, to_warehouse_id: 2, quantity: 3)
    refute result

    assert_includes $stdout.string, 'Product not found in source warehouse'
  end

  def test_transfer_stock_failure_insufficient_stock
    original_stdout = $stdout
    $stdout = StringIO.new

    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.transfer_stock(product_id: 1, from_warehouse_id: 1, to_warehouse_id: 2, quantity: 11)
    refute result

    assert_includes $stdout.string, 'Insufficient stock'
  end

  def test_sell_product_success
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    expected_result = {
      product: 'Product 1',
      quantity: 3,
      total_price: 3 * 1
    }
    result = @manager.sell_product(product_id: 1, warehouse_id: 1, quantity: 3, customer_name: 'Customer 1')
    assert_equal expected_result, result

    warehouse_repository = @manager.instance_variable_get(:@warehouse_repository)
    warehouse1 = warehouse_repository.find(1)
    warehouse1_product1_stock_count = warehouse1.stock(1)

    assert_equal (10 - 3), warehouse1_product1_stock_count
  end

  def test_sell_product_failure_product_not_exists
    original_stdout = $stdout
    $stdout = StringIO.new

    result = @manager.sell_product(product_id: -1, warehouse_id: 1, quantity: 3, customer_name: 'Customer 1')
    assert_nil result

    assert_includes $stdout.string, 'Product not found'
  end

  def test_sell_product_failure_product_not_in_warehouse
    original_stdout = $stdout
    $stdout = StringIO.new

    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.sell_product(product_id: 1, warehouse_id: 2, quantity: 3, customer_name: 'Customer 1')
    assert_nil result

    assert_includes $stdout.string, 'Product not found in warehouse'
  end

  def test_sell_product_failure_insufficient_stock
    original_stdout = $stdout
    $stdout = StringIO.new

    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    result = @manager.sell_product(product_id: 1, warehouse_id: 1, quantity: 11, customer_name: 'Customer 1')
    assert_nil result

    assert_includes $stdout.string, 'Insufficient stock'
  end

  def test_get_inventory_report_single_product_single_warehouse
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    report = @manager.get_inventory_report
    expected_report = <<~HEREDOC
      INVENTORY REPORT
      =================

      Product: Product 1
        Total Quantity: 10
        Price: $1
        Total Value: $10
        Locations:

          1: 10 units

      WAREHOUSE REPORT
      =================

      Warehouse: 1
        Total Items: 10
        Total Value: $10

    HEREDOC
    assert_equal expected_report, report
  end

  def test_get_inventory_report_multiple_products_single_warehouse
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    @manager.add_product(id: 2, name: 'Product 2', price: 2, warehouse_id: 1, quantity: 20)
    report = @manager.get_inventory_report
    expected_report = <<~HEREDOC
      INVENTORY REPORT
      =================

      Product: Product 1
        Total Quantity: 10
        Price: $1
        Total Value: $10
        Locations:

          1: 10 units

      Product: Product 2
        Total Quantity: 20
        Price: $2
        Total Value: $40
        Locations:

          1: 20 units

      WAREHOUSE REPORT
      =================

      Warehouse: 1
        Total Items: 30
        Total Value: $50

    HEREDOC
    assert_equal expected_report, report
  end

  def test_get_inventory_report_multiple_products_multiple_warehouse
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 10)
    @manager.add_product(id: 2, name: 'Product 2', price: 2, warehouse_id: 1, quantity: 20)
    @manager.add_product(id: 3, name: 'Product 3', price: 3, warehouse_id: 2, quantity: 30)

    report = @manager.get_inventory_report
    expected_report = <<~HEREDOC
      INVENTORY REPORT
      =================

      Product: Product 1
        Total Quantity: 10
        Price: $1
        Total Value: $10
        Locations:

          1: 10 units

      Product: Product 2
        Total Quantity: 20
        Price: $2
        Total Value: $40
        Locations:

          1: 20 units

      Product: Product 3
        Total Quantity: 30
        Price: $3
        Total Value: $90
        Locations:

          2: 30 units

      WAREHOUSE REPORT
      =================

      Warehouse: 1
        Total Items: 30
        Total Value: $50

      Warehouse: 2
        Total Items: 30
        Total Value: $90

    HEREDOC
    assert_equal expected_report, report
  end

  def test_get_low_stock_alert_triggered
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 5)
    alerts = @manager.get_low_stock_alert(threshold: 10)
    expected_alerts = ['LOW STOCK: Product 1 - Only 5 units remaining']
    assert_equal expected_alerts, alerts
  end

  def test_get_low_stock_alert_none
    @manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 5)
    result = @manager.get_low_stock_alert(threshold: 1)
    expected_result = []
    assert_equal expected_result, result
  end

  def test_get_low_stock_alert_multiple
    manager = InventoryManager.new
    manager.add_product(id: 1, name: 'Product 1', price: 1, warehouse_id: 1, quantity: 3)
    manager.add_product(id: 2, name: 'Product 2', price: 1, warehouse_id: 1, quantity: 2)
    alerts = manager.get_low_stock_alert(threshold: 5)
    expected_alerts = [
      'LOW STOCK: Product 1 - Only 3 units remaining',
      'LOW STOCK: Product 2 - Only 2 units remaining'
    ]
    assert_equal expected_alerts, alerts
  end
end
