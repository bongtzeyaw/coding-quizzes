# frozen_string_literal: true

require 'time'

class TimeDateParser
  def self.parse_time(str)
    Time.parse(str).utc
  rescue ArgumentError
    puts 'Warning: Unable to parse time string'
    nil
  end

  def self.parse_date(str)
    Date.parse(str)
  rescue ArgumentError
    puts 'Warning: Unable to parse date string'
    nil
  end
end

class TimeRange
  attr_reader :start_time, :duration_hours, :end_time

  def initialize(start_time:, duration_hours: nil, end_time: nil)
    @start_time = start_time.utc

    if duration_hours.nil? && end_time.nil?
      raise ArgumentError, 'Must provide either duration_hours or end_time'
    elsif duration_hours && end_time
      raise ArgumentError, 'Cannot provide both duration_hours and end_time'
    end

    if duration_hours
      @duration_hours = duration_hours
      @end_time = @start_time + (@duration_hours * 60 * 60)
    else
      @duration_hours = (end_time - start_time) / 60 * 60
      @end_time = end_time.utc
    end
  end

  def range
    @range ||= @start_time..@end_time
  end

  def overlaps?(other)
    range.overlaps?(other.range)
  end

  def includes?(time)
    range.include?(time)
  end

  def precedes?(time)
    @end_time <= time
  end
end

class EventValidator
  DURATION_MIN = 0
  DURATION_MAX = 24

  def initialize(time_range)
    @time_range = time_range
  end

  def validate
    return { error: 'Start time must be in the future' } unless future?
    return { error: "Duration must be between #{DURATION_MIN} and #{DURATION_MAX} hours" } unless valid_duration?

    { success: true }
  end

  private

  def future?
    @time_range.start_time >= Time.now.utc
  end

  def valid_duration?
    @time_range.duration_hours.between?(DURATION_MIN, DURATION_MAX)
  end
end

class EventScheduler
  def create_event(title, start_time_str, duration_hours)
    start_time = TimeDateParser.parse_time(start_time_str)
    return { error: 'Invalid time format' } unless start_time

    time_range = TimeRange.new(start_time:, duration_hours:)

    validation_result = EventValidator.new(time_range).validate
    return validation_result unless validation_result[:success]

    year = time_range.start_time.year
    month = time_range.start_time.month
    day = time_range.start_time.day
    hour = time_range.start_time.hour
    minute = time_range.start_time.min

    end_time = time_range.end_time

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
    date = TimeDateParser.parse_date(date_str)
    return { error: 'Invalid date format' } unless date

    year = date.year
    month = date.month
    day = date.day

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
