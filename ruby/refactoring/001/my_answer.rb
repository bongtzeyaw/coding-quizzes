class ReservationSystem
  def check_reservation(user, room_type, date)
    return 'error' if user.nil?

    if room_type == 1
      unless date[0..3].to_i >= 2024 && date[5..6].to_i >= 1 && date[5..6].to_i <= 12 && date[8..9].to_i >= 1 && date[8..9].to_i <= 31
        return 'error'
      end

      price = 8000
      price *= 1.5 if date[5..6] == '08'
      price *= 0.9 if user[0] == 'G'
      "Single room reserved for #{date}. Price: #{price}"

    elsif room_type == 2
      unless date[0..3].to_i >= 2024 && date[5..6].to_i >= 1 && date[5..6].to_i <= 12 && date[8..9].to_i >= 1 && date[8..9].to_i <= 31
        return 'error'
      end

      price = 12_000
      price *= 1.5 if date[5..6] == '08'
      price *= 0.9 if user[0] == 'G'
      "Double room reserved for #{date}. Price: #{price}"

    elsif room_type == 3
      unless date[0..3].to_i >= 2024 && date[5..6].to_i >= 1 && date[5..6].to_i <= 12 && date[8..9].to_i >= 1 && date[8..9].to_i <= 31
        return 'error'
      end

      price = 20_000
      price *= 1.5 if date[5..6] == '08'
      price *= 0.9 if user[0] == 'G'
      "Suite reserved for #{date}. Price: #{price}"

    else
      'error'
    end
  end
end
