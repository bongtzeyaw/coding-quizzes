# frozen_string_literal: true

require 'time'

class TimeDateParser
  class << self
    def parse_time(str)
      Time.parse(str).utc
    rescue ArgumentError
      puts 'Warning: Unable to parse time string'
      nil
    end

    def parse_date(str)
      Date.parse(str)
    rescue ArgumentError
      puts 'Warning: Unable to parse date string'
      nil
    end
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
      @duration_hours = (end_time - start_time) / (60 * 60)
      @end_time = end_time.utc
    end
  end

  def range
    @range ||= @start_time..@end_time
  end

  def overlap?(other)
    range.overlap?(other.range)
  end

  def includes?(time)
    range.include?(time)
  end

  def precedes?(time)
    @end_time <= time
  end
end

class PredefinedHours
  class << self
    def time_range(date)
      start_time = Time.new(
        date.year,
        date.month,
        date.day,
        self::START_HOUR,
        self::START_MINUTE
      ).utc

      end_time = Time.new(
        date.year,
        date.month,
        date.day,
        self::END_HOUR,
        self::END_MINUTE
      ).utc

      TimeRange.new(start_time:, end_time:)
    end
  end
end

class BusinessHours < PredefinedHours
  START_HOUR = 9
  START_MINUTE = 0
  END_HOUR = 18
  END_MINUTE = 0
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

class EventClient
  class << self
    def all
      Event.all
    end

    def create(title, time_range)
      event = Event.new
      event.title = title
      event.start_time = time_range.start_time
      event.end_time = time_range.end_time
      event.duration = time_range.duration_hours
      event.save
      event
    end
  end
end

class ConflictChecker
  class << self
    def find_conflict(time_range:, existing_events: EventClient.all)
      existing_events.find { |event| event_overlap?(event, time_range) }
    end

    private

    def event_overlap?(event, time_range)
      event_time_range = TimeRange.new(start_time: event.start_time, end_time: event.end_time)
      time_range.overlap?(event_time_range)
    end
  end
end

class AvailableSlotFinder
  class << self
    def find(date:, slot_duration_hours:, search_range: BusinessHours.time_range(date))
      events_in_search_range = find_events(search_range)

      available_slots = []
      current_start = search_range.start_time

      events_in_search_range.each do |event|
        if slot_available_before_event?(event, current_start, slot_duration_hours)
          available_slots << create_slot(current_start, event.start_time)
        end

        current_start = event.end_time
      end

      if slot_available_before_time?(search_range.end_time, current_start, slot_duration_hours)
        available_slots << create_slot(current_start, search_range.end_time)
      end

      available_slots
    end

    private

    def find_events(time_range)
      EventClient.all.select { |event| time_range.includes?(event.start_time) }
                     .sort_by(&:start_time)
    end

    def slot_available_before_time?(time, current_start, slot_duration_hours)
      desired_time_range = TimeRange.new(
        start_time: current_start,
        duration_hours: slot_duration_hours
      )

      desired_time_range.precedes?(time)
    end

    def slot_available_before_event?(event, current_start, slot_duration_hours)
      slot_available_before_time?(event.start_time, current_start, slot_duration_hours)
    end

    def create_slot(start_time, end_time)
      { start: start_time, end: end_time }
    end
  end
end

class EventScheduler
  def create_event(title, start_time_str, duration_hours)
    start_time = TimeDateParser.parse_time(start_time_str)
    return { error: 'Invalid time format' } unless start_time

    time_range = TimeRange.new(start_time:, duration_hours:)

    validation_result = EventValidator.new(time_range).validate
    return validation_result unless validation_result[:success]

    conflict = ConflictChecker.find_conflict(time_range:)
    return { error: "Time slot conflicts with existing event: #{conflict.title}" } if conflict

    event = EventClient.create(title, time_range)

    { success: true, event: event }
  end

  def get_available_slots(date_str, slot_duration_hours)
    date = TimeDateParser.parse_date(date_str)
    return { error: 'Invalid date format' } unless date

    AvailableSlotFinder.find(date:, slot_duration_hours:)
  end
end
