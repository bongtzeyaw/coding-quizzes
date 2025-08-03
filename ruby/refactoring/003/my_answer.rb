# frozen_string_literal: true

class SalesRecord
  VALID_STATUSES = %w[completed cancelled].freeze
  VALID_CATEGORIES = %w[a b].freeze

  attr_reader :amount, :status, :category, :is_vip

  def initialize(amount:, status:, category:, is_vip:)
    raise ArgumentError, 'Invalid amount' unless amount.is_a?(Integer) && amount.positive?
    raise ArgumentError, 'Invalid status' unless VALID_STATUSES.include?(status)
    raise ArgumentError, 'Invalid category' unless VALID_CATEGORIES.include?(category)
    raise ArgumentError, 'Invalid is_vip' unless [true, false].include?(is_vip)

    @amount = amount
    @status = status
    @category = category
    @is_vip = is_vip
  end
end

class SalesRecordCollection
  def initialize(sales_data)
    raise ArgumentError, 'Invalid sales data' unless sales_data.is_a?(Array)

    @sales_records = sales_data.map { |sales_record_data| SalesRecord.new(**sales_record_data) }
  end
end

class SalesReport
  def generate_report(sales_data)
    result = {}

    sales_record_collection = SalesRecordCollection.new(sales_data)

    total = 0
    for i in 0..sales_data.length - 1
      total += sales_data[i][:amount] if sales_data[i][:status] != 'cancelled'
    end
    result[:total] = total

    count = 0
    for i in 0..sales_data.length - 1
      count += 1 if sales_data[i][:status] != 'cancelled'
    end
    result[:average] = if count > 0
                         total / count
                       else
                         0
                       end

    max = nil
    for i in 0..sales_data.length - 1
      next unless sales_data[i][:status] != 'cancelled'

      max = sales_data[i][:amount] if max.nil? || sales_data[i][:amount] > max
    end
    result[:max] = max

    categories = {}
    for i in 0..sales_data.length - 1
      next unless sales_data[i][:status] != 'cancelled'

      cat = sales_data[i][:category]
      categories[cat] = 0 if categories[cat].nil?
      categories[cat] = categories[cat] + sales_data[i][:amount]
    end
    result[:by_category] = categories

    vip_total = 0
    for i in 0..sales_data.length - 1
      vip_total += sales_data[i][:amount] if sales_data[i][:status] != 'cancelled' && sales_data[i][:is_vip] == true
    end
    result[:vip_sales] = vip_total

    result
  end
end
