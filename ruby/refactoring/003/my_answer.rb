# frozen_string_literal: true

class SalesReport
  def generate_report(sales_data)
    completed_sales_records = filter_completed_sales_records(sales_data)
    completed_sales_amounts = extract_amount(completed_sales_records)

    {
      total: calculate_total_sales(completed_sales_amounts),
      average: calculate_average_sales(completed_sales_amounts),
      max: calculate_max_sales(completed_sales_amounts),
      by_category: calculate_total_sales_by_category(completed_sales_records),
      vip_sales: calculate_vip_total_sales(completed_sales_records)
    }
  end

  private

  def filter_completed_sales_records(sales_records)
    sales_records.filter { |record| record[:status] != 'cancelled' }
  end

  def extract_amount(sales_records)
    sales_records.map { |record| record[:amount]}
  end

  def calculate_total_sales(sales_amounts)
    sales_amounts.sum
  end

  def calculate_average_sales(sales_amounts)
    sales_amounts.empty? ? 0 : sales_amounts.sum / sales_amounts.size
  end

  def calculate_max_sales(sales_amounts)
    sales_amounts.max
  end

  def calculate_total_sales_by_category(sales_records)
    sales_records
      .group_by { |record| record[:category] }
      .transform_values do |category_sales_records|
        category_sales_amounts = extract_amount(category_sales_records)
        calculate_total_sales(category_sales_amounts)
      end
  end

  def calculate_vip_total_sales(sales_records)
    vip_sales_records = sales_records.filter { |record| record[:is_vip] }
    vip_sales_amounts = extract_amount(vip_sales_records)
    calculate_total_sales(vip_sales_amounts)
  end
end
