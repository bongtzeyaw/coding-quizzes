# frozen_string_literal: true

class Product
  attr_reader :id, :name, :price

  def initialize(id:, name:, price:)
    @id = id
    @name = name
    @price = price
  end
end

class ProductRepository
  def initialize
    @products = {}
  end

  def find_product_by(id)
    @products[id][:product]
  end

  def all
    @products.values
  end

  def product_found?(id)
    @products.key?(id)
  end

  def add(product:, total_quantity:)
    @products[product.id] = { product:, total_quantity: }
  end

  def reduce_total_quantity(product_id:, quantity:)
    @products[product_id][:total_quantity] -= quantity
  end
end

class InventoryManager
  def initialize
    @product_repository = ProductRepository.new

    @warehouses = {}
    @transactions = []
  end

  def add_product(id, name, price, warehouse_id, quantity)
    if @product_repository.product_found?(id)
      puts 'Product already exists'
      return false
    end

    @product_repository.add(product:, total_quantity: quantity)

    @warehouses[warehouse_id] = {} unless @warehouses[warehouse_id]

    if @warehouses[warehouse_id][id]
      @warehouses[warehouse_id][id] += quantity
    else
      @warehouses[warehouse_id][id] = quantity
    end

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
    unless @product_repository.product_found?(id)
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

    @product_repository.reduce_total_quantity(product_id:, quantity:)

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

    @product_repository.reduce_total_quantity(product_id:, quantity:)

    @product_repository.all.map do |product_detail|
      product = product_detail[:product]
      total_quantity = product_detail[:total_quantity]

      <<~CONTENT
        Product: #{product.name}
          Total Quantity: #{total_quantity}
          Price: $#{product.price}
          Total Value: $#{total_value(product, total_quantity)}
          Locations:

          #{
            @warehouses.each do |warehouse_id, inventory|
              report += "    #{warehouse_id}: #{inventory[id]} units\n" if inventory[id] && inventory[id] > 0
            end
          }
      CONTENT
    end.join("\n")

    report += "WAREHOUSE SUMMARY\n"
    report += "=================\n\n"

    @warehouses.each do |warehouse_id, inventory|
      total_value = 0
      total_items = 0

      inventory.each do |product_id, quantity|
        product = product_repository.find_product_by(product_id)

        if product && quantity > 0
          total_value += product.price * quantity
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

    product_repository.all.filter_map do |product_detail|
      product = product_detail[:product]
      quantity = product_detail[:total_quantity]

      if product[:total_quantity] < threshold
        alerts << "LOW STOCK: #{product.name} - Only #{quantity} units remaining"
      end
    end

    alerts
  end
end
