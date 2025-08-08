# frozen_string_literal: true

class SalesRecord
  VALID_STATUSES = %w[completed cancelled].freeze
  VALID_CATEGORIES = %w[a b].freeze

  attr_reader :amount, :status, :category, :is_vip

  def initialize(amount:, status:, category:, is_vip:)
    raise ArgumentError, 'Invalid amount' unless validate_amount(amount)
    raise ArgumentError, 'Invalid status' unless validate_status(status)
    raise ArgumentError, 'Invalid category' unless validate_category(category)
    raise ArgumentError, 'Invalid is_vip' unless validate_is_vip(is_vip)

    @amount = amount
    @status = status
    @category = category
    @is_vip = is_vip
  end

  private

  def validate_amount(amount)
    amount.is_a?(Integer) && amount.positive?
  end

  def validate_status(status)
    VALID_STATUSES.include?(status)
  end

  def validate_category(category)
    VALID_CATEGORIES.include?(category)
  end

  def validate_is_vip(is_vip)
    [true, false].include?(is_vip)
  end
end

class SalesRecordCollection
  def initialize(sales_data)
    raise ArgumentError, 'Invalid sales data' unless validate_sales_data(sales_data)

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

  private

  def validate_sales_data(sales_data)
    sales_data.is_a?(Array)
  end
end

class SalesReport
  def generate_report(sales_data)
    sales_record_collection = SalesRecordCollection.new(sales_data)

    completed_sales_record_collection = sales_record_collection.filter_by(:status, 'cancelled', negation: true)
    completed_sales_amounts = completed_sales_record_collection.extract_column(:amount)

    {
      total: calculate_total_sales(completed_sales_amounts),
      average: calculate_average_sales(completed_sales_amounts),
      max: calculate_max_sales(completed_sales_amounts),
      by_category: calculate_total_sales_by_category(completed_sales_record_collection),
      vip_sales: calculate_vip_total_sales(completed_sales_record_collection)
    }
  end

  private

  def calculate_total_sales(sales_amounts)
    sales_amounts.sum
  end

  def calculate_average_sales(sales_amounts)
    sales_amounts.empty? ? 0 : sales_amounts.sum / sales_amounts.size
  end

  def calculate_max_sales(sales_amounts)
    sales_amounts.max
  end

  def calculate_total_sales_by_category(sales_record_collection)
    sales_record_collection.group_by(:category)
                           .transform_values { |sales_record_list| sales_record_list.sum(&:amount) }
  end

  def calculate_vip_total_sales(sales_record_collection)
    sales_record_collection.filter_by(:is_vip, true).extract_column(:amount).sum
  end
end
