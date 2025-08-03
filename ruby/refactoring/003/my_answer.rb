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

  def filter_by(attribute, value, negation: false)
    filtered_sales_records = @sales_records.filter do |sales_record|
      if negation
        sales_record.public_send(attribute) != value
      else
        sales_record.public_send(attribute) == value
      end
    end

    SalesRecordCollection.new(
      filtered_sales_records.map do |sales_record|
        {
          amount: sales_record.amount,
          status: sales_record.status,
          category: sales_record.category,
          is_vip: sales_record.is_vip
        }
      end
    )
  end

  def extract_column(attribute)
    @sales_records.map { |sales_record| sales_record.public_send(attribute) }
  end

  def group_by(attribute)
    @sales_records.group_by { |sales_record| sales_record.public_send(attribute) }
  end
end

class SalesReport
  def generate_report(sales_data)
    sales_record_collection = SalesRecordCollection.new(sales_data)
    completed_sales_record_collection = sales_record_collection.filter_by(:status, 'cancelled', negation: true)
    completed_sales_amounts = completed_sales_record_collection.extract_column(:amount)

    total_sales = completed_sales_amounts.sum
    average_sales = completed_sales_amounts.empty? ? 0 : total_sales / completed_sales_amounts.size
    max_sales = completed_sales_amounts.max
    sales_by_category = calculate_sales_by_category(completed_sales_record_collection)
    vip_sales = completed_sales_record_collection.filter_by(:is_vip, true).extract_column(:amount).sum

    {
      total: total_sales,
      average: average_sales,
      max: max_sales,
      by_category: sales_by_category,
      vip_sales: vip_sales
    }
  end

  private

  def calculate_sales_by_category(sales_record_collection)
    sales_record_collection.group_by(:category)
                           .transform_values { |sales_record_list| sales_record_list.sum(&:amount) }
  end
end
