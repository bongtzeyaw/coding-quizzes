class EventScheduler
  def create_event(title, start_time_str, duration_hours)
    year = start_time_str[0..3].to_i
    month = start_time_str[5..6].to_i
    day = start_time_str[8..9].to_i
    hour = start_time_str[11..12].to_i
    minute = start_time_str[14..15].to_i

    start_time = Time.new(year, month, day, hour, minute)
    end_time = start_time + (duration_hours * 3600)

    return { error: 'Start time must be in the future' } if start_time < Time.now

    return { error: 'Duration must be between 0 and 24 hours' } if duration_hours <= 0 || duration_hours > 24

    existing_events = Event.all
    for i in 0..existing_events.length - 1
      event = existing_events[i]
      event_start = event.start_time
      event_end = event.end_time

      if (start_time >= event_start && start_time < event_end) ||
         (end_time > event_start && end_time <= event_end) ||
         (start_time <= event_start && end_time >= event_end)
        return { error: "Time slot conflicts with existing event: #{event.title}" }
      end
    end

    event = Event.new
    event.title = title
    event.start_time = start_time
    event.end_time = end_time
    event.duration = duration_hours
    event.save

    { success: true, event: event }
  end

  def get_available_slots(date_str, slot_duration_hours)
    year = date_str[0..3].to_i
    month = date_str[5..6].to_i
    day = date_str[8..9].to_i

    start_of_day = Time.new(year, month, day, 9, 0)
    end_of_day = Time.new(year, month, day, 18, 0)

    events_on_day = []
    all_events = Event.all
    for i in 0..all_events.length - 1
      event = all_events[i]
      events_on_day << event if event.start_time >= start_of_day && event.start_time < end_of_day
    end

    for i in 0..events_on_day.length - 1
      for j in i + 1..events_on_day.length - 1
        next unless events_on_day[i].start_time > events_on_day[j].start_time

        temp = events_on_day[i]
        events_on_day[i] = events_on_day[j]
        events_on_day[j] = temp
      end
    end

    available_slots = []
    current_time = start_of_day

    for i in 0..events_on_day.length - 1
      event = events_on_day[i]

      if current_time + (slot_duration_hours * 3600) <= event.start_time
        available_slots << {
          start: current_time,
          end: event.start_time
        }
      end

      current_time = event.end_time
    end

    if current_time + (slot_duration_hours * 3600) <= end_of_day
      available_slots << {
        start: current_time,
        end: end_of_day
      }
    end

    available_slots
  end
end
