require 'minitest/autorun'
require_relative 'my_answer'

class TestSalesReport < Minitest::Test
  def setup
    @sales_report = SalesReport.new
  end

  def test_generate_report_with_mixed_data
    sales_data = [
      { amount: 1, status: 'completed', category: 'a', is_vip: true },
      { amount: 2, status: 'completed', category: 'b', is_vip: false },
      { amount: 3, status: 'cancelled', category: 'a', is_vip: true },
      { amount: 4, status: 'completed', category: 'a', is_vip: false },
      { amount: 5, status: 'completed', category: 'b', is_vip: true }
    ]
    report = @sales_report.generate_report(sales_data)

    assert_equal 12, report[:total]
    assert_equal 3, report[:average]
    assert_equal 5, report[:max]
    assert_equal({ 'a' => 5, 'b' => 7 }, report[:by_category])
    assert_equal 6, report[:vip_sales]
  end

  def test_generate_report_with_no_sales_data
    sales_data = []
    report = @sales_report.generate_report(sales_data)

    assert_equal 0, report[:total]
    assert_equal 0, report[:average]
    assert_nil report[:max]
    assert_empty report[:by_category]
    assert_equal 0, report[:vip_sales]
  end

  def test_generate_report_with_all_sales_cancelled
    sales_data = [
      { amount: 1, status: 'cancelled', category: 'a', is_vip: true },
      { amount: 2, status: 'cancelled', category: 'b', is_vip: false }
    ]
    report = @sales_report.generate_report(sales_data)

    assert_equal 0, report[:total]
    assert_equal 0, report[:average]
    assert_nil report[:max]
    assert_empty report[:by_category]
    assert_equal 0, report[:vip_sales]
  end

  def test_generate_report_with_only_one_valid_sale
    sales_data = [
      { amount: 1, status: 'completed', category: 'a', is_vip: false }
    ]
    report = @sales_report.generate_report(sales_data)

    assert_equal 1, report[:total]
    assert_equal 1, report[:average]
    assert_equal 1, report[:max]
    assert_equal({ 'a' => 1 }, report[:by_category])
    assert_equal 0, report[:vip_sales]
  end

  def test_generate_report_with_multiple_sales_of_the_same_amount
    sales_data = [
      { amount: 1, status: 'completed', category: 'a', is_vip: false },
      { amount: 1, status: 'completed', category: 'a', is_vip: false }
    ]
    report = @sales_report.generate_report(sales_data)

    assert_equal 2, report[:total]
    assert_equal 1, report[:average]
    assert_equal 1, report[:max]
  end

  def test_generate_report_with_only_vip_sales
    sales_data = [
      { amount: 1, status: 'completed', category: 'a', is_vip: true },
      { amount: 2, status: 'completed', category: 'b', is_vip: true }
    ]
    report = @sales_report.generate_report(sales_data)

    assert_equal 3, report[:total]
    assert_equal 1, report[:average]
    assert_equal 2, report[:max]
    assert_equal({ 'a' => 1, 'b' => 2 }, report[:by_category])
    assert_equal 3, report[:vip_sales]
  end
end
