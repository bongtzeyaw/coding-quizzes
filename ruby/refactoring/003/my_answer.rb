# frozen_string_literal: true

class SalesReport
  def generate_report(sales_data)
    non_cancelled_sales = filter_non_cancelled_sales(sales_data)

    {
      total: calculate_total_sales(non_cancelled_sales),
      average: calculate_average_sales(non_cancelled_sales),
      max: calculate_max_sales(non_cancelled_sales),
      by_category: calculate_total_sales_by_category(non_cancelled_sales),
      vip_sales: calculate_vip_total_sales(non_cancelled_sales)
    }
  end

  private

  def filter_non_cancelled_sales(sales)
    sales.filter { |sale| sale[:status] != 'cancelled' }
  end

  def calculate_total_sales(sales)
    sales.map { |sale| sale[:amount] }.sum
  end

  def calculate_average_sales(sales)
    sales.empty? ? 0 : calculate_total_sales(sales) / sales.size
  end

  def calculate_max_sales(sales)
    sales.map { |sale| sale[:amount] }.max
  end

  def calculate_total_sales_by_category(sales)
    sales
      .group_by { |sale| sale[:category] }
      .transform_values { |category_sales| calculate_total_sales(category_sales) }
  end

  def calculate_vip_total_sales(sales)
    vip_sales = sales.filter { |sale| sale[:is_vip] }
    calculate_total_sales(vip_sales)
  end
end
