class InventoryManager
  def initialize
    @products = {}
    @warehouses = {}
    @transactions = []
  end

  def add_product(id, name, price, warehouse_id, quantity)
    if @products[id]
      puts 'Product already exists'
      return false
    end

    @products[id] = {
      name: name,
      price: price,
      total_quantity: 0
    }

    @warehouses[warehouse_id] = {} unless @warehouses[warehouse_id]

    if @warehouses[warehouse_id][id]
      @warehouses[warehouse_id][id] += quantity
    else
      @warehouses[warehouse_id][id] = quantity
    end

    @products[id][:total_quantity] += quantity

    @transactions << {
      type: 'ADD',
      product_id: id,
      warehouse_id: warehouse_id,
      quantity: quantity,
      timestamp: Time.now
    }

    true
  end

  def transfer_stock(product_id, from_warehouse, to_warehouse, quantity)
    if !@warehouses[from_warehouse] || !@warehouses[from_warehouse][product_id]
      puts 'Product not found in source warehouse'
      return false
    end

    if @warehouses[from_warehouse][product_id] < quantity
      puts 'Insufficient stock'
      return false
    end

    @warehouses[to_warehouse] = {} unless @warehouses[to_warehouse]

    @warehouses[from_warehouse][product_id] -= quantity

    if @warehouses[to_warehouse][product_id]
      @warehouses[to_warehouse][product_id] += quantity
    else
      @warehouses[to_warehouse][product_id] = quantity
    end

    @transactions << {
      type: 'TRANSFER',
      product_id: product_id,
      from_warehouse: from_warehouse,
      to_warehouse: to_warehouse,
      quantity: quantity,
      timestamp: Time.now
    }

    true
  end

  def sell_product(product_id, warehouse_id, quantity, customer_name)
    unless @products[product_id]
      puts 'Product not found'
      return nil
    end

    if !@warehouses[warehouse_id] || !@warehouses[warehouse_id][product_id]
      puts 'Product not found in warehouse'
      return nil
    end

    if @warehouses[warehouse_id][product_id] < quantity
      puts 'Insufficient stock'
      return nil
    end

    total_price = @products[product_id][:price] * quantity

    @warehouses[warehouse_id][product_id] -= quantity
    @products[product_id][:total_quantity] -= quantity

    @transactions << {
      type: 'SALE',
      product_id: product_id,
      warehouse_id: warehouse_id,
      quantity: quantity,
      customer: customer_name,
      total_price: total_price,
      timestamp: Time.now
    }

    {
      product: @products[product_id][:name],
      quantity: quantity,
      total_price: total_price
    }
  end

  def get_inventory_report
    report = "INVENTORY REPORT\n"
    report += "================\n\n"

    @products.each do |id, product|
      report += "Product: #{product[:name]}\n"
      report += "  Total Quantity: #{product[:total_quantity]}\n"
      report += "  Price: $#{product[:price]}\n"
      report += "  Total Value: $#{product[:total_quantity] * product[:price]}\n"
      report += "  Locations:\n"

      @warehouses.each do |warehouse_id, inventory|
        report += "    #{warehouse_id}: #{inventory[id]} units\n" if inventory[id] && inventory[id] > 0
      end

      report += "\n"
    end

    report += "WAREHOUSE SUMMARY\n"
    report += "=================\n\n"

    @warehouses.each do |warehouse_id, inventory|
      total_value = 0
      total_items = 0

      inventory.each do |product_id, quantity|
        if @products[product_id] && quantity > 0
          total_value += @products[product_id][:price] * quantity
          total_items += quantity
        end
      end

      report += "Warehouse: #{warehouse_id}\n"
      report += "  Total Items: #{total_items}\n"
      report += "  Total Value: $#{total_value}\n\n"
    end

    report
  end

  def get_low_stock_alert(threshold = 10)
    alerts = []

    @products.each do |id, product|
      if product[:total_quantity] < threshold
        alerts << "LOW STOCK: #{product[:name]} - Only #{product[:total_quantity]} units remaining"
      end
    end

    alerts
  end
end
