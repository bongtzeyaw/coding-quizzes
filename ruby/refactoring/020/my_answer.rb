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

class Warehouse
  attr_reader :id

  def initialize(id)
    @id = id
    @inventory = {}
  end

  def stock(product_id)
    @inventory[product_id]
  end

  def product_found?(product_id)
    @inventory.key?(product_id)
  end

  def stock_positive?(product_id)
    @inventory[product_id]&.positive?
  end

  def sufficient_stock?(product_id:, quantity:)
    @inventory[product_id] >= quantity
  end

  def add_stock(product_id:, quantity:)
    @inventory[product_id] ||= 0
    @inventory[product_id] += quantity
  end

  def reduce_stock(product_id:, quantity:)
    @inventory[product_id] -= quantity
  end

  def total_value_and_items(product_repository)
    filtered_inventory = @inventory.filter_map do |product_id, quantity|
      product = product_repository.find_product_by(product_id)

      [product, quantity] if product && quantity.positive?
    end

    total_value = filtered_inventory.sum do |product, quantity|
      ValueCalculator.calculate_total_value(price: product.price, quantity:)
    end

    total_items = filtered_inventory.sum { |_, quantity| quantity }

    [total_value, total_items]
  end
end

class WarehouseRepository
  def initialize
    @warehouses = {}
  end

  def find(id)
    warehouse = @warehouses[id]
    raise 'Warehouse not found' unless warehouse

    warehouse
  end

  def find_or_create(id)
    @warehouses[id] ||= Warehouse.new(id)
  end

  def all
    @warehouses.values
  end

  def warehouses_with_stock(product_id)
    @warehouses.select do |_warehouse_id, warehouse|
      warehouse.stock_positive?(product_id)
    end
  end

  def product_found_in_existing_warehouse?(product_id:, warehouse_id:)
    warehouse = @warehouses[warehouse_id]
    return false unless warehouse

    warehouse.product_found?(product_id)
  end

  def sufficient_stock_in_existing_warehouse?(product_id:, warehouse_id:, quantity:)
    warehouse = @warehouses[warehouse_id]
    return false unless warehouse

    warehouse.sufficient_stock?(product_id:, quantity:)
  end

  def add_stock(product_id:, warehouse_id:, quantity:)
    warehouse = find_or_create(warehouse_id)

    warehouse.add_stock(product_id:, quantity:)
  end

  def reduce_stock(product_id:, warehouse_id:, quantity:)
    warehouse = @warehouses[warehouse_id]
    raise 'Warehouse not found' unless warehouse

    warehouse.reduce_stock(product_id:, quantity:)
  end

  def transfer_stock(product_id:, from_warehouse_id:, to_warehouse_id:, quantity:)
    from_warehouse = find(from_warehouse_id)
    to_warehouse = find_or_create(to_warehouse_id)

    from_warehouse.reduce_stock(product_id:, quantity:)
    to_warehouse.add_stock(product_id:, quantity:)
  end
end

class Transaction
  def initialize
    @timestamp = Time.now.utc
    @type = self.class::TYPE.to_s
  end

  def to_h
    raise NotImplementedError, "#{self.class} must implement #to_h"
  end
end

class ProductAdditionTransaction < Transaction
  TYPE = :ADD

  def initialize(product_id:, warehouse_id:, quantity:)
    super()
    @product_id = product_id
    @warehouse_id = warehouse_id
    @quantity = quantity
  end

  def to_h
    {
      type: @type,
      product_id: @product_id,
      warehouse_id: @warehouse_id,
      quantity: @quantity,
      timestamp: @timestamp
    }
  end
end

class StockTransferTransaction < Transaction
  TYPE = :TRANSFER

  def initialize(product_id:, from_warehouse_id:, to_warehouse_id:, quantity:)
    super()
    @product_id = product_id
    @from_warehouse_id = from_warehouse_id
    @to_warehouse_id = to_warehouse_id
    @quantity = quantity
  end

  def to_h
    {
      type: @type,
      product_id: @product_id,
      from_warehouse: @from_warehouse_id,
      to_warehouse: @to_warehouse_id,
      quantity: @quantity,
      timestamp: @timestamp
    }
  end
end

class ProductSaleTransaction < Transaction
  TYPE = :SALE

  def initialize(product_id:, warehouse_id:, quantity:, customer_name:, total_price:)
    super()
    @product_id = product_id
    @warehouse_id = warehouse_id
    @quantity = quantity
    @customer_name = customer_name
    @total_price = total_price
  end

  def to_h
    {
      type: @type,
      product_id: @product_id,
      warehouse_id: @warehouse_id,
      quantity: @quantity,
      customer: @customer_name,
      total_price: @total_price,
      timestamp: @timestamp
    }
  end
end

class TransactionLog
  def initialize
    @transactions = []
  end

  def record(transaction)
    @transactions << transaction.to_h
  end
end

class OperationResult
  attr_reader :info

  def initialize(success:, info: nil)
    @success = success
    @info = info
  end

  def success?
    @success
  end
end

class InventoryValidator
  def validate
    raise NotImplementedError, "#{self.class} must implement #validate"
  end

  protected

  def product_found_in_product_repository?(product_repository:, product_id:)
    product_repository.product_found?(product_id)
  end

  def product_found_in_existing_warehouse?(warehouse_repository:, product_id:, warehouse_id:)
    warehouse_repository.product_found_in_existing_warehouse?(product_id:, warehouse_id:)
  end

  def sufficient_stock_in_existing_warehouse?(warehouse_repository:, product_id:, warehouse_id:, quantity:)
    warehouse_repository.sufficient_stock_in_existing_warehouse?(product_id:, warehouse_id:, quantity:)
  end
