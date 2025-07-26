# frozen_string_literal: true

require 'date'

class RoomDetail
  VALID_ROOM_TYPES = [1, 2, 3].freeze

  def initialize(room_type)
    raise ArgumentError, 'Invalid room type' unless valid_room?(room_type)

    @room_type = room_type
  end

  def room_name
    case @room_type
    when 1 then 'Single room'
    when 2 then 'Double room'
    when 3 then 'Suite'
    else raise ArgumentError, 'Invalid room type'
    end
  end

  def base_price
    case @room_type
    when 1 then 8_000.00
    when 2 then 12_000.00
    when 3 then 20_000.00
    else raise ArgumentError, 'Invalid room type'
    end
  end

  private

  def valid_room?(room_type)
    VALID_ROOM_TYPES.include?(room_type)
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
    return 'error' unless valid_room_type?(room_type)
    return 'error' unless valid_date?(date)

    room_detail = RoomDetail.new(room_type)
    room_name = room_detail.room_name
    final_price = apply_rate(room_detail.base_price, date, user)

    "#{room_name} reserved for #{date}. Price: #{format('%.2f', final_price)}"
  end

  private

  def parse_date(date)
    Date.strptime(date, '%Y-%m-%d')
  end

  def valid_room_type?(room_type)
    RoomDetail.new(room_type)
  rescue ArgumentError
    false
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
