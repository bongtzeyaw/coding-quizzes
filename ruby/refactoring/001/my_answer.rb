require 'date'

class ReservationSystem
  ROOM_TYPE_NAME_BASE_PRICE = {
    1 => {room_name: "Single room", base_price: 8000},
    2 => {room_name: "Double room", base_price: 12000},
    3 => {room_name: "Suite", base_price: 20000}
  }

  def check_reservation(user, room_type, date)
    return 'error' if user.nil?
    return 'error' unless [1, 2, 3].include?(room_type)
    return 'error' unless check_date(date)
    
    parsed_date = Date.strptime(date, '%Y-%m-%d')

    base_price = ROOM_TYPE_NAME_BASE_PRICE[room_type][:base_price]
    room_name = ROOM_TYPE_NAME_BASE_PRICE[room_type][:room_name]

    "#{room_name} reserved for #{date}. Price: #{apply_rate(base_price, parsed_date, user)}"
  end

  private

  def check_date(date)
    parsed_date = Date.strptime(date, '%Y-%m-%d')
    parsed_date.year >= 2024
  rescue ArgumentError
    false
  end

  def apply_rate(price, parsed_date, user)
    price *= 1.5 if parsed_date.month == 8
    price *= 0.9 if user[0] == 'G'
    price
  end
end