end

class ProductAdditionValidator < InventoryValidator
  def initialize(product_repository:, product_id:)
    @product_repository = product_repository
    @product_id = product_id
  end

  def validate
    if product_found_in_product_repository?(
      product_repository: @product_repository,
      product_id: @product_id
    )
      return OperationResult.new(success: false, info: 'Product already exists')
    end

    OperationResult.new(success: true)
  end
end

class StockTransferValidator < InventoryValidator
  def initialize(warehouse_repository:, product_id:, from_warehouse_id:, quantity:)
    @warehouse_repository = warehouse_repository
    @product_id = product_id
    @from_warehouse_id = from_warehouse_id
    @quantity = quantity
  end

  def validate
    unless product_found_in_existing_warehouse?(
      warehouse_repository: @warehouse_repository,
      product_id: @product_id,
      warehouse_id: @from_warehouse_id
    )
      return OperationResult.new(success: false, info: 'Product not found in source warehouse')
    end

    unless sufficient_stock_in_existing_warehouse?(
      warehouse_repository: @warehouse_repository,
      product_id: @product_id,
      warehouse_id: @from_warehouse_id,
      quantity: @quantity
    )
      return OperationResult.new(success: false, info: 'Insufficient stock')
    end

    OperationResult.new(success: true)
  end
end

class ProductSaleValidator < InventoryValidator
  def initialize(product_repository:, warehouse_repository:, product_id:, warehouse_id:, quantity:)
    @product_repository = product_repository
    @warehouse_repository = warehouse_repository
    @product_id = product_id
    @warehouse_id = warehouse_id
    @quantity = quantity
  end

  def validate
    unless product_found_in_product_repository?(
      product_repository: @product_repository,
      product_id: @product_id
    )
      return OperationResult.new(success: false, info: 'Product not found')
    end

    unless product_found_in_existing_warehouse?(
      warehouse_repository: @warehouse_repository,
      product_id: @product_id,
      warehouse_id: @warehouse_id
    )
      return OperationResult.new(success: false, info: 'Product not found in warehouse')
    end

    unless sufficient_stock_in_existing_warehouse?(
      warehouse_repository: @warehouse_repository,
      product_id: @product_id,
      warehouse_id: @warehouse_id,
      quantity: @quantity
    )
      return OperationResult.new(success: false, info: 'Insufficient stock')
    end

    OperationResult.new(success: true)
  end
end

class InventoryManager
  def initialize
    @product_repository = ProductRepository.new
    @warehouse_repository = WarehouseRepository.new
    @transaction_log = TransactionLog.new
  end

  def add_product(id, name, price, warehouse_id, quantity)
    product = Product.new(
      id:,
      name:,
      price:
    )

    validator = ProductAdditionValidator.new(
      product_repository: @product_repository,
      product_id: id
    )

    validation_result = validator.validate

    unless validation_result.success?
      puts validation_result.info
      return false
    end

    @product_repository.add(product:, total_quantity: quantity)

    @warehouse_repository.add_stock(
      product_id: id,
      warehouse_id:,
      quantity:
    )

    @transaction_log.record(ProductAdditionTransaction.new(
                              product_id: id,
                              warehouse_id:,
                              quantity:
                            ))

    true
  end

  def transfer_stock(product_id, from_warehouse, to_warehouse, quantity)
    validator = StockTransferValidator.new(
      warehouse_repository: @warehouse_repository,
      product_id:,
      from_warehouse_id:,
      quantity:
    )

    validation_result = validator.validate

    unless validation_result.success?
      puts validation_result.info
      return false
    end

    @warehouse_repository.transfer_stock(
      product_id:,
      from_warehouse_id:,
      to_warehouse_id:,
      quantity:
    )

    @transaction_log.record(StockTransferTransaction.new(
                              product_id: product_id,
                              from_warehouse_id: from_warehouse_id,
                              to_warehouse_id: to_warehouse_id,
                              quantity: quantity
                            ))

    true
  end

  def sell_product(product_id, warehouse_id, quantity, customer_name)
    validator = ProductSaleValidator.new(
      product_repository: @product_repository,
      warehouse_repository: @warehouse_repository,
      product_id:,
      warehouse_id:,
      quantity:
    )

    validation_result = validator.validate

    unless validation_result.success?
      puts validation_result.info
      return nil
    end

    total_price = @products[product_id][:price] * quantity

    @warehouse_repository.reduce_stock(
      product_id: product_id,
      warehouse_id: warehouse_id,
      quantity: quantity
    )

    @product_repository.reduce_total_quantity(product_id:, quantity:)

    @transaction_log.record(ProductSaleTransaction.new(
                              product_id:,
                              warehouse_id:,
                              quantity:,
                              customer_name:,
                              total_price:
                            ))

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
            @warehouse_repository.all.each do |warehouse_id, inventory|
              report += "    #{warehouse_id}: #{inventory[id]} units\n" if inventory[id] && inventory[id] > 0
            end
          }
      CONTENT
    end.join("\n")

    report += "WAREHOUSE SUMMARY\n"
    report += "=================\n\n"

    @warehouse_repository.all.each do |warehouse_id, inventory|
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
