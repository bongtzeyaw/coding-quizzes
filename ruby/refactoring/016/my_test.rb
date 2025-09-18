require 'minitest/autorun'
require_relative 'my_answer'

class Event
  attr_accessor :title, :start_time, :end_time, :duration

  def save; end

  def self.all
    []
  end
end

class TestEventScheduler < Minitest::Test
  def setup
    @scheduler = EventScheduler.new
    @now = Time.new(2025, 9, 8, 14, 0)
    Time.stub :now, @now do
      Event.stub :all, [] do
        @event1 = Event.new
        @event1.title = 'Meeting'
        @event1.start_time = Time.new(2025, 9, 10, 10, 0)
        @event1.end_time = Time.new(2025, 9, 10, 11, 0)

        @event2 = Event.new
        @event2.title = 'Appointment'
        @event2.start_time = Time.new(2025, 9, 10, 15, 0)
        @event2.end_time = Time.new(2025, 9, 10, 16, 0)

        @all_events = [@event1, @event2]
      end
    end
  end

  def test_create_event_success
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        result = @scheduler.create_event('Lunch', '2025-09-10 12:00', 1.0)
        assert result[:success]
        assert_equal 'Lunch', result[:event].title
      end
    end
  end

  def test_create_event_fails_with_past_time
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        result = @scheduler.create_event('Past Event', '2025-09-07 10:00', 1.0)
        assert result[:error]
        assert_equal 'Start time must be in the future', result[:error]
      end
    end
  end

  def test_create_event_fails_with_invalid_duration
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        result = @scheduler.create_event('Long Event', '2025-09-10 10:00', 25.0)
        assert result[:error]
        assert_equal 'Duration must be between 0 and 24 hours', result[:error]
      end
    end
  end

  def test_create_event_fails_with_conflicting_time_before
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        result = @scheduler.create_event('Conflict', '2025-09-10 09:30', 2.0)
        assert result[:error]
        assert_equal 'Time slot conflicts with existing event: Meeting', result[:error]
      end
    end
  end

  def test_create_event_fails_with_conflicting_time_in_between
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        result = @scheduler.create_event('Conflict', '2025-09-10 10:30', 0.5)
        assert result[:error]
        assert_equal 'Time slot conflicts with existing event: Meeting', result[:error]
      end
    end
  end

  def test_create_event_fails_with_conflicting_time_after
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        result = @scheduler.create_event('Conflict', '2025-09-10 10:30', 1.0)
        assert result[:error]
        assert_equal 'Time slot conflicts with existing event: Meeting', result[:error]
      end
    end
  end

  def test_get_available_slots_returns_correct_slots
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        slots = @scheduler.get_available_slots('2025-09-10', 1.0)
        expected_slots = [
          { start: Time.new(2025, 9, 10, 9, 0), end: Time.new(2025, 9, 10, 10, 0) },
          { start: Time.new(2025, 9, 10, 11, 0), end: Time.new(2025, 9, 10, 15, 0) },
          { start: Time.new(2025, 9, 10, 16, 0), end: Time.new(2025, 9, 10, 18, 0) }
        ]
        assert_equal expected_slots, slots
      end
    end
  end

  def test_get_available_slots_returns_correct_slots_with_slot_starting_before_business_hours
    event1 = Event.new
    event1.title = 'Early Meeting'
    event1.start_time = Time.new(2025, 9, 10, 7, 0)
    event1.end_time = Time.new(2025, 9, 10, 11, 0)

    event2 = Event.new
    event2.title = 'Appointment'
    event2.start_time = Time.new(2025, 9, 10, 15, 0)
    event2.end_time = Time.new(2025, 9, 10, 16, 0)

    all_events = [event1, event2]

    Time.stub :now, @now do
      Event.stub :all, all_events do
        slots = @scheduler.get_available_slots('2025-09-10', 1.0)
        expected_slots = [
          { start: Time.new(2025, 9, 10, 11, 0), end: Time.new(2025, 9, 10, 15, 0) },
          { start: Time.new(2025, 9, 10, 16, 0), end: Time.new(2025, 9, 10, 18, 0) }
        ]
        assert_equal expected_slots, slots
      end
    end
  end

  def test_get_available_slots_returns_correct_slots_with_slot_ending_after_business_hours
    event1 = Event.new
    event1.title = 'Meeting'
    event1.start_time = Time.new(2025, 9, 10, 10, 0)
    event1.end_time = Time.new(2025, 9, 10, 11, 0)

    event2 = Event.new
    event2.title = 'Late appointment'
    event2.start_time = Time.new(2025, 9, 10, 17, 0)
    event2.end_time = Time.new(2025, 9, 10, 19, 0)

    all_events = [event1, event2]

    Time.stub :now, @now do
      Event.stub :all, all_events do
        slots = @scheduler.get_available_slots('2025-09-10', 1.0)
        expected_slots = [
          { start: Time.new(2025, 9, 10, 9, 0), end: Time.new(2025, 9, 10, 10, 0) },
          { start: Time.new(2025, 9, 10, 11, 0), end: Time.new(2025, 9, 10, 17, 0) }
        ]
        assert_equal expected_slots, slots
      end
    end
  end

  def test_get_available_slots_returns_empty_when_no_slots_are_long_enough
    Time.stub :now, @now do
      Event.stub :all, @all_events do
        slots = @scheduler.get_available_slots('2025-09-10', 5.0)
        assert_equal [], slots
      end
    end
  end

  def test_get_available_slots_returns_full_day_when_no_events
    Time.stub :now, @now do
      Event.stub :all, [] do
        slots = @scheduler.get_available_slots('2025-09-10', 1.0)
        expected_slots = [
          { start: Time.new(2025, 9, 10, 9, 0), end: Time.new(2025, 9, 10, 18, 0) }
        ]
        assert_equal expected_slots, slots
      end
    end
  end
end
