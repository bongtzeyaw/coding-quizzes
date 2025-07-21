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

    base_price = ROOM_TYPE_NAME_BASE_PRICE[room_type][:base_price]
    room_name = ROOM_TYPE_NAME_BASE_PRICE[room_type][:room_name]

    "#{room_name} reserved for #{date}. Price: #{apply_rate(base_price, date, user)}"
  end

  private

  def check_date(date)
    date[0..3].to_i >= 2024 && date[5..6].to_i >= 1 && date[5..6].to_i <= 12 && date[8..9].to_i >= 1 && date[8..9].to_i <= 31
  end

  def apply_rate(price, date, user)
    price *= 1.5 if date[5..6] == '08'
    price *= 0.9 if user[0] == 'G'
    price
  end
end
