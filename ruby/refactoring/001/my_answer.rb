# frozen_string_literal: true

require 'date'

class ReservationSystem
  ROOM_TYPE_DETAILS = {
    1 => { room_name: 'Single room', base_price: 8_000.00 },
    2 => { room_name: 'Double room', base_price: 12_000.00 },
    3 => { room_name: 'Suite', base_price: 20_000.00 }
  }.freeze

  DEFAULT_SEASONAL_RATE = 1.00
  AUGUST_SEASONAL_RATE = 1.50
  DEFAULT_DISCOUNT_RATE = 1.00
  GUEST_DISCOUNT_RATE = 0.90

  MIN_RESERVATION_YEAR = 2024

  def check_reservation(user, room_type, date)
    return 'error' if user.nil?
    return 'error' unless ROOM_TYPE_DETAILS.key?(room_type)
    return 'error' unless valid_date?(date)

    room_type_details = ROOM_TYPE_DETAILS[room_type]
    parsed_date = Date.strptime(date, '%Y-%m-%d')

    room_name = room_type_details[:room_name]
    final_price = apply_rate(room_type_details[:base_price], parsed_date, user)

    "#{room_name} reserved for #{date}. Price: #{format('%.2f', final_price)}"
  end

  private

  def valid_date?(date)
    parsed_date = Date.strptime(date, '%Y-%m-%d')
    parsed_date.year >= MIN_RESERVATION_YEAR
  rescue ArgumentError
    false
  end

  def apply_rate(base_price, parsed_date, user)
    august_surcharge = parsed_date.month == 8 ? AUGUST_SEASONAL_RATE : DEFAULT_SEASONAL_RATE
    guest_discount = user[0] == 'G' ? GUEST_DISCOUNT_RATE : DEFAULT_DISCOUNT_RATE

    base_price * august_surcharge * guest_discount
  end
end
