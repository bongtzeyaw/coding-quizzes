require 'minitest/autorun'
require_relative 'my_answer'

class TestReservationSystem < Minitest::Test
  def setup
    @system = ReservationSystem.new
  end

  def test_nil_user
    assert_equal 'error', @system.check_reservation(nil, 1, '2024-01-01')
  end

  def test_invalid_year
    assert_equal 'error', @system.check_reservation('A123', 1, '2023-01-01')
  end

  def test_invalid_month
    assert_equal 'error', @system.check_reservation('A123', 1, '2024-13-01')
  end

  def test_invalid_day
    assert_equal 'error', @system.check_reservation('A123', 1, '2024-01-32')
  end

  def test_invalid_room_type
    assert_equal 'error', @system.check_reservation('A123', 4, '2024-01-01')
  end

  def test_single_room_regular_user
    expected = 'Single room reserved for 2024-01-01. Price: 8000.00'
    assert_equal expected, @system.check_reservation('A123', 1, '2024-01-01')
  end

  def test_single_room_regular_user_august_surcharge
    expected = 'Single room reserved for 2024-08-01. Price: 12000.00'
    assert_equal expected, @system.check_reservation('A123', 1, '2024-08-01')
  end

  def test_single_room_guest_user
    expected = 'Single room reserved for 2024-01-01. Price: 7200.00'
    assert_equal expected, @system.check_reservation('G123', 1, '2024-01-01')
  end

  def test_single_room_guest_user_august_surcharge
    expected = 'Single room reserved for 2024-08-01. Price: 10800.00'
    assert_equal expected, @system.check_reservation('G123', 1, '2024-08-01')
  end

  def test_double_room_regular_user
    expected = 'Double room reserved for 2024-01-01. Price: 12000.00'
    assert_equal expected, @system.check_reservation('A123', 2, '2024-01-01')
  end

  def test_double_room_regular_user_august_surcharge
    expected = 'Double room reserved for 2024-08-01. Price: 18000.00'
    assert_equal expected, @system.check_reservation('A123', 2, '2024-08-01')
  end

  def test_double_room_guest_user
    expected = 'Double room reserved for 2024-01-01. Price: 10800.00'
    assert_equal expected, @system.check_reservation('G123', 2, '2024-01-01')
  end

  def test_double_room_guest_user_august_surcharge
    expected = 'Double room reserved for 2024-08-01. Price: 16200.00'
    assert_equal expected, @system.check_reservation('G123', 2, '2024-08-01')
  end

  def test_suite_regular_user
    expected = 'Suite reserved for 2024-01-01. Price: 20000.00'
    assert_equal expected, @system.check_reservation('A123', 3, '2024-01-01')
  end

  def test_suite_regular_user_august_surcharge
    expected = 'Suite reserved for 2024-08-01. Price: 30000.00'
    assert_equal expected, @system.check_reservation('A123', 3, '2024-08-01')
  end

  def test_suite_guest_user
    expected = 'Suite reserved for 2024-01-01. Price: 18000.00'
    assert_equal expected, @system.check_reservation('G123', 3, '2024-01-01')
  end

  def test_suite_guest_user_august_surcharge
    expected = 'Suite reserved for 2024-08-01. Price: 27000.00'
    assert_equal expected, @system.check_reservation('G123', 3, '2024-08-01')
  end
end
