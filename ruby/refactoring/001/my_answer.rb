require 'date'

class ReservationSystem
  ROOM_TYPE_NAME_BASE_PRICE = {
    1 => {room_name: "Single room", base_price: 8_000.00},
    2 => {room_name: "Double room", base_price: 12_000.00},
    3 => {room_name: "Suite", base_price: 20_000.00}
  }

  def check_reservation(user, room_type, date)
    return 'error' if user.nil?
    return 'error' unless [1, 2, 3].include?(room_type)
    return 'error' unless check_date(date)
    
    parsed_date = Date.strptime(date, '%Y-%m-%d')

    room_name = ROOM_TYPE_NAME_BASE_PRICE[room_type][:room_name]
    base_price = ROOM_TYPE_NAME_BASE_PRICE[room_type][:base_price]

    final_price = apply_rate(base_price, parsed_date, user)

    "#{room_name} reserved for #{date}. Price: #{format('%.2f', final_price)}"
  end

  private

  def check_date(date)
    parsed_date = Date.strptime(date, '%Y-%m-%d')
    parsed_date.year >= 2024
  rescue ArgumentError
    false
  end

  def apply_rate(base_price, parsed_date, user)
    august_surcharge = parsed_date.month == 8 ? 1.50 : 1.00
    guest_discount = user[0] == 'G' ? 0.90 : 1.00

    base_price * august_surcharge * guest_discount
  end
end
