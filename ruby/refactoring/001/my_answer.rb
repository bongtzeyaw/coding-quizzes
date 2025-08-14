# frozen_string_literal: true

require 'date'

class RoomDetail
  ROOM_DETAIL_MAP = {
    1 => {
      name: 'Single room',
      price: 8_000.00
    },
    2 => {
      name: 'Double room',
      price: 12_000.00
    },
    3 => {
      name: 'Suite',
      price: 20_000.00
    }
  }.freeze

  def initialize(room_type)
    raise ArgumentError, 'Invalid room type' unless valid_room?(room_type)

    @room_type = room_type
  end

  def room_name
    ROOM_DETAIL_MAP[@room_type][:name]
  end

  def base_price
    ROOM_DETAIL_MAP[@room_type][:price]
  end

  private

  def valid_room?(room_type)
    ROOM_DETAIL_MAP.keys.include?(room_type)
  end
end

class ReservationSystem
  DEFAULT_SEASONAL_RATE = 1.00
  AUGUST_SEASONAL_RATE = 1.50
  DEFAULT_DISCOUNT_RATE = 1.00
  GUEST_DISCOUNT_RATE = 0.90

  MIN_RESERVATION_YEAR = 2024

  def check_reservation(user, room_type, date)
    return 'error' if user.nil?
    return 'error' unless valid_date?(date)

    room_detail = RoomDetail.new(room_type)
    room_name = room_detail.room_name
    final_price = apply_rate(room_detail.base_price, date, user)

    "#{room_name} reserved for #{date}. Price: #{format('%.2f', final_price)}"
  rescue ArgumentError
    'error'
  end

  private

  def parse_date(date)
    Date.strptime(date, '%Y-%m-%d')
  end

  def valid_date?(date)
    parsed_date = parse_date(date)
    parsed_date.year >= MIN_RESERVATION_YEAR
  rescue ArgumentError
    false
  end

  def apply_rate(base_price, date, user)
    parsed_date = parse_date(date)
    august_surcharge = parsed_date.month == 8 ? AUGUST_SEASONAL_RATE : DEFAULT_SEASONAL_RATE
    guest_discount = user[0] == 'G' ? GUEST_DISCOUNT_RATE : DEFAULT_DISCOUNT_RATE

    base_price * august_surcharge * guest_discount
  end
end
