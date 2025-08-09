require 'net/http'
require 'json'

class WeatherAPIError < StandardError
  private_class_method :new

  attr_reader :message, :code

  def initialize(message, code = nil)
    @message = message
    @code = code
  end

  CITY_NOT_FOUND = new('City not found', '404')
  SERVER_ERROR   = new('Server error', '500')
  UNKNOWN_ERROR  = new('Unknown error')
end

class WeatherAPI
  BASE_PATH = 'https://api.weather.example.com/v1/'

  WEATHER_METRICS_UNIT = {
    'temperature' => "\u00b0C",
    'humidity' => '%',
    'wind_speed' => 'km/h'
  }

  WEATHER_METRICS_DISPLAYED_LABEL = {
    'temperature' => 'Temperature',
    'description' => 'Description',
    'humidity' => 'Humidity',
    'wind_speed' => 'Wind'
  }

  def get_weather(city)
    with_error_handling do
      return nil unless valid_city_input?(city)

      uri = build_uri('current', { city: })

      handle_response(Net::HTTP.get_response(uri)) do |weather_detail|
        weather_message(city, weather_detail)
      end
    end
  end

  def get_forecast(city, days)
    with_error_handling do
      return nil unless valid_city_input?(city) && valid_days_input?(days)

      uri = build_uri('forecast', { city:, days: })

      handle_response(Net::HTTP.get_response(uri)) do |forecast_detail|
        forecast_multiple_days = forecast_detail['forecasts']
        forecast_message(city, days, forecast_multiple_days)
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

  def build_uri(path, query_params = {})
    uri = URI.join(BASE_PATH, path)
    uri.query = URI.encode_www_form(query_params) unless query_params.empty?
    uri
  end

  def handle_response(response)
    case response.code
    when '200'
      parsed_body = JSON.parse(response.body)
      yield(parsed_body)
    when '404'
      raise WeatherAPIError::CITY_NOT_FOUND
    when '500'
      raise WeatherAPIError::SERVER_ERROR
    else
      raise WeatherAPIError::UNKNOWN_ERROR
    end
  end

  def valid_city_input?(city)
    return false unless city

    !city.empty?
  end

  def valid_days_input?(days)
    return false unless days

    days.is_a?(Integer) && days.between?(2, 6)
  end

  def weather_metric_message(metric, value)
    if WEATHER_METRICS_UNIT[metric]
      "#{WEATHER_METRICS_DISPLAYED_LABEL[metric]}: #{value}#{WEATHER_METRICS_UNIT[metric]}"
    else
      "#{WEATHER_METRICS_DISPLAYED_LABEL[metric]}: #{value}"
    end
  end

  def weather_message(city, weather_detail)
    "Weather in #{city}: ".concat(
      weather_detail.map { |metric, value| weather_metric_message(metric, value) }.join(", ")
    )
  end

  def forecast_single_day_message(forecast_single_day)
    "#{forecast_single_day['date']}: #{forecast_single_day['temperature']}#{WEATHER_METRICS_UNIT['temperature']}, #{forecast_single_day['description']}\n"
  end

  def forecast_message(city, days, forecast_multiple_days)
    "#{days}-day forecast for #{city}:\n".concat(
      forecast_multiple_days.map do |forecast_single_day|
        forecast_single_day_message(forecast_single_day)
      end.join
    )
  end
end
