# frozen_string_literal: true

class SalesReport
  def generate_report(sales_data)
    completed_sales_records = filter_completed_sales_records(sales_data)

    {
      total: calculate_total_sales(completed_sales_records),
      average: calculate_average_sales(completed_sales_records),
      max: calculate_max_sales(completed_sales_records),
      by_category: calculate_total_sales_by_category(completed_sales_records),
      vip_sales: calculate_vip_total_sales(completed_sales_records)
    }
  end

  private

  def filter_completed_sales_records(sales_records)
    sales_records.filter { |record| record[:status] != 'cancelled' }
  end

  def calculate_total_sales(sales_records)
    sales_records.map { |record| record[:amount]}.sum
  end

  def calculate_average_sales(sales_records)
    sales_records.empty? ? 0 : calculate_total_sales(sales_records) / sales_records.size
  end

  def calculate_max_sales(sales_records)
    sales_records.map { |record| record[:amount]}.max
  end

  def calculate_total_sales_by_category(sales_records)
    sales_records
      .group_by { |record| record[:category] }
      .transform_values { |category_sales_records| calculate_total_sales(category_sales_records) }
  end

  def calculate_vip_total_sales(sales_records)
    vip_sales_records = sales_records.filter { |record| record[:is_vip] }
    calculate_total_sales(vip_sales_records)
  end
end
