require 'net/http'
require 'json'

class WeatherAPIError < StandardError
  private_class_method :new

  attr_reader :message

  def initialize(message, code = nil)
    @message = message
    @code = code
  end

  CITY_NOT_FOUND = new('City not found', '404')
  SERVER_ERROR   = new('Server error', '500')
  UNKNOWN_ERROR  = new('Unknown error')
end

class WeatherMessageGenerator
  WEATHER_METRICS_UNIT = {
    'temperature' => "\u00b0C",
    'humidity'    => '%',
    'wind_speed'  => 'km/h'
  }

  WEATHER_METRICS_DISPLAYED_LABEL = {
    'temperature' => 'Temperature',
    'description' => 'Description',
    'humidity'    => 'Humidity',
    'wind_speed'  => 'Wind'
  }

  def initialize(city)
    @city = city
  end

  def generate_weather_message(weather_detail)
    "Weather in #{@city}: ".concat(
      weather_detail.map { |metric, value| generate_weather_metric_message(metric, value) }.join(", ")
    )
  end

  def generate_forecast_message(days, forecast_detail)
    forecast_multiple_days = forecast_detail['forecasts']

    "#{days}-day forecast for #{@city}:\n".concat(
      forecast_multiple_days.map { |forecast_single_day| generate_forecast_single_day_message(forecast_single_day) }.join
    )
  end

  private

  def generate_weather_metric_message(metric, value)
    metric_label = WEATHER_METRICS_DISPLAYED_LABEL[metric]
    metric_unit = WEATHER_METRICS_UNIT[metric]

    if metric_unit
      "#{metric_label}: #{value}#{metric_unit}"
    else
      "#{metric_label}: #{value}"
    end
  end

  def generate_forecast_single_day_message(forecast_single_day)
    date = forecast_single_day['date']
    temperature_value = forecast_single_day['temperature']
    temperature_unit = WEATHER_METRICS_UNIT['temperature']
    description = forecast_single_day['description']

    "#{date}: #{temperature_value}#{temperature_unit}, #{description}\n"
  end
end

class WeatherAPI
  BASE_PATH = 'https://api.weather.example.com/v1/'

  def get_weather(city)
    with_error_handling do
      return nil unless valid_city_input?(city)

      handle_response(make_request('current', { city: })) do |weather_detail|
        generate_weather_message(city, weather_detail)
      end
    end
  end

  def get_forecast(city, days)
    with_error_handling do
      return nil unless valid_city_input?(city) && valid_days_input?(days)

      handle_response(make_request('forecast', { city:, days: })) do |forecast_detail|
        generate_forecast_message(city, days, forecast_detail)
      end
    end
  end

  private

  def with_error_handling
    yield
  rescue WeatherAPIError => e
    e.message
  rescue StandardError => e
    "Error: #{e.message}"
  end

  def parse_response(response)
    JSON.parse(response.body)
  end

  def handle_response(response)
    case response.code
    when '200'
      parsed_body = parse_response(response)
      yield(parsed_body)
    when '404'
      raise WeatherAPIError::CITY_NOT_FOUND
    when '500'
      raise WeatherAPIError::SERVER_ERROR
    else
      raise WeatherAPIError::UNKNOWN_ERROR
    end
  end

  def build_uri(endpoint, params = {})
    uri = URI.join(BASE_PATH, endpoint)
    uri.query = URI.encode_www_form(params) unless params.empty?
    uri
  end

  def fetch_response(uri)
    Net::HTTP.get_response(uri)
  end

  def make_request(endpoint, params = {})
    uri = build_uri(endpoint, params)
    fetch_response(uri)
  end

  def valid_city_input?(city)
    return false unless city

    !city.empty?
  end

  def valid_days_input?(days)
    return false unless days

    days.is_a?(Integer) && days.between?(2, 6)
  end

  def generate_weather_message(city, weather_detail)
    WeatherMessageGenerator.new(city).generate_weather_message(weather_detail)
  end

  def generate_forecast_message(city, days, forecast_detail)
    WeatherMessageGenerator.new(city).generate_forecast_message(days, forecast_detail)
  end
end
